-- v0.256: o evento da Hotmart é gravado inteiro numa tabela bruta só dela; depois o banco trata e atualiza vendas e clientes.
-- O bruto guarda tudo, inclusive CPF e endereço: sem acesso direto pelo app, só pelas funções abaixo, que não devolvem o payload.
-- Aditiva. plataforma_eventos (criada na v0.255) só é removida se estiver vazia; se tiver linhas, elas são copiadas antes.
-- Para desfazer: drop do gatilho e de hotmart_vendas_bruto, e reaplicar as funções da v0.255.

create table if not exists public.hotmart_vendas_bruto (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  evento_id text not null,
  evento text not null,
  transacao text,
  produto_externo text,
  produto_nome text,
  payload jsonb not null,
  ocorrido_em timestamptz,
  recebido_em timestamptz not null default now(),
  tratamento text not null default 'aguardando' check (tratamento in ('aguardando', 'processado', 'ignorado', 'revisar', 'erro')),
  motivo text,
  venda_id uuid references public.vendas(id) on delete set null,
  tratado_em timestamptz,
  unique (workspace_id, evento_id)
);
create index if not exists hotmart_bruto_trat_ix on public.hotmart_vendas_bruto (workspace_id, tratamento, recebido_em desc);
create index if not exists hotmart_bruto_tx_ix on public.hotmart_vendas_bruto (workspace_id, transacao);
alter table public.hotmart_vendas_bruto enable row level security;
revoke all on public.hotmart_vendas_bruto from anon, authenticated;

do $m$
begin
  if to_regclass('public.plataforma_eventos') is not null then
    insert into public.hotmart_vendas_bruto (workspace_id, evento_id, evento, transacao, produto_externo, produto_nome, payload, ocorrido_em, recebido_em, tratamento, motivo, venda_id, tratado_em)
    select workspace_id, evento_id, evento, transacao, produto_externo, produto_nome, payload, ocorrido_em, recebido_em, situacao, motivo, venda_id, recebido_em
      from public.plataforma_eventos where provedor = 'hotmart'
    on conflict (workspace_id, evento_id) do nothing;
    drop table public.plataforma_eventos;
  end if;
end $m$;

-- cliente: procura por e-mail, telefone e documento. Se já existe, não cria outro: só completa o que estiver vazio.
create or replace function public._hotmart_cliente(p_ws uuid, b jsonb, p_src text) returns uuid language plpgsql security definer set search_path = public as $$
declare e text; f text; fone text; ddi text; doc text; em text; nm text; pid uuid; p pessoas; ender jsonb;
begin
  em := nullif(lower(trim(coalesce(b ->> 'email', ''))), ''); e := norm_email(em);
  ddi := regexp_replace(coalesce(b ->> 'checkout_phone_code', ''), '\D', '', 'g');
  fone := regexp_replace(coalesce(b ->> 'checkout_phone', ''), '\D', '', 'g');
  if fone <> '' and ddi <> '' and left(fone, length(ddi)) <> ddi then fone := ddi || fone; end if;
  fone := nullif(fone, ''); f := norm_fone(fone);
  doc := nullif(regexp_replace(coalesce(b ->> 'document', ''), '\D', '', 'g'), '');
  if doc is not null and not (doc ~ '^\d{11}$|^\d{14}$' and documento_valido(doc)) then doc := null; end if;
  if e is null and f is null and doc is null then return null; end if;
  nm := left(coalesce(nullif(trim(b ->> 'name'), ''), em, fone, doc), 160);
  ender := case when jsonb_typeof(b -> 'address') = 'object' then b -> 'address' end;

  if e is not null then select id into pid from pessoas where workspace_id = p_ws and email_norm = e; end if;
  if pid is null and f is not null then select id into pid from pessoas where workspace_id = p_ws and telefone_norm = f; end if;
  if pid is null and doc is not null then select id into pid from pessoas where workspace_id = p_ws and documento = doc; end if;

  if pid is null then
    insert into pessoas (workspace_id, nome, email, telefone, documento, status_funil, utm_source, extras)
    values (p_ws, nm, em, fone, doc, 'lead', p_src, jsonb_strip_nulls(jsonb_build_object('endereco', ender)))
    returning id into pid;
    return pid;
  end if;
  select * into p from pessoas where id = pid;
  update pessoas set
    nome = case when coalesce(trim(p.nome), '') = '' or p.nome = p.email or p.nome = p.telefone then nm else p.nome end,
    email = case when p.email_norm is null and e is not null and not exists (select 1 from pessoas x where x.workspace_id = p_ws and x.email_norm = e) then em else p.email end,
    telefone = case when p.telefone_norm is null and f is not null and not exists (select 1 from pessoas x where x.workspace_id = p_ws and x.telefone_norm = f) then fone else p.telefone end,
    documento = case when p.documento is null and doc is not null and not exists (select 1 from pessoas x where x.workspace_id = p_ws and x.documento = doc) then doc else p.documento end,
    extras = case when ender is not null and not (coalesce(p.extras, '{}'::jsonb) ? 'endereco') then coalesce(p.extras, '{}'::jsonb) || jsonb_build_object('endereco', ender) else p.extras end
  where id = pid;
  return pid;
