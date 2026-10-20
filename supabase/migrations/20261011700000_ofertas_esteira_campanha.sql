-- v0.97 — Growth Now, fase A: oferta independente (versões e bundle), esteira de ofertas ramificada, campanha híbrida com execução por canal e NSM
-- 1. ofertas: descrição, condições, parcelamento, vigência, situação e versão; produto_id passa a ser só o produto principal (o pacote fica em oferta_itens).
-- 2. oferta_itens: produtos da oferta (bundle) com quantidade e % da receita alocada a cada um (soma 100%).
-- 3. oferta_versoes: foto imutável de cada versão (nome, preço, condições, itens). oferta_salvar grava oferta + itens e cria versão quando algo comercial muda.
-- 4. campanha_ofertas = esteira da campanha: versão da oferta usada, instância anterior (pai_id), condição (sempre/aceitou/recusou), etapa de exibição,
--    elegibilidade, gatilho e premissas de exposição e aceite. Gatilho valida: uma oferta principal, pai na mesma campanha, sem ciclos, downsell só após recusa.
-- 5. campanha_ofertas_resultado: aceite com o denominador certo (quem recebeu a oferta: compradores da etapa anterior, ou quem recusou no caso de downsell).
-- 6. Campanha híbrida/paga/orgânica; canais com tipo pago/orgânico; execução por canal com estratégia, tipo e custo de produção; campanha × estratégias (N:N).
-- 7. North Star: evento, população elegível, frequência, fonte e produto.
-- Rode DEPOIS de 20261011600000_cenarios_indicadores.sql. Idempotente.

-- ============ 1. ofertas ============
alter table ofertas alter column produto_id drop not null;
alter table ofertas add column if not exists descricao text;
alter table ofertas add column if not exists condicoes text;
alter table ofertas add column if not exists parcelas_max int check (parcelas_max is null or parcelas_max between 1 and 36);
alter table ofertas add column if not exists vigencia_ini date;
alter table ofertas add column if not exists vigencia_fim date;
alter table ofertas add column if not exists status text not null default 'ativa';
alter table ofertas add column if not exists versao int not null default 1;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'ofertas_status_check') then
    alter table ofertas add constraint ofertas_status_check check (status in ('rascunho', 'ativa', 'pausada', 'encerrada'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'ofertas_vigencia_check') then
    alter table ofertas add constraint ofertas_vigencia_check check (vigencia_fim is null or vigencia_ini is null or vigencia_fim >= vigencia_ini);
  end if;
end $$;
update ofertas set status = case when ativo then 'ativa' else 'pausada' end where status = 'ativa' and not ativo;

-- ============ 2. itens (bundle) ============
create table if not exists oferta_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  oferta_id uuid not null references ofertas(id) on delete cascade,
  produto_id uuid not null references produtos(id) on delete restrict,
  quantidade numeric not null default 1 check (quantidade > 0),
  alocacao_pct numeric not null default 100 check (alocacao_pct >= 0 and alocacao_pct <= 100),
  unique (oferta_id, produto_id)
);
create index if not exists oferta_itens_oferta on oferta_itens (oferta_id);
insert into oferta_itens (workspace_id, oferta_id, produto_id, quantidade, alocacao_pct)
select o.workspace_id, o.id, o.produto_id, 1, 100 from ofertas o
 where o.produto_id is not null and not exists (select 1 from oferta_itens i where i.oferta_id = o.id);

-- ============ 3. versões ============
create table if not exists oferta_versoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  oferta_id uuid not null references ofertas(id) on delete cascade,
  versao int not null,
  nome text not null,
  preco numeric(12,2) not null,
  condicoes text,
  parcelas_max int,
  itens jsonb not null default '[]'::jsonb,
  criado_em timestamptz not null default now(),
  criado_por uuid default auth.uid(),
  unique (oferta_id, versao)
);
insert into oferta_versoes (workspace_id, oferta_id, versao, nome, preco, condicoes, parcelas_max, itens)
select o.workspace_id, o.id, o.versao, o.nome, o.preco, o.condicoes, o.parcelas_max,
       coalesce((select jsonb_agg(jsonb_build_object('produto_id', i.produto_id, 'quantidade', i.quantidade, 'alocacao_pct', i.alocacao_pct) order by i.produto_id) from oferta_itens i where i.oferta_id = o.id), '[]'::jsonb)
  from ofertas o where not exists (select 1 from oferta_versoes v where v.oferta_id = o.id);

