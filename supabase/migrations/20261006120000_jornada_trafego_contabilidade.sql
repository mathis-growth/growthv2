-- =====================================================================
-- v0.3.0: tracking completo do lead, jornada por funil (etapas e listas),
-- tráfego pago por anúncio, lançamentos imutáveis e lançamento manual.
-- =====================================================================

-- ---------- Tracking do lead ----------
alter table pessoas
  add column utm_id text,
  add column gclid text,
  add column fbclid text,
  add column referrer text;
create index pessoas_utm_content_ix on pessoas (workspace_id, utm_content);

-- ---------- Jornada por funil ----------
create table funil_etapas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  nome text not null,
  ordem int not null,
  tipo text not null default 'meio' check (tipo in ('entrada', 'meio', 'compra')),
  unique (funil_id, nome)
);
create unique index funil_etapas_entrada_uq on funil_etapas (funil_id) where tipo = 'entrada';
create unique index funil_etapas_compra_uq on funil_etapas (funil_id) where tipo = 'compra';

create table funil_listas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  nome text not null,
  tipo text not null default 'outro' check (tipo in ('grupo', 'api', 'outro')),
  lista_pai_id uuid references funil_listas(id) on delete set null check (lista_pai_id <> id),
  reinicia_jornada boolean not null default false,
  etapa_ao_entrar_id uuid references funil_etapas(id) on delete set null,
  unique (funil_id, nome)
);

create table pessoa_funil (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  etapa_id uuid not null references funil_etapas(id),
  entrou_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (pessoa_id, funil_id)
);
create index pessoa_funil_ix on pessoa_funil (workspace_id, funil_id, etapa_id);

create table pessoa_lista (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  lista_id uuid not null references funil_listas(id) on delete cascade,
  ativo boolean not null default true,
  entrou_em timestamptz not null default now(),
  saiu_em timestamptz,
  primary key (pessoa_id, lista_id)
);

create table pessoa_funil_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  tipo text not null check (tipo in ('etapa', 'lista')),
  ref text,
  de text,
  para text,
  em timestamptz not null default now()
);
create index pessoa_funil_historico_ix on pessoa_funil_historico (pessoa_id, em);

create function pessoa_funil_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id)
     or not exists (select 1 from funis where id = new.funil_id and workspace_id = new.workspace_id)
     or not exists (select 1 from funil_etapas where id = new.etapa_id and funil_id = new.funil_id and workspace_id = new.workspace_id) then
    raise exception 'Pessoa, funil e etapa precisam ser do mesmo workspace, e a etapa precisa pertencer ao funil';
  end if;
  new.atualizado_em := now();
  return new;
end $$;
create trigger pessoa_funil_valida before insert or update on pessoa_funil
  for each row execute function pessoa_funil_valida();

create function pessoa_funil_historico_fn() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into pessoa_funil_historico (workspace_id, pessoa_id, funil_id, tipo, de, para)
    values (new.workspace_id, new.pessoa_id, new.funil_id, 'etapa', null, (select nome from funil_etapas where id = new.etapa_id));
  elsif new.etapa_id is distinct from old.etapa_id then
    insert into pessoa_funil_historico (workspace_id, pessoa_id, funil_id, tipo, de, para)
    values (new.workspace_id, new.pessoa_id, new.funil_id, 'etapa',
            (select nome from funil_etapas where id = old.etapa_id), (select nome from funil_etapas where id = new.etapa_id));
  end if;
  return null;
end $$;
create trigger pessoa_funil_historico after insert or update of etapa_id on pessoa_funil
  for each row execute function pessoa_funil_historico_fn();

create function pessoa_lista_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id)
     or not exists (select 1 from funil_listas where id = new.lista_id and workspace_id = new.workspace_id) then
    raise exception 'Pessoa e lista precisam ser do mesmo workspace';
  end if;
  return new;
end $$;
create trigger pessoa_lista_valida before insert or update on pessoa_lista
  for each row execute function pessoa_lista_valida();