end $$;

-- aplica um evento: igual à v0.255, com o cliente tratado em _hotmart_cliente
create or replace function public._hotmart_aplicar(p_ws uuid, p_plat uuid, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  ev text := p ->> 'event'; d jsonb := coalesce(p -> 'data', '{}'::jsonb); c jsonb := coalesce(p -> 'data' -> 'purchase', '{}'::jsonb);
  b jsonb := coalesce(p -> 'data' -> 'buyer', '{}'::jsonb);
  tx text := nullif(c ->> 'transaction', ''); rec int := coalesce(nullif(c ->> 'recurrence_number', '')::int, 1);
  idx text; alvo text; pr uuid; pid uuid; of_ uuid; cp uuid; v vendas; moeda text; valor numeric;
  quando timestamptz; aprov timestamptz; forma text; bump boolean; pai text; sck text; n int; ex jsonb;
begin
  alvo := case ev
    when 'PURCHASE_APPROVED' then 'aprovada' when 'PURCHASE_COMPLETE' then 'aprovada'
    when 'PURCHASE_BILLET_PRINTED' then 'pendente'
    when 'PURCHASE_CANCELED' then 'cancelada' when 'PURCHASE_EXPIRED' then 'cancelada'
    when 'PURCHASE_REFUNDED' then 'reembolsada' when 'PURCHASE_CHARGEBACK' then 'chargeback' end;
  if alvo is null then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'Evento sem efeito na venda: ' || coalesce(ev, 'sem nome')); end if;
  if tx is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'O evento veio sem o código da transação.'); end if;
  idx := tx || case when rec > 1 then '-r' || rec else '' end;
  perform pg_advisory_xact_lock(hashtext(p_ws::text || idx));

  aprov := _hotmart_data(c ->> 'approved_date');
  quando := coalesce(aprov, _hotmart_data(c ->> 'order_date'), _hotmart_data(p ->> 'creation_date'), now());

  select * into v from vendas where workspace_id = p_ws and id_externo = idx and (plataforma_id = p_plat or plataforma_id is null) limit 1;
  if v.id is not null then
    if v.status = alvo then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já estava ' || alvo || '.', 'venda_id', v.id); end if;
    if v.status in ('reembolsada', 'chargeback') and alvo not in ('reembolsada', 'chargeback') then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já está ' || v.status || '; o evento atrasado não muda isso.', 'venda_id', v.id); end if;
    if alvo = 'pendente' then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já está ' || v.status || '.', 'venda_id', v.id); end if;
    if alvo = 'aprovada' then
      if exists (select 1 from estornos where venda_id = v.id) then return jsonb_build_object('situacao', 'revisar', 'motivo', 'Aprovação recebida para uma venda já estornada. Confira na Hotmart.', 'venda_id', v.id); end if;
      update vendas set status = 'aprovada', aprovada_em = coalesce(aprov, now()) where id = v.id;
    elsif v.status = 'aprovada' and exists (select 1 from lancamentos where origem_tipo = 'venda' and origem_id = v.id) then
      perform registrar_estorno(v.id, case alvo when 'cancelada' then 'cancelamento' when 'reembolsada' then 'reembolso' else 'chargeback' end, 'Hotmart: ' || ev, (coalesce(_hotmart_data(p ->> 'creation_date'), now()) at time zone 'America/Sao_Paulo')::date);
    else
      update vendas set status = alvo where id = v.id;
    end if;
    return jsonb_build_object('situacao', 'processado', 'motivo', 'Venda atualizada para ' || alvo || '.', 'venda_id', v.id);
  end if;

  moeda := upper(coalesce(c -> 'price' ->> 'currency_value', 'BRL'));
  valor := nullif(c -> 'price' ->> 'value', '')::numeric;
  if valor is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'O evento veio sem o valor da venda.'); end if;
  if moeda <> 'BRL' then return jsonb_build_object('situacao', 'revisar', 'motivo', 'Venda em ' || moeda || '. Ainda não convertemos moeda: lance em reais.'); end if;

  select x.produto_id into pr from plataforma_produto_vinculos x
    where x.workspace_id = p_ws and x.plataforma_id = p_plat and x.id_externo = d -> 'product' ->> 'id';
  if pr is null then
    select x.produto_id into pr from produto_plataforma x where x.workspace_id = p_ws and x.plataforma_id = p_plat
      and x.id_externo in (d -> 'product' ->> 'id', d -> 'product' ->> 'ucode') limit 1;
  end if;
  if pr is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'Produto da Hotmart ainda não ligado a um produto do Growths.'); end if;

  pid := _hotmart_cliente(p_ws, b, nullif(c -> 'origin' ->> 'src', ''));
  if pid is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'A Hotmart não enviou e-mail, telefone nem documento do comprador.'); end if;

  bump := coalesce((c -> 'order_bump' ->> 'is_order_bump')::boolean, false);
  pai := nullif(c -> 'order_bump' ->> 'parent_purchase_transaction', '');
  sck := nullif(c -> 'origin' ->> 'sck', '');
  select count(*), min(o.id::text)::uuid into n, of_ from ofertas o where o.workspace_id = p_ws and o.produto_id = pr and o.ativo and o.preco = valor;
  if n > 1 then
    select count(*), min(o.id::text)::uuid into n, of_ from ofertas o where o.workspace_id = p_ws and o.produto_id = pr and o.ativo and o.preco = valor and (o.papel = 'order_bump') = bump;
    if n <> 1 then of_ := null; end if;
  end if;
  if of_ is not null and not exists (select 1 from campanha_vendedores where workspace_id = p_ws and codigo = sck) then
    select count(*), min(k.id::text)::uuid into n, cp from campanhas k join campanha_ofertas co on co.campanha_id = k.id
      where k.workspace_id = p_ws and co.oferta_id = of_ and k.status = 'ativa' and (quando at time zone 'America/Sao_Paulo')::date between coalesce(k.data_inicio, '-infinity'::date) and coalesce(k.data_fim, 'infinity'::date);
    if n <> 1 then cp := null; end if;
  end if;
  forma := case when c -> 'payment' ->> 'type' = 'CREDIT_CARD' then 'cartao_credito' when c -> 'payment' ->> 'type' = 'PIX' then 'pix' when c -> 'payment' ->> 'type' in ('BILLET', 'FINANCED_BILLET') then 'boleto' else 'outro' end;
  ex := jsonb_strip_nulls(jsonb_build_object('fonte', 'hotmart', 'sck', sck, 'src', nullif(c -> 'origin' ->> 'src', ''), 'xcod', nullif(c -> 'origin' ->> 'xcod', ''),
    'oferta_codigo', nullif(c -> 'offer' ->> 'code', ''), 'cupom', nullif(c -> 'offer' ->> 'coupon_code', ''), 'order_bump', case when bump then true end,
    'recorrencia', case when rec > 1 then rec end, 'preco_total', c -> 'full_price' -> 'value', 'comissoes_hotmart', d -> 'commissions', 'produto_hotmart', d -> 'product' ->> 'name'));

  insert into vendas (workspace_id, pessoa_id, produto_id, oferta_id, plataforma_id, campanha_id, forma_pagamento, parcelas, status, data_venda, valor_bruto, id_externo, pedido_ref, utm_source, utm_content, comprador_email, comprador_telefone, aprovada_em, origem_dado, extras)
  values (p_ws, pid, pr, of_, p_plat, cp, forma, greatest(coalesce(nullif(c -> 'payment' ->> 'installments_number', '')::int, 1), 1), alvo, quando, valor, idx, coalesce(pai, tx), nullif(c -> 'origin' ->> 'src', ''), sck, nullif(lower(trim(coalesce(b ->> 'email', ''))), ''), nullif(regexp_replace(coalesce(b ->> 'checkout_phone', ''), '\D', '', 'g'), ''), aprov, 'integracao', ex)
  returning * into v;
  return jsonb_build_object('situacao', 'processado', 'motivo', 'Venda criada (' || alvo || ').', 'venda_id', v.id);
