-- RODAR no SQL Editor do Supabase (cópia de migrations/20261202100000_go_to_market.sql).
-- v0.205 — Pacote Go-to-Market (sem financeiro no Growths) e Custos de marketing.
-- 1. Tela nova "Custos de marketing" (mkt-custos) no catálogo de telas e o pacote "Go-to-Market": tudo, menos o Financeiro
--    (contas a pagar e a receber, lançamentos, bancos, DRE) e o cadastro financeiro e contábil.
-- 2. Custos de marketing por cliente (opcional): itens fixos (repetem todo mês até mudar) e variáveis (lançados todo mês),
--    meses fechados e a configuração (ligado e quem lança).
-- 3. Funções: resultado de marketing do período, vendas por plataforma, fechar e reabrir o mês.
-- 4. Rotina diária (pg_cron, se existir): no último dia do mês cria a atividade "Lançar os custos de marketing" para o cliente;
--    a partir do dia 3 do mês seguinte, se ainda falta lançar ou fechar, avisa a equipe da agência (Mathisa).
-- Pode rodar de novo sem erro.

-- 1. tela e pacote
insert into acesso_telas (tela, modulo, nome, grupo, ordem)
values ('mkt-custos', 'mkt', 'Custos de marketing', 'Marketing', coalesce((select ordem from acesso_telas where tela = 'mkt-video'), 0) + 1)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;

insert into pacotes_acesso (nome, descricao, telas, ativo)
select 'Go-to-Market', 'Administrativo, Marketing, Vendas, Atendimento e Customer Success, sem o financeiro: sem contas a pagar e a receber, bancos, lançamentos e DRE. Custos de marketing opcionais para o CAC completo e o Resultado de marketing.',
  array(select tela from acesso_telas
        where grupo not in ('Financeiro', 'Configurações / Financeiro e contabilidade', 'Growth Starter')
          and tela not in ('gro-lucro', 'gro-analise', 'gro-cenarios', 'ho-cohort', 'ho-ascensao') order by ordem), true
where not exists (select 1 from pacotes_acesso where nome = 'Go-to-Market');

-- 2. custos de marketing
create table if not exists public.mkt_custos_config (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  ativo boolean not null default false,
  responsavel_id uuid references equipe(id) on delete set null,
  atualizado_em timestamptz not null default now()
);
comment on table public.mkt_custos_config is 'v0.205: custos de marketing ligados para o cliente e quem lança os variáveis no fim do mês (pessoa da equipe do cliente).';

create table if not exists public.mkt_custos_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 120),
  tipo text not null check (tipo in ('fixo', 'variavel')),
  valor numeric(14,2) check (valor is null or valor >= 0),
  desde date not null check (desde = date_trunc('month', desde)::date),
  ate date check (ate is null or ate = date_trunc('month', ate)::date),
  criado_em timestamptz not null default now(),
  check (tipo = 'variavel' or valor is not null),
  check (ate is null or ate >= desde)
);
comment on table public.mkt_custos_itens is 'v0.205: um custo que entra no CAC completo. Fixo: valor que repete todo mês de "desde" até "ate". Variável: o valor é lançado mês a mês em mkt_custos_valores.';
create index if not exists mkt_custos_itens_ws on public.mkt_custos_itens (workspace_id);

create table if not exists public.mkt_custos_valores (
  item_id uuid not null references mkt_custos_itens(id) on delete cascade,
  mes date not null check (mes = date_trunc('month', mes)::date),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  valor numeric(14,2) not null check (valor >= 0),
  lancado_em timestamptz not null default now(),
  lancado_por uuid default auth.uid(),
  primary key (item_id, mes)
);

create table if not exists public.mkt_custos_meses (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  mes date not null check (mes = date_trunc('month', mes)::date),
  fechado_em timestamptz,
  fechado_por uuid,
  atividade_id uuid references projeto_atividades(id) on delete set null,
  aviso_cliente_em timestamptz,
  aviso_equipe_em timestamptz,
  primary key (workspace_id, mes)
);

