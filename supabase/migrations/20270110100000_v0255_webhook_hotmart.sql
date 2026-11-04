-- v0.255: vendas da Hotmart entram sozinhas, pelo webhook 2.0.0 (função vendas-hotmart).
-- Aditiva e idempotente. Depende da v0.254 (código do vendedor em extras.sck).
-- Para desfazer: revogar a chave em chaves_api, drop das funções hotmart_* e das tabelas plataforma_webhooks,
-- plataforma_eventos e plataforma_produto_vinculos. As vendas já criadas continuam (origem_dado = 'integracao').

-- configuração por workspace. O hottok fica só como hash.
create table if not exists public.plataforma_webhooks (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  provedor text not null check (provedor in ('hotmart')),
  plataforma_id uuid not null references public.plataformas_venda(id),
  chave_id uuid references public.chaves_api(id) on delete set null,
  segredo_hash text not null,
  criado_em timestamptz not null default now(),
  ultimo_evento_em timestamptz,
  primary key (workspace_id, provedor)
);

-- tudo o que chega fica registrado, para conferir e reprocessar. Documento, endereço e dados de pagamento não são guardados.
create table if not exists public.plataforma_eventos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  provedor text not null,
  evento_id text not null,
  evento text not null,
  transacao text,
  produto_externo text,
  produto_nome text,
  situacao text not null check (situacao in ('processado', 'ignorado', 'revisar', 'erro')),
  motivo text,
  venda_id uuid references public.vendas(id) on delete set null,
  payload jsonb not null,
  ocorrido_em timestamptz,
  recebido_em timestamptz not null default now(),
  unique (workspace_id, provedor, evento_id)
);
create index if not exists plataforma_eventos_rev_ix on public.plataforma_eventos (workspace_id, situacao, recebido_em desc);

-- produto da plataforma → produto do Growths (mais de um produto da plataforma pode ir para o mesmo)
create table if not exists public.plataforma_produto_vinculos (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  plataforma_id uuid not null references public.plataformas_venda(id) on delete cascade,
  id_externo text not null,
  produto_id uuid not null references public.produtos(id) on delete cascade,
  criado_em timestamptz not null default now(),
  primary key (workspace_id, plataforma_id, id_externo)
);

alter table public.plataforma_webhooks enable row level security;
alter table public.plataforma_eventos enable row level security;
alter table public.plataforma_produto_vinculos enable row level security;
-- sem políticas de escrita: tudo passa pelas funções abaixo. Leitura direta só pelo painel.
revoke all on public.plataforma_webhooks, public.plataforma_eventos, public.plataforma_produto_vinculos from anon, authenticated;

-- número em milissegundos (ou texto com número, ou data ISO) → timestamptz
create or replace function public._hotmart_data(p text) returns timestamptz language plpgsql immutable set search_path = public as $$
begin
  if p is null or p = '' then return null; end if;
  if p ~ '^\d{10,}$' then return to_timestamp(p::numeric / 1000); end if;
  return p::timestamptz;
exception when others then return null;
end $$;

