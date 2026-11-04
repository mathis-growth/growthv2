-- v0.257: Kiwify, Eduzz e Hubla no mesmo modelo da Hotmart: bruto completo numa tabela por plataforma; depois o banco trata e atualiza vendas e clientes.
-- Aditiva e idempotente. Kiwify e Eduzz assinam o corpo com HMAC, por isso guardam o segredo em plataforma_webhooks.segredo_hmac (tabela sem acesso pelo app).
-- Para desfazer: drop das funções plataforma_* e _pv_*, das tabelas kiwify_, eduzz_ e hubla_vendas_bruto e da coluna segredo_hmac.

alter table public.plataforma_webhooks add column if not exists segredo_hmac text;
alter table public.plataforma_webhooks drop constraint if exists plataforma_webhooks_provedor_check;
alter table public.plataforma_webhooks add constraint plataforma_webhooks_provedor_check check (provedor in ('hotmart', 'kiwify', 'eduzz', 'hubla'));

do $m$
declare t text;
begin
  foreach t in array array['kiwify', 'eduzz', 'hubla'] loop
    execute format($f$create table if not exists public.%1$I (
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
      unique (workspace_id, evento_id))$f$, t || '_vendas_bruto');
    execute format('create index if not exists %I on public.%I (workspace_id, tratamento, recebido_em desc)', t || '_bruto_trat_ix', t || '_vendas_bruto');
    execute format('alter table public.%I enable row level security', t || '_vendas_bruto');
    execute format('revoke all on public.%I from anon, authenticated', t || '_vendas_bruto');
  end loop;
end $m$;

-- só estes três nomes viram tabela em SQL dinâmico
create or replace function public._pv_tabela(p_prov text) returns text language plpgsql immutable set search_path = public as $$
begin
  if p_prov not in ('kiwify', 'eduzz', 'hubla') then raise exception 'Plataforma inválida'; end if;
  return p_prov || '_vendas_bruto';
end $$;

-- data: número em ms, 'YYYY-MM-DD HH:mm' (horário de Brasília, na Kiwify) ou ISO
create or replace function public._pv_data(p text) returns timestamptz language plpgsql stable set search_path = public as $$
begin
  if p is null or p = '' then return null; end if;
  if p ~ '^\d{10,}$' then return to_timestamp(p::numeric / 1000); end if;
  if p ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$' then return p::timestamp at time zone 'America/Sao_Paulo'; end if;
  return p::timestamptz;
exception when others then return null;
end $$;

