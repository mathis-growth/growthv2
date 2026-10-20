-- v0.88 — Fase 1 da comparação com o Growth's do Rogério: segurança e confiança do dado
-- 1. Identidade da pessoa: telefone e e-mail normalizados pelo banco, telefone único por workspace, pessoa_resolver (telefone > e-mail),
--    cadastros repetidos (v_pessoas_duplicadas) e pessoas_mesclar (junta com histórico em pessoas_mesclagens).
-- 2. Venda sem duplicar: plataforma + ID externo únicos por workspace.
-- 3. Evidência na venda: e-mail e telefone do comprador como estavam, aprovada_em, reembolsada_em, cancelada_em, origem do dado.
-- 4. Auditoria geral (tabela auditoria + gatilho auditar) nas tabelas críticas. Só leitura, só administradores.
-- 5. Indisponível não é zero: disponibilidade (completo | parcial | indisponivel) e atualizado_na_origem nas métricas diárias.
-- 6. Qualidade do dado: qualidade_regras (tolerâncias por workspace) e qualidade_dados(ws, ini, fim) com os avisos para os painéis.
-- 7. Dicionário oficial de métricas (metricas_definicoes).
-- 8. Fechamento de campanha versionado e imutável: campanha_fechar (V1, V2… com motivo), sem alterar nem apagar fechamento.
-- 9. Extrato calculado no banco (extrato_conta).
-- Rode DEPOIS de 20261010250000_casa_modulo.sql. Idempotente.

-- ============ 1. identidade ============
create or replace function public.norm_fone(t text) returns text language sql immutable as $$
  select case when length(d) in (10, 11) then '55' || d when length(d) between 12 and 13 then d else null end
  from (select regexp_replace(coalesce(t, ''), '\D', '', 'g') as d) x;
$$;
create or replace function public.norm_email(t text) returns text language sql immutable as $$
  select nullif(lower(trim(coalesce(t, ''))), '');
$$;
create or replace function public.norm_nome(t text) returns text language sql immutable as $$
  select nullif(lower(regexp_replace(trim(coalesce(t, '')), '\s+', ' ', 'g')), '');
$$;
alter table pessoas add column if not exists telefone_norm text generated always as (norm_fone(telefone)) stored;
alter table pessoas add column if not exists email_norm text generated always as (norm_email(email)) stored;

do $$ begin
  if not exists (select 1 from pg_indexes where indexname = 'pessoas_telefone_uq') then
    if exists (select 1 from pessoas where telefone_norm is not null group by workspace_id, telefone_norm having count(*) > 1) then
      raise notice 'Há telefones repetidos: o índice único de telefone não foi criado. Junte os cadastros em Cadastros repetidos e rode esta migração de novo.';
    else
      create unique index pessoas_telefone_uq on pessoas (workspace_id, telefone_norm) where telefone_norm is not null;
    end if;
  end if;
end $$;
create index if not exists pessoas_nome_norm_ix on pessoas (workspace_id, norm_nome(nome));

create table if not exists pessoas_mesclagens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_mantida uuid not null,
  pessoa_removida uuid not null,
  dados_removida jsonb not null,
  motivo text,
  feito_por uuid default auth.uid(),
  feito_em timestamptz not null default now()
);
alter table pessoas_mesclagens enable row level security;
drop policy if exists pessoas_mesclagens_ler on pessoas_mesclagens;
create policy pessoas_mesclagens_ler on pessoas_mesclagens for select to authenticated using (pertence_ao_workspace(workspace_id));
revoke insert, update, delete on pessoas_mesclagens from anon, authenticated;
grant select on pessoas_mesclagens to authenticated;

