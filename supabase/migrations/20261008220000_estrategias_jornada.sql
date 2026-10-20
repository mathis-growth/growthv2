-- v0.77 — Estratégias (evolução do cadastro de funis), etapas por campanha, números por dia,
-- jornada do lead (pontos de contato) e último clique na venda.
-- As etapas do Kanban da jornada (funil_etapas) continuam como estão: são os estados por onde as pessoas andam.
-- As etapas da ESTRATÉGIA são métricas do funil (investimento, impressões, entrou no grupo, assistiu aula, comprou…)
-- e ficam em estrategia_etapas; "chegou à etapa X do Kanban" é uma das origens possíveis do número.

-- 1. Funis viram estratégias: tipos novos e o modelo pronto de origem
alter table funis drop constraint if exists funis_tipo_check;
alter table funis add constraint funis_tipo_check check (tipo in ('captacao', 'lancamento', 'perpetuo', 'assinatura', 'webinario', 'disparo', 'recompra', 'comercial', 'outro'));
alter table funis add column if not exists modelo_pronto text check (modelo_pronto is null or char_length(modelo_pronto) <= 40);

-- 2. Catálogo de etapas do cliente (a mesma etapa em todas as campanhas, para comparar e somar)
create table if not exists etapas_catalogo (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  chave text not null check (chave ~ '^[a-z0-9_]{1,40}$'),
  nome text not null check (char_length(nome) between 1 and 80),
  unidade text not null default 'numero' check (unidade in ('numero', 'brl', 'pct')),
  origem text not null default 'manual' check (origem in ('anuncios', 'leads', 'etapa_funil', 'lista', 'video', 'vendas', 'disparo', 'manual')),
  metrica text check (metrica is null or char_length(metrica) <= 30),
  criado_em timestamptz not null default now(),
  unique (workspace_id, chave)
);

-- 3. Etapas da estratégia (o desenho do funil)
create table if not exists estrategia_etapas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  ordem int not null default 0,
  fase text not null default 'aquisicao' check (fase in ('aquisicao', 'aquecimento', 'conversao', 'retencao')),
  chave text not null check (chave ~ '^[a-z0-9_]{1,40}$'),
  nome text not null check (char_length(nome) between 1 and 80),
  unidade text not null default 'numero' check (unidade in ('numero', 'brl', 'pct')),
  origem text not null default 'manual' check (origem in ('anuncios', 'leads', 'etapa_funil', 'lista', 'video', 'vendas', 'disparo', 'manual')),
  metrica text check (metrica is null or char_length(metrica) <= 30),
  origem_ref uuid,
  conta_como text check (conta_como in ('investimento', 'clientes_novos', 'upgrades', 'renovados', 'receita')),
  taxa_esperada numeric check (taxa_esperada is null or taxa_esperada >= 0),
  criado_em timestamptz not null default now(),
  unique (funil_id, chave)
);
create index if not exists estrategia_etapas_funil on estrategia_etapas (funil_id, ordem);

-- 4. Cópia das etapas em cada campanha (mudar a estratégia depois não mexe no histórico da campanha)
create table if not exists campanha_etapas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  ordem int not null default 0,
  fase text not null default 'aquisicao' check (fase in ('aquisicao', 'aquecimento', 'conversao', 'retencao')),
  chave text not null check (chave ~ '^[a-z0-9_]{1,40}$'),
  nome text not null check (char_length(nome) between 1 and 80),
  unidade text not null default 'numero' check (unidade in ('numero', 'brl', 'pct')),
  origem text not null default 'manual' check (origem in ('anuncios', 'leads', 'etapa_funil', 'lista', 'video', 'vendas', 'disparo', 'manual')),
  metrica text check (metrica is null or char_length(metrica) <= 30),
  origem_ref uuid,
  conta_como text check (conta_como in ('investimento', 'clientes_novos', 'upgrades', 'renovados', 'receita')),
  taxa_esperada numeric check (taxa_esperada is null or taxa_esperada >= 0),
  ativa boolean not null default true,
  criado_em timestamptz not null default now(),
  unique (campanha_id, chave)
);
create index if not exists campanha_etapas_camp on campanha_etapas (campanha_id, ordem);
-- datas de cada fase da campanha: {"aquisicao": {"ini": "2026-10-01", "fim": "2026-10-14"}, ...}
alter table campanhas add column if not exists fases jsonb not null default '{}'::jsonb check (jsonb_typeof(fases) = 'object');