-- traduz o evento de cada plataforma para um formato único. Campo que não vier fica nulo e o tratamento manda para revisar.
create or replace function public._pv_normaliza(p_prov text, p jsonb) returns jsonb language plpgsql stable set search_path = public as $$
declare d jsonb; i jsonb; t text; st text; alvo text; b jsonb; tr jsonb; it jsonb; v numeric;
begin
  if p_prov = 'kiwify' then
    t := coalesce(p ->> 'webhook_event_type', ''); st := p ->> 'order_status';
    alvo := case t when 'order_approved' then 'aprovada' when 'billet_created' then 'pendente' when 'pix_created' then 'pendente' when 'order_refunded' then 'reembolsada' when 'chargeback' then 'chargeback' end;
    b := coalesce(p -> 'Customer', p -> 'customer', '{}'::jsonb); tr := coalesce(p -> 'TrackingParameters', p -> 'tracking', '{}'::jsonb);
    -- os exemplos da API trazem centavos
    v := coalesce(nullif(p -> 'Commissions' ->> 'product_base_price', ''), nullif(p -> 'Commissions' ->> 'charge_amount', ''), nullif(p -> 'payment' ->> 'product_base_price', ''), nullif(p -> 'payment' ->> 'charge_amount', ''))::numeric / 100;
    return jsonb_build_object('evento', coalesce(nullif(t, ''), 'desconhecido'), 'alvo', alvo, 'transacao', nullif(p ->> 'order_id', ''), 'pai', nullif(p ->> 'parent_order_id', ''),
      'valor', v, 'moeda', coalesce(p -> 'Commissions' ->> 'product_base_price_currency', p ->> 'currency', 'BRL'),
      'produto_ids', jsonb_build_array(coalesce(p -> 'Product' ->> 'product_id', p -> 'Product' ->> 'id', p -> 'product' ->> 'id')),
      'produto_nome', coalesce(p -> 'Product' ->> 'product_name', p -> 'Product' ->> 'name', p -> 'product' ->> 'name'),
      'comprador', jsonb_build_object('name', coalesce(b ->> 'full_name', b ->> 'name'), 'email', b ->> 'email', 'checkout_phone', b ->> 'mobile', 'document', coalesce(b ->> 'CPF', b ->> 'cpf', b ->> 'cnpj')),
      'data', coalesce(p ->> 'approved_date', p ->> 'created_at'), 'aprovada', p ->> 'approved_date',
      'forma', case lower(coalesce(p ->> 'payment_method', '')) when 'credit_card' then 'cartao_credito' when 'pix' then 'pix' when 'boleto' then 'boleto' else 'outro' end,
      'parcelas', p ->> 'installments', 'sck', tr ->> 'sck', 'src', coalesce(tr ->> 'src', tr ->> 'utm_source'), 'utm_content', tr ->> 'utm_content', 'utm_campaign', tr ->> 'utm_campaign', 'utm_medium', tr ->> 'utm_medium', 'bump', false);
  elsif p_prov = 'eduzz' then
    t := coalesce(p ->> 'event', ''); d := coalesce(p -> 'data', '{}'::jsonb);
    alvo := case t when 'myeduzz.invoice_paid' then 'aprovada' when 'myeduzz.invoice_waiting_payment' then 'pendente' when 'myeduzz.invoice_canceled' then 'cancelada' when 'myeduzz.invoice_expired' then 'cancelada' when 'myeduzz.invoice_refunded' then 'reembolsada' when 'myeduzz.invoice_chargeback' then 'chargeback' end;
    b := coalesce(d -> 'buyer', '{}'::jsonb);
    -- a fatura é uma venda só: o produto é o primeiro item que não é order bump; os itens ficam nos extras
    select x into it from jsonb_array_elements(case when jsonb_typeof(d -> 'items') = 'array' then d -> 'items' else '[]'::jsonb end) x order by coalesce((x ->> 'isBump')::boolean, false) limit 1;
    return jsonb_build_object('evento', coalesce(nullif(t, ''), 'desconhecido'), 'alvo', alvo, 'transacao', nullif(d ->> 'id', ''), 'pai', nullif(d -> 'orderBump' ->> 'mainSaleId', ''),
      'valor', coalesce(nullif(d -> 'paid' ->> 'value', ''), nullif(d -> 'price' ->> 'value', ''))::numeric, 'moeda', coalesce(d -> 'paid' ->> 'currency', d -> 'price' ->> 'currency', 'BRL'),
      'produto_ids', jsonb_build_array(it ->> 'productId'), 'produto_nome', it ->> 'name',
      'comprador', jsonb_build_object('name', b ->> 'name', 'email', b ->> 'email', 'checkout_phone', coalesce(nullif(b ->> 'cellphone', ''), nullif(b ->> 'phone', '')), 'document', b ->> 'document', 'address', b -> 'address'),
      'data', coalesce(d ->> 'paidAt', d ->> 'createdAt', p ->> 'sentDate'), 'aprovada', d ->> 'paidAt',
      'forma', case coalesce(d ->> 'paymentMethod', '') when 'creditCard' then 'cartao_credito' when 'pix' then 'pix' when 'bankslip' then 'boleto' when 'installmentBankslip' then 'boleto' else 'outro' end,
      'parcelas', d ->> 'installments', 'sck', coalesce(d -> 'tracker' ->> 'code1', d -> 'utm' ->> 'content'), 'src', d -> 'utm' ->> 'source', 'utm_content', d -> 'utm' ->> 'content', 'utm_campaign', d -> 'utm' ->> 'campaign', 'utm_medium', d -> 'utm' ->> 'medium',
      'bump', coalesce((d -> 'orderBump' ->> 'has')::boolean, false) and not coalesce((d -> 'orderBump' ->> 'isMainSale')::boolean, true), 'itens', d -> 'items');
  elsif p_prov = 'hubla' then
    t := coalesce(p ->> 'type', ''); d := coalesce(p -> 'event', '{}'::jsonb); i := coalesce(d -> 'invoice', '{}'::jsonb); st := i ->> 'status';
    alvo := case t when 'invoice.payment_succeeded' then 'aprovada' when 'invoice.created' then 'pendente' when 'invoice.expired' then 'cancelada' when 'invoice.refunded' then 'reembolsada'
      when 'invoice.status_updated' then case st when 'paid' then 'aprovada' when 'refunded' then 'reembolsada' when 'chargeback' then 'chargeback' when 'canceled' then 'cancelada' end end;
    b := coalesce(i -> 'payer', d -> 'user', '{}'::jsonb); tr := coalesce(i -> 'paymentSession', '{}'::jsonb);
    -- sem a taxa de parcelamento: o mesmo critério da Hotmart
    v := (coalesce(nullif(i -> 'amount' ->> 'totalCents', '')::numeric, 0) - coalesce(nullif(i -> 'amount' ->> 'installmentFeeCents', '')::numeric, 0)) / 100;
    if nullif(i -> 'amount' ->> 'totalCents', '') is null then v := null; end if;
    return jsonb_build_object('evento', coalesce(nullif(t, ''), 'desconhecido') || case when t = 'invoice.status_updated' and st is not null then ':' || st else '' end, 'alvo', alvo, 'transacao', nullif(i ->> 'id', ''), 'pai', nullif(i ->> 'parentInvoiceId', ''),
      'valor', v, 'moeda', coalesce(i ->> 'currency', 'BRL'),
      'produto_ids', jsonb_build_array(d -> 'product' ->> 'id'), 'produto_nome', d -> 'product' ->> 'name',
      'comprador', jsonb_build_object('name', nullif(trim(coalesce(b ->> 'firstName', '') || ' ' || coalesce(b ->> 'lastName', '')), ''), 'email', b ->> 'email', 'checkout_phone', b ->> 'phone', 'document', b ->> 'document',
        'address', case when jsonb_typeof(i -> 'billingAddress') = 'object' then i -> 'billingAddress' end),
      'data', coalesce(i ->> 'saleDate', i ->> 'createdAt'), 'aprovada', case when alvo = 'aprovada' then coalesce(i ->> 'saleDate', i ->> 'modifiedAt') end,
      'forma', case i ->> 'paymentMethod' when 'credit_card' then 'cartao_credito' when 'pix' then 'pix' when 'bank_slip' then 'boleto' else 'outro' end,
      'parcelas', i ->> 'installments', 'sck', coalesce(tr -> 'params' ->> 'SCK', tr -> 'params' ->> 'sck'), 'src', tr -> 'utm' ->> 'source', 'utm_content', tr -> 'utm' ->> 'content', 'utm_campaign', tr -> 'utm' ->> 'campaign', 'utm_medium', tr -> 'utm' ->> 'medium',
      'bump', nullif(i ->> 'parentInvoiceId', '') is not null);
  end if;
  raise exception 'Plataforma inválida';
