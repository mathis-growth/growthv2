-- v0.89 — Fase 2 da comparação com o Growth's do Rogério: captação e vendas
-- Decisões da Rebecka (10/10/2026): atribuição grava primeiro e último toque em toda venda e os painéis usam o último toque;
-- ROAS oficial é o bruto; cadastros com o mesmo telefone são juntados sozinhos.
-- 1. Junção automática por telefone em pessoa_resolver (_pessoas_mesclar sem checagem, usada por dentro).
-- 2. Lead por campanha: campanha_participacoes (entrada, era aluno, era cliente, canal, UTMs, tentativas) + registrar_captura + campanha_captacao.
-- 3. Duplicidade de captação: nova tentativa de quem já participa soma em tentativas (não cria lead novo).
-- 4. Público frio e quente: campanha_canais.temperatura e anuncios.temperatura.
-- 5. Ofertas: vendas.pedido_ref e taxa de aceite (order bump, upsell, downsell, cross-sell) em campanha_ofertas_resultado.
-- 6. Abandono de checkout: checkout_abandonos, recuperação automática pela venda, abandono_registrar, abandonos_resumo.
-- 7. Atribuição explícita: venda_atribuicoes (primeiro_toque e ultimo_toque, peso, versão da regra, evidência) + vendas_por_canal.
-- 8. Metas por tipo, canal, segmento e período: campanha_metas + campanha_metas_painel.
-- Rode DEPOIS de 20261011000000_fase1_confianca_dado.sql. Idempotente.

-- ============ 1. junção automática por telefone ============
do $$ begin
  if to_regprocedure('public._pessoas_mesclar_v088(uuid, uuid, text)') is null then
    alter function public.pessoas_mesclar(uuid, uuid, text) rename to _pessoas_mesclar_v088;
  end if;
end $$;
create or replace function public._pessoas_mesclar(p_manter uuid, p_remover uuid, p_motivo text default null)
returns uuid language plpgsql security definer set search_path = public as $$
begin
  -- a função da v0.88 checa permissão de vendas; por dentro (captação, integrações) quem chama já foi checado
  perform set_config('growths.mesclar_interno', '1', true);
  return _pessoas_mesclar_v088(p_manter, p_remover, p_motivo);