-- 5. Números por etapa e por dia (digitados ou vindos de integração)
create table if not exists campanha_etapa_valores (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_etapa_id uuid not null references campanha_etapas(id) on delete cascade,
  data date not null,
  valor numeric not null check (valor >= 0),
  origem text not null default 'manual' check (origem in ('manual', 'sendflow', 'importacao')),
  atualizado_em timestamptz not null default now(),
  unique (campanha_etapa_id, data)
);

-- 6. Último clique na venda: canal e UTM de fechamento (a primeira origem continua no cadastro do lead)
alter table vendas add column if not exists canal_fechamento text check (canal_fechamento is null or char_length(canal_fechamento) <= 60);
alter table vendas add column if not exists utm_source text;
alter table vendas add column if not exists utm_medium text;
alter table vendas add column if not exists utm_campaign text;
alter table vendas add column if not exists utm_content text;

-- 7. Jornada do lead: cada ponto de contato é uma linha
create table if not exists pessoa_toques (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  em timestamptz not null default now(),
  tipo text not null check (tipo in ('entrada', 'etapa', 'lista', 'video', 'disparo', 'comercial', 'compra', 'recompra', 'outro')),
  canal text,
  campanha_id uuid references campanhas(id) on delete set null,
  chave text,
  descricao text,
  utm_source text, utm_medium text, utm_campaign text, utm_content text,
  origem text not null default 'sistema' check (origem in ('sistema', 'sendflow', 'manual', 'importacao')),
  ref_tabela text,
  ref_id uuid,
  constraint pessoa_toques_ref unique (pessoa_id, ref_tabela, ref_id, tipo)
);
create index if not exists pessoa_toques_pessoa on pessoa_toques (pessoa_id, em);
create index if not exists pessoa_toques_ws_em on pessoa_toques (workspace_id, em);