-- aplica um evento. Levanta exceção em erro inesperado (quem chama registra). Retorna situacao, motivo, venda_id.
create or replace function public._hotmart_aplicar(p_ws uuid, p_plat uuid, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  ev text := p ->> 'event'; d jsonb := coalesce(p -> 'data', '{}'::jsonb); c jsonb := coalesce(p -> 'data' -> 'purchase', '{}'::jsonb);
  b jsonb := coalesce(p -> 'data' -> 'buyer', '{}'::jsonb);
  tx text := nullif(c ->> 'transaction', ''); rec int := coalesce(nullif(c ->> 'recurrence_number', '')::int, 1);
  idx text; alvo text; pr uuid; pid uuid; of_ uuid; cp uuid; v vendas; e text; f text; fone text; ddi text; moeda text; valor numeric;
  quando timestamptz; aprov timestamptz; forma text; bump boolean; pai text; sck text; n int; ex jsonb;
begin
  alvo := case ev
    when 'PURCHASE_APPROVED' then 'aprovada' when 'PURCHASE_COMPLETE' then 'aprovada'
    when 'PURCHASE_BILLET_PRINTED' then 'pendente'
    when 'PURCHASE_CANCELED' then 'cancelada' when 'PURCHASE_EXPIRED' then 'cancelada'
    when 'PURCHASE_REFUNDED' then 'reembolsada' when 'PURCHASE_CHARGEBACK' then 'chargeback' end;
  if alvo is null then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'Evento sem efeito na venda: ' || coalesce(ev, 'sem nome')); end if;
  if tx is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'O evento veio sem o código da transação.'); end if;
  -- cada renovação de assinatura é uma venda
  idx := tx || case when rec > 1 then '-r' || rec else '' end;
  perform pg_advisory_xact_lock(hashtext(p_ws::text || idx));

  aprov := _hotmart_data(c ->> 'approved_date');
  quando := coalesce(aprov, _hotmart_data(c ->> 'order_date'), _hotmart_data(p ->> 'creation_date'), now());

  select * into v from vendas where workspace_id = p_ws and id_externo = idx and (plataforma_id = p_plat or plataforma_id is null) limit 1;
  if v.id is not null then
    if v.status = alvo then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já estava ' || alvo || '.', 'venda_id', v.id); end if;
    -- status final não volta atrás, mesmo com evento fora de ordem; venda estornada só muda pela tela
    if v.status in ('reembolsada', 'chargeback') and alvo not in ('reembolsada', 'chargeback') then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já está ' || v.status || '; o evento atrasado não muda isso.', 'venda_id', v.id); end if;
    if alvo = 'pendente' then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já está ' || v.status || '.', 'venda_id', v.id); end if;
    if alvo = 'aprovada' then
      if exists (select 1 from estornos where venda_id = v.id) then return jsonb_build_object('situacao', 'revisar', 'motivo', 'Aprovação recebida para uma venda já estornada. Confira na Hotmart.', 'venda_id', v.id); end if;
      update vendas set status = 'aprovada', aprovada_em = coalesce(aprov, now()) where id = v.id;
    elsif v.status = 'aprovada' and exists (select 1 from lancamentos where origem_tipo = 'venda' and origem_id = v.id) then
      -- mesmo caminho do estorno pela tela: contabilidade, conta a receber, matrícula e situação do cliente
      perform registrar_estorno(v.id, case alvo when 'cancelada' then 'cancelamento' when 'reembolsada' then 'reembolso' else 'chargeback' end, 'Hotmart: ' || ev, (coalesce(_hotmart_data(p ->> 'creation_date'), now()) at time zone 'America/Sao_Paulo')::date);
    else
      update vendas set status = alvo where id = v.id;
    end if;
    return jsonb_build_object('situacao', 'processado', 'motivo', 'Venda atualizada para ' || alvo || '.', 'venda_id', v.id);
  end if;

  -- venda nova
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

  e := norm_email(nullif(lower(trim(coalesce(b ->> 'email', ''))), ''));
  ddi := regexp_replace(coalesce(b ->> 'checkout_phone_code', ''), '\D', '', 'g');
  fone := regexp_replace(coalesce(b ->> 'checkout_phone', ''), '\D', '', 'g');
  if fone <> '' and ddi <> '' and left(fone, length(ddi)) <> ddi then fone := ddi || fone; end if;
  fone := nullif(fone, ''); f := norm_fone(fone);
  if e is null and f is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'A Hotmart não enviou e-mail nem telefone do comprador.'); end if;
  if e is not null then select id into pid from pessoas where workspace_id = p_ws and email_norm = e; end if;
  if pid is null and f is not null then select id into pid from pessoas where workspace_id = p_ws and telefone_norm = f; end if;
  if pid is null then
    insert into pessoas (workspace_id, nome, email, telefone, status_funil, utm_source)
    values (p_ws, left(coalesce(nullif(trim(b ->> 'name'), ''), nullif(lower(trim(b ->> 'email')), ''), fone), 160), nullif(lower(trim(coalesce(b ->> 'email', ''))), ''), fone, 'lead', nullif(c -> 'origin' ->> 'src', ''))
    returning id into pid;
  end if;

  bump := coalesce((c -> 'order_bump' ->> 'is_order_bump')::boolean, false);
  pai := nullif(c -> 'order_bump' ->> 'parent_purchase_transaction', '');
  sck := nullif(c -> 'origin' ->> 'sck', '');
  -- oferta: a única ativa do produto com o mesmo preço (o order bump prefere o papel certo)
  select count(*), min(o.id::text)::uuid into n, of_ from ofertas o where o.workspace_id = p_ws and o.produto_id = pr and o.ativo and o.preco = valor;
  if n > 1 then
    select count(*), min(o.id::text)::uuid into n, of_ from ofertas o where o.workspace_id = p_ws and o.produto_id = pr and o.ativo and o.preco = valor and (o.papel = 'order_bump') = bump;
    if n <> 1 then of_ := null; end if;
  end if;
  -- campanha: sem código de vendedor, a única campanha ativa com essa oferta no período; se não houver, a da pessoa (gatilho)
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
  values (p_ws, pid, pr, of_, p_plat, cp, forma, greatest(coalesce(nullif(c -> 'payment' ->> 'installments_number', '')::int, 1), 1), alvo, quando, valor, idx, coalesce(pai, tx), nullif(c -> 'origin' ->> 'src', ''), sck, nullif(lower(trim(coalesce(b ->> 'email', ''))), ''), fone, aprov, 'integracao', ex)
  returning * into v;
  return jsonb_build_object('situacao', 'processado', 'motivo', 'Venda criada (' || alvo || ').', 'venda_id', v.id);
