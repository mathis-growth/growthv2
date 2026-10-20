-- Planejamento da empresa: plano -> objetivos -> índices (indicadores) -> metas por setor -> campanhas.
create table planos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  data_inicio date not null,
  data_fim date not null,
  visao text,                 -- onde a empresa quer chegar (tamanho, receita, equipe...)
  estrategia text,            -- como vamos alcançar
  status text not null default 'rascunho' check (status in ('rascunho', 'ativo', 'encerrado')),
  criado_em timestamptz not null default now(),
  check (data_fim >= data_inicio)
);
create table plano_objetivos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  plano_id uuid not null references planos(id) on delete cascade,
  titulo text not null,
  descricao text,
  ordem int not null default 0
);
-- índices que queremos mover (resultados-chave). chave = origem automática; sem chave = valor manual.
create table plano_indicadores (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  plano_id uuid not null references planos(id) on delete cascade,
  objetivo_id uuid not null references plano_objetivos(id) on delete cascade,
  nome text not null,
  chave text check (chave in ('receita', 'mrr', 'leads', 'clientes', 'conversao', 'investimento', 'cac', 'ticket_medio')),
  unidade text not null default 'num' check (unidade in ('brl', 'num', 'pct')),
  sentido text not null default 'aumentar' check (sentido in ('aumentar', 'diminuir')),
  valor_base numeric(16, 4) not null default 0,
  valor_meta numeric(16, 4) not null,
  valor_atual numeric(16, 4),         -- só para os manuais
  responsavel text
);
create table plano_metas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  plano_id uuid not null references planos(id) on delete cascade,
  indicador_id uuid references plano_indicadores(id) on delete set null,
  setor text not null check (setor in ('marketing', 'vendas', 'financeiro', 'operacao', 'produto', 'cs', 'outro')),
  titulo text not null,
  chave text check (chave in ('receita', 'mrr', 'leads', 'clientes', 'conversao', 'investimento', 'cac', 'ticket_medio')),
  unidade text not null default 'num' check (unidade in ('brl', 'num', 'pct')),
  sentido text not null default 'aumentar' check (sentido in ('aumentar', 'diminuir')),
  valor_base numeric(16, 4) not null default 0,
  valor_meta numeric(16, 4) not null,
  valor_atual numeric(16, 4),
  prazo date,
  responsavel text,
  status text not null default 'em_andamento' check (status in ('em_andamento', 'concluida', 'cancelada'))
);
alter table campanhas add column meta_id uuid references plano_metas(id) on delete set null;

do $$ declare t text; begin
  foreach t in array array['planos', 'plano_objetivos', 'plano_indicadores', 'plano_metas'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_rls', t);
  end loop;
end $$;
create index plano_ind_ix on plano_indicadores (plano_id);
create index plano_metas_ix on plano_metas (plano_id);

-- Valor realizado de um índice no período, por regra fixa (nada de IA).
create or replace function valor_indicador(p_ws uuid, p_chave text, p_ini date, p_fim date) returns numeric
language plpgsql stable security definer set search_path = public as $$
declare v numeric; cli numeric; rec numeric; lds numeric; inv numeric;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este workspace'; end if;
  select coalesce(sum(valor), 0) into rec from v_dre_mensal
   where workspace_id = p_ws and tipo = 'receita' and mes >= date_trunc('month', p_ini)::date and mes <= date_trunc('month', p_fim)::date;
  select count(*) into lds from pessoas where workspace_id = p_ws
   and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select count(*) into cli from pessoas where workspace_id = p_ws and convertido_em is not null
   and (convertido_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select coalesce(sum(custo), 0) into inv from v_trafego_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim;
  v := case p_chave
    when 'receita' then rec
    when 'leads' then lds
    when 'clientes' then cli
    when 'investimento' then inv
    when 'conversao' then case when lds > 0 then round(100.0 * (select count(*) from pessoas where workspace_id = p_ws and convertido_em is not null
         and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim) / lds, 2) end
    when 'cac' then case when cli > 0 then round(inv / cli, 2) end
    when 'ticket_medio' then case when cli > 0 then round(rec / cli, 2) end
    when 'mrr' then (select coalesce(sum(
                       (select coalesce(sum(i.quantidade * i.valor), 0) from contrato_itens i where i.contrato_id = c.id)
                       / (case c.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end)), 0)
                     from contratos c where c.workspace_id = p_ws and c.status = 'ativo' and c.recorrente
                       and c.data_inicio <= p_fim and (c.data_fim is null or c.data_fim >= p_fim))
  end;
  return v;
end $$;
revoke execute on function valor_indicador(uuid, text, date, date) from public, anon;
grant execute on function valor_indicador(uuid, text, date, date) to authenticated;

-- Impede ligar itens a plano/meta de outro cliente (workspace).
create or replace function plano_mesmo_workspace() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'campanhas' then
    if new.meta_id is not null and not exists (select 1 from plano_metas where id = new.meta_id and workspace_id = new.workspace_id) then
      raise exception 'A meta precisa ser do mesmo workspace da campanha';
    end if;
  else
    if not exists (select 1 from planos where id = new.plano_id and workspace_id = new.workspace_id) then
      raise exception 'O plano precisa ser do mesmo workspace';
    end if;
  end if;
  return new;
end $$;
create trigger plano_obj_ws before insert or update on plano_objetivos for each row execute function plano_mesmo_workspace();
create trigger plano_ind_ws before insert or update on plano_indicadores for each row execute function plano_mesmo_workspace();
create trigger plano_met_ws before insert or update on plano_metas for each row execute function plano_mesmo_workspace();
create trigger camp_meta_ws before insert or update of meta_id on campanhas for each row execute function plano_mesmo_workspace();