-- 8. Acesso: por workspace + permissões por módulo (como funis e campanhas)
alter table etapas_catalogo enable row level security;
alter table estrategia_etapas enable row level security;
alter table campanha_etapas enable row level security;
alter table campanha_etapa_valores enable row level security;
alter table pessoa_toques enable row level security;
do $p$
declare t text;
begin
  foreach t in array array['etapas_catalogo', 'estrategia_etapas', 'campanha_etapas', 'campanha_etapa_valores'] loop
    execute format('drop policy if exists %I on %I', t || '_acesso', t); execute format('drop policy if exists perm_ler on %I', t); execute format('drop policy if exists perm_inserir on %I', t); execute format('drop policy if exists perm_alterar on %I', t); execute format('drop policy if exists perm_excluir on %I', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format($f$create policy perm_ler on %I as restrictive for select using (perm(workspace_id, 'ler', array['mkt','vendas','gro','adm']))$f$, t);
    execute format($f$create policy perm_inserir on %I as restrictive for insert with check (perm(workspace_id, 'editar', array['mkt','gro']))$f$, t);
    execute format($f$create policy perm_alterar on %I as restrictive for update using (perm(workspace_id, 'editar', array['mkt','gro'])) with check (perm(workspace_id, 'editar', array['mkt','gro']))$f$, t);
    execute format($f$create policy perm_excluir on %I as restrictive for delete using (perm(workspace_id, 'editar', array['mkt','gro']))$f$, t);
  end loop;
end $p$;
drop policy if exists pessoa_toques_acesso on pessoa_toques; drop policy if exists perm_ler on pessoa_toques; drop policy if exists perm_inserir on pessoa_toques; drop policy if exists perm_alterar on pessoa_toques; drop policy if exists perm_excluir on pessoa_toques;
create policy pessoa_toques_acesso on pessoa_toques for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on pessoa_toques as restrictive for select using (perm(workspace_id, 'ler', array['mkt','vendas','gro','adm','cad']));
create policy perm_inserir on pessoa_toques as restrictive for insert with check (perm(workspace_id, 'editar', array['mkt','vendas','gro']));
create policy perm_alterar on pessoa_toques as restrictive for update using (perm(workspace_id, 'editar', array['mkt','vendas','gro'])) with check (perm(workspace_id, 'editar', array['mkt','vendas','gro']));
create policy perm_excluir on pessoa_toques as restrictive for delete using (perm(workspace_id, 'editar', array['mkt','vendas','gro']));

-- 9. Registro automático dos toques (nunca bloqueia a operação de origem)
create or replace function toque_registrar(p_ws uuid, p_pessoa uuid, p_em timestamptz, p_tipo text, p_canal text, p_campanha uuid, p_descricao text,
  p_us text, p_um text, p_uc text, p_ux text, p_ref_tabela text, p_ref_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
  values (p_ws, p_pessoa, coalesce(p_em, now()), p_tipo, nullif(p_canal, ''), p_campanha, p_descricao, p_us, p_um, p_uc, p_ux, 'sistema', p_ref_tabela, p_ref_id)
  on conflict on constraint pessoa_toques_ref do nothing;
exception when others then
  raise warning 'toque_registrar: %', sqlerrm;
end $$;
revoke execute on function toque_registrar(uuid, uuid, timestamptz, text, text, uuid, text, text, text, text, text, text, uuid) from public, anon, authenticated;

create or replace function toque_trg_pessoa() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform toque_registrar(new.workspace_id, new.id, new.criado_em, 'entrada', coalesce(new.canal_origem, new.utm_source), new.campanha_id,
      'Entrou como lead', new.utm_source, new.utm_medium, new.utm_campaign, new.utm_content, 'pessoas', new.id);
  end if;
  return null;
end $$;
drop trigger if exists toque_pessoa_t on pessoas;
create trigger toque_pessoa_t after insert on pessoas for each row execute function toque_trg_pessoa();

create or replace function toque_trg_funil_hist() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.tipo = 'etapa' and new.para is not null then
    perform toque_registrar(new.workspace_id, new.pessoa_id, new.em, 'etapa', null,
      (select c.id from campanhas c where c.funil_id = new.funil_id order by c.data_inicio desc nulls last limit 1),
      new.para, null, null, null, null, 'pessoa_funil_historico', new.id);
  end if;
  return null;
end $$;
drop trigger if exists toque_funil_hist_t on pessoa_funil_historico;
create trigger toque_funil_hist_t after insert on pessoa_funil_historico for each row execute function toque_trg_funil_hist();

create or replace function toque_trg_lista() returns trigger language plpgsql security definer set search_path = public as $$
declare l record;
begin
  if new.ativo and (tg_op = 'INSERT' or not old.ativo) then
    select fl.nome, fl.tipo, fl.funil_id into l from funil_listas fl where fl.id = new.lista_id;
    perform toque_registrar(new.workspace_id, new.pessoa_id, new.entrou_em, 'lista', case when l.tipo = 'grupo' then 'whatsapp' else 'lista' end,
      (select c.id from campanhas c where c.funil_id = l.funil_id order by c.data_inicio desc nulls last limit 1),
      coalesce(l.nome, 'Lista'), null, null, null, null, 'pessoa_lista', new.lista_id);
  end if;
  return null;
end $$;
drop trigger if exists toque_lista_t on pessoa_lista;
create trigger toque_lista_t after insert or update of ativo on pessoa_lista for each row execute function toque_trg_lista();

create or replace function toque_trg_video() returns trigger language plpgsql security definer set search_path = public as $$
declare f record;
begin
  select fv.nome, fv.tipo, fv.campanha_id into f from fontes_video fv where fv.id = new.fonte_id;
  perform toque_registrar(new.workspace_id, new.pessoa_id, new.primeiro_em, 'video', 'video', f.campanha_id,
    coalesce(f.nome, 'Vídeo') || case when new.ao_vivo then ' (ao vivo)' else '' end, null, null, null, null, 'presencas_video', new.id);
  return null;
end $$;
drop trigger if exists toque_video_t on presencas_video;
create trigger toque_video_t after insert on presencas_video for each row execute function toque_trg_video();

create or replace function toque_trg_comercial() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.tipo = 'comercial' and new.pessoa_id is not null and new.para_equipe_id is not null then
    perform toque_registrar(new.workspace_id, new.pessoa_id, new.alterado_em, 'comercial', 'comercial', null,
      'Atendimento comercial: ' || coalesce(new.para_nome, ''), null, null, null, null, 'responsavel_historico', new.id);
  end if;
  return null;
end $$;
drop trigger if exists toque_comercial_t on responsavel_historico;
create trigger toque_comercial_t after insert on responsavel_historico for each row execute function toque_trg_comercial();

create or replace function toque_trg_venda() returns trigger language plpgsql security definer set search_path = public as $$
declare v_antes boolean;
begin
  if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
    v_antes := exists (select 1 from vendas b where b.pessoa_id = new.pessoa_id and b.status = 'aprovada' and b.id <> new.id and b.data_venda < new.data_venda)
            or exists (select 1 from contratos k where k.pessoa_id = new.pessoa_id and k.ativado_em is not null and k.status in ('ativo', 'encerrado') and k.ativado_em < new.data_venda);
    perform toque_registrar(new.workspace_id, new.pessoa_id, new.data_venda, case when v_antes then 'recompra' else 'compra' end,
      coalesce(new.canal_fechamento, new.utm_source), new.campanha_id,
      coalesce((select nome from produtos where id = new.produto_id), 'Compra'), new.utm_source, new.utm_medium, new.utm_campaign, new.utm_content, 'vendas', new.id);
  end if;
  return null;
end $$;
drop trigger if exists toque_venda_t on vendas;
create trigger toque_venda_t after insert or update of status on vendas for each row execute function toque_trg_venda();

create or replace function toque_trg_contrato() returns trigger language plpgsql security definer set search_path = public as $$
declare v_antes boolean;
begin
  if new.ativado_em is not null and new.status in ('ativo', 'encerrado') and (tg_op = 'INSERT' or old.ativado_em is null) then
    v_antes := exists (select 1 from vendas b where b.pessoa_id = new.pessoa_id and b.status = 'aprovada' and b.data_venda < new.ativado_em)
            or exists (select 1 from contratos k where k.pessoa_id = new.pessoa_id and k.id <> new.id and k.ativado_em is not null and k.status in ('ativo', 'encerrado') and k.ativado_em < new.ativado_em);
    perform toque_registrar(new.workspace_id, new.pessoa_id, new.ativado_em, case when v_antes then 'recompra' else 'compra' end,
      'comercial', new.campanha_id, 'Contrato #' || new.numero, null, null, null, null, 'contratos', new.id);
  end if;
  return null;
end $$;
drop trigger if exists toque_contrato_t on contratos;
create trigger toque_contrato_t after insert or update of ativado_em, status on contratos for each row execute function toque_trg_contrato();

-- 10. Copiar o que já existe para a jornada (não começa vazia)
insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, ref_tabela, ref_id)
select p.workspace_id, p.id, p.criado_em, 'entrada', coalesce(p.canal_origem, p.utm_source), p.campanha_id, 'Entrou como lead', p.utm_source, p.utm_medium, p.utm_campaign, p.utm_content, 'pessoas', p.id
from pessoas p on conflict on constraint pessoa_toques_ref do nothing;
insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, campanha_id, descricao, ref_tabela, ref_id)
select h.workspace_id, h.pessoa_id, h.em, 'etapa', (select c.id from campanhas c where c.funil_id = h.funil_id order by c.data_inicio desc nulls last limit 1), h.para, 'pessoa_funil_historico', h.id
from pessoa_funil_historico h where h.tipo = 'etapa' and h.para is not null on conflict on constraint pessoa_toques_ref do nothing;
insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, ref_tabela, ref_id)
select pl.workspace_id, pl.pessoa_id, pl.entrou_em, 'lista', case when fl.tipo = 'grupo' then 'whatsapp' else 'lista' end,
  (select c.id from campanhas c where c.funil_id = fl.funil_id order by c.data_inicio desc nulls last limit 1), fl.nome, 'pessoa_lista', pl.lista_id