-- acha a pessoa pelo telefone (prioridade) ou pelo e-mail; se não achar, cria. Completa e-mail/telefone/nome que faltarem.
create or replace function public.pessoa_resolver(p_ws uuid, p_nome text, p_email text, p_telefone text, p_dados jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare id_ uuid; f text := norm_fone(p_telefone); e text := norm_email(p_email); p pessoas;
begin
  if not pode_editar(p_ws, '{vendas,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if f is null and e is null then raise exception 'Informe telefone ou e-mail para identificar a pessoa'; end if;
  if f is not null then select * into p from pessoas where workspace_id = p_ws and telefone_norm = f; end if;
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

-- prováveis cadastros repetidos: mesmo nome e nenhum contato conflitante (telefone e e-mail não se contradizem)
create or replace view v_pessoas_duplicadas with (security_invoker = true) as
select a.workspace_id, a.id as pessoa_a, b.id as pessoa_b, a.nome as nome_a, b.nome as nome_b,
       a.email as email_a, b.email as email_b, a.telefone as telefone_a, b.telefone as telefone_b,
       a.criado_em as criado_a, b.criado_em as criado_b, 'mesmo nome, contatos compatíveis'::text as motivo
  from pessoas a join pessoas b on b.workspace_id = a.workspace_id and norm_nome(b.nome) = norm_nome(a.nome) and a.id < b.id
 where length(coalesce(norm_nome(a.nome), '')) >= 6
   and not (a.telefone_norm is not null and b.telefone_norm is not null and a.telefone_norm <> b.telefone_norm)
   and not (a.email_norm is not null and b.email_norm is not null and a.email_norm <> b.email_norm);
revoke all on v_pessoas_duplicadas from anon;
grant select on v_pessoas_duplicadas to authenticated;

-- junta dois cadastros: tudo o que aponta para a removida passa para a mantida; a removida é guardada em pessoas_mesclagens
create or replace function public.pessoas_mesclar(p_manter uuid, p_remover uuid, p_motivo text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare a pessoas; b pessoas; r record; c record;
begin
  if p_manter = p_remover then raise exception 'Escolha dois cadastros diferentes'; end if;
  select * into a from pessoas where id = p_manter for update;
  select * into b from pessoas where id = p_remover for update;
  if a.id is null or b.id is null or a.workspace_id <> b.workspace_id then raise exception 'Cadastros não encontrados no mesmo workspace'; end if;
  if not pode_editar(a.workspace_id, '{vendas}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  insert into pessoas_mesclagens (workspace_id, pessoa_mantida, pessoa_removida, dados_removida, motivo)
  values (a.workspace_id, a.id, b.id, to_jsonb(b), p_motivo);
  -- libera o e-mail e o telefone da removida antes de passar para a mantida (são únicos)
  update pessoas set email = null, telefone = null where id = b.id;
  update pessoas set
    email = coalesce(a.email, b.email), telefone = coalesce(a.telefone, b.telefone),
    utm_source = coalesce(a.utm_source, b.utm_source), utm_medium = coalesce(a.utm_medium, b.utm_medium),
    utm_campaign = coalesce(a.utm_campaign, b.utm_campaign), utm_content = coalesce(a.utm_content, b.utm_content),
    utm_term = coalesce(a.utm_term, b.utm_term), pagina_origem = coalesce(a.pagina_origem, b.pagina_origem),
    campanha_id = coalesce(a.campanha_id, b.campanha_id), canal_origem = coalesce(a.canal_origem, b.canal_origem),
    referrer = coalesce(a.referrer, b.referrer), gclid = coalesce(a.gclid, b.gclid), fbclid = coalesce(a.fbclid, b.fbclid),
    tags = (select array_agg(distinct t) from unnest(coalesce(a.tags, '{}') || coalesce(b.tags, '{}')) t),
    status_funil = case when 'cliente' in (a.status_funil, b.status_funil) then 'cliente' else a.status_funil end,
    status_cliente = coalesce(a.status_cliente, b.status_cliente),
    convertido_em = least(a.convertido_em, b.convertido_em),
    criado_em = least(a.criado_em, b.criado_em)
  where id = a.id;
  -- tudo o que aponta para a removida (todas as chaves estrangeiras para pessoas)
  for r in select c2.conrelid::regclass as t, at.attname as col
             from pg_constraint c2 join pg_attribute at on at.attrelid = c2.conrelid and at.attnum = c2.conkey[1]
            where c2.confrelid = 'public.pessoas'::regclass and c2.contype = 'f' and c2.conrelid <> 'public.pessoas'::regclass loop
    begin
      execute format('update %s set %I = $1 where %I = $2', r.t, r.col, r.col) using a.id, b.id;
    exception when unique_violation then
      -- linha a linha: o que já existe para a mantida (ex.: mesma lista) fica só uma vez
      for c in execute format('select ctid as k from %s where %I = $1', r.t, r.col) using b.id loop
        begin
          execute format('update %s set %I = $1 where ctid = $2', r.t, r.col) using a.id, c.k;
        exception when unique_violation then
          execute format('delete from %s where ctid = $1', r.t) using c.k;
        end;
      end loop;
    end;
  end loop;
  delete from pessoas where id = b.id;
  return a.id;
end $$;

revoke execute on function public.pessoa_resolver(uuid, text, text, text, jsonb), public.pessoas_mesclar(uuid, uuid, text) from public, anon;
grant execute on function public.pessoa_resolver(uuid, text, text, text, jsonb), public.pessoas_mesclar(uuid, uuid, text) to authenticated, service_role;

-- ============ 2 e 3. venda sem duplicar e evidência ============
do $$ begin
  if not exists (select 1 from pg_indexes where indexname = 'vendas_externo_uq') then
    if exists (select 1 from vendas where id_externo is not null group by workspace_id, plataforma_id, id_externo having count(*) > 1) then
      raise notice 'Há vendas repetidas pelo ID externo: o índice único não foi criado.';
    else
      create unique index vendas_externo_uq on vendas (workspace_id, coalesce(plataforma_id, '00000000-0000-0000-0000-000000000000'::uuid), id_externo) where id_externo is not null;
    end if;
  end if;
end $$;
alter table vendas add column if not exists comprador_email text;
alter table vendas add column if not exists comprador_telefone text;
alter table vendas add column if not exists aprovada_em timestamptz;
alter table vendas add column if not exists reembolsada_em timestamptz;
alter table vendas add column if not exists cancelada_em timestamptz;
alter table vendas add column if not exists origem_dado text not null default 'manual';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendas_origem_dado_check') then
    alter table vendas add constraint vendas_origem_dado_check check (origem_dado in ('manual', 'importacao', 'integracao'));
  end if;
end $$;

-- dados antigos: aprovação na data da venda, reembolso na data do estorno, comprador pelo cadastro atual
update vendas v set aprovada_em = v.data_venda where v.aprovada_em is null and v.status in ('aprovada', 'reembolsada', 'chargeback');
update vendas v set reembolsada_em = (select min(e.data)::timestamptz from estornos e where e.venda_id = v.id) where v.reembolsada_em is null and v.status in ('reembolsada', 'chargeback');
update vendas v set comprador_email = p.email, comprador_telefone = p.telefone from pessoas p where p.id = v.pessoa_id and v.comprador_email is null and v.comprador_telefone is null;

create or replace function public.vendas_evidencia() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and new.comprador_email is null and new.comprador_telefone is null then
    select email, telefone into new.comprador_email, new.comprador_telefone from pessoas where id = new.pessoa_id;
  end if;
  if tg_op = 'UPDATE' then
    -- a evidência original não muda depois de gravada
    new.comprador_email := coalesce(old.comprador_email, new.comprador_email);
    new.comprador_telefone := coalesce(old.comprador_telefone, new.comprador_telefone);
    new.aprovada_em := coalesce(old.aprovada_em, new.aprovada_em);
  end if;
  if new.status = 'aprovada' and new.aprovada_em is null then new.aprovada_em := case when tg_op = 'INSERT' then coalesce(new.data_venda, now()) else now() end; end if;
  if new.status in ('reembolsada', 'chargeback') and new.reembolsada_em is null then new.reembolsada_em := now(); end if;
  if new.status = 'cancelada' and new.cancelada_em is null then new.cancelada_em := now(); end if;
  return new;
end $$;
revoke execute on function public.vendas_evidencia() from public, anon;
drop trigger if exists vendas_evidencia_t on vendas;
create trigger vendas_evidencia_t before insert or update on vendas for each row execute function public.vendas_evidencia();

-- ============ 4. auditoria ============
create table if not exists auditoria (
  id bigserial primary key,
  workspace_id uuid,
  tabela text not null,
  registro_id uuid,
  acao text not null check (acao in ('inclusao', 'alteracao', 'exclusao')),
  campos text[],
  antes jsonb,
  depois jsonb,
  usuario_id uuid,
  usuario_email text,
  origem text not null,
  em timestamptz not null default now()
);
create index if not exists auditoria_ws_em on auditoria (workspace_id, em desc);
create index if not exists auditoria_registro on auditoria (tabela, registro_id);
alter table auditoria enable row level security;
drop policy if exists auditoria_ler on auditoria;
create policy auditoria_ler on auditoria for select to authenticated
  using ((workspace_id is not null and pertence_ao_workspace(workspace_id) and eh_admin(workspace_id)) or (workspace_id is null and sou_equipe_interna()));
revoke insert, update, delete on auditoria from anon, authenticated;
grant select on auditoria to authenticated;

create or replace function public.auditar() returns trigger
language plpgsql security definer set search_path = public as $$
declare o jsonb; n jsonb; cheio jsonb; mud text[]; ws uuid; rid uuid; claims jsonb;
begin
  if tg_op <> 'INSERT' then o := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then n := to_jsonb(new); end if;
  cheio := coalesce(n, o);
  ws := case when tg_table_name = 'workspaces' then (cheio->>'id')::uuid else nullif(cheio->>'workspace_id', '')::uuid end;
  rid := case when cheio ? 'id' and (cheio->>'id') ~ '^[0-9a-f-]{36}$' then (cheio->>'id')::uuid end;
  if tg_op = 'UPDATE' then
    select array_agg(k order by k) into mud from jsonb_object_keys(n) k
     where (o->k) is distinct from (n->k) and k not in ('atualizado_em', 'updated_at', 'telefone_norm', 'email_norm');
    if mud is null then return null; end if;
    o := (select jsonb_object_agg(k, o->k) from unnest(mud) k);
    n := (select jsonb_object_agg(k, n->k) from unnest(mud) k);
  end if;
  begin claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb; exception when others then claims := null; end;
  insert into auditoria (workspace_id, tabela, registro_id, acao, campos, antes, depois, usuario_id, usuario_email, origem)
  values (ws, tg_table_name, rid, case tg_op when 'INSERT' then 'inclusao' when 'UPDATE' then 'alteracao' else 'exclusao' end,
          mud, o, n, auth.uid(), claims->>'email',
          case when auth.uid() is not null then 'app' when coalesce(auth.role(), '') = 'service_role' then 'servico' else 'banco' end);
  return null;
end $$;
revoke execute on function public.auditar() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['vendas', 'estornos', 'contas_pagar', 'contas_receber', 'contratos', 'campanhas', 'campanha_fechamentos', 'produtos', 'pessoas',
                           'funcoes', 'equipe', 'workspace_membros', 'workspaces', 'pacotes_acesso', 'plano_contas', 'regras_contabilizacao',
                           'contas_bancarias', 'formas_pagamento', 'fornecedores', 'despesas_recorrentes', 'impostos_config', 'plataformas_venda'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end if;
  end loop;
end $$;

-- ============ 5. indisponível não é zero ============
do $$
declare t text;
begin
  foreach t in array array['metricas_anuncio_dia', 'video_metricas_dia', 'campanha_etapa_valores', 'conteudo_conta_dia'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I add column if not exists disponibilidade text not null default %L', t, 'completo');
      execute format('alter table public.%I add column if not exists atualizado_na_origem timestamptz', t);
      if not exists (select 1 from pg_constraint where conname = t || '_disp_check') then
        execute format('alter table public.%I add constraint %I check (disponibilidade in (%L, %L, %L))', t, t || '_disp_check', 'completo', 'parcial', 'indisponivel');
      end if;
    end if;
  end loop;
end $$;

-- ============ 6. qualidade do dado ============
create table if not exists qualidade_regras (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  codigo text not null,
  ativa boolean not null default true,
  tolerancia numeric,
  atualizado_em timestamptz not null default now(),
  primary key (workspace_id, codigo)
);
alter table qualidade_regras enable row level security;
drop policy if exists qualidade_regras_ler on qualidade_regras;
create policy qualidade_regras_ler on qualidade_regras for select to authenticated using (pertence_ao_workspace(workspace_id));
drop policy if exists qualidade_regras_editar on qualidade_regras;
create policy qualidade_regras_editar on qualidade_regras for all to authenticated using (eh_admin(workspace_id)) with check (eh_admin(workspace_id));
grant select, insert, update, delete on qualidade_regras to authenticated;

-- catálogo das verificações (tolerância padrão e unidade)
create or replace function public.qualidade_catalogo() returns jsonb language sql immutable as $$
  select jsonb_build_array(
    jsonb_build_object('codigo', 'vendas_sem_origem', 'titulo', 'Vendas sem origem', 'unidade', '% das vendas', 'padrao', 10, 'explica', 'Venda aprovada sem campanha, sem UTM e sem canal de fechamento: não entra no CAC e no ROAS por canal.'),
    jsonb_build_object('codigo', 'venda_receber_diverge', 'titulo', 'Venda diferente do a receber', 'unidade', 'R$ por venda', 'padrao', 0.05, 'explica', 'O valor a receber da venda não bate com a soma das contas a receber dela.'),
    jsonb_build_object('codigo', 'cliques_maior_impressoes', 'titulo', 'Mais cliques que impressões', 'unidade', 'linhas', 'padrao', 0, 'explica', 'Dia de anúncio com mais cliques do que impressões: dado de mídia impossível.'),
    jsonb_build_object('codigo', 'metricas_incompletas', 'titulo', 'Métricas parciais ou indisponíveis', 'unidade', 'linhas', 'padrao', 0, 'explica', 'Dias marcados como parciais ou indisponíveis na mídia, vídeo, etapas ou conteúdo.'),
    jsonb_build_object('codigo', 'dias_sem_midia', 'titulo', 'Dias sem dado de mídia', 'unidade', 'dias', 'padrao', 0, 'explica', 'Dias entre o primeiro e o último dado de mídia do período sem nenhum registro: o investimento pode estar faltando, não é zero.'),
    jsonb_build_object('codigo', 'gasto_midia_diverge', 'titulo', 'Mídia dos anúncios × financeiro', 'unidade', '% de diferença', 'padrao', 15, 'explica', 'O custo importado dos anúncios difere do lançado em contas de mídia (6.1) no financeiro.'),
    jsonb_build_object('codigo', 'leads_sem_origem', 'titulo', 'Leads sem origem', 'unidade', '% dos leads', 'padrao', 20, 'explica', 'Cadastros novos sem UTM, canal e campanha: somem dos números por canal.'),
    jsonb_build_object('codigo', 'cadastros_repetidos', 'titulo', 'Cadastros repetidos', 'unidade', 'pares', 'padrao', 0, 'explica', 'Pessoas com o mesmo nome e contatos compatíveis: podem ser a mesma pessoa contada duas vezes.'),
    jsonb_build_object('codigo', 'estimativas_vencidas', 'titulo', 'Estimativas vencidas', 'unidade', 'contas', 'padrao', 0, 'explica', 'Conta a pagar com valor estimado já vencida e sem o valor real confirmado.'),
    jsonb_build_object('codigo', 'integracao_atrasada', 'titulo', 'Integração atrasada', 'unidade', 'dias sem sincronizar', 'padrao', 2, 'explica', 'Integração ativa sem sincronizar há mais dias que a tolerância.'));
$$;

create or replace function public.qualidade_dados(p_ws uuid, p_ini date, p_fim date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare cat jsonb := qualidade_catalogo(); it jsonb; tol numeric; ativa boolean; res jsonb := '[]'::jsonb;
        h date := (now() at time zone 'America/Sao_Paulo')::date; fim date := least(p_fim, (now() at time zone 'America/Sao_Paulo')::date);
        n numeric; t numeric; a numeric; b numeric; d1 date; d2 date;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  for it in select * from jsonb_array_elements(cat) loop
    select coalesce(r.ativa, true), coalesce(r.tolerancia, (it->>'padrao')::numeric) into ativa, tol
      from (select 1) x left join qualidade_regras r on r.workspace_id = p_ws and r.codigo = it->>'codigo';
    if not ativa then continue; end if;
    n := null; t := null; a := null; b := null;
    case it->>'codigo'
    when 'vendas_sem_origem' then
      select count(*), count(*) filter (where campanha_id is null and coalesce(utm_source, '') = '' and coalesce(canal_fechamento, '') = '') into t, n
        from vendas where workspace_id = p_ws and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between p_ini and fim;
      if t > 0 and n / t * 100 > tol then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'atencao', 'qtd', n, 'total', t, 'pct', round(n / t * 100, 1),
          'texto', n || ' de ' || t || ' vendas aprovadas do período sem campanha, UTM ou canal de fechamento.', 'afeta', jsonb_build_array('CAC', 'ROAS', 'Ticket médio por canal'), 'tela', 'crm-vendas');
      end if;
    when 'venda_receber_diverge' then
      select count(*) into n from vendas v
       where v.workspace_id = p_ws and v.status = 'aprovada' and (v.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and fim
         and abs(v.valor_a_receber - coalesce((select sum(cr.valor + coalesce(cr.desconto, 0)) from contas_receber cr
                                                where cr.venda_id = v.id and cr.status <> 'cancelado' and cr.substituida_por is null), 0)) > tol;
      if n > 0 then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'alerta', 'qtd', n,
          'texto', n || ' venda(s) com valor a receber diferente da soma das contas a receber.', 'afeta', jsonb_build_array('A receber', 'Caixa projetado'), 'tela', 'fin-receber');
      end if;
    when 'cliques_maior_impressoes' then
      select count(*) into n from metricas_anuncio_dia where workspace_id = p_ws and data between p_ini and fim and impressoes > 0 and cliques > impressoes;
      if n > tol then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'alerta', 'qtd', n,
          'texto', n || ' dia(s) de anúncio com mais cliques que impressões.', 'afeta', jsonb_build_array('CTR', 'CPC', 'Cliques'), 'tela', 'mkt-trafego');
      end if;
    when 'metricas_incompletas' then
      select (select count(*) from metricas_anuncio_dia where workspace_id = p_ws and data between p_ini and fim and disponibilidade <> 'completo')
           + (select count(*) from video_metricas_dia where workspace_id = p_ws and data between p_ini and fim and disponibilidade <> 'completo')
           + (select count(*) from campanha_etapa_valores where workspace_id = p_ws and data between p_ini and fim and disponibilidade <> 'completo')
           + (select count(*) from conteudo_conta_dia where workspace_id = p_ws and data between p_ini and fim and disponibilidade <> 'completo') into n;
      if n > tol then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'atencao', 'qtd', n,
          'texto', n || ' registro(s) diários marcados como parciais ou indisponíveis: os totais estão incompletos, não zerados.', 'afeta', jsonb_build_array('Investimento', 'CPL', 'CAC', 'Leads'), 'tela', 'mkt-trafego');
      end if;
    when 'dias_sem_midia' then
      select min(data), max(data) into d1, d2 from metricas_anuncio_dia where workspace_id = p_ws and data between p_ini and fim;
      if d1 is not null then
        select count(*) into n from generate_series(d1, d2, interval '1 day') g(d)
         where not exists (select 1 from metricas_anuncio_dia m where m.workspace_id = p_ws and m.data = g.d::date);
        if n > tol then
          res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'atencao', 'qtd', n,
            'texto', n || ' dia(s) entre ' || to_char(d1, 'DD/MM') || ' e ' || to_char(d2, 'DD/MM') || ' sem nenhum dado de mídia. O investimento desses dias está faltando (não é zero).',
            'afeta', jsonb_build_array('Investimento', 'CPL', 'CAC', 'ROAS'), 'tela', 'mkt-trafego');
        end if;
      end if;
    when 'gasto_midia_diverge' then
      select coalesce(sum(custo), 0) into a from metricas_anuncio_dia where workspace_id = p_ws and data between p_ini and fim;
      select coalesce(sum(cp.valor), 0) into b from contas_pagar cp join plano_contas pc on pc.id = cp.conta_despesa_id
       where cp.workspace_id = p_ws and pc.codigo like '6.1.%' and cp.status <> 'cancelado' and cp.substituida_por is null and cp.competencia between date_trunc('month', p_ini)::date and fim;
      if a > 0 and b > 0 and abs(a - b) / greatest(a, b) * 100 > tol then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'atencao', 'qtd', round(abs(a - b) / greatest(a, b) * 100, 1),
          'texto', 'Anúncios somam ' || to_char(a, 'FM999G999G990D00') || ' e o financeiro tem ' || to_char(b, 'FM999G999G990D00') || ' em contas de mídia no período.',
          'afeta', jsonb_build_array('Investimento', 'CAC'), 'tela', 'fin-pagar');
      end if;
    when 'leads_sem_origem' then
      select count(*), count(*) filter (where coalesce(utm_source, '') = '' and coalesce(canal_origem, '') = '' and campanha_id is null) into t, n
        from pessoas where workspace_id = p_ws and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and fim;
      if t > 0 and n / t * 100 > tol then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'atencao', 'qtd', n, 'total', t, 'pct', round(n / t * 100, 1),
          'texto', n || ' de ' || t || ' cadastros novos sem UTM, canal ou campanha.', 'afeta', jsonb_build_array('Leads por canal', 'CPL'), 'tela', 'cad-clientes');
      end if;
    when 'cadastros_repetidos' then
      select count(*) into n from v_pessoas_duplicadas where workspace_id = p_ws;
      if n > tol then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'atencao', 'qtd', n,
          'texto', n || ' par(es) de cadastros que parecem ser a mesma pessoa.', 'afeta', jsonb_build_array('Leads', 'Clientes'), 'tela', 'cad-duplicados');
      end if;
    when 'estimativas_vencidas' then
      select count(*) into n from contas_pagar where workspace_id = p_ws and estimativa and status = 'previsto' and vencimento < h and substituida_por is null;
      if n > tol then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'atencao', 'qtd', n,
          'texto', n || ' conta(s) a pagar vencida(s) ainda com valor estimado.', 'afeta', jsonb_build_array('A pagar', 'Resultado do mês', 'Caixa projetado'), 'tela', 'fin-pagar');
      end if;
    when 'integracao_atrasada' then
      select count(*) into n from integracoes where workspace_id = p_ws and ultima_sincronizacao is not null
         and coalesce(status, '') not in ('inativa', 'pausada', 'desconectada', 'pendente') and ultima_sincronizacao < now() - make_interval(days => greatest(tol, 0)::int);
      if n > 0 then
        res := res || jsonb_build_object('codigo', it->>'codigo', 'titulo', it->>'titulo', 'severidade', 'alerta', 'qtd', n,
          'texto', n || ' integração(ões) sem sincronizar há mais de ' || tol || ' dia(s): os dados delas podem estar desatualizados.', 'afeta', jsonb_build_array('Leads', 'Vendas', 'Investimento'), 'tela', 'cfg-integracoes');
      end if;
    else null;
    end case;
  end loop;
  return res;