end $$;

-- roda o evento isolado: se algo falhar, nada da venda fica gravado pela metade e o erro vai para o registro
create or replace function public._hotmart_tenta(p_ws uuid, p_plat uuid, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  return _hotmart_aplicar(p_ws, p_plat, p);
exception when others then
  return jsonb_build_object('situacao', 'erro', 'motivo', left(sqlerrm, 300));
end $$;

-- entrada do webhook: só a função vendas-hotmart chama (papel service_role)
create or replace function public.hotmart_webhook(p_chave text, p_hottok text, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare w uuid; cfg plataforma_webhooks; r jsonb; ev_id text; lim jsonb; e_id uuid;
begin
  w := chave_api_ws_escopo(p_chave, 'vendas');
  select * into cfg from plataforma_webhooks where workspace_id = w and provedor = 'hotmart';
  if cfg.workspace_id is null or cfg.segredo_hash is distinct from chave_api_hash(coalesce(p_hottok, '')) then raise exception 'Hottok inválido' using errcode = '28000'; end if;
  ev_id := coalesce(nullif(p ->> 'id', ''), md5(p::text));
  if exists (select 1 from plataforma_eventos where workspace_id = w and provedor = 'hotmart' and evento_id = ev_id) then
    return jsonb_build_object('ok', true, 'situacao', 'repetido');
  end if;
  r := _hotmart_tenta(w, cfg.plataforma_id, p);
  -- sem documento, endereço e dados de pagamento
  lim := p #- '{data,buyer,document}' #- '{data,buyer,document_type}' #- '{data,buyer,address}' #- '{data,producer}' #- '{data,purchase,payment,billet_barcode}' #- '{data,purchase,payment,billet_url}' #- '{data,purchase,payment,pix_code}' #- '{data,purchase,payment,pix_qrcode}';
  insert into plataforma_eventos (workspace_id, provedor, evento_id, evento, transacao, produto_externo, produto_nome, situacao, motivo, venda_id, payload, ocorrido_em)
  values (w, 'hotmart', ev_id, coalesce(p ->> 'event', 'desconhecido'), p -> 'data' -> 'purchase' ->> 'transaction', p -> 'data' -> 'product' ->> 'id', p -> 'data' -> 'product' ->> 'name', r ->> 'situacao', r ->> 'motivo', nullif(r ->> 'venda_id', '')::uuid, lim, _hotmart_data(p ->> 'creation_date'))
  on conflict (workspace_id, provedor, evento_id) do nothing returning id into e_id;
  update plataforma_webhooks set ultimo_evento_em = now() where workspace_id = w and provedor = 'hotmart';
  update integracoes set status = 'conectado', ultima_sincronizacao = now() where workspace_id = w and provedor = 'Hotmart';
  return jsonb_build_object('ok', true, 'situacao', r ->> 'situacao', 'motivo', r ->> 'motivo');
end $$;

create or replace function public._hotmart_pode(p_ws uuid) returns boolean language sql stable security definer set search_path = public as $$
  select pode_editar(p_ws, array['vendas', 'fin', 'cad']);
$$;

-- configurar: grava o hottok e, se pedido, gera um endereço novo (o antigo deixa de valer). Devolve a chave uma única vez.
create or replace function public.hotmart_configurar(p_ws uuid, p_plataforma uuid, p_hottok text, p_novo_endereco boolean default false) returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg plataforma_webhooks; k text; cid uuid; tok text := nullif(trim(coalesce(p_hottok, '')), '');
begin
  if auth.uid() is null or not _hotmart_pode(p_ws) then raise exception 'Só quem edita Vendas, Financeiro ou Cadastros pode configurar a integração'; end if;
  if not exists (select 1 from plataformas_venda where id = p_plataforma and workspace_id = p_ws) then raise exception 'Escolha a plataforma cadastrada neste workspace'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = 'hotmart';
  if cfg.workspace_id is null and tok is null then raise exception 'Cole o hottok da sua conta Hotmart'; end if;
  if tok is not null and char_length(tok) < 10 then raise exception 'Esse hottok parece incompleto. Copie de novo na Hotmart'; end if;
  cid := cfg.chave_id;
  if cfg.workspace_id is null or p_novo_endereco then
    if cid is not null then update chaves_api set revogada_em = now() where id = cid and revogada_em is null; end if;
    k := 'gw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    insert into chaves_api (workspace_id, nome, escopo, prefixo, hash) values (p_ws, 'Webhook Hotmart', 'vendas', left(k, 9), chave_api_hash(k)) returning id into cid;
  end if;
  insert into plataforma_webhooks (workspace_id, provedor, plataforma_id, chave_id, segredo_hash)
  values (p_ws, 'hotmart', p_plataforma, cid, case when tok is null then cfg.segredo_hash else chave_api_hash(tok) end)
  on conflict (workspace_id, provedor) do update set plataforma_id = excluded.plataforma_id, chave_id = excluded.chave_id, segredo_hash = excluded.segredo_hash;
  insert into integracoes (workspace_id, provedor, categoria, status)
  values (p_ws, 'Hotmart', 'vendas', 'configurando') on conflict (workspace_id, provedor) do nothing;
  return jsonb_build_object('chave', k);
end $$;

-- painel da tela
create or replace function public.hotmart_painel(p_ws uuid) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare cfg plataforma_webhooks;
begin
  if not pertence_ao_workspace(p_ws) or not perm(p_ws, 'ler', array['vendas', 'fin', 'cad']) then raise exception 'Sem acesso'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = 'hotmart';
  return jsonb_build_object(
    'configurado', cfg.workspace_id is not null, 'plataforma_id', cfg.plataforma_id, 'ultimo_evento_em', cfg.ultimo_evento_em,
    'pode_editar', _hotmart_pode(p_ws),
    'recebidos', (select count(*) from plataforma_eventos where workspace_id = p_ws and provedor = 'hotmart' and recebido_em > now() - interval '30 days'),
    'processados', (select count(*) from plataforma_eventos where workspace_id = p_ws and provedor = 'hotmart' and situacao = 'processado' and recebido_em > now() - interval '30 days'),
    'revisar', (select count(*) from plataforma_eventos where workspace_id = p_ws and provedor = 'hotmart' and situacao in ('revisar', 'erro')),
    'sem_ligacao', (select coalesce(jsonb_agg(x order by x.ultimo desc), '[]'::jsonb) from (
       select produto_externo as id, max(produto_nome) as nome, count(*) as eventos, max(recebido_em) as ultimo from plataforma_eventos
        where workspace_id = p_ws and provedor = 'hotmart' and situacao = 'revisar' and motivo like 'Produto da Hotmart%' and produto_externo is not null group by produto_externo) x),
    'ultimos', (select coalesce(jsonb_agg(y), '[]'::jsonb) from (
       select id, evento, transacao, produto_nome, situacao, motivo, recebido_em, venda_id from plataforma_eventos where workspace_id = p_ws and provedor = 'hotmart' order by recebido_em desc limit 15) y));
end $$;

-- reprocessa o que ficou a revisar ou com erro, na ordem em que chegou
create or replace function public.hotmart_reprocessar(p_ws uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg plataforma_webhooks; e plataforma_eventos; r jsonb; ok int := 0; resta int := 0;
begin
  if auth.uid() is null or not _hotmart_pode(p_ws) then raise exception 'Sem permissão para reprocessar'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = 'hotmart';
  if cfg.workspace_id is null then raise exception 'Integração ainda não configurada'; end if;
  for e in select * from plataforma_eventos where workspace_id = p_ws and provedor = 'hotmart' and situacao in ('revisar', 'erro') order by coalesce(ocorrido_em, recebido_em) loop
    r := _hotmart_tenta(p_ws, cfg.plataforma_id, e.payload);
    update plataforma_eventos set situacao = r ->> 'situacao', motivo = r ->> 'motivo', venda_id = coalesce(nullif(r ->> 'venda_id', '')::uuid, venda_id) where id = e.id;
    if r ->> 'situacao' in ('revisar', 'erro') then resta := resta + 1; else ok := ok + 1; end if;
  end loop;
  return jsonb_build_object('resolvidos', ok, 'restam', resta);
end $$;

-- liga um produto da Hotmart a um produto do Growths e processa o que estava esperando
create or replace function public.hotmart_ligar_produto(p_ws uuid, p_externo text, p_produto uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg plataforma_webhooks;
begin
  if auth.uid() is null or not _hotmart_pode(p_ws) then raise exception 'Sem permissão para ligar produtos'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = 'hotmart';
  if cfg.workspace_id is null then raise exception 'Integração ainda não configurada'; end if;
  if not exists (select 1 from produtos where id = p_produto and workspace_id = p_ws) then raise exception 'Escolha um produto deste workspace'; end if;
  if coalesce(trim(p_externo), '') = '' then raise exception 'Produto da Hotmart não informado'; end if;
  insert into plataforma_produto_vinculos (workspace_id, plataforma_id, id_externo, produto_id) values (p_ws, cfg.plataforma_id, p_externo, p_produto)
  on conflict (workspace_id, plataforma_id, id_externo) do update set produto_id = excluded.produto_id;
  return hotmart_reprocessar(p_ws);
end $$;

revoke execute on function public._hotmart_data(text), public._hotmart_aplicar(uuid, uuid, jsonb), public._hotmart_tenta(uuid, uuid, jsonb), public._hotmart_pode(uuid), public.hotmart_webhook(text, text, jsonb) from public, anon, authenticated;
revoke execute on function public.hotmart_configurar(uuid, uuid, text, boolean), public.hotmart_painel(uuid), public.hotmart_reprocessar(uuid), public.hotmart_ligar_produto(uuid, text, uuid) from public, anon;
grant execute on function public.hotmart_webhook(text, text, jsonb) to service_role;
grant execute on function public.hotmart_configurar(uuid, uuid, text, boolean), public.hotmart_painel(uuid), public.hotmart_reprocessar(uuid), public.hotmart_ligar_produto(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';