from pessoa_lista pl join funil_listas fl on fl.id = pl.lista_id on conflict on constraint pessoa_toques_ref do nothing;
insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, ref_tabela, ref_id)
select pv.workspace_id, pv.pessoa_id, pv.primeiro_em, 'video', 'video', fv.campanha_id, fv.nome || case when pv.ao_vivo then ' (ao vivo)' else '' end, 'presencas_video', pv.id
from presencas_video pv join fontes_video fv on fv.id = pv.fonte_id on conflict on constraint pessoa_toques_ref do nothing;
insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, descricao, ref_tabela, ref_id)
select r.workspace_id, r.pessoa_id, r.alterado_em, 'comercial', 'comercial', 'Atendimento comercial: ' || coalesce(r.para_nome, ''), 'responsavel_historico', r.id
from responsavel_historico r where r.tipo = 'comercial' and r.pessoa_id is not null and r.para_equipe_id is not null on conflict on constraint pessoa_toques_ref do nothing;
insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, ref_tabela, ref_id)
select v.workspace_id, v.pessoa_id, v.data_venda,
  case when exists (select 1 from vendas b where b.pessoa_id = v.pessoa_id and b.status = 'aprovada' and b.id <> v.id and b.data_venda < v.data_venda) then 'recompra' else 'compra' end,
  null, v.campanha_id, coalesce((select nome from produtos where id = v.produto_id), 'Compra'), 'vendas', v.id