alter table public.mkt_custos_config enable row level security;
alter table public.mkt_custos_itens enable row level security;
alter table public.mkt_custos_valores enable row level security;
alter table public.mkt_custos_meses enable row level security;
do $$ declare t text; begin
  foreach t in array array['mkt_custos_config', 'mkt_custos_itens', 'mkt_custos_valores', 'mkt_custos_meses'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna())', t || '_ver', t);
    execute format('drop policy if exists %I on public.%I', t || '_gravar', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (pode_editar(workspace_id, ''{adm,mkt}''::text[]))', t || '_gravar', t);
    execute format('drop policy if exists %I on public.%I', t || '_alterar', t);
    execute format('create policy %I on public.%I for update to authenticated using (pode_editar(workspace_id, ''{adm,mkt}''::text[])) with check (pode_editar(workspace_id, ''{adm,mkt}''::text[]))', t || '_alterar', t);
    execute format('drop policy if exists %I on public.%I', t || '_excluir', t);
    execute format('create policy %I on public.%I for delete to authenticated using (pode_editar(workspace_id, ''{adm,mkt}''::text[]))', t || '_excluir', t);
    execute format('revoke all on public.%I from anon', t);
  end loop; end $$;
grant select, insert, update, delete on public.mkt_custos_config, public.mkt_custos_itens, public.mkt_custos_valores to authenticated;
grant select on public.mkt_custos_meses to authenticated;
-- o mês fechado só muda pelas funções (fechar e reabrir)
drop policy if exists mkt_custos_meses_gravar on public.mkt_custos_meses;
drop policy if exists mkt_custos_meses_alterar on public.mkt_custos_meses;
drop policy if exists mkt_custos_meses_excluir on public.mkt_custos_meses;
-- valor de variável não muda em mês fechado
create or replace function public.mkt_custos_valor_trava() returns trigger language plpgsql security definer set search_path = public as $$
declare ws uuid := coalesce(new.workspace_id, old.workspace_id); m date := coalesce(new.mes, old.mes);
begin
  if exists (select 1 from mkt_custos_meses where workspace_id = ws and mes = m and fechado_em is not null) then
    raise exception 'O mês % já foi fechado. Reabra o mês para mudar os custos.', to_char(m, 'MM/YYYY');
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists mkt_custos_valor_trava on public.mkt_custos_valores;
create trigger mkt_custos_valor_trava before insert or update or delete on public.mkt_custos_valores for each row execute function mkt_custos_valor_trava();

-- custos de um mês: fixos vigentes + variáveis lançados, e quantos variáveis faltam
create or replace function public.mkt_custos_mes(p_ws uuid, p_mes date) returns jsonb
language sql stable security definer set search_path = public as $$
  with it as (select * from mkt_custos_itens where workspace_id = p_ws and desde <= p_mes and (ate is null or ate >= p_mes))
  select jsonb_build_object('mes', p_mes,
    'fixos', coalesce((select sum(valor) from it where tipo = 'fixo'), 0),
    'variaveis', coalesce((select sum(v.valor) from it join mkt_custos_valores v on v.item_id = it.id and v.mes = p_mes where it.tipo = 'variavel'), 0),
    'n_variaveis', (select count(*) from it where tipo = 'variavel'),
    'faltam', (select count(*) from it where tipo = 'variavel' and not exists (select 1 from mkt_custos_valores v where v.item_id = it.id and v.mes = p_mes)),
    'fechado_em', (select fechado_em from mkt_custos_meses where workspace_id = p_ws and mes = p_mes))
$$;
revoke all on function public.mkt_custos_mes(uuid, date) from public, anon, authenticated;

-- 3. resultado de marketing do período: receita, mídia, custos de marketing (proporcionais aos dias do mês no período),
--    clientes novos (primeira compra aprovada no período) e a situação de cada mês
create or replace function public.mkt_resultado(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare rec numeric; nv int; novos int; midia numeric; cm numeric := 0; m date; dm jsonb; meses jsonb := '[]'::jsonb; dias int; dentro int; ativo boolean;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  select coalesce(sum(valor_bruto), 0), count(*) into rec, nv from vendas
    where workspace_id = p_ws and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select count(*) into novos from (select pessoa_id, min((data_venda at time zone 'America/Sao_Paulo')::date) d from vendas
    where workspace_id = p_ws and status = 'aprovada' and pessoa_id is not null group by pessoa_id) x where x.d between p_ini and p_fim;
  select coalesce(sum(custo), 0) into midia from metricas_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim;
  select coalesce((select c.ativo from mkt_custos_config c where c.workspace_id = p_ws), false) into ativo;
  if ativo then
    m := date_trunc('month', p_ini)::date;
    while m <= p_fim loop
      dm := mkt_custos_mes(p_ws, m);
      dias := extract(day from (m + interval '1 month - 1 day'))::int;
      dentro := (least(p_fim, (m + interval '1 month - 1 day')::date) - greatest(p_ini, m) + 1);
      cm := cm + ((dm->>'fixos')::numeric + (dm->>'variaveis')::numeric) * dentro / dias;
      meses := meses || (dm || jsonb_build_object('dias_no_periodo', dentro, 'dias_mes', dias));
      m := (m + interval '1 month')::date;
    end loop;
  end if;
  return jsonb_build_object('ini', p_ini, 'fim', p_fim, 'receita', round(rec, 2), 'vendas', nv, 'clientes_novos', novos, 'midia', round(midia, 2),
    'custos_ativo', ativo, 'custos_mkt', case when ativo then round(cm, 2) end, 'meses', meses);
end $$;
revoke all on function public.mkt_resultado(uuid, date, date) from public, anon;
grant execute on function public.mkt_resultado(uuid, date, date) to authenticated;

-- vendas por plataforma no período (o que a plataforma deve repassar; o Growths não sabe se caiu na conta)
create or replace function public.vendas_por_plataforma(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  return coalesce((select jsonb_agg(x order by x.bruto desc) from (
    select coalesce(p.nome, 'Sem plataforma') plataforma,
      count(*) filter (where v.status = 'aprovada') vendas,
      round(coalesce(sum(v.valor_bruto) filter (where v.status = 'aprovada'), 0), 2) bruto,
      round(coalesce(sum(v.taxa_plataforma) filter (where v.status = 'aprovada'), 0), 2) taxa,
      round(coalesce(sum(v.impostos) filter (where v.status = 'aprovada'), 0), 2) impostos,
      round(coalesce(sum(c.valor) filter (where v.status = 'aprovada'), 0), 2) comissoes,
      count(*) filter (where v.status = 'reembolsada') reembolsos,
      round(coalesce(sum(v.valor_bruto) filter (where v.status = 'reembolsada'), 0), 2) valor_reembolsado,
      round(coalesce(sum(coalesce(v.valor_a_receber, v.valor_bruto - coalesce(v.taxa_plataforma, 0))) filter (where v.status = 'aprovada'), 0), 2) a_receber
    from vendas v left join plataformas_venda p on p.id = v.plataforma_id
    left join (select venda_id, sum(valor) valor from comissoes where workspace_id = p_ws and status <> 'cancelada' group by venda_id) c on c.venda_id = v.id
    where v.workspace_id = p_ws and (v.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim and v.status in ('aprovada', 'reembolsada')
    group by 1) x), '[]'::jsonb);
end $$;
revoke all on function public.vendas_por_plataforma(uuid, date, date) from public, anon;
grant execute on function public.vendas_por_plataforma(uuid, date, date) to authenticated;

-- fechar o mês: só com todos os variáveis lançados; conclui a atividade do mês
create or replace function public.mkt_custos_fechar(p_ws uuid, p_mes date) returns jsonb
language plpgsql security definer set search_path = public as $$
declare d jsonb; a uuid;
begin
  if not pode_editar(p_ws, '{adm,mkt}'::text[]) then raise exception 'Sem permissão para fechar o mês'; end if;
  p_mes := date_trunc('month', p_mes)::date;
  if p_mes >= date_trunc('month', (now() at time zone 'America/Sao_Paulo'))::date and (now() at time zone 'America/Sao_Paulo')::date < (p_mes + interval '1 month - 1 day')::date then
    raise exception 'O mês ainda não terminou: dá para fechar a partir do último dia.';
  end if;
  d := mkt_custos_mes(p_ws, p_mes);
  if (d->>'faltam')::int > 0 then raise exception 'Faltam % custo(s) variável(is) de % para fechar o mês.', d->>'faltam', to_char(p_mes, 'MM/YYYY'); end if;
  insert into mkt_custos_meses (workspace_id, mes, fechado_em, fechado_por) values (p_ws, p_mes, now(), auth.uid())
  on conflict (workspace_id, mes) do update set fechado_em = now(), fechado_por = auth.uid() returning atividade_id into a;
  if a is not null then update projeto_atividades set status = 'concluida', concluida_em = coalesce(concluida_em, now()), atualizado_em = now() where id = a and status <> 'concluida'; end if;
  return mkt_custos_mes(p_ws, p_mes);
end $$;
revoke all on function public.mkt_custos_fechar(uuid, date) from public, anon;
grant execute on function public.mkt_custos_fechar(uuid, date) to authenticated;

create or replace function public.mkt_custos_reabrir(p_ws uuid, p_mes date) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not pode_editar(p_ws, '{adm,mkt}'::text[]) then raise exception 'Sem permissão para reabrir o mês'; end if;
  update mkt_custos_meses set fechado_em = null, fechado_por = null where workspace_id = p_ws and mes = date_trunc('month', p_mes)::date;
end $$;
revoke all on function public.mkt_custos_reabrir(uuid, date) from public, anon;
grant execute on function public.mkt_custos_reabrir(uuid, date) to authenticated;

-- 4. rotina diária
create or replace function public.mkt_custos_rodar(p_ref timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = public as $$
declare d date := (p_ref at time zone 'America/Sao_Paulo')::date; c record; alvo date; dm jsonb; mm record; prj uuid; atv uuid; ag record;
        n_atv int := 0; n_av int := 0; rot text;
begin
  for c in select k.*, w.nome wnome from mkt_custos_config k join workspaces w on w.id = k.workspace_id where k.ativo loop
    begin
      for alvo in select x from unnest(array[case when d = (date_trunc('month', d) + interval '1 month - 1 day')::date then date_trunc('month', d)::date end,
                                               (date_trunc('month', d) - interval '1 month')::date]) x where x is not null loop
        dm := mkt_custos_mes(c.workspace_id, alvo);
        if (dm->>'n_variaveis')::int = 0 and (dm->>'fixos')::numeric = 0 then continue; end if;
        if dm->>'fechado_em' is not null then continue; end if;
        rot := to_char(alvo, 'MM/YYYY');
        insert into mkt_custos_meses (workspace_id, mes) values (c.workspace_id, alvo) on conflict do nothing;
        select * into mm from mkt_custos_meses where workspace_id = c.workspace_id and mes = alvo;
        -- a atividade do cliente, uma vez por mês
        if mm.atividade_id is null and mm.aviso_cliente_em is null then
          select id into prj from projetos where workspace_id = c.workspace_id and nome = 'Rotinas do mês' and status <> 'cancelado' limit 1;
          if prj is null then
            insert into projetos (workspace_id, nome, descricao, status) values (c.workspace_id, 'Rotinas do mês', 'Criado pelo Growths: as rotinas de fim de mês (custos de marketing).', 'em_andamento') returning id into prj;
          end if;
          insert into projeto_atividades (workspace_id, projeto_id, titulo, descricao, responsavel_id, status, ordem, prazo, liberada_em, tags)
          values (c.workspace_id, prj, 'Lançar os custos de marketing de ' || rot,
            'Em Marketing › Custos de marketing, lance os custos variáveis de ' || rot || ' e confira os fixos. Depois, feche o mês. Sem isso, o CAC completo e o Resultado de marketing de ' || rot || ' ficam incompletos.',
            c.responsavel_id, 'liberada', 0, (alvo + interval '1 month + 2 days')::date, now(), array['rotina', 'custos-marketing'])
          returning id into atv;
          update mkt_custos_meses set atividade_id = atv, aviso_cliente_em = now() where workspace_id = c.workspace_id and mes = alvo;
          perform growths_avisar(c.workspace_id, 'atividade', 'Lançar os custos de marketing de ' || rot,
            'Os custos variáveis de marketing de ' || rot || ' precisam ser lançados no Growths (Marketing › Custos de marketing) para fechar o mês.');
          n_atv := n_atv + 1;
        end if;
        -- a partir do dia 3 do mês seguinte, avisa a equipe da agência uma vez
        if d >= (alvo + interval '1 month + 2 days')::date and mm.aviso_equipe_em is null then
          for ag in select id from workspaces where agencia loop
            perform growths_avisar(ag.id, 'alerta', 'Custos de marketing pendentes · ' || c.wnome,
              case when (dm->>'faltam')::int > 0 then c.wnome || ': faltam ' || (dm->>'faltam') || ' custo(s) variável(is) de marketing de ' || rot || '. Sem eles, o CAC completo e o Resultado de marketing do mês ficam incompletos.'
                   else c.wnome || ': os custos de marketing de ' || rot || ' estão lançados, mas o mês ainda não foi fechado.' end);
          end loop;
          update mkt_custos_meses set aviso_equipe_em = now() where workspace_id = c.workspace_id and mes = alvo;
          n_av := n_av + 1;
        end if;
      end loop;
    exception when others then raise warning 'mkt_custos_rodar %: %', c.workspace_id, sqlerrm;
    end;
  end loop;
  return jsonb_build_object('dia', d, 'atividades', n_atv, 'avisos_equipe', n_av);
end $$;
revoke all on function public.mkt_custos_rodar(timestamptz) from public, anon, authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'growths-custos-marketing';
    perform cron.schedule('growths-custos-marketing', '7 11 * * *', 'select public.mkt_custos_rodar()');
  end if;
end $$;