end $$;
revoke execute on function public.qualidade_dados(uuid, date, date) from public, anon;
grant execute on function public.qualidade_dados(uuid, date, date), public.qualidade_catalogo() to authenticated, service_role;

-- ============ 7. dicionário de métricas ============
create table if not exists metricas_definicoes (
  codigo text primary key,
  nome text not null,
  formula text not null,
  fonte text not null,
  sem_dado text not null,
  observacao text,
  versao int not null default 1,
  atualizado_em timestamptz not null default now()
);
alter table metricas_definicoes enable row level security;
drop policy if exists metricas_definicoes_ler on metricas_definicoes;
create policy metricas_definicoes_ler on metricas_definicoes for select to authenticated using (true);
revoke insert, update, delete on metricas_definicoes from anon, authenticated;
grant select on metricas_definicoes to authenticated;
insert into metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao) values
('venda_valida', 'Venda válida', 'Venda com status aprovada. Pendente, cancelada, reembolsada e chargeback não contam.', 'vendas.status', 'Sem venda aprovada = 0 vendas.', 'Regra também do Growth''s do Rogério (approved/paid).'),
('cliente', 'Clientes', 'Pessoas únicas com ao menos uma venda válida.', 'vendas + pessoas', 'Sem venda válida = 0.', null),
('leads', 'Leads', 'Pessoas cadastradas no período (data de criação).', 'pessoas.criado_em', 'Sem cadastro = 0.', 'A mesma pessoa conta uma vez, pelo telefone ou e-mail.'),
('investimento', 'Investimento', 'Soma do custo diário dos anúncios no período.', 'metricas_anuncio_dia.custo', 'Dia sem registro ou marcado como indisponível não vira zero: aparece aviso de dado faltando.', null),
('cpl', 'CPL', 'Investimento ÷ leads do período.', 'metricas_anuncio_dia + pessoas', 'Sem leads: sem valor (não é zero).', null),
('cac', 'CAC', 'Custos que entram no CAC (centros de custo marcados e mídia) ÷ clientes novos do período.', 'contas_pagar, custos_cac, metricas_anuncio_dia, vendas', 'Sem cliente novo: sem valor.', 'CAC de mídia usa só o investimento em anúncios.'),
('roas', 'ROAS', 'Receita bruta das vendas válidas ÷ investimento em mídia.', 'vendas.valor_bruto + metricas_anuncio_dia.custo', 'Sem investimento: sem valor.', 'Bruto. O líquido (depois de taxas e impostos) é o ROAS real.'),
('receita', 'Receita', 'Soma do valor bruto das vendas válidas (vendas) ou receitas da DRE (financeiro, por competência).', 'vendas.valor_bruto / partidas', 'Sem venda: 0.', null),
('ticket_medio', 'Ticket médio', 'Receita bruta ÷ número de vendas válidas.', 'vendas', 'Sem venda: sem valor.', null),
('conv_lead_venda', 'Lead → cliente', 'Clientes ÷ leads.', 'pessoas', 'Sem lead: sem valor.', null),
('saldo_banco', 'Saldo em banco', 'Saldo inicial + entradas − saídas das contas do tipo conta. Cartão de crédito fica fora.', 'contas_bancarias + movimentacoes_bancarias', 'Conta sem movimento = saldo inicial.', null),
('a_receber', 'A receber no período', 'Contas a receber previstas com vencimento no período.', 'contas_receber', 'Nada a receber = 0.', null),
('a_pagar', 'A pagar no período', 'Contas a pagar previstas com vencimento no período.', 'contas_pagar', 'Nada a pagar = 0.', 'Estimativa conta pelo valor estimado até ser confirmada.'),
('resultado_mes', 'Resultado do mês', 'Receitas − deduções − custos − despesas do mês, por competência (DRE).', 'partidas / lancamentos', 'Sem lançamento = 0.', null),
('mrr', 'MRR', 'Soma mensalizada dos contratos recorrentes ativos hoje.', 'contratos + contrato_itens', 'Sem contrato recorrente = 0.', null),
('churn', 'Churn', 'Alunos que saíram ÷ alunos ativos no início do período.', 'alunos', 'Sem aluno ativo: sem valor.', null)
on conflict (codigo) do update set nome = excluded.nome, formula = excluded.formula, fonte = excluded.fonte, sem_dado = excluded.sem_dado, observacao = excluded.observacao, atualizado_em = now();