from vendas v where v.status = 'aprovada' on conflict on constraint pessoa_toques_ref do nothing;
insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, ref_tabela, ref_id)
select k.workspace_id, k.pessoa_id, k.ativado_em,
  case when exists (select 1 from vendas b where b.pessoa_id = k.pessoa_id and b.status = 'aprovada' and b.data_venda < k.ativado_em)
         or exists (select 1 from contratos k2 where k2.pessoa_id = k.pessoa_id and k2.id <> k.id and k2.ativado_em is not null and k2.status in ('ativo', 'encerrado') and k2.ativado_em < k.ativado_em)
       then 'recompra' else 'compra' end,
  'comercial', k.campanha_id, 'Contrato #' || k.numero, 'contratos', k.id
from contratos k where k.ativado_em is not null and k.status in ('ativo', 'encerrado') on conflict on constraint pessoa_toques_ref do nothing;

-- 11. Aplicar a estratégia na campanha: copia as etapas (as que já existem na campanha ficam, com os números delas)
create or replace function campanha_aplicar_estrategia(p_campanha uuid, p_funil uuid, p_substituir boolean default false) returns int
language plpgsql set search_path = public as $$
declare v_ws uuid; v_n int;
begin
  select workspace_id into v_ws from campanhas where id = p_campanha;
  if v_ws is null then raise exception 'Campanha não encontrada.'; end if;
  if not exists (select 1 from funis where id = p_funil and workspace_id = v_ws) then raise exception 'Estratégia não encontrada.'; end if;
  update campanhas set funil_id = p_funil where id = p_campanha;
  if p_substituir then delete from campanha_etapas where campanha_id = p_campanha; end if;
  insert into campanha_etapas (workspace_id, campanha_id, ordem, fase, chave, nome, unidade, origem, metrica, origem_ref, conta_como, taxa_esperada)
  select v_ws, p_campanha, e.ordem, e.fase, e.chave, e.nome, e.unidade, e.origem, e.metrica, e.origem_ref, e.conta_como, e.taxa_esperada
  from estrategia_etapas e where e.funil_id = p_funil
  on conflict (campanha_id, chave) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- 12. Funil etapa por etapa de uma campanha no período: volume de cada etapa, pela origem do dado