create or replace function public.oferta_versoes_imutavel() returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' then raise exception 'Versão de oferta não pode ser alterada: salve a oferta para criar uma nova versão'; end if;
  return old;
end $$;
drop trigger if exists oferta_versoes_imutavel_t on oferta_versoes;
create trigger oferta_versoes_imutavel_t before update on oferta_versoes for each row execute function oferta_versoes_imutavel();

do $r$
declare t text;
begin
  foreach t in array array['oferta_itens', 'oferta_versoes'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_acesso', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format('drop policy if exists perm_ler on %I', t);
    execute format('create policy perm_ler on %I as restrictive for select using (perm(workspace_id, ''ler'', array[''mkt'',''adm'',''gro'',''vendas'',''cad'']))', t);
    execute format('drop policy if exists perm_inserir on %I', t);
    execute format('create policy perm_inserir on %I as restrictive for insert with check (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad'']))', t);
    execute format('drop policy if exists perm_alterar on %I', t);
    execute format('create policy perm_alterar on %I as restrictive for update using (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad''])) with check (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad'']))', t);
    execute format('drop policy if exists perm_excluir on %I', t);
    execute format('create policy perm_excluir on %I as restrictive for delete using (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad'']))', t);
  end loop;
end
$r$;

-- grava a oferta e os itens numa operação; cria versão nova quando nome, preço, condições, parcelamento ou itens mudam
create or replace function public.oferta_salvar(p_ws uuid, p_id uuid, p_dados jsonb, p_itens jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare o ofertas; novo uuid := p_id; soma numeric; ult oferta_versoes; itj jsonb; mudou boolean;
begin
  if not pertence_ao_workspace(p_ws) or not perm(p_ws, 'editar', array['mkt','gro','cad']) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if coalesce(trim(p_dados ->> 'nome'), '') = '' then raise exception 'Dê um nome à oferta'; end if;
  if coalesce((p_dados ->> 'preco')::numeric, -1) < 0 then raise exception 'Informe um preço válido'; end if;
  if jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then raise exception 'A oferta precisa de pelo menos um produto'; end if;
  if exists (select 1 from jsonb_array_elements(p_itens) e where not exists (select 1 from produtos pr where pr.id = (e ->> 'produto_id')::uuid and pr.workspace_id = p_ws)) then
    raise exception 'Produto da oferta não encontrado'; end if;
  if (select count(distinct e ->> 'produto_id') from jsonb_array_elements(p_itens) e) <> jsonb_array_length(p_itens) then raise exception 'O mesmo produto aparece duas vezes na oferta'; end if;
  select sum(coalesce((e ->> 'alocacao_pct')::numeric, 0)) into soma from jsonb_array_elements(p_itens) e;
  if jsonb_array_length(p_itens) = 1 then soma := 100; p_itens := jsonb_build_array((p_itens -> 0) || jsonb_build_object('alocacao_pct', 100)); end if;
  if abs(soma - 100) > 0.01 then raise exception 'Num pacote, a receita alocada aos produtos precisa somar 100%% (está em %)', round(soma, 2) || '%'; end if;
  if p_id is null then
    insert into ofertas (workspace_id, produto_id, nome, papel, preco, ativo, descricao, condicoes, parcelas_max, vigencia_ini, vigencia_fim, status, versao)
    values (p_ws, (p_itens -> 0 ->> 'produto_id')::uuid, trim(p_dados ->> 'nome'), coalesce(nullif(p_dados ->> 'papel', ''), 'principal'), (p_dados ->> 'preco')::numeric,
            coalesce(p_dados ->> 'status', 'ativa') = 'ativa', nullif(p_dados ->> 'descricao', ''), nullif(p_dados ->> 'condicoes', ''), nullif(p_dados ->> 'parcelas_max', '')::int,
            nullif(p_dados ->> 'vigencia_ini', '')::date, nullif(p_dados ->> 'vigencia_fim', '')::date, coalesce(nullif(p_dados ->> 'status', ''), 'ativa'), 1)
    returning id into novo;
  else
    select * into o from ofertas where id = p_id and workspace_id = p_ws for update;
    if not found then raise exception 'Oferta não encontrada'; end if;
    update ofertas set produto_id = (p_itens -> 0 ->> 'produto_id')::uuid, nome = trim(p_dados ->> 'nome'), papel = coalesce(nullif(p_dados ->> 'papel', ''), papel),
      preco = (p_dados ->> 'preco')::numeric, descricao = nullif(p_dados ->> 'descricao', ''), condicoes = nullif(p_dados ->> 'condicoes', ''),
      parcelas_max = nullif(p_dados ->> 'parcelas_max', '')::int, vigencia_ini = nullif(p_dados ->> 'vigencia_ini', '')::date, vigencia_fim = nullif(p_dados ->> 'vigencia_fim', '')::date,
      status = coalesce(nullif(p_dados ->> 'status', ''), status), ativo = coalesce(nullif(p_dados ->> 'status', ''), status) = 'ativa'
    where id = p_id;
    delete from oferta_itens where oferta_id = p_id;
  end if;
  insert into oferta_itens (workspace_id, oferta_id, produto_id, quantidade, alocacao_pct)
  select p_ws, novo, (e ->> 'produto_id')::uuid, coalesce(nullif(e ->> 'quantidade', '')::numeric, 1), coalesce(nullif(e ->> 'alocacao_pct', '')::numeric, 100)
    from jsonb_array_elements(p_itens) e;
  select * into o from ofertas where id = novo;
  select coalesce(jsonb_agg(jsonb_build_object('produto_id', i.produto_id, 'quantidade', i.quantidade, 'alocacao_pct', i.alocacao_pct) order by i.produto_id), '[]'::jsonb) into itj from oferta_itens i where i.oferta_id = novo;
  select * into ult from oferta_versoes where oferta_id = novo order by versao desc limit 1;
  mudou := ult.id is null or ult.nome <> o.nome or ult.preco <> o.preco or coalesce(ult.condicoes, '') <> coalesce(o.condicoes, '')
           or coalesce(ult.parcelas_max, 0) <> coalesce(o.parcelas_max, 0) or ult.itens <> itj;
  if mudou then
    update ofertas set versao = coalesce(ult.versao, 0) + 1 where id = novo;
    insert into oferta_versoes (workspace_id, oferta_id, versao, nome, preco, condicoes, parcelas_max, itens)
    values (p_ws, novo, coalesce(ult.versao, 0) + 1, o.nome, o.preco, o.condicoes, o.parcelas_max, itj);
  end if;
  return novo;
end $$;
revoke execute on function public.oferta_salvar(uuid, uuid, jsonb, jsonb) from public, anon;
grant execute on function public.oferta_salvar(uuid, uuid, jsonb, jsonb) to authenticated, service_role;

-- ============ 4. esteira da campanha ============
alter table campanha_ofertas add column if not exists oferta_versao int;
alter table campanha_ofertas add column if not exists pai_id uuid references campanha_ofertas(id) on delete set null;
alter table campanha_ofertas add column if not exists condicao text not null default 'sempre';
alter table campanha_ofertas add column if not exists etapa_exibicao text;
alter table campanha_ofertas add column if not exists elegibilidade text;
alter table campanha_ofertas add column if not exists gatilho text;
alter table campanha_ofertas add column if not exists taxa_exposicao numeric check (taxa_exposicao is null or (taxa_exposicao >= 0 and taxa_exposicao <= 1));
alter table campanha_ofertas add column if not exists taxa_aceite numeric check (taxa_aceite is null or (taxa_aceite >= 0 and taxa_aceite <= 1));
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'campanha_ofertas_condicao_check') then
    alter table campanha_ofertas add constraint campanha_ofertas_condicao_check check (condicao in ('sempre', 'aceitou', 'recusou'));
  end if;
end $$;
create index if not exists campanha_ofertas_pai on campanha_ofertas (pai_id);

create or replace function public.campanha_ofertas_valida() returns trigger language plpgsql set search_path = public as $$
declare p campanha_ofertas; cur uuid; n int := 0;
begin
  if new.papel = 'principal' then
    if new.pai_id is not null then raise exception 'A oferta principal não pode depender de outra oferta'; end if;
    new.condicao := 'sempre';
    if exists (select 1 from campanha_ofertas x where x.campanha_id = new.campanha_id and x.papel = 'principal' and x.id <> new.id) then
      raise exception 'Esta campanha já tem uma oferta principal. Troque o papel da atual antes.'; end if;
  end if;
  if new.pai_id is not null then
    if new.pai_id = new.id then raise exception 'Uma oferta não pode vir depois dela mesma'; end if;
    select * into p from campanha_ofertas where id = new.pai_id;
    if not found or p.campanha_id <> new.campanha_id then raise exception 'A etapa anterior precisa ser uma oferta desta campanha'; end if;
    cur := p.pai_id;
    while cur is not null loop
      if cur = new.id then raise exception 'Esse caminho cria um ciclo na esteira (uma oferta voltando para ela mesma)'; end if;
      n := n + 1; if n > 50 then raise exception 'Esteira longa demais ou com ciclo'; end if;
      select pai_id into cur from campanha_ofertas where id = cur;
    end loop;
  else
    if new.papel <> 'principal' and new.condicao <> 'sempre' then raise exception 'Escolha a etapa anterior para usar a condição aceitou ou recusou'; end if;
  end if;
  if new.papel = 'downsell' and (new.pai_id is null or new.condicao <> 'recusou') then
    raise exception 'Downsell aparece depois de uma recusa: escolha a oferta anterior e a condição "recusou"'; end if;
  if new.papel = 'order_bump' and new.pai_id is not null and p.papel <> 'principal' then
    raise exception 'Order bump fica no checkout da oferta principal'; end if;
  return new;
end $$;
drop trigger if exists campanha_ofertas_valida_t on campanha_ofertas;
create trigger campanha_ofertas_valida_t before insert or update on campanha_ofertas for each row execute function campanha_ofertas_valida();

-- ============ 5. resultado com o denominador certo ============
create or replace function public.campanha_ofertas_resultado(p_ws uuid, p_campanha uuid)
returns jsonb language plpgsql stable set search_path = public as $$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with recursive base as (
    select o.*, pr.nome as produto,
           coalesce(v.n, 0) + coalesce(c.n, 0) as vendas, coalesce(v.rec, 0) + coalesce(c.rec, 0) as receita
      from campanha_ofertas o left join produtos pr on pr.id = o.produto_id
      left join lateral (select count(*) n, sum(x.valor_bruto) rec from vendas x where x.workspace_id = p_ws and x.campanha_id = p_campanha and x.produto_id = o.produto_id and x.status = 'aprovada') v on true
      left join lateral (select count(distinct k.id) n, sum(ci.quantidade * ci.valor) rec from contratos k join contrato_itens ci on ci.contrato_id = k.id
          where k.workspace_id = p_ws and k.campanha_id = p_campanha and ci.produto_id = o.produto_id and k.status in ('ativo', 'encerrado')) c on true
     where o.workspace_id = p_ws and o.campanha_id = p_campanha),
  princ as (select coalesce(sum(vendas), 0) n from base where papel = 'principal'),
  -- quem recebeu cada oferta: sem etapa anterior = compradores da principal; com etapa anterior = compradores dela (aceitou/sempre) ou quem recusou
  arv as (
    select b.id, case when b.papel = 'principal' then null else (select n from princ) end::numeric as recebeu from base b where b.pai_id is null
    union all
    select b.id, (case b.condicao when 'recusou' then case when a.recebeu is null then null else greatest(a.recebeu - p.vendas, 0) end else p.vendas end)::numeric
      from base b join arv a on a.id = b.pai_id join base p on p.id = b.pai_id)
  select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'produto_id', b.produto_id, 'produto', b.produto, 'nome', b.nome, 'papel', b.papel, 'preco', b.preco,
      'oferta_id', b.oferta_id, 'oferta_versao', b.oferta_versao, 'pai_id', b.pai_id, 'condicao', b.condicao, 'etapa_exibicao', b.etapa_exibicao,
      'elegibilidade', b.elegibilidade, 'gatilho', b.gatilho, 'taxa_exposicao', b.taxa_exposicao, 'taxa_aceite', b.taxa_aceite, 'ordem', b.ordem,
      'vendas', b.vendas, 'receita', b.receita,
      'aceite', case when b.papel <> 'principal' and a.recebeu > 0 then round(b.vendas * 100.0 / a.recebeu, 1) end, 'base_aceite', a.recebeu)
      order by b.ordem, b.criado_em), '[]'::jsonb) into r
  from base b left join arv a on a.id = b.id;
  return r;