-- ============ 8. fechamento versionado ============
alter table campanha_fechamentos add column if not exists versao int;
alter table campanha_fechamentos add column if not exists status text not null default 'oficial';
alter table campanha_fechamentos add column if not exists motivo text;
alter table campanha_fechamentos add column if not exists substitui_id uuid references campanha_fechamentos(id);
alter table campanha_fechamentos add column if not exists corte_em timestamptz;
alter table campanha_fechamentos add column if not exists qualidade jsonb;
alter table campanha_fechamentos add column if not exists fase text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'campanha_fechamentos_status_check') then
    alter table campanha_fechamentos add constraint campanha_fechamentos_status_check check (status in ('oficial', 'substituido'));
  end if;
end $$;
-- fechamentos antigos: numera e deixa o último de cada campanha como oficial
update campanha_fechamentos f set versao = x.v, corte_em = coalesce(f.corte_em, f.fechado_em),
       status = case when x.v = x.n then 'oficial' else 'substituido' end,
       motivo = coalesce(f.motivo, case when x.v = 1 then null else 'Fechamento anterior à v0.88' end)
  from (select id, row_number() over (partition by campanha_id order by fechado_em) v, count(*) over (partition by campanha_id) n from campanha_fechamentos) x
 where x.id = f.id and f.versao is null;