create or replace function campanha_funil_etapas(p_campanha uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable set search_path = public as $$
declare c record; e record; v numeric; r jsonb := '[]'::jsonb; v_kanban text;
begin
  select * into c from campanhas where id = p_campanha;
  if c.id is null then return r; end if;
  for e in select * from campanha_etapas where campanha_id = p_campanha and ativa order by ordem, criado_em loop
    v := null;
    if e.origem = 'anuncios' then
      select case e.metrica when 'investimento' then sum(t.custo) when 'impressoes' then sum(t.impressoes) when 'cliques' then sum(t.cliques) when 'visitas' then sum(t.visualizacoes_pagina) else sum(t.custo) end
        into v from v_trafego_anuncio_dia t where t.campanha_id = p_campanha and t.data between p_ini and p_fim;
    elsif e.origem = 'leads' then
      select count(*) into v from pessoas p where p.campanha_id = p_campanha and (p.criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
    elsif e.origem = 'etapa_funil' and e.origem_ref is not null then
      select nome into v_kanban from funil_etapas where id = e.origem_ref;
      select count(distinct h.pessoa_id) into v from pessoa_funil_historico h
        where h.funil_id = c.funil_id and h.tipo = 'etapa' and h.para = v_kanban and (h.em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
    elsif e.origem = 'lista' and e.origem_ref is not null then
      select count(distinct pl.pessoa_id) into v from pessoa_lista pl where pl.lista_id = e.origem_ref and (pl.entrou_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
    elsif e.origem = 'video' and e.origem_ref is not null then
      select count(distinct pv.pessoa_id) into v from presencas_video pv where pv.fonte_id = e.origem_ref
        and (e.metrica is distinct from 'ao_vivo' or pv.ao_vivo) and (pv.primeiro_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
    elsif e.origem = 'vendas' then
      if e.metrica = 'receita' then
        select coalesce((select sum(x.valor_bruto) from vendas x where x.campanha_id = p_campanha and x.status = 'aprovada' and (x.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim), 0)
             + coalesce((select sum(ci.valor * ci.quantidade) from contratos k join contrato_itens ci on ci.contrato_id = k.id
                         where k.campanha_id = p_campanha and k.status in ('ativo', 'encerrado') and k.ativado_em is not null and (k.ativado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim), 0) into v;
      else
        select count(distinct z.pessoa_id) into v from (
          select x.pessoa_id from vendas x where x.campanha_id = p_campanha and x.status = 'aprovada' and (x.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim
          union select k.pessoa_id from contratos k where k.campanha_id = p_campanha and k.status in ('ativo', 'encerrado') and k.ativado_em is not null and (k.ativado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim) z;
      end if;
    end if;
    -- manual, disparo, ou etapa sem item escolhido / sem dado automático: vale o que foi lançado por dia
    if e.origem in ('manual', 'disparo') or v is null then
      select sum(cv.valor) into v from campanha_etapa_valores cv where cv.campanha_etapa_id = e.id and cv.data between p_ini and p_fim;
    end if;
    r := r || jsonb_build_object('id', e.id, 'chave', e.chave, 'nome', e.nome, 'fase', e.fase, 'unidade', e.unidade, 'origem', e.origem, 'metrica', e.metrica,
      'conta_como', e.conta_como, 'taxa_esperada', e.taxa_esperada, 'valor', coalesce(v, 0), 'tem', v is not null);
  end loop;
  return r;
end $$;
grant execute on function campanha_aplicar_estrategia(uuid, uuid, boolean), campanha_funil_etapas(uuid, date, date) to authenticated;