end $$;

-- trata uma linha do bruto. Se o tratamento falhar, a linha bruta continua gravada, com o erro.
create or replace function public._hotmart_bruto_tratar(p_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare l hotmart_vendas_bruto; cfg plataforma_webhooks; r jsonb;
begin
  select * into l from hotmart_vendas_bruto where id = p_id;
  select * into cfg from plataforma_webhooks where workspace_id = l.workspace_id and provedor = 'hotmart';
  if cfg.workspace_id is null then return jsonb_build_object('situacao', 'aguardando'); end if;
  r := _hotmart_tenta(l.workspace_id, cfg.plataforma_id, l.payload);
  update hotmart_vendas_bruto set tratamento = r ->> 'situacao', motivo = r ->> 'motivo', venda_id = coalesce(nullif(r ->> 'venda_id', '')::uuid, venda_id), tratado_em = now() where id = p_id;
  return r;
end $$;

create or replace function public._hotmart_bruto_trg() returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform _hotmart_bruto_tratar(new.id);
  return null;
end $$;
drop trigger if exists hotmart_bruto_tratar_t on public.hotmart_vendas_bruto;
create trigger hotmart_bruto_tratar_t after insert on public.hotmart_vendas_bruto for each row execute function public._hotmart_bruto_trg();

-- entrada do webhook: confere o acesso e grava o bruto. O gatilho faz o tratamento.
create or replace function public.hotmart_webhook(p_chave text, p_hottok text, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare w uuid; cfg plataforma_webhooks; ev_id text; l hotmart_vendas_bruto; rid uuid;
begin
  w := chave_api_ws_escopo(p_chave, 'vendas');
  select * into cfg from plataforma_webhooks where workspace_id = w and provedor = 'hotmart';
  if cfg.workspace_id is null or cfg.segredo_hash is distinct from chave_api_hash(coalesce(p_hottok, '')) then raise exception 'Hottok inválido' using errcode = '28000'; end if;
  ev_id := coalesce(nullif(p ->> 'id', ''), md5(p::text));
  insert into hotmart_vendas_bruto (workspace_id, evento_id, evento, transacao, produto_externo, produto_nome, payload, ocorrido_em)
  values (w, ev_id, coalesce(p ->> 'event', 'desconhecido'), p -> 'data' -> 'purchase' ->> 'transaction', p -> 'data' -> 'product' ->> 'id', p -> 'data' -> 'product' ->> 'name', p, _hotmart_data(p ->> 'creation_date'))
  on conflict (workspace_id, evento_id) do nothing returning id into rid;
  if rid is null then return jsonb_build_object('ok', true, 'situacao', 'repetido'); end if;
  select * into l from hotmart_vendas_bruto where id = rid;
  update plataforma_webhooks set ultimo_evento_em = now() where workspace_id = w and provedor = 'hotmart';
  update integracoes set status = 'conectado', ultima_sincronizacao = now() where workspace_id = w and provedor = 'Hotmart';
  return jsonb_build_object('ok', true, 'situacao', l.tratamento, 'motivo', l.motivo);
end $$;

-- painel da tela: não devolve o payload
create or replace function public.hotmart_painel(p_ws uuid) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare cfg plataforma_webhooks;
begin
  if not pertence_ao_workspace(p_ws) or not perm(p_ws, 'ler', array['vendas', 'fin', 'cad']) then raise exception 'Sem acesso'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = 'hotmart';
  return jsonb_build_object(
    'configurado', cfg.workspace_id is not null, 'plataforma_id', cfg.plataforma_id, 'ultimo_evento_em', cfg.ultimo_evento_em,
    'pode_editar', _hotmart_pode(p_ws),
    'recebidos', (select count(*) from hotmart_vendas_bruto where workspace_id = p_ws and recebido_em > now() - interval '30 days'),
    'processados', (select count(*) from hotmart_vendas_bruto where workspace_id = p_ws and tratamento = 'processado' and recebido_em > now() - interval '30 days'),
    'revisar', (select count(*) from hotmart_vendas_bruto where workspace_id = p_ws and tratamento in ('revisar', 'erro')),
    'sem_ligacao', (select coalesce(jsonb_agg(x order by x.ultimo desc), '[]'::jsonb) from (
       select produto_externo as id, max(produto_nome) as nome, count(*) as eventos, max(recebido_em) as ultimo from hotmart_vendas_bruto
        where workspace_id = p_ws and tratamento = 'revisar' and motivo like 'Produto da Hotmart%' and produto_externo is not null group by produto_externo) x),
    'ultimos', (select coalesce(jsonb_agg(y), '[]'::jsonb) from (
       select id, evento, transacao, produto_nome, tratamento as situacao, motivo, recebido_em, venda_id from hotmart_vendas_bruto where workspace_id = p_ws order by recebido_em desc limit 15) y));
end $$;

-- trata de novo o que ficou a revisar ou com erro, na ordem em que aconteceu
create or replace function public.hotmart_reprocessar(p_ws uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg plataforma_webhooks; l record; r jsonb; ok int := 0; resta int := 0;
begin
  if auth.uid() is null or not _hotmart_pode(p_ws) then raise exception 'Sem permissão para reprocessar'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = 'hotmart';
  if cfg.workspace_id is null then raise exception 'Integração ainda não configurada'; end if;
  for l in select id from hotmart_vendas_bruto where workspace_id = p_ws and tratamento in ('aguardando', 'revisar', 'erro') order by coalesce(ocorrido_em, recebido_em) loop
    r := _hotmart_bruto_tratar(l.id);
    if r ->> 'situacao' in ('revisar', 'erro', 'aguardando') then resta := resta + 1; else ok := ok + 1; end if;
  end loop;
  return jsonb_build_object('resolvidos', ok, 'restam', resta);
end $$;

revoke execute on function public._hotmart_cliente(uuid, jsonb, text), public._hotmart_bruto_tratar(uuid), public._hotmart_bruto_trg() from public, anon, authenticated;
revoke execute on function public._hotmart_aplicar(uuid, uuid, jsonb), public.hotmart_webhook(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.hotmart_webhook(text, text, jsonb) to service_role;

notify pgrst, 'reload schema';