end $$;

-- ============ 6. campanha híbrida e execução por canal ============
alter table campanhas add column if not exists tipo_midia text not null default 'hibrida';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'campanhas_tipo_midia_check') then
    alter table campanhas add constraint campanhas_tipo_midia_check check (tipo_midia in ('hibrida', 'paga', 'organica'));
  end if;
end $$;
alter table canais add column if not exists tipo text;
update canais set tipo = case when codigo like '%\_ads' or coalesce(utm_medium, '') in ('cpc', 'paid', 'ppc', 'cpm', 'paid_social') then 'pago' else 'organico' end where tipo is null;
alter table canais alter column tipo set default 'organico';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'canais_tipo_check') then
    alter table canais add constraint canais_tipo_check check (tipo in ('pago', 'organico'));
  end if;
end $$;
alter table campanha_canais add column if not exists tipo text;
alter table campanha_canais add column if not exists funil_id uuid references funis(id) on delete set null;
alter table campanha_canais add column if not exists custo_producao numeric(12,2) check (custo_producao is null or custo_producao >= 0);
alter table campanha_canais add column if not exists observacoes text;
update campanha_canais cc set tipo = coalesce((select k.tipo from canais k where k.workspace_id = cc.workspace_id and k.codigo = cc.canal), case when cc.canal like '%\_ads' then 'pago' else 'organico' end) where cc.tipo is null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'campanha_canais_tipo_check') then
    alter table campanha_canais add constraint campanha_canais_tipo_check check (tipo is null or tipo in ('pago', 'organico'));
  end if;