end $$;

-- aplica o evento já traduzido: mesmas regras da Hotmart (sem duplicar, estorno completo, evento atrasado não desfaz)
create or replace function public._pv_aplicar(p_ws uuid, p_plat uuid, p_prov text, n jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo text := n ->> 'alvo'; ev text := n ->> 'evento'; idx text := n ->> 'transacao'; v vendas; pr uuid; pid uuid; of_ uuid; cp uuid; valor numeric; moeda text; quando timestamptz; aprov timestamptz; bump boolean := coalesce((n ->> 'bump')::boolean, false); sck text := nullif(n ->> 'sck', ''); nm int; ex jsonb; id_ext text;
begin
  if alvo is null then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'Evento sem efeito na venda: ' || coalesce(ev, 'sem nome')); end if;
  if idx is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'O evento veio sem o código da venda.'); end if;
  perform pg_advisory_xact_lock(hashtext(p_ws::text || p_prov || idx));
  aprov := _pv_data(n ->> 'aprovada'); quando := coalesce(_pv_data(n ->> 'data'), aprov, now());

  select * into v from vendas where workspace_id = p_ws and id_externo = idx and (plataforma_id = p_plat or plataforma_id is null) limit 1;
  if v.id is not null then
    if v.status = alvo then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já estava ' || alvo || '.', 'venda_id', v.id); end if;
    if v.status in ('reembolsada', 'chargeback') and alvo not in ('reembolsada', 'chargeback') then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já está ' || v.status || '; o evento atrasado não muda isso.', 'venda_id', v.id); end if;
    if alvo = 'pendente' then return jsonb_build_object('situacao', 'ignorado', 'motivo', 'A venda já está ' || v.status || '.', 'venda_id', v.id); end if;
    if alvo = 'aprovada' then
      if exists (select 1 from estornos where venda_id = v.id) then return jsonb_build_object('situacao', 'revisar', 'motivo', 'Aprovação recebida para uma venda já estornada. Confira na plataforma.', 'venda_id', v.id); end if;
      update vendas set status = 'aprovada', aprovada_em = coalesce(aprov, now()) where id = v.id;
    elsif v.status = 'aprovada' and exists (select 1 from lancamentos where origem_tipo = 'venda' and origem_id = v.id) then
      perform registrar_estorno(v.id, case alvo when 'cancelada' then 'cancelamento' when 'reembolsada' then 'reembolso' else 'chargeback' end, initcap(p_prov) || ': ' || ev, (now() at time zone 'America/Sao_Paulo')::date);
    else
      update vendas set status = alvo where id = v.id;
    end if;
    return jsonb_build_object('situacao', 'processado', 'motivo', 'Venda atualizada para ' || alvo || '.', 'venda_id', v.id);
  end if;

  moeda := upper(coalesce(n ->> 'moeda', 'BRL')); valor := nullif(n ->> 'valor', '')::numeric;
  if valor is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'O evento veio sem o valor da venda.'); end if;
  if moeda <> 'BRL' then return jsonb_build_object('situacao', 'revisar', 'motivo', 'Venda em ' || moeda || '. Ainda não convertemos moeda: lance em reais.'); end if;

  select x.produto_id into pr from plataforma_produto_vinculos x where x.workspace_id = p_ws and x.plataforma_id = p_plat and x.id_externo in (select jsonb_array_elements_text(n -> 'produto_ids')) limit 1;
  if pr is null then select x.produto_id into pr from produto_plataforma x where x.workspace_id = p_ws and x.plataforma_id = p_plat and x.id_externo in (select jsonb_array_elements_text(n -> 'produto_ids')) limit 1; end if;
  if pr is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'Produto da plataforma ainda não ligado a um produto do Growths.'); end if;

  pid := _hotmart_cliente(p_ws, n -> 'comprador', nullif(n ->> 'src', ''));
  if pid is null then return jsonb_build_object('situacao', 'revisar', 'motivo', 'A plataforma não enviou e-mail, telefone nem documento do comprador.'); end if;

  select count(*), min(o.id::text)::uuid into nm, of_ from ofertas o where o.workspace_id = p_ws and o.produto_id = pr and o.ativo and o.preco = valor;
  if nm > 1 then
    select count(*), min(o.id::text)::uuid into nm, of_ from ofertas o where o.workspace_id = p_ws and o.produto_id = pr and o.ativo and o.preco = valor and (o.papel = 'order_bump') = bump;
    if nm <> 1 then of_ := null; end if;
  end if;
  if of_ is not null and not exists (select 1 from campanha_vendedores where workspace_id = p_ws and codigo in (sck, nullif(n ->> 'utm_content', ''))) then
    select count(*), min(k.id::text)::uuid into nm, cp from campanhas k join campanha_ofertas co on co.campanha_id = k.id
      where k.workspace_id = p_ws and co.oferta_id = of_ and k.status = 'ativa' and (quando at time zone 'America/Sao_Paulo')::date between coalesce(k.data_inicio, '-infinity'::date) and coalesce(k.data_fim, 'infinity'::date);
    if nm <> 1 then cp := null; end if;
  end if;
  ex := jsonb_strip_nulls(jsonb_build_object('fonte', p_prov, 'sck', sck, 'order_bump', case when bump then true end, 'produto_plataforma', n ->> 'produto_nome', 'itens', n -> 'itens'));
  insert into vendas (workspace_id, pessoa_id, produto_id, oferta_id, plataforma_id, campanha_id, forma_pagamento, parcelas, status, data_venda, valor_bruto, id_externo, pedido_ref, utm_source, utm_medium, utm_campaign, utm_content, comprador_email, comprador_telefone, aprovada_em, origem_dado, extras)
  values (p_ws, pid, pr, of_, p_plat, cp, coalesce(n ->> 'forma', 'outro'), greatest(coalesce(nullif(n ->> 'parcelas', '')::int, 1), 1), alvo, quando, valor, idx, coalesce(nullif(n ->> 'pai', ''), idx), nullif(n ->> 'src', ''), nullif(n ->> 'utm_medium', ''), nullif(n ->> 'utm_campaign', ''), coalesce(nullif(n ->> 'utm_content', ''), sck),
          nullif(lower(trim(coalesce(n -> 'comprador' ->> 'email', ''))), ''), nullif(regexp_replace(coalesce(n -> 'comprador' ->> 'checkout_phone', ''), '\D', '', 'g'), ''), aprov, 'integracao', ex)
  returning * into v;
  return jsonb_build_object('situacao', 'processado', 'motivo', 'Venda criada (' || alvo || ').', 'venda_id', v.id);