end $$;
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public._pessoas_mesclar_v088(uuid, uuid, text)'::regprocedure);
  if position('mesclar_interno' in d) = 0 then
    n := replace(d, 'if not pode_editar(a.workspace_id, ''{vendas}''::text[]) then',
                    'if coalesce(current_setting(''growths.mesclar_interno'', true), '''') <> ''1'' and not pode_editar(a.workspace_id, ''{vendas}''::text[]) then');
    if n = d then raise exception '_pessoas_mesclar_v088: trecho não encontrado'; end if;
    execute n;
  end if;
end $$;
create or replace function public.pessoas_mesclar(p_manter uuid, p_remover uuid, p_motivo text default null)
returns uuid language plpgsql security definer set search_path = public as $$
begin
  perform set_config('growths.mesclar_interno', '', true);
  return _pessoas_mesclar_v088(p_manter, p_remover, p_motivo);
end $$;
revoke execute on function public._pessoas_mesclar_v088(uuid, uuid, text), public._pessoas_mesclar(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.pessoas_mesclar(uuid, uuid, text) to authenticated, service_role;

create or replace function public.pessoa_resolver(p_ws uuid, p_nome text, p_email text, p_telefone text, p_dados jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare id_ uuid; f text := norm_fone(p_telefone); e text := norm_email(p_email); p pessoas; o pessoas;
begin
  if not pode_editar(p_ws, '{vendas,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if f is null and e is null then raise exception 'Informe telefone ou e-mail para identificar a pessoa'; end if;
  if f is not null then select * into p from pessoas where workspace_id = p_ws and telefone_norm = f; end if;
  if p.id is not null and e is not null then
    -- o e-mail está num cadastro sem telefone: é a mesma pessoa → junta no cadastro do telefone
    select * into o from pessoas where workspace_id = p_ws and email_norm = e and id <> p.id;
    if o.id is not null and o.telefone_norm is null then perform _pessoas_mesclar(p.id, o.id, 'Automático: mesmo telefone'); end if;
  end if;
  if p.id is null and e is not null then select * into p from pessoas where workspace_id = p_ws and email_norm = e; end if;
  if p.id is not null then
    update pessoas set
      nome = coalesce(nullif(trim(nome), ''), nullif(trim(p_nome), ''), nome),
      telefone = case when telefone_norm is null and f is not null and not exists (select 1 from pessoas x where x.workspace_id = p_ws and x.telefone_norm = f) then p_telefone else telefone end,
      email = case when email_norm is null and e is not null and not exists (select 1 from pessoas x where x.workspace_id = p_ws and x.email_norm = e) then lower(trim(p_email)) else email end
    where id = p.id;
    return p.id;
  end if;
  insert into pessoas (workspace_id, nome, email, telefone, status_funil,
                       utm_source, utm_medium, utm_campaign, utm_content, utm_term, canal_origem, campanha_id)
  values (p_ws, coalesce(nullif(trim(p_nome), ''), coalesce(e, f)), lower(trim(p_email)), p_telefone, coalesce(p_dados->>'status_funil', 'lead'),
          p_dados->>'utm_source', p_dados->>'utm_medium', p_dados->>'utm_campaign', p_dados->>'utm_content', p_dados->>'utm_term',
          p_dados->>'canal_origem', nullif(p_dados->>'campanha_id', '')::uuid)
  returning id into id_;
  return id_;
end $$;

-- ============ 4. temperatura (antes da participação, que lê o canal da campanha) ============
alter table campanha_canais add column if not exists temperatura text;
alter table anuncios add column if not exists temperatura text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'campanha_canais_temperatura_check') then
    alter table campanha_canais add constraint campanha_canais_temperatura_check check (temperatura is null or temperatura in ('frio', 'quente'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'anuncios_temperatura_check') then
    alter table anuncios add constraint anuncios_temperatura_check check (temperatura is null or temperatura in ('frio', 'quente'));
  end if;
end $$;

-- canal oficial: código do cadastro de canais (pelo próprio código ou pela utm_source)
create or replace function public._canal_de(p_ws uuid, p_canal text, p_utm_source text) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select codigo from canais where workspace_id = p_ws and codigo = p_canal limit 1),
    (select codigo from canais where workspace_id = p_ws and lower(utm_source) = lower(coalesce(p_utm_source, p_canal)) and utm_source is not null limit 1),
    nullif(p_canal, ''), nullif(lower(p_utm_source), ''));
$$;

-- ============ 2 e 3. lead por campanha e duplicidade ============
-- a jornada passa a aceitar o toque 'captura' (cada tentativa de cadastro) e as origens 'captura' e 'integracao'
do $$
declare k record;
begin
  for k in select conname, pg_get_constraintdef(oid) d from pg_constraint where conrelid = 'public.pessoa_toques'::regclass and contype = 'c' loop
    if k.d like '%tipo%' and k.d not like '%captura%' then
      execute format('alter table pessoa_toques drop constraint %I', k.conname);
      alter table pessoa_toques add constraint pessoa_toques_tipo_check check (tipo in ('entrada', 'etapa', 'lista', 'video', 'disparo', 'comercial', 'compra', 'recompra', 'outro', 'captura'));
    elsif k.d like '%origem%' and k.d not like '%integracao%' then
      execute format('alter table pessoa_toques drop constraint %I', k.conname);
      alter table pessoa_toques add constraint pessoa_toques_origem_check check (origem in ('sistema', 'sendflow', 'manual', 'importacao', 'captura', 'integracao'));
    end if;
  end loop;
end $$;
create table if not exists campanha_participacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  entrou_em timestamptz not null,
  era_aluno boolean not null default false,
  era_cliente boolean not null default false,
  canal text,
  campanha_canal_id uuid references campanha_canais(id) on delete set null,
  temperatura text,
  utm_source text, utm_medium text, utm_campaign text, utm_content text,
  tentativas int not null default 1,
  ultima_tentativa_em timestamptz,
  unique (campanha_id, pessoa_id)
);
create index if not exists campanha_participacoes_ws on campanha_participacoes (workspace_id, entrou_em);
alter table campanha_participacoes enable row level security;
drop policy if exists campanha_participacoes_ler on campanha_participacoes;
create policy campanha_participacoes_ler on campanha_participacoes for select to authenticated
  using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'ler', '{mkt,vendas,gro}'::text[]));
revoke insert, update, delete on campanha_participacoes from anon, authenticated;
grant select on campanha_participacoes to authenticated;

create or replace function public._participacao_registrar(t pessoa_toques) returns void
language plpgsql security definer set search_path = public as $$
declare cc campanha_canais; conta int;
begin
  if t.campanha_id is null or t.tipo not in ('entrada', 'lista', 'captura') then return; end if;
  if t.utm_campaign is not null then select * into cc from campanha_canais where workspace_id = t.workspace_id and utm_campaign = t.utm_campaign; end if;
  conta := case when t.tipo in ('entrada', 'captura') then 1 else 0 end;
  insert into campanha_participacoes (workspace_id, campanha_id, pessoa_id, entrou_em, era_aluno, era_cliente, canal, campanha_canal_id, temperatura,
                                      utm_source, utm_medium, utm_campaign, utm_content, tentativas, ultima_tentativa_em)
  values (t.workspace_id, t.campanha_id, t.pessoa_id, t.em,
          exists (select 1 from alunos a where a.pessoa_id = t.pessoa_id and a.entrou_em <= t.em and (a.saiu_em is null or a.saiu_em > t.em)),
          exists (select 1 from vendas v where v.pessoa_id = t.pessoa_id and v.status = 'aprovada' and v.data_venda < t.em),
          coalesce(cc.canal, _canal_de(t.workspace_id, t.canal, t.utm_source)), cc.id, cc.temperatura,
          t.utm_source, t.utm_medium, t.utm_campaign, t.utm_content, greatest(conta, 1), t.em)
  on conflict (campanha_id, pessoa_id) do update set
    tentativas = campanha_participacoes.tentativas + conta,
    ultima_tentativa_em = greatest(campanha_participacoes.ultima_tentativa_em, excluded.ultima_tentativa_em),
    -- a entrada oficial é a primeira; canal e UTMs só completam o que faltava
    canal = coalesce(campanha_participacoes.canal, excluded.canal),
    campanha_canal_id = coalesce(campanha_participacoes.campanha_canal_id, excluded.campanha_canal_id),
    temperatura = coalesce(campanha_participacoes.temperatura, excluded.temperatura),
    utm_source = coalesce(campanha_participacoes.utm_source, excluded.utm_source);
end $$;
revoke execute on function public._participacao_registrar(pessoa_toques) from public, anon, authenticated;

create or replace function public.participacao_trg() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform _participacao_registrar(new);
  return null;
end $$;
revoke execute on function public.participacao_trg() from public, anon, authenticated;
drop trigger if exists participacao_t on pessoa_toques;
create trigger participacao_t after insert on pessoa_toques for each row execute function public.participacao_trg();

-- pessoa ligada a uma campanha depois de cadastrada também participa
create or replace function public.participacao_pessoa_trg() returns trigger
language plpgsql security definer set search_path = public as $$
declare t pessoa_toques;
begin
  if new.campanha_id is not null and new.campanha_id is distinct from old.campanha_id then
    t.workspace_id := new.workspace_id; t.pessoa_id := new.id; t.campanha_id := new.campanha_id; t.em := now(); t.tipo := 'lista';
    t.canal := new.canal_origem; t.utm_source := new.utm_source; t.utm_medium := new.utm_medium; t.utm_campaign := new.utm_campaign; t.utm_content := new.utm_content;
    perform _participacao_registrar(t);
  end if;
  return null;
end $$;
revoke execute on function public.participacao_pessoa_trg() from public, anon, authenticated;
drop trigger if exists participacao_pessoa_t on pessoas;
create trigger participacao_pessoa_t after update of campanha_id on pessoas for each row execute function public.participacao_pessoa_trg();

-- histórico: participações a partir da jornada e do cadastro
do $$
declare t pessoa_toques;
begin
  if not exists (select 1 from campanha_participacoes) then
    for t in select * from pessoa_toques where campanha_id is not null and tipo in ('entrada', 'lista', 'captura') order by em loop
      perform _participacao_registrar(t);
    end loop;
    insert into campanha_participacoes (workspace_id, campanha_id, pessoa_id, entrou_em, canal, utm_source, utm_medium, utm_campaign, utm_content, ultima_tentativa_em)
    select p.workspace_id, p.campanha_id, p.id, p.criado_em, _canal_de(p.workspace_id, p.canal_origem, p.utm_source), p.utm_source, p.utm_medium, p.utm_campaign, p.utm_content, p.criado_em
      from pessoas p where p.campanha_id is not null
    on conflict (campanha_id, pessoa_id) do nothing;
  end if;
end $$;

-- porta de entrada única da captação (formulários, importação, integrações): acha ou cria a pessoa e registra a tentativa
create or replace function public.registrar_captura(p_ws uuid, p_campanha uuid, p_nome text, p_email text, p_telefone text, p_dados jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pid uuid; ja boolean; existia boolean;
begin
  if p_campanha is not null and not exists (select 1 from campanhas where id = p_campanha and workspace_id = p_ws) then raise exception 'Campanha não encontrada'; end if;
  existia := exists (select 1 from pessoas where workspace_id = p_ws and (telefone_norm = norm_fone(p_telefone) or email_norm = norm_email(p_email)));
  pid := pessoa_resolver(p_ws, p_nome, p_email, p_telefone, p_dados || case when p_campanha is null then '{}'::jsonb else jsonb_build_object('campanha_id', p_campanha) end);
  ja := p_campanha is not null and exists (select 1 from campanha_participacoes where campanha_id = p_campanha and pessoa_id = pid);
  -- pessoa nova já entra na campanha pelo toque de entrada do cadastro; só quem já existia ganha um toque de captura
  if p_campanha is not null and existia then
    insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
    values (p_ws, pid, coalesce(nullif(p_dados->>'em', '')::timestamptz, now()), 'captura', p_dados->>'canal_origem', p_campanha,
            case when ja then 'Nova tentativa de cadastro (repetida)' else 'Cadastro na campanha' end,
            p_dados->>'utm_source', p_dados->>'utm_medium', p_dados->>'utm_campaign', p_dados->>'utm_content', coalesce(p_dados->>'origem', 'captura'), 'captura', gen_random_uuid());
  end if;
  return jsonb_build_object('pessoa_id', pid, 'nova', not existia, 'repetida', ja);
end $$;
revoke execute on function public.registrar_captura(uuid, uuid, text, text, text, jsonb) from public, anon;
grant execute on function public.registrar_captura(uuid, uuid, text, text, text, jsonb) to authenticated, service_role;

create or replace function public.campanha_captacao(p_campanha uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c campanhas; r jsonb;
begin
  select * into c from campanhas where id = p_campanha;
  if not found or not pertence_ao_workspace(c.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  with p as (select cp.*, pe.qualificacao from campanha_participacoes cp join pessoas pe on pe.id = cp.pessoa_id where cp.campanha_id = c.id)
  select jsonb_build_object(
    'leads', (select count(*) from p),
    'tentativas', coalesce((select sum(tentativas) from p), 0),
    'repetidas', coalesce((select sum(tentativas - 1) from p where tentativas > 1), 0),
    'leads_com_repeticao', (select count(*) from p where tentativas > 1),
    'taxa_duplicidade', case when coalesce((select sum(tentativas) from p), 0) > 0 then round(coalesce((select sum(tentativas - 1) from p where tentativas > 1), 0)::numeric * 100 / (select sum(tentativas) from p), 1) end,
    'alunos', (select count(*) from p where era_aluno), 'nao_alunos', (select count(*) from p where not era_aluno),
    'ja_clientes', (select count(*) from p where era_cliente), 'qualificados', (select count(*) from p where qualificacao = 'qualificado'),
    'por_canal', coalesce((select jsonb_agg(x order by x.leads desc) from (
        select coalesce(p.canal, 'sem origem') as canal, p.temperatura, count(*) as leads, coalesce(sum(tentativas - 1), 0) as repetidas,
               count(*) filter (where qualificacao = 'qualificado') as qualificados, count(*) filter (where era_aluno) as alunos
          from p group by 1, 2) x), '[]'::jsonb))
  into r;
  return r;
end $$;
revoke execute on function public.campanha_captacao(uuid) from public, anon;
grant execute on function public.campanha_captacao(uuid) to authenticated, service_role;

-- ============ 5. ofertas: pedido e taxa de aceite ============
alter table vendas add column if not exists pedido_ref text;
create index if not exists vendas_pedido_ref on vendas (workspace_id, pedido_ref) where pedido_ref is not null;
create or replace function public.campanha_ofertas_resultado(p_ws uuid, p_campanha uuid)
returns jsonb language plpgsql stable set search_path = public as $$
declare r jsonb; princ numeric;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  -- base do aceite: vendas aprovadas das ofertas principais da campanha (cada pedido principal é uma oportunidade de bump/upsell)
  select count(*) into princ from vendas x
   where x.workspace_id = p_ws and x.campanha_id = p_campanha and x.status = 'aprovada'
     and x.produto_id in (select produto_id from campanha_ofertas where campanha_id = p_campanha and papel = 'principal');
  select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'produto_id', o.produto_id, 'produto', pr.nome, 'nome', o.nome, 'papel', o.papel, 'preco', o.preco,
      'vendas', coalesce(v.n, 0) + coalesce(c.n, 0), 'receita', coalesce(v.rec, 0) + coalesce(c.rec, 0),
      'aceite', case when o.papel <> 'principal' and princ > 0 then round(coalesce(v.n, 0) * 100.0 / princ, 1) end, 'base_aceite', princ) order by o.ordem, o.criado_em), '[]'::jsonb) into r
  from campanha_ofertas o join produtos pr on pr.id = o.produto_id
  left join lateral (select count(*) n, sum(x.valor_bruto) rec from vendas x where x.workspace_id = p_ws and x.campanha_id = p_campanha and x.produto_id = o.produto_id and x.status = 'aprovada') v on true
  left join lateral (select count(distinct k.id) n, sum(ci.quantidade * ci.valor) rec from contratos k join contrato_itens ci on ci.contrato_id = k.id
      where k.workspace_id = p_ws and k.campanha_id = p_campanha and ci.produto_id = o.produto_id and k.status in ('ativo', 'encerrado')) c on true
  where o.workspace_id = p_ws and o.campanha_id = p_campanha;
  return r;
end $$;

-- ============ 6. abandono de checkout ============
create table if not exists checkout_abandonos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid references campanhas(id) on delete set null,
  pessoa_id uuid references pessoas(id) on delete set null,
  produto_id uuid references produtos(id) on delete set null,
  valor numeric,
  abandonado_em timestamptz not null,
  origem text not null default 'manual',
  id_externo text,
  recuperado_venda_id uuid references vendas(id) on delete set null,
  recuperado_em timestamptz,
  criado_em timestamptz not null default now()
);
create unique index if not exists checkout_abandonos_externo on checkout_abandonos (workspace_id, id_externo) where id_externo is not null;
create index if not exists checkout_abandonos_ws on checkout_abandonos (workspace_id, abandonado_em);
alter table checkout_abandonos enable row level security;
drop policy if exists checkout_abandonos_ler on checkout_abandonos;
create policy checkout_abandonos_ler on checkout_abandonos for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'ler', '{vendas,mkt}'::text[]));
revoke insert, update, delete on checkout_abandonos from anon, authenticated;
grant select on checkout_abandonos to authenticated;

create or replace function public.abandono_registrar(p_ws uuid, p_campanha uuid, p_nome text, p_email text, p_telefone text, p_produto uuid, p_valor numeric,
                                                     p_em timestamptz default null, p_id_externo text default null, p_origem text default 'manual')
returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid; v uuid; vd vendas;
begin
  if not pode_editar(p_ws, '{vendas,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  pid := pessoa_resolver(p_ws, p_nome, p_email, p_telefone, '{}'::jsonb);
  insert into checkout_abandonos (workspace_id, campanha_id, pessoa_id, produto_id, valor, abandonado_em, origem, id_externo)
  values (p_ws, p_campanha, pid, p_produto, p_valor, coalesce(p_em, now()), coalesce(p_origem, 'manual'), p_id_externo)
  on conflict (workspace_id, id_externo) where id_externo is not null do nothing
  returning id into v;
  if v is null then select id into v from checkout_abandonos where workspace_id = p_ws and id_externo = p_id_externo; return v; end if;
  -- já comprou depois do abandono? marca como recuperado
  select * into vd from vendas where pessoa_id = pid and status = 'aprovada' and (p_produto is null or produto_id = p_produto)
     and data_venda >= coalesce(p_em, now()) and data_venda <= coalesce(p_em, now()) + interval '30 days' order by data_venda limit 1;
  if vd.id is not null then update checkout_abandonos set recuperado_venda_id = vd.id, recuperado_em = vd.data_venda where id = v; end if;
  return v;
end $$;
revoke execute on function public.abandono_registrar(uuid, uuid, text, text, text, uuid, numeric, timestamptz, text, text) from public, anon;
grant execute on function public.abandono_registrar(uuid, uuid, text, text, text, uuid, numeric, timestamptz, text, text) to authenticated, service_role;

create or replace function public.abandono_recupera_trg() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
    update checkout_abandonos a set recuperado_venda_id = new.id, recuperado_em = new.data_venda
     where a.id = (select id from checkout_abandonos b where b.workspace_id = new.workspace_id and b.pessoa_id = new.pessoa_id and b.recuperado_venda_id is null
                     and (b.produto_id is null or b.produto_id = new.produto_id)
                     and b.abandonado_em <= new.data_venda and b.abandonado_em >= new.data_venda - interval '30 days'
                   order by b.abandonado_em desc limit 1);
  end if;
  return null;
end $$;
revoke execute on function public.abandono_recupera_trg() from public, anon, authenticated;
drop trigger if exists abandono_recupera_t on vendas;
create trigger abandono_recupera_t after insert or update of status on vendas for each row execute function public.abandono_recupera_trg();

create or replace function public.abandonos_resumo(p_ws uuid, p_ini date, p_fim date, p_campanha uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with a as (select * from checkout_abandonos where workspace_id = p_ws and (abandonado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim
               and (p_campanha is null or campanha_id = p_campanha))
  select jsonb_build_object('abandonos', (select count(*) from a), 'valor_abandonado', coalesce((select sum(valor) from a), 0),
    'recuperados', (select count(*) from a where recuperado_venda_id is not null),
    'valor_recuperado', coalesce((select sum(v.valor_bruto) from a join vendas v on v.id = a.recuperado_venda_id), 0),
    'taxa_recuperacao', case when (select count(*) from a) > 0 then round((select count(*) from a where recuperado_venda_id is not null) * 100.0 / (select count(*) from a), 1) end)
  into r;
  return r;
end $$;
revoke execute on function public.abandonos_resumo(uuid, date, date, uuid) from public, anon;
grant execute on function public.abandonos_resumo(uuid, date, date, uuid) to authenticated, service_role;

-- ============ 7. atribuição explícita ============
alter table workspaces add column if not exists atribuicao_padrao text not null default 'ultimo_toque';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'workspaces_atribuicao_check') then
    alter table workspaces add constraint workspaces_atribuicao_check check (atribuicao_padrao in ('primeiro_toque', 'ultimo_toque'));
  end if;
end $$;
create table if not exists venda_atribuicoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  venda_id uuid not null references vendas(id) on delete cascade,
  modelo text not null check (modelo in ('primeiro_toque', 'ultimo_toque')),
  canal text,
  campanha_id uuid,
  campanha_canal_id uuid,
  temperatura text,
  utm_source text, utm_medium text, utm_campaign text, utm_content text,
  toque_id uuid,
  peso numeric not null default 1,
  regra_versao int not null default 1,
  evidencia jsonb not null default '{}'::jsonb,
  atribuido_em timestamptz not null default now(),
  unique (venda_id, modelo)
);
create index if not exists venda_atribuicoes_ws on venda_atribuicoes (workspace_id, modelo, canal);
alter table venda_atribuicoes enable row level security;
drop policy if exists venda_atribuicoes_ler on venda_atribuicoes;
create policy venda_atribuicoes_ler on venda_atribuicoes for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'ler', '{vendas,mkt,fin}'::text[]));
revoke insert, update, delete on venda_atribuicoes from anon, authenticated;
grant select on venda_atribuicoes to authenticated;

-- regra v1: primeiro toque = primeira entrada/captura/lista da pessoa com origem até a data da venda;
-- último toque = a origem da própria venda (canal de fechamento ou UTM); sem ela, o último toque com origem antes da venda.
create or replace function public.atribuir_venda(p_venda uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v vendas; t1 pessoa_toques; t2 pessoa_toques; cc campanha_canais; m text; tt pessoa_toques; ev jsonb;
begin
  select * into v from vendas where id = p_venda;
  if not found or v.status <> 'aprovada' then delete from venda_atribuicoes where venda_id = p_venda; return; end if;
  select * into t1 from pessoa_toques where pessoa_id = v.pessoa_id and tipo in ('entrada', 'captura', 'lista') and em <= v.data_venda
     and (coalesce(canal, '') <> '' or coalesce(utm_source, '') <> '') order by em, id limit 1;
  select * into t2 from pessoa_toques where pessoa_id = v.pessoa_id and tipo in ('entrada', 'captura', 'lista', 'etapa', 'comercial') and em <= v.data_venda
     and (coalesce(canal, '') <> '' or coalesce(utm_source, '') <> '') order by em desc, id desc limit 1;
  foreach m in array array['primeiro_toque', 'ultimo_toque'] loop
    cc := null; tt := case when m = 'primeiro_toque' then t1 else t2 end;
    if m = 'ultimo_toque' and (coalesce(v.canal_fechamento, '') <> '' or coalesce(v.utm_source, '') <> '') then
      if v.utm_campaign is not null then select * into cc from campanha_canais where workspace_id = v.workspace_id and utm_campaign = v.utm_campaign; end if;
      ev := jsonb_build_object('fonte', 'venda', 'canal_fechamento', v.canal_fechamento, 'utm_source', v.utm_source);
      insert into venda_atribuicoes (workspace_id, venda_id, modelo, canal, campanha_id, campanha_canal_id, temperatura, utm_source, utm_medium, utm_campaign, utm_content, toque_id, evidencia)
      values (v.workspace_id, v.id, m, coalesce(cc.canal, _canal_de(v.workspace_id, v.canal_fechamento, v.utm_source)), coalesce(v.campanha_id, cc.campanha_id), cc.id, cc.temperatura,
              v.utm_source, v.utm_medium, v.utm_campaign, v.utm_content, null, ev)
      on conflict (venda_id, modelo) do update set canal = excluded.canal, campanha_id = excluded.campanha_id, campanha_canal_id = excluded.campanha_canal_id, temperatura = excluded.temperatura,
        utm_source = excluded.utm_source, utm_medium = excluded.utm_medium, utm_campaign = excluded.utm_campaign, utm_content = excluded.utm_content, toque_id = null, evidencia = excluded.evidencia, atribuido_em = now();
    elsif tt.id is not null then
      if tt.utm_campaign is not null then select * into cc from campanha_canais where workspace_id = v.workspace_id and utm_campaign = tt.utm_campaign; end if;
      ev := jsonb_build_object('fonte', 'toque', 'tipo', tt.tipo, 'em', tt.em, 'descricao', tt.descricao);
      insert into venda_atribuicoes (workspace_id, venda_id, modelo, canal, campanha_id, campanha_canal_id, temperatura, utm_source, utm_medium, utm_campaign, utm_content, toque_id, evidencia)
      values (v.workspace_id, v.id, m, coalesce(cc.canal, _canal_de(v.workspace_id, tt.canal, tt.utm_source)), coalesce(tt.campanha_id, v.campanha_id), cc.id, cc.temperatura,
              tt.utm_source, tt.utm_medium, tt.utm_campaign, tt.utm_content, tt.id, ev)
      on conflict (venda_id, modelo) do update set canal = excluded.canal, campanha_id = excluded.campanha_id, campanha_canal_id = excluded.campanha_canal_id, temperatura = excluded.temperatura,
        utm_source = excluded.utm_source, utm_medium = excluded.utm_medium, utm_campaign = excluded.utm_campaign, utm_content = excluded.utm_content, toque_id = excluded.toque_id, evidencia = excluded.evidencia, atribuido_em = now();
    else
      insert into venda_atribuicoes (workspace_id, venda_id, modelo, canal, campanha_id, evidencia)
      values (v.workspace_id, v.id, m, null, v.campanha_id, jsonb_build_object('fonte', 'nenhuma', 'motivo', 'sem origem registrada antes da venda'))
      on conflict (venda_id, modelo) do update set canal = null, campanha_canal_id = null, temperatura = null, utm_source = null, utm_medium = null, utm_campaign = null, utm_content = null,
        toque_id = null, evidencia = excluded.evidencia, atribuido_em = now();
    end if;
  end loop;
end $$;
revoke execute on function public.atribuir_venda(uuid) from public, anon, authenticated;

create or replace function public.atribuicao_trg() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform atribuir_venda(new.id);
  return null;
end $$;
revoke execute on function public.atribuicao_trg() from public, anon, authenticated;
drop trigger if exists atribuicao_t on vendas;
create trigger atribuicao_t after insert or update of status, utm_source, canal_fechamento, utm_campaign on vendas for each row execute function public.atribuicao_trg();

do $$
declare x uuid;
begin
  for x in select id from vendas v where status = 'aprovada' and not exists (select 1 from venda_atribuicoes a where a.venda_id = v.id) loop
    perform atribuir_venda(x);
  end loop;
end $$;

-- vendas, investimento, CAC e ROAS bruto por canal no modelo escolhido (padrão do workspace)
create or replace function public.vendas_por_canal(p_ws uuid, p_ini date, p_fim date, p_modelo text default null, p_campanha uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m text; r jsonb;
begin
  if not pertence_ao_workspace(p_ws) or not perm(p_ws, 'ler', '{vendas,mkt,fin}'::text[]) then raise exception 'sem acesso ao workspace'; end if;
  m := coalesce(p_modelo, (select atribuicao_padrao from workspaces where id = p_ws), 'ultimo_toque');
  with v as (
    select v.id, v.pessoa_id, v.valor_bruto, coalesce(a.canal, 'sem_origem') as canal, a.temperatura
      from vendas v left join venda_atribuicoes a on a.venda_id = v.id and a.modelo = m
     where v.workspace_id = p_ws and v.status = 'aprovada' and (v.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim
       and (p_campanha is null or v.campanha_id = p_campanha)),
  vs as (select canal, temperatura, count(*) as vendas, count(distinct pessoa_id) as clientes, sum(valor_bruto) as receita from v group by 1, 2),
  inv as (select cc.canal, cc.temperatura, sum(md.custo) as investimento
            from metricas_anuncio_dia md join anuncios an on an.id = md.anuncio_id join campanha_canais cc on cc.id = an.campanha_canal_id
           where md.workspace_id = p_ws and md.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha)
           group by 1, 2),
  j as (select coalesce(vs.canal, inv.canal) as canal, coalesce(vs.temperatura, inv.temperatura) as temperatura,
               coalesce(vs.vendas, 0) as vendas, coalesce(vs.clientes, 0) as clientes, coalesce(vs.receita, 0) as receita, inv.investimento
          from vs full join inv on inv.canal = vs.canal and inv.temperatura is not distinct from vs.temperatura)
  select jsonb_build_object('modelo', m, 'canais', coalesce(jsonb_agg(jsonb_build_object(
      'canal', j.canal, 'nome', coalesce((select nome from canais where workspace_id = p_ws and codigo = j.canal limit 1), case when j.canal = 'sem_origem' then 'Sem origem' else j.canal end),
      'temperatura', j.temperatura, 'vendas', j.vendas, 'clientes', j.clientes, 'receita', j.receita, 'investimento', j.investimento,
      'cac', case when j.investimento is not null and j.clientes > 0 then round(j.investimento / j.clientes, 2) end,
      'roas', case when j.investimento > 0 then round(j.receita / j.investimento, 2) end) order by j.receita desc, j.investimento desc nulls last), '[]'::jsonb))
  into r from j;
  return r;
end $$;
revoke execute on function public.vendas_por_canal(uuid, date, date, text, uuid) from public, anon;
grant execute on function public.vendas_por_canal(uuid, date, date, text, uuid) to authenticated, service_role;

-- ============ 8. metas por tipo ============
create table if not exists campanha_metas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  tipo text not null check (tipo in ('investimento', 'leads', 'leads_qualificados', 'vendas', 'conversao', 'receita', 'ticket_medio', 'cpl', 'cac', 'roas', 'impressoes', 'cliques')),
  valor numeric not null check (valor >= 0),
  fase text,
  canal text,
  temperatura text check (temperatura is null or temperatura in ('frio', 'quente')),
  segmento text check (segmento is null or segmento in ('aluno', 'nao_aluno', 'cliente')),
  data_ini date,
  data_fim date,
  observacao text,
  criado_em timestamptz not null default now()
);
create unique index if not exists campanha_metas_uq on campanha_metas (campanha_id, tipo, coalesce(fase, ''), coalesce(canal, ''), coalesce(temperatura, ''), coalesce(segmento, ''), coalesce(data_ini, '2000-01-01'), coalesce(data_fim, '2000-01-01'));
alter table campanha_metas enable row level security;
drop policy if exists campanha_metas_ler on campanha_metas;
create policy campanha_metas_ler on campanha_metas for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'ler', '{mkt,vendas}'::text[]));
drop policy if exists campanha_metas_editar on campanha_metas;
create policy campanha_metas_editar on campanha_metas for all to authenticated using (pode_editar(workspace_id, '{mkt}'::text[])) with check (pode_editar(workspace_id, '{mkt}'::text[]));
grant select, insert, update, delete on campanha_metas to authenticated;

create or replace function public._meta_realizado(c campanhas, mt campanha_metas, ini date, fim date) returns numeric
language plpgsql stable security definer set search_path = public as $$
declare v_mod text := (select atribuicao_padrao from workspaces where id = c.workspace_id); leads numeric; quals numeric; vend numeric; rec numeric; cli numeric; inv numeric; imp numeric; clq numeric;
begin
  select count(*), count(*) filter (where pe.qualificacao = 'qualificado') into leads, quals
    from campanha_participacoes p join pessoas pe on pe.id = p.pessoa_id
   where p.campanha_id = c.id and (p.entrou_em at time zone 'America/Sao_Paulo')::date between ini and fim
     and (mt.canal is null or p.canal = mt.canal) and (mt.temperatura is null or p.temperatura = mt.temperatura)
     and (mt.segmento is null or (mt.segmento = 'aluno' and p.era_aluno) or (mt.segmento = 'nao_aluno' and not p.era_aluno) or (mt.segmento = 'cliente' and p.era_cliente));
  select count(*), coalesce(sum(v.valor_bruto), 0), count(distinct v.pessoa_id) into vend, rec, cli
    from vendas v left join venda_atribuicoes a on a.venda_id = v.id and a.modelo = coalesce(v_mod, 'ultimo_toque')
    left join campanha_participacoes p on p.campanha_id = c.id and p.pessoa_id = v.pessoa_id
   where v.campanha_id = c.id and v.status = 'aprovada' and (v.data_venda at time zone 'America/Sao_Paulo')::date between ini and fim
     and (mt.canal is null or a.canal = mt.canal) and (mt.temperatura is null or a.temperatura = mt.temperatura)
     and (mt.segmento is null or (mt.segmento = 'aluno' and p.era_aluno) or (mt.segmento = 'nao_aluno' and not coalesce(p.era_aluno, false)) or (mt.segmento = 'cliente' and p.era_cliente));
  select sum(md.custo), sum(md.impressoes), sum(md.cliques) into inv, imp, clq
    from metricas_anuncio_dia md join anuncios an on an.id = md.anuncio_id join campanha_canais cc on cc.id = an.campanha_canal_id
   where cc.campanha_id = c.id and md.data between ini and fim and (mt.canal is null or cc.canal = mt.canal)
     and (mt.temperatura is null or coalesce(an.temperatura, cc.temperatura) = mt.temperatura);
  return case mt.tipo
    when 'leads' then leads when 'leads_qualificados' then quals when 'vendas' then vend when 'receita' then rec
    when 'ticket_medio' then case when vend > 0 then round(rec / vend, 2) end
    when 'conversao' then case when leads > 0 then round(vend * 100 / leads, 2) end
    when 'investimento' then inv when 'impressoes' then imp when 'cliques' then clq
    when 'cpl' then case when leads > 0 and inv is not null then round(inv / leads, 2) end
    when 'cac' then case when cli > 0 and inv is not null then round(inv / cli, 2) end
    when 'roas' then case when inv > 0 then round(rec / inv, 2) end end;
end $$;
revoke execute on function public._meta_realizado(campanhas, campanha_metas, date, date) from public, anon, authenticated;

create or replace function public.campanha_metas_painel(p_campanha uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c campanhas; r jsonb := '[]'::jsonb; mt campanha_metas; ini date; fim date; vr numeric; menor boolean;
        h date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  select * into c from campanhas where id = p_campanha;
  if not found or not pertence_ao_workspace(c.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  for mt in select * from campanha_metas where campanha_id = c.id order by fase nulls first, tipo, canal nulls first loop
    ini := coalesce(mt.data_ini, c.data_inicio, '2000-01-01'); fim := least(coalesce(mt.data_fim, c.data_fim, h), h);
    vr := _meta_realizado(c, mt, ini, fim);
    menor := mt.tipo in ('investimento', 'cpl', 'cac');
    r := r || jsonb_build_object('id', mt.id, 'tipo', mt.tipo, 'meta', mt.valor, 'realizado', vr, 'fase', mt.fase, 'canal', mt.canal, 'temperatura', mt.temperatura,
      'segmento', mt.segmento, 'data_ini', mt.data_ini, 'data_fim', mt.data_fim, 'observacao', mt.observacao, 'menor_melhor', menor,
      'pct', case when mt.valor > 0 and vr is not null then round(vr * 100 / mt.valor, 1) end,
      'ok', case when mt.valor > 0 and vr is not null then (case when menor then vr <= mt.valor else vr >= mt.valor end) end);
  end loop;
  return r;
end $$;
revoke execute on function public.campanha_metas_painel(uuid) from public, anon;
grant execute on function public.campanha_metas_painel(uuid) to authenticated, service_role;

-- ============ dicionário: decisões da Fase 2 ============
update metricas_definicoes set observacao = 'Oficial é o bruto (decisão de 10/10/2026). Por canal, a receita segue a atribuição do workspace (último toque, por padrão).', versao = versao + 1, atualizado_em = now()
 where codigo = 'roas' and observacao is distinct from 'Oficial é o bruto (decisão de 10/10/2026). Por canal, a receita segue a atribuição do workspace (último toque, por padrão).';
insert into metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao) values
('atribuicao', 'Atribuição', 'Toda venda aprovada guarda o primeiro toque (primeira entrada com origem) e o último toque (origem da própria venda ou último toque com origem antes dela). Os painéis usam o último toque.', 'venda_atribuicoes', 'Sem origem antes da venda: canal "Sem origem".', 'Regra v1.'),
('taxa_duplicidade', 'Taxa de duplicidade', 'Tentativas repetidas ÷ total de tentativas de cadastro na campanha.', 'campanha_participacoes.tentativas', 'Sem cadastro: sem valor.', 'Alta duplicidade indica formulário, pixel ou página com problema.'),
('aceite_oferta', 'Aceite da oferta', 'Vendas do order bump, upsell, downsell ou cross-sell ÷ vendas das ofertas principais da campanha.', 'vendas + campanha_ofertas', 'Sem venda principal: sem valor.', null),
('recuperacao_checkout', 'Recuperação de checkout', 'Abandonos que viraram venda aprovada do mesmo produto em até 30 dias ÷ abandonos.', 'checkout_abandonos', 'Sem abandono: sem valor.', null)
on conflict (codigo) do update set nome = excluded.nome, formula = excluded.formula, fonte = excluded.fonte, sem_dado = excluded.sem_dado, observacao = excluded.observacao, atualizado_em = now();

-- ============ tela nova no catálogo de acesso ============
insert into acesso_telas (tela, modulo, nome, grupo, ordem) values ('crm-abandonos', 'vendas', 'Abandono de checkout', 'Vendas', 16)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
update pacotes_acesso set telas = telas || array['crm-abandonos'] where telas @> array['crm-vendas'] and not telas @> array['crm-abandonos'];