end $$;

create table if not exists campanha_estrategias (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  principal boolean not null default false,
  criado_em timestamptz not null default now(),
  unique (campanha_id, funil_id)
);
insert into campanha_estrategias (workspace_id, campanha_id, funil_id, principal)
select c.workspace_id, c.id, c.funil_id, true from campanhas c where c.funil_id is not null
on conflict (campanha_id, funil_id) do nothing;
alter table campanha_estrategias enable row level security;
drop policy if exists campanha_estrategias_acesso on campanha_estrategias;
create policy campanha_estrategias_acesso on campanha_estrategias for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on campanha_estrategias;
create policy perm_ler on campanha_estrategias as restrictive for select using (perm(workspace_id, 'ler', array['mkt','adm','gro','vendas']));
drop policy if exists perm_escrever on campanha_estrategias;
create policy perm_escrever on campanha_estrategias as restrictive for all using (perm(workspace_id, 'editar', array['mkt','gro'])) with check (perm(workspace_id, 'editar', array['mkt','gro']));
-- a estratégia principal da campanha continua em campanhas.funil_id: ao trocar, a lista N:N acompanha
create or replace function public.campanha_estrategia_principal_t() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.funil_id is not null and (tg_op = 'INSERT' or new.funil_id is distinct from old.funil_id) then
    update campanha_estrategias set principal = false where campanha_id = new.id and funil_id <> new.funil_id;
    insert into campanha_estrategias (workspace_id, campanha_id, funil_id, principal) values (new.workspace_id, new.id, new.funil_id, true)
    on conflict (campanha_id, funil_id) do update set principal = true;
  end if;
  return null;
end $$;
drop trigger if exists campanha_estrategia_principal on campanhas;
create trigger campanha_estrategia_principal after insert or update of funil_id on campanhas for each row execute function campanha_estrategia_principal_t();

-- ============ 7. North Star ============
alter table growth_metricas add column if not exists nsm_evento text;
alter table growth_metricas add column if not exists nsm_populacao text;
alter table growth_metricas add column if not exists nsm_frequencia text;
alter table growth_metricas add column if not exists nsm_fonte text;
alter table growth_metricas add column if not exists produto_id uuid references produtos(id) on delete set null;

-- ============ auditoria ============
do $$
declare t text;
begin
  if to_regprocedure('public.auditar()') is not null then
    foreach t in array array['ofertas', 'oferta_itens', 'campanha_ofertas', 'campanha_canais', 'campanha_estrategias'] loop
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end loop;
  end if;
end $$;