create or replace function public.campanha_fechamentos_imutavel() returns trigger
language plpgsql set search_path = public as $$
begin
  if coalesce(current_setting('growths.fechar', true), '') <> '1' then
    raise exception 'Fechamento é oficial e não pode ser alterado nem apagado. Para corrigir, feche de novo com o motivo (vira uma nova versão).';
  end if;
  if tg_op = 'DELETE' then raise exception 'Fechamento não pode ser apagado'; end if;
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'status') is distinct from (to_jsonb(old) - 'status') then
    raise exception 'Só a situação do fechamento muda (oficial para substituído)';
  end if;
  return coalesce(new, old);
end $$;
revoke execute on function public.campanha_fechamentos_imutavel() from public, anon;
drop trigger if exists campanha_fechamentos_imutavel_t on campanha_fechamentos;
create trigger campanha_fechamentos_imutavel_t before insert or update or delete on campanha_fechamentos
  for each row execute function public.campanha_fechamentos_imutavel();

create or replace function public.campanha_fechar(p_campanha uuid, p_ini date, p_fim date, p_snapshot jsonb, p_motivo text default null, p_fase text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c campanhas; ant campanha_fechamentos; v int; novo uuid;
begin
  select * into c from campanhas where id = p_campanha;
  if not found then raise exception 'Campanha não encontrada'; end if;
  if not pode_editar(c.workspace_id, '{mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_snapshot is null then raise exception 'Fechamento sem os números'; end if;
  select * into ant from campanha_fechamentos where campanha_id = c.id and fase is not distinct from p_fase and status = 'oficial' order by versao desc limit 1 for update;
  if ant.id is not null and length(trim(coalesce(p_motivo, ''))) < 10 then
    raise exception 'Esta campanha já tem um fechamento oficial (V%). Para fechar de novo, explique o motivo (mínimo 10 caracteres).', ant.versao;
  end if;
  select coalesce(max(versao), 0) + 1 into v from campanha_fechamentos where campanha_id = c.id and fase is not distinct from p_fase;
  perform set_config('growths.fechar', '1', true);
  if ant.id is not null then update campanha_fechamentos set status = 'substituido' where id = ant.id; end if;
  insert into campanha_fechamentos (workspace_id, campanha_id, fechado_por, periodo_ini, periodo_fim, snapshot, versao, status, motivo, substitui_id, corte_em, qualidade, fase)
  values (c.workspace_id, c.id, auth.uid(), p_ini, p_fim, p_snapshot, v, 'oficial', nullif(trim(p_motivo), ''), ant.id, now(),
          qualidade_dados(c.workspace_id, coalesce(p_ini, c.data_inicio, '2000-01-01'), coalesce(p_fim, (now() at time zone 'America/Sao_Paulo')::date)), p_fase)
  returning id into novo;
  perform set_config('growths.fechar', '', true);
  return novo;
end $$;
revoke execute on function public.campanha_fechar(uuid, date, date, jsonb, text, text) from public, anon;
grant execute on function public.campanha_fechar(uuid, date, date, jsonb, text, text) to authenticated, service_role;

-- ============ 9. extrato no banco ============
create or replace function public.extrato_conta(p_conta uuid, p_ini date, p_fim date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare b contas_bancarias; ant numeric; r jsonb;
begin
  select * into b from contas_bancarias where id = p_conta;
  if not found or not perm(b.workspace_id, 'ler', '{fin}'::text[]) or not pertence_ao_workspace(b.workspace_id) then raise exception 'Conta não encontrada'; end if;
  select b.saldo_inicial + coalesce(sum(case tipo when 'entrada' then valor else -valor end), 0) into ant
    from movimentacoes_bancarias where conta_bancaria_id = b.id and p_ini is not null and data < p_ini;
  with m as (
    select id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id,
           ant + sum(case tipo when 'entrada' then valor else -valor end) over (order by data, id) as saldo
      from movimentacoes_bancarias
     where conta_bancaria_id = b.id and (p_ini is null or data >= p_ini) and (p_fim is null or data <= p_fim))
  select jsonb_build_object('conta', b.id, 'nome', b.nome, 'cartao', b.tipo = 'cartao', 'saldo_anterior', ant,
           'entradas', coalesce((select sum(valor) from m where tipo = 'entrada'), 0), 'saidas', coalesce((select sum(valor) from m where tipo = 'saida'), 0),
           'saldo_final', coalesce((select saldo from m order by data desc, id desc limit 1), ant),
           'linhas', coalesce((select jsonb_agg(to_jsonb(m) order by data, id) from m), '[]'::jsonb))
    into r;
  return r;
end $$;
revoke execute on function public.extrato_conta(uuid, date, date) from public, anon;
grant execute on function public.extrato_conta(uuid, date, date) to authenticated, service_role;

-- ============ telas novas no catálogo de acesso ============
insert into acesso_telas (tela, modulo, nome, grupo, ordem) values
('cfg-qualidade', 'cfg', 'Qualidade dos dados', 'Configurações / Dados e integrações', 39),
('cfg-metricas', 'cfg', 'Dicionário de métricas', 'Configurações / Dados e integrações', 39),
('cad-auditoria', 'cad', 'Auditoria', 'Configurações / Pessoas e acessos', 41),
('cad-duplicados', 'cad', 'Cadastros repetidos', 'Configurações / Comercial e produtos', 42)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
update pacotes_acesso set telas = telas || array['cfg-qualidade', 'cfg-metricas', 'cad-auditoria']
 where not telas @> array['cfg-qualidade'];
update pacotes_acesso set telas = telas || array['cad-duplicados'] where telas @> array['cad-clientes'] and not telas @> array['cad-duplicados'];