end $$;

create or replace function public._pv_tenta(p_ws uuid, p_plat uuid, p_prov text, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  return _pv_aplicar(p_ws, p_plat, p_prov, _pv_normaliza(p_prov, p));
exception when others then
  return jsonb_build_object('situacao', 'erro', 'motivo', left(sqlerrm, 300));
end $$;

create or replace function public._pv_bruto_tratar(p_prov text, p_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare ws uuid; pl jsonb; cfg plataforma_webhooks; r jsonb; tb text := _pv_tabela(p_prov);
begin
  execute format('select workspace_id, payload from %I where id = $1', tb) into ws, pl using p_id;
  select * into cfg from plataforma_webhooks where workspace_id = ws and provedor = p_prov;
  if cfg.workspace_id is null then return jsonb_build_object('situacao', 'aguardando'); end if;
  r := _pv_tenta(ws, cfg.plataforma_id, p_prov, pl);
  execute format('update %I set tratamento = $1, motivo = $2, venda_id = coalesce($3, venda_id), tratado_em = now() where id = $4', tb) using r ->> 'situacao', r ->> 'motivo', nullif(r ->> 'venda_id', '')::uuid, p_id;
  return r;
end $$;

create or replace function public._pv_bruto_trg() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.tratamento = 'aguardando' then perform _pv_bruto_tratar(tg_argv[0], new.id); end if;
  return null;
end $$;
do $m$
declare t text;
begin
  foreach t in array array['kiwify', 'eduzz', 'hubla'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_bruto_tratar_t', t || '_vendas_bruto');
    execute format('create trigger %I after insert on public.%I for each row execute function public._pv_bruto_trg(%L)', t || '_bruto_tratar_t', t || '_vendas_bruto', t);
  end loop;
end $m$;

-- confere se a chave é desta plataforma neste workspace
create or replace function public._pv_cfg(p_chave text, p_prov text) returns plataforma_webhooks language plpgsql security definer set search_path = public as $$
declare w uuid; cfg plataforma_webhooks;
begin
  perform _pv_tabela(p_prov);
  w := chave_api_ws_escopo(p_chave, 'vendas');
  select pw.* into cfg from plataforma_webhooks pw join chaves_api k on k.id = pw.chave_id where pw.workspace_id = w and pw.provedor = p_prov and k.hash = chave_api_hash(p_chave);
  if cfg.workspace_id is null then raise exception 'Chave de outra plataforma' using errcode = '28000'; end if;
  return cfg;
end $$;

-- a função da borda busca o segredo para conferir a assinatura sobre o corpo original
create or replace function public.plataforma_webhook_segredo(p_chave text, p_prov text) returns text language plpgsql security definer set search_path = public as $$
begin
  return (_pv_cfg(p_chave, p_prov)).segredo_hmac;
end $$;

-- grava o bruto; o gatilho trata. p_token só vale para a Hubla, que manda um token fixo em vez de assinar.
create or replace function public.plataforma_webhook_gravar(p_chave text, p_prov text, p_token text, p_evento_id text, p_teste boolean, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg plataforma_webhooks := _pv_cfg(p_chave, p_prov); n jsonb := _pv_normaliza(p_prov, p); tb text := _pv_tabela(p_prov); rid uuid; ev_id text := coalesce(nullif(p_evento_id, ''), md5(p::text)); tr text; mo text;
begin
  if p_prov = 'hubla' and cfg.segredo_hash is distinct from chave_api_hash(coalesce(p_token, '')) then raise exception 'Token inválido' using errcode = '28000'; end if;
  execute format($f$insert into %I (workspace_id, evento_id, evento, transacao, produto_externo, produto_nome, payload, ocorrido_em, tratamento, motivo)
    values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) on conflict (workspace_id, evento_id) do nothing returning id$f$, tb) into rid
    using cfg.workspace_id, ev_id, n ->> 'evento', n ->> 'transacao', n -> 'produto_ids' ->> 0, n ->> 'produto_nome', p, _pv_data(n ->> 'data'),
      case when p_teste then 'ignorado' else 'aguardando' end, case when p_teste then 'Evento de teste da plataforma.' end;
  if rid is null then return jsonb_build_object('ok', true, 'situacao', 'repetido'); end if;
  execute format('select tratamento, motivo from %I where id = $1', tb) into tr, mo using rid;
  update plataforma_webhooks set ultimo_evento_em = now() where workspace_id = cfg.workspace_id and provedor = p_prov;
  update integracoes set status = 'conectado', ultima_sincronizacao = now() where workspace_id = cfg.workspace_id and lower(provedor) = p_prov;
  return jsonb_build_object('ok', true, 'situacao', tr, 'motivo', mo);
end $$;

create or replace function public.plataforma_configurar(p_ws uuid, p_prov text, p_plataforma uuid, p_segredo text, p_novo_endereco boolean default false) returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg plataforma_webhooks; k text; cid uuid; tok text := nullif(trim(coalesce(p_segredo, '')), ''); nome text;
begin
  perform _pv_tabela(p_prov); nome := initcap(p_prov);
  if auth.uid() is null or not _hotmart_pode(p_ws) then raise exception 'Só quem edita Vendas, Financeiro ou Cadastros pode configurar a integração'; end if;
  if not exists (select 1 from plataformas_venda where id = p_plataforma and workspace_id = p_ws) then raise exception 'Escolha a plataforma cadastrada neste workspace'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = p_prov;
  if cfg.workspace_id is null and tok is null then raise exception 'Cole o token de %', nome; end if;
  if tok is not null and char_length(tok) < 8 then raise exception 'Esse token parece incompleto. Copie de novo em %', nome; end if;
  cid := cfg.chave_id;
  if cfg.workspace_id is null or p_novo_endereco then
    if cid is not null then update chaves_api set revogada_em = now() where id = cid and revogada_em is null; end if;
    k := 'gw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    insert into chaves_api (workspace_id, nome, escopo, prefixo, hash) values (p_ws, 'Webhook ' || nome, 'vendas', left(k, 9), chave_api_hash(k)) returning id into cid;
  end if;
  insert into plataforma_webhooks (workspace_id, provedor, plataforma_id, chave_id, segredo_hash, segredo_hmac)
  values (p_ws, p_prov, p_plataforma, cid, case when tok is null then cfg.segredo_hash else chave_api_hash(tok) end, case when p_prov = 'hubla' then null when tok is null then cfg.segredo_hmac else tok end)
  on conflict (workspace_id, provedor) do update set plataforma_id = excluded.plataforma_id, chave_id = excluded.chave_id, segredo_hash = excluded.segredo_hash, segredo_hmac = excluded.segredo_hmac;
  insert into integracoes (workspace_id, provedor, categoria, status) values (p_ws, nome, 'vendas', 'configurando') on conflict (workspace_id, provedor) do nothing;
  return jsonb_build_object('chave', k);
end $$;

create or replace function public.plataforma_painel(p_ws uuid, p_prov text) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare cfg plataforma_webhooks; tb text := _pv_tabela(p_prov); rec bigint; pro bigint; rev bigint; sl jsonb; ul jsonb;
begin
  if not pertence_ao_workspace(p_ws) or not perm(p_ws, 'ler', array['vendas', 'fin', 'cad']) then raise exception 'Sem acesso'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = p_prov;
  execute format($f$select count(*) filter (where recebido_em > now() - interval '30 days'), count(*) filter (where tratamento = 'processado' and recebido_em > now() - interval '30 days'), count(*) filter (where tratamento in ('revisar', 'erro')) from %I where workspace_id = $1$f$, tb) into rec, pro, rev using p_ws;
  execute format($f$select coalesce(jsonb_agg(x order by x.ultimo desc), '[]'::jsonb) from (select produto_externo as id, max(produto_nome) as nome, count(*) as eventos, max(recebido_em) as ultimo from %I where workspace_id = $1 and tratamento = 'revisar' and motivo like 'Produto da %%' and produto_externo is not null group by produto_externo) x$f$, tb) into sl using p_ws;
  execute format($f$select coalesce(jsonb_agg(y), '[]'::jsonb) from (select id, evento, transacao, produto_nome, tratamento as situacao, motivo, recebido_em, venda_id from %I where workspace_id = $1 order by recebido_em desc limit 15) y$f$, tb) into ul using p_ws;
  return jsonb_build_object('configurado', cfg.workspace_id is not null, 'plataforma_id', cfg.plataforma_id, 'ultimo_evento_em', cfg.ultimo_evento_em, 'pode_editar', _hotmart_pode(p_ws), 'recebidos', rec, 'processados', pro, 'revisar', rev, 'sem_ligacao', sl, 'ultimos', ul);
end $$;

create or replace function public.plataforma_reprocessar(p_ws uuid, p_prov text) returns jsonb language plpgsql security definer set search_path = public as $$
declare tb text := _pv_tabela(p_prov); l record; r jsonb; ok int := 0; resta int := 0;
begin
  if auth.uid() is null or not _hotmart_pode(p_ws) then raise exception 'Sem permissão para reprocessar'; end if;
  if not exists (select 1 from plataforma_webhooks where workspace_id = p_ws and provedor = p_prov) then raise exception 'Integração ainda não configurada'; end if;
  for l in execute format($f$select id from %I where workspace_id = $1 and tratamento in ('aguardando', 'revisar', 'erro') order by coalesce(ocorrido_em, recebido_em)$f$, tb) using p_ws loop
    r := _pv_bruto_tratar(p_prov, l.id);
    if r ->> 'situacao' in ('revisar', 'erro', 'aguardando') then resta := resta + 1; else ok := ok + 1; end if;
  end loop;
  return jsonb_build_object('resolvidos', ok, 'restam', resta);
end $$;

create or replace function public.plataforma_ligar_produto(p_ws uuid, p_prov text, p_externo text, p_produto uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg plataforma_webhooks;
begin
  perform _pv_tabela(p_prov);
  if auth.uid() is null or not _hotmart_pode(p_ws) then raise exception 'Sem permissão para ligar produtos'; end if;
  select * into cfg from plataforma_webhooks where workspace_id = p_ws and provedor = p_prov;
  if cfg.workspace_id is null then raise exception 'Integração ainda não configurada'; end if;
  if not exists (select 1 from produtos where id = p_produto and workspace_id = p_ws) then raise exception 'Escolha um produto deste workspace'; end if;
  if coalesce(trim(p_externo), '') = '' then raise exception 'Produto da plataforma não informado'; end if;
  insert into plataforma_produto_vinculos (workspace_id, plataforma_id, id_externo, produto_id) values (p_ws, cfg.plataforma_id, p_externo, p_produto)
  on conflict (workspace_id, plataforma_id, id_externo) do update set produto_id = excluded.produto_id;
  return plataforma_reprocessar(p_ws, p_prov);
end $$;

revoke execute on function public._pv_tabela(text), public._pv_data(text), public._pv_normaliza(text, jsonb), public._pv_aplicar(uuid, uuid, text, jsonb), public._pv_tenta(uuid, uuid, text, jsonb), public._pv_bruto_tratar(text, uuid), public._pv_bruto_trg(), public._pv_cfg(text, text), public.plataforma_webhook_segredo(text, text), public.plataforma_webhook_gravar(text, text, text, text, boolean, jsonb) from public, anon, authenticated;
revoke execute on function public.plataforma_configurar(uuid, text, uuid, text, boolean), public.plataforma_painel(uuid, text), public.plataforma_reprocessar(uuid, text), public.plataforma_ligar_produto(uuid, text, text, uuid) from public, anon;
grant execute on function public.plataforma_webhook_segredo(text, text), public.plataforma_webhook_gravar(text, text, text, text, boolean, jsonb) to service_role;
grant execute on function public.plataforma_configurar(uuid, text, uuid, text, boolean), public.plataforma_painel(uuid, text), public.plataforma_reprocessar(uuid, text), public.plataforma_ligar_produto(uuid, text, text, uuid) to authenticated;

notify pgrst, 'reload schema';