-- matrícula automática: lead de campanha com funil entra na etapa de entrada
create function _matricular_pessoa(p_pessoa uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p pessoas; f uuid; e uuid;
begin
  select * into p from pessoas where id = p_pessoa;
  if p.campanha_id is null then return; end if;
  select funil_id into f from campanhas where id = p.campanha_id;
  if f is null then return; end if;
  select id into e from funil_etapas where funil_id = f order by (tipo = 'entrada') desc, ordem limit 1;
  if e is null then return; end if;
  insert into pessoa_funil (workspace_id, pessoa_id, funil_id, etapa_id)
  values (p.workspace_id, p.id, f, e) on conflict (pessoa_id, funil_id) do nothing;
end $$;

create function pessoas_matricular_fn() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform _matricular_pessoa(new.id);
  return null;
end $$;
create trigger pessoas_matricular_ins after insert on pessoas for each row execute function pessoas_matricular_fn();
create trigger pessoas_matricular_upd after update of campanha_id on pessoas for each row execute function pessoas_matricular_fn();

create function campanhas_matricular_fn() returns trigger
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if new.funil_id is not null and new.funil_id is distinct from old.funil_id then
    for r in select id from pessoas where campanha_id = new.id loop
      perform _matricular_pessoa(r.id);
    end loop;
  end if;
  return null;
end $$;
create trigger campanhas_matricular after update of funil_id on campanhas for each row execute function campanhas_matricular_fn();

-- venda aprovada leva a pessoa para a etapa de compra dos funis em que ela está
create function vendas_mover_jornada() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
    update pessoa_funil pf set etapa_id = c.id
    from funil_etapas c join funis fu on fu.id = c.funil_id
    where pf.pessoa_id = new.pessoa_id and pf.funil_id = c.funil_id and c.tipo = 'compra'
      and (fu.produto_id is null or fu.produto_id = new.produto_id) and pf.etapa_id <> c.id;
  end if;
  return null;
end $$;
create trigger vendas_mover_jornada after insert or update of status on vendas
  for each row execute function vendas_mover_jornada();

create function entrar_na_lista(p_pessoa uuid, p_lista uuid) returns void
language plpgsql security definer set search_path = public as $$
declare l funil_listas; pf pessoa_funil; cur uuid; n int := 0; was boolean; nome_l text; o_atual int; o_alvo int;
begin
  select * into l from funil_listas where id = p_lista;
  if not found then raise exception 'Lista não encontrada'; end if;
  if not pode_operar(l.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  select * into pf from pessoa_funil where pessoa_id = p_pessoa and funil_id = l.funil_id;
  if not found then raise exception 'A pessoa não está neste funil'; end if;

  cur := p_lista;
  while cur is not null and n < 10 loop
    select nome into nome_l from funil_listas where id = cur;
    select ativo into was from pessoa_lista where pessoa_id = p_pessoa and lista_id = cur;
    insert into pessoa_lista (workspace_id, pessoa_id, lista_id, ativo, entrou_em, saiu_em)
    values (l.workspace_id, p_pessoa, cur, true, now(), null)
    on conflict (pessoa_id, lista_id) do update
      set ativo = true, saiu_em = null,
          entrou_em = case when pessoa_lista.ativo then pessoa_lista.entrou_em else now() end;
    if not coalesce(was, false) then
      insert into pessoa_funil_historico (workspace_id, pessoa_id, funil_id, tipo, ref, de, para)
      values (l.workspace_id, p_pessoa, l.funil_id, 'lista', nome_l, 'fora', 'dentro');
    end if;
    select lista_pai_id into cur from funil_listas where id = cur;
    n := n + 1;
  end loop;

  if l.etapa_ao_entrar_id is not null then
    select ordem into o_alvo from funil_etapas where id = l.etapa_ao_entrar_id;
    select ordem into o_atual from funil_etapas where id = pf.etapa_id;
    if o_alvo > o_atual then update pessoa_funil set etapa_id = l.etapa_ao_entrar_id where id = pf.id; end if;
  end if;
end $$;

create function sair_da_lista(p_pessoa uuid, p_lista uuid) returns void
language plpgsql security definer set search_path = public as $$
declare l funil_listas; pf pessoa_funil; ids uuid[]; r record; entrada uuid; tp text;
begin
  select * into l from funil_listas where id = p_lista;
  if not found then raise exception 'Lista não encontrada'; end if;
  if not pode_operar(l.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;

  if l.reinicia_jornada then
    ids := array(select id from funil_listas where funil_id = l.funil_id);
  else
    with recursive d as (
      select id from funil_listas where id = p_lista
      union select f.id from funil_listas f join d on f.lista_pai_id = d.id)
    select array_agg(id) into ids from d;
  end if;

  for r in
    with u as (
      update pessoa_lista set ativo = false, saiu_em = now()
      where pessoa_id = p_pessoa and ativo and lista_id = any(ids)
      returning lista_id)
    select lista_id from u
  loop
    insert into pessoa_funil_historico (workspace_id, pessoa_id, funil_id, tipo, ref, de, para)
    values (l.workspace_id, p_pessoa, l.funil_id, 'lista', (select nome from funil_listas where id = r.lista_id), 'dentro', 'fora');
  end loop;

  if l.reinicia_jornada then
    select * into pf from pessoa_funil where pessoa_id = p_pessoa and funil_id = l.funil_id;
    if found then
      select tipo into tp from funil_etapas where id = pf.etapa_id;
      select id into entrada from funil_etapas where funil_id = l.funil_id order by (tipo = 'entrada') desc, ordem limit 1;
      if tp <> 'compra' and entrada is not null and entrada <> pf.etapa_id then
        update pessoa_funil set etapa_id = entrada where id = pf.id;
      end if;
    end if;
  end if;
end $$;

-- ---------- Tráfego pago por anúncio ----------
create table anuncios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_canal_id uuid not null references campanha_canais(id) on delete cascade,
  nome text not null,
  utm_content text not null,
  imagem_url text,
  id_externo text,
  ativo boolean not null default true,
  unique (campanha_canal_id, utm_content)
);

create table metricas_anuncio_dia (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  anuncio_id uuid not null references anuncios(id) on delete cascade,
  data date not null,
  impressoes int not null default 0 check (impressoes >= 0),
  cliques int not null default 0 check (cliques >= 0),
  custo numeric(14, 2) not null default 0 check (custo >= 0),
  visualizacoes_pagina int not null default 0 check (visualizacoes_pagina >= 0),
  unique (anuncio_id, data)
);
create index metricas_anuncio_dia_ix on metricas_anuncio_dia (workspace_id, data);

create function trafego_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'anuncios' then
    if not exists (select 1 from campanha_canais where id = new.campanha_canal_id and workspace_id = new.workspace_id) then
      raise exception 'Canal da campanha precisa pertencer ao mesmo workspace';
    end if;
  else
    if not exists (select 1 from anuncios where id = new.anuncio_id and workspace_id = new.workspace_id) then
      raise exception 'Anúncio precisa pertencer ao mesmo workspace';
    end if;
  end if;
  return new;
end $$;
create trigger anuncios_valida before insert or update on anuncios for each row execute function trafego_valida();
create trigger metricas_valida before insert or update on metricas_anuncio_dia for each row execute function trafego_valida();

create view v_trafego_anuncio_dia with (security_invoker = true) as
with base as (
  select a.id as anuncio_id, a.workspace_id, cc.utm_campaign, a.utm_content
  from anuncios a join campanha_canais cc on cc.id = a.campanha_canal_id
), lead_dia as (
  select b.anuncio_id, (p.criado_em at time zone 'America/Sao_Paulo')::date as data,
         count(*) as leads, count(*) filter (where p.qualificacao = 'qualificado') as qualificados
  from base b join pessoas p on p.workspace_id = b.workspace_id and p.utm_campaign = b.utm_campaign and p.utm_content = b.utm_content
  group by 1, 2
), venda_dia as (
  select b.anuncio_id, (v.data_venda at time zone 'America/Sao_Paulo')::date as data,
         count(*) as vendas, sum(v.valor_bruto) as receita, count(distinct v.pessoa_id) as clientes
  from base b
  join pessoas p on p.workspace_id = b.workspace_id and p.utm_campaign = b.utm_campaign and p.utm_content = b.utm_content
  join vendas v on v.pessoa_id = p.id and v.status = 'aprovada'
  group by 1, 2
), chaves as (
  select anuncio_id, data from metricas_anuncio_dia
  union select anuncio_id, data from lead_dia
  union select anuncio_id, data from venda_dia
)
select k.anuncio_id, a.workspace_id, a.nome as anuncio, a.utm_content, a.imagem_url,
       cc.canal, cc.utm_campaign, cc.campanha_id, c.nome as campanha, k.data,
       coalesce(m.impressoes, 0) as impressoes, coalesce(m.cliques, 0) as cliques,
       coalesce(m.custo, 0) as custo, coalesce(m.visualizacoes_pagina, 0) as visualizacoes_pagina,
       coalesce(l.leads, 0) as leads, coalesce(l.qualificados, 0) as qualificados,
       coalesce(v.vendas, 0) as vendas, coalesce(v.receita, 0) as receita, coalesce(v.clientes, 0) as clientes
from chaves k
join anuncios a on a.id = k.anuncio_id
join campanha_canais cc on cc.id = a.campanha_canal_id
join campanhas c on c.id = cc.campanha_id
left join metricas_anuncio_dia m on m.anuncio_id = k.anuncio_id and m.data = k.data
left join lead_dia l on l.anuncio_id = k.anuncio_id and l.data = k.data
left join venda_dia v on v.anuncio_id = k.anuncio_id and v.data = k.data;

-- ---------- Contabilidade: lançamentos imutáveis ----------
create function bloqueia_alteracao_contabil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' and not exists (select 1 from workspaces where id = old.workspace_id) then
    return old; -- exclusão do workspace inteiro
  end if;
  raise exception 'Lançamentos contábeis não podem ser alterados nem apagados. Cancele a operação de origem para gerar o estorno.';
end $$;
create trigger lancamentos_imutavel before update or delete on lancamentos for each row execute function bloqueia_alteracao_contabil();
create trigger partidas_imutavel before update or delete on partidas for each row execute function bloqueia_alteracao_contabil();

create function plano_contas_guarda() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.tipo is distinct from old.tipo or new.natureza is distinct from old.natureza or new.codigo is distinct from old.codigo)
     and exists (select 1 from partidas where conta_id = old.id) then
    raise exception 'Esta conta já tem lançamentos: só dá para mudar nome, conta pai, situação e se aceita lançamento.';
  end if;
  return new;
end $$;
create trigger plano_contas_guarda before update on plano_contas for each row execute function plano_contas_guarda();

create function registrar_lancamento_manual(p_ws uuid, p_data date, p_descricao text, p_partidas jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare l uuid; it jsonb; d numeric := 0; c numeric := 0; v numeric; t text; conta uuid; cc uuid;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  if p_partidas is null or jsonb_typeof(p_partidas) <> 'array' or jsonb_array_length(p_partidas) < 2 then
    raise exception 'Informe pelo menos duas partidas (débito e crédito)';
  end if;
  if coalesce(trim(p_descricao), '') = '' then raise exception 'Informe a descrição do lançamento'; end if;
  for it in select * from jsonb_array_elements(p_partidas) loop
    t := it ->> 'tipo'; v := (it ->> 'valor')::numeric;
    if t not in ('D', 'C') or v is null or v <= 0 then
      raise exception 'Cada partida precisa de tipo (D ou C) e valor maior que zero';
    end if;
    if t = 'D' then d := d + v; else c := c + v; end if;
  end loop;
  if d <> c then raise exception 'Débitos (%) e créditos (%) precisam ser iguais', d, c; end if;

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo)
  values (p_ws, coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date), p_descricao, 'manual')
  returning id into l;
  for it in select * from jsonb_array_elements(p_partidas) loop
    conta := nullif(it ->> 'conta_id', '')::uuid; cc := nullif(it ->> 'centro_custo_id', '')::uuid;
    if not exists (select 1 from plano_contas where id = conta and workspace_id = p_ws and aceita_lancamento and ativo) then
      raise exception 'Conta inválida, inativa ou que não aceita lançamento';
    end if;
    if cc is not null and not exists (select 1 from centros_custo where id = cc and workspace_id = p_ws) then
      raise exception 'Centro de custo inválido para este workspace';
    end if;
    insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
    values (p_ws, l, conta, cc, it ->> 'tipo', (it ->> 'valor')::numeric);
  end loop;
  return l;
