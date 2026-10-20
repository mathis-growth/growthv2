-- Módulo Growth: Growth Model (árvore de métricas) e ciclo de experimentos (Kanban).
create table growth_metricas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pai_id uuid references growth_metricas(id) on delete set null,
  nome text not null,
  descricao text,
  formula text,
  tipo text not null default 'driver' check (tipo in ('north_star', 'driver', 'input')),
  fonte text not null default 'manual' check (fonte in ('manual', 'auto')),
  chave_auto text check (chave_auto in ('investimento', 'leads', 'cpl', 'vendas', 'receita', 'ticket', 'cac', 'roas', 'conv', 'clientes_ativos')),
  unidade text not null default 'numero' check (unidade in ('numero', 'brl', 'pct', 'x')),
  direcao text not null default 'sobe' check (direcao in ('sobe', 'desce')),
  meta numeric,
  valor_manual numeric,
  valor_manual_anterior numeric,
  ordem int not null default 0,
  criado_em timestamptz not null default now(),
  check ((fonte = 'auto') = (chave_auto is not null)),
  check (pai_id is distinct from id)
);
create unique index growth_metricas_north_star on growth_metricas (workspace_id) where tipo = 'north_star';
create index growth_metricas_ws on growth_metricas (workspace_id, pai_id);

create table growth_experimentos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  metrica_id uuid references growth_metricas(id) on delete set null,
  titulo text not null,
  hipotese text,
  criterio_sucesso text,
  responsavel text,
  etapa text not null default 'ideia' check (etapa in ('ideia', 'priorizado', 'rodando', 'analise', 'concluido')),
  impacto int check (impacto between 1 and 10),
  confianca int check (confianca between 1 and 10),
  facilidade int check (facilidade between 1 and 10),
  score numeric(4, 1) generated always as (round((impacto + confianca + facilidade) / 3.0, 1)) stored,
  inicio date,
  fim_previsto date,
  valor_base numeric,
  valor_resultado numeric,
  resultado text check (resultado in ('venceu', 'perdeu', 'inconclusivo')),
  decisao text check (decisao in ('escalar', 'repetir', 'descartar')),
  aprendizado text,
  concluido_em date,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  check (etapa <> 'concluido' or (resultado is not null and aprendizado is not null))
);
create index growth_experimentos_ws on growth_experimentos (workspace_id, etapa);

create function growth_valida() returns trigger
language plpgsql security definer set search_path = public as $$
declare cur uuid; n int := 0;
begin
  if tg_table_name = 'growth_metricas' then
    if new.pai_id is not null then
      if not exists (select 1 from growth_metricas where id = new.pai_id and workspace_id = new.workspace_id) then
        raise exception 'A métrica pai precisa pertencer ao mesmo workspace'; end if;
      cur := new.pai_id;
      while cur is not null and n < 50 loop
        if cur = new.id then raise exception 'A métrica não pode ficar abaixo de si mesma'; end if;
        select pai_id into cur from growth_metricas where id = cur;
        n := n + 1;
      end loop;
    end if;
  else
    if new.metrica_id is not null and not exists (select 1 from growth_metricas where id = new.metrica_id and workspace_id = new.workspace_id) then
      raise exception 'A métrica precisa pertencer ao mesmo workspace'; end if;
    new.atualizado_em := now();
  end if;
  return new;
end $$;
create trigger growth_metricas_valida before insert or update on growth_metricas for each row execute function growth_valida();
create trigger growth_experimentos_valida before insert or update on growth_experimentos for each row execute function growth_valida();
revoke execute on function growth_valida() from public, anon, authenticated;

alter table growth_metricas enable row level security;
alter table growth_experimentos enable row level security;
create policy growth_metricas_acesso on growth_metricas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy growth_experimentos_acesso on growth_experimentos for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