end $$;

create function estornar_lancamento(p_lanc uuid, p_motivo text default null, p_data date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare l lancamentos; n uuid;
begin
  select * into l from lancamentos where id = p_lanc for update;
  if not found then raise exception 'Lançamento não encontrado'; end if;
  if not pode_operar(l.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if l.origem_tipo <> 'manual' then
    raise exception 'Este lançamento veio de "%" e se cancela pela operação de origem (venda, conta a pagar etc.)', l.origem_tipo;
  end if;
  if exists (select 1 from lancamentos where estorno_de = l.id) then raise exception 'Este lançamento já foi estornado'; end if;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (l.workspace_id, coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date),
          'Estorno: ' || coalesce(l.descricao, '') || coalesce(' (' || p_motivo || ')', ''), 'estorno', l.id, l.id)
  returning id into n;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, n, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor
  from partidas where lancamento_id = l.id;
  return n;
end $$;

create view v_lancamentos with (security_invoker = true) as
select l.id, l.workspace_id, l.data_fato, l.descricao, l.origem_tipo, l.origem_id, l.estorno_de, l.criado_em,
       (select coalesce(sum(p.valor), 0) from partidas p where p.lancamento_id = l.id and p.tipo = 'D') as total,
       (select count(*) from partidas p where p.lancamento_id = l.id) as n_partidas,
       (select e.id from lancamentos e where e.estorno_de = l.id limit 1) as estornado_por
from lancamentos l;

-- ---------- Segurança ----------
do $$
declare t text;
begin
  foreach t in array array['funil_etapas', 'funil_listas', 'pessoa_funil', 'pessoa_lista', 'anuncios', 'metricas_anuncio_dia'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
  end loop;
end $$;
alter table pessoa_funil_historico enable row level security;
create policy pessoa_funil_historico_leitura on pessoa_funil_historico for select to authenticated using (pertence_ao_workspace(workspace_id));

do $$
declare f text;
begin
  foreach f in array array[
    'pessoa_funil_valida()', 'pessoa_funil_historico_fn()', 'pessoa_lista_valida()', '_matricular_pessoa(uuid)',
    'pessoas_matricular_fn()', 'campanhas_matricular_fn()', 'vendas_mover_jornada()', 'trafego_valida()',
    'bloqueia_alteracao_contabil()', 'plano_contas_guarda()',
    'entrar_na_lista(uuid, uuid)', 'sair_da_lista(uuid, uuid)',
    'registrar_lancamento_manual(uuid, date, text, jsonb)', 'estornar_lancamento(uuid, text, date)'] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
  end loop;
end $$;
grant execute on function entrar_na_lista(uuid, uuid) to authenticated;
grant execute on function sair_da_lista(uuid, uuid) to authenticated;
grant execute on function registrar_lancamento_manual(uuid, date, text, jsonb) to authenticated;
grant execute on function estornar_lancamento(uuid, text, date) to authenticated;
