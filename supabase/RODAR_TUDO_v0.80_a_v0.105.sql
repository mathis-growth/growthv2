-- Growths — TODAS as migrações pendentes (v0.80 a v0.105) num arquivo só.
-- Como usar: Supabase → SQL Editor → New query → cole este arquivo inteiro → Run.
-- Roda tudo numa transação: se der erro em qualquer ponto, nada é gravado (é só me mandar a mensagem).
-- Pode rodar de novo sem problema (todas são idempotentes).

begin;

-- ================================================================
-- >>> 20261008230000_seguranca_fase1.sql
-- ================================================================
-- v0.80 — Segurança, fase 1 (auditoria de 08/10/2026)
-- 1. Nenhuma função executável por quem não está logado (anon), exceto a pesquisa pública.
-- 2. Funções criadas daqui em diante nascem fechadas para anon/public.
-- 3. sincroniza_acesso exige login + administrador (antes, sem login a checagem não rodava).
-- 4. _provisionar_prolabore, equipe_avisa, projeto_do_produto e provisionar_workspace deixam de ser
--    chamáveis direto (continuam funcionando dentro das outras funções e gatilhos).
-- 5. As 32 operações de escrita passam a exigir nível "editar" no módulo certo (antes bastava ser membro).
-- 6. Trava no banco: não se paga conta a pagar cujo valor ainda é estimativa (era a migração 20261006500100).
-- Idempotente: pode rodar de novo sem efeito colateral.

-- ---------- 1 e 2: EXECUTE ----------
do $$
declare r record; a boolean; s boolean;
begin
  for r in select p.oid, p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f' loop
    a := has_function_privilege('authenticated', r.oid, 'execute');
    s := has_function_privilege('service_role', r.oid, 'execute');
    execute format('revoke execute on function %s from public, anon', r.sig);
    if a then execute format('grant execute on function %s to authenticated', r.sig); end if;
    if s then execute format('grant execute on function %s to service_role', r.sig); end if;
  end loop;
end $$;

grant execute on function public.pesquisa_publica(text) to anon;
grant execute on function public.pesquisa_responder(text, jsonb, text) to anon;

alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon;
alter default privileges for role postgres in schema public revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from anon;

-- ---------- 4: internas fora do alcance direto ----------
revoke execute on function public._provisionar_prolabore(uuid) from authenticated;
revoke execute on function public.equipe_avisa(uuid, uuid, uuid, text, text) from authenticated;
revoke execute on function public.projeto_do_produto(uuid, uuid, uuid, uuid, uuid, date) from authenticated;
revoke execute on function public.provisionar_workspace(text) from authenticated;
-- Workspace novo só pela equipe interna: criar_workspace_cliente / criar_workspace_starter.

-- ---------- 3: sincroniza_acesso ----------
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.sincroniza_acesso(uuid)'::regprocedure);
  n := replace(d, 'if auth.uid() is not null and not eh_admin(e.workspace_id) then',
    'if not (session_user in (''postgres'', ''supabase_admin'') or coalesce(auth.role(), '''') = ''service_role'' or (auth.uid() is not null and eh_admin(e.workspace_id))) then');
  if n = d and position('session_user in' in d) = 0 then
    raise exception 'sincroniza_acesso: trecho esperado não encontrado — revisar antes de aplicar';
  end if;
  execute n;
end $$;

-- ---------- 5: permissão por módulo ----------
create or replace function public.pode_editar(ws uuid, mods text[])
returns boolean language sql stable security definer set search_path = public as $$
  select session_user in ('postgres', 'supabase_admin')
      or coalesce(auth.role(), '') = 'service_role'
      or (pertence_ao_workspace(ws) and perm(ws, 'editar', mods));
$$;
revoke execute on function public.pode_editar(uuid, text[]) from public, anon;
grant execute on function public.pode_editar(uuid, text[]) to authenticated, service_role;
comment on function public.pode_editar(uuid, text[]) is 'v0.80: membro com nível editar em algum dos módulos (ou sessão de serviço). Substitui pode_operar nas RPCs de escrita.';

do $$
declare
  m record; d text; n text; k int;
  mapa constant jsonb := jsonb_build_object(
    'entrar_na_lista', '{mkt,vendas}', 'sair_da_lista', '{mkt,vendas}',
    'processar_venda', '{vendas,fin}', 'registrar_estorno', '{vendas,fin}',
    'registrar_recebimento', '{fin}', 'registrar_recebimento_parcial', '{fin}', 'registrar_recebimentos_ate', '{fin}', 'desfazer_recebimento', '{fin}',
    'registrar_pagamento', '{fin}', 'registrar_pagamento_parcial', '{fin}', 'desfazer_pagamento', '{fin}',
    'cancelar_conta_pagar', '{fin}', 'reativar_conta_pagar', '{fin}', 'confirmar_valor_conta_pagar', '{fin}',
    'provisionar_contas_pagar', '{fin}', 'provisionar_recorrencias', '{fin}',
    'registrar_lancamento_manual', '{fin}', 'estornar_lancamento', '{fin}',
    'ativar_contrato', '{vendas,fin}', 'cancelar_contrato', '{vendas,fin}', 'reabrir_contrato', '{vendas,fin}',
    'cancelar_parcela_contrato', '{vendas,fin}', 'reativar_parcela_contrato', '{vendas,fin}', 'dar_desconto_parcela', '{vendas,fin}',
    'cadastrar_cliente_historico', '{vendas,revops}',
    'registrar_presenca_video', '{mkt}', 'conteudo_importar_ideias', '{mkt}',
    'projetos_das_campanhas', '{prj,mkt}', 'modelo_padrao_campanha', '{prj,mkt}', 'aplica_modelo_projeto', '{prj}',
    'pesquisa_gerar_envios', '{gro,mkt}', 'pesquisa_enviar_para', '{gro,mkt}');
begin
  for m in select p.oid, p.proname from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and p.proname in (select jsonb_object_keys(mapa)) loop
    d := pg_get_functiondef(m.oid);
    if position('pode_editar(' in d) > 0 then continue; end if;  -- já convertida
    k := (select count(*) from regexp_matches(d, 'pode_operar\(', 'g'));
    if k <> 1 then raise exception '%: esperava 1 chamada de pode_operar, achou %', m.proname, k; end if;
    n := regexp_replace(d, 'pode_operar\(([a-z_.]+)\)', 'pode_editar(\1, ''' || (mapa ->> m.proname) || '''::text[])');
    n := replace(n, 'Sem permissão neste workspace', 'Sem permissão para esta operação neste módulo');
    execute n;
  end loop;
  if (select count(*) from pg_proc p join pg_namespace s on s.oid = p.pronamespace
      where s.nspname = 'public' and p.prokind = 'f' and p.proname <> 'pode_operar' and pg_get_functiondef(p.oid) ~ 'pode_operar\(') > 0 then
    raise exception 'Ainda há funções usando pode_operar — revisar';
  end if;
end $$;

-- ---------- 6: não pagar estimativa ----------
create or replace function public.contas_pagar_bloqueia_estimativa() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.status = 'pago' and old.status is distinct from 'pago' and coalesce(old.estimativa, false) then
    raise exception 'O valor desta conta ainda é uma estimativa. Confirme o valor real antes de pagar.';
  end if;
  return new;
end $$;
revoke execute on function public.contas_pagar_bloqueia_estimativa() from public, anon;
drop trigger if exists contas_pagar_estimativa_t on public.contas_pagar;
create trigger contas_pagar_estimativa_t before update on public.contas_pagar
  for each row execute function public.contas_pagar_bloqueia_estimativa();


-- ================================================================
-- >>> 20261010200000_blocos_e_simulador.sql
-- ================================================================
-- v0.81 — Blocos de estratégia e Simulador de lucro
-- 1. Blocos: a estratégia passa a ser montada com blocos prontos (Conteúdo, Tráfego, Grupo, Aula, Checkout...).
--    Cada bloco agrupa etapas-métrica; uma delas é a principal (passa para o próximo bloco), as outras são de diagnóstico.
-- 2. Simulador de lucro (Growth): cenários salvos em JSON + fotos (snapshots) com a versão da fórmula.
-- Idempotente. Depende da 20261008220000_estrategias_jornada.sql. Rode também a 20261008230000_seguranca_fase1.sql se ainda não rodou.

-- ---------- 1. Blocos ----------
create table if not exists estrategia_blocos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  ordem int not null default 10,
  fase text not null default 'aquisicao' check (fase in ('aquisicao', 'aquecimento', 'conversao', 'retencao')),
  tipo text not null,
  nome text not null,
  origem_ref uuid,
  criado_em timestamptz not null default now()
);
create index if not exists estrategia_blocos_funil on estrategia_blocos (funil_id);

create table if not exists campanha_blocos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  bloco_origem_id uuid,
  ordem int not null default 10,
  fase text not null default 'aquisicao' check (fase in ('aquisicao', 'aquecimento', 'conversao', 'retencao')),
  tipo text not null,
  nome text not null,
  origem_ref uuid,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create index if not exists campanha_blocos_campanha on campanha_blocos (campanha_id);

alter table estrategia_etapas add column if not exists bloco_id uuid references estrategia_blocos(id) on delete cascade;
alter table estrategia_etapas add column if not exists papel text;
alter table estrategia_etapas add column if not exists fonte text;
alter table campanha_etapas add column if not exists bloco_id uuid references campanha_blocos(id) on delete cascade;
alter table campanha_etapas add column if not exists papel text;
alter table campanha_etapas add column if not exists fonte text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'estrategia_etapas_papel_chk') then
    alter table estrategia_etapas add constraint estrategia_etapas_papel_chk check (papel is null or papel in ('principal', 'diagnostico'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'campanha_etapas_papel_chk') then
    alter table campanha_etapas add constraint campanha_etapas_papel_chk check (papel is null or papel in ('principal', 'diagnostico'));
  end if;
end $$;
create index if not exists estrategia_etapas_bloco on estrategia_etapas (bloco_id);
create index if not exists campanha_etapas_bloco on campanha_etapas (bloco_id);

-- bloco e etapa do mesmo workspace e da mesma estratégia/campanha
create or replace function bloco_etapa_valida() returns trigger language plpgsql set search_path = public as $$
begin
  if new.bloco_id is null then return new; end if;
  if tg_table_name = 'estrategia_etapas' then
    if not exists (select 1 from estrategia_blocos b where b.id = new.bloco_id and b.funil_id = new.funil_id and b.workspace_id = new.workspace_id) then
      raise exception 'O bloco não pertence a esta estratégia.';
    end if;
  else
    if not exists (select 1 from campanha_blocos b where b.id = new.bloco_id and b.campanha_id = new.campanha_id and b.workspace_id = new.workspace_id) then
      raise exception 'O bloco não pertence a esta campanha.';
    end if;
  end if;
  return new;
end $$;
revoke execute on function bloco_etapa_valida() from public, anon;
drop trigger if exists estrategia_etapas_bloco_t on estrategia_etapas;
create trigger estrategia_etapas_bloco_t before insert or update of bloco_id on estrategia_etapas for each row execute function bloco_etapa_valida();
drop trigger if exists campanha_etapas_bloco_t on campanha_etapas;
create trigger campanha_etapas_bloco_t before insert or update of bloco_id on campanha_etapas for each row execute function bloco_etapa_valida();

-- RLS: mesmo padrão de estrategia_etapas/campanha_etapas (v0.77): ler mkt/vendas/gro/adm, editar mkt/gro
alter table estrategia_blocos enable row level security;
alter table campanha_blocos enable row level security;
do $$ declare t text; begin
  foreach t in array array['estrategia_blocos', 'campanha_blocos'] loop
    execute format('drop policy if exists %1$s_acesso on %1$s', t);
    execute format('drop policy if exists perm_ler on %1$s', t);
    execute format('drop policy if exists perm_inserir on %1$s', t);
    execute format('drop policy if exists perm_alterar on %1$s', t);
    execute format('drop policy if exists perm_excluir on %1$s', t);
    execute format('create policy %1$s_acesso on %1$s for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t);
    execute format('create policy perm_ler on %1$s as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''mkt'',''vendas'',''gro'',''adm'']))', t);
    execute format('create policy perm_inserir on %1$s as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''mkt'',''gro'']))', t);
    execute format('create policy perm_alterar on %1$s as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''mkt'',''gro'']))', t);
    execute format('create policy perm_excluir on %1$s as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''mkt'',''gro'']))', t);
  end loop;
end $$;

-- aplicar a estratégia na campanha agora copia os blocos e liga cada etapa ao bloco copiado
create or replace function campanha_aplicar_estrategia(p_campanha uuid, p_funil uuid, p_substituir boolean default false) returns int
language plpgsql set search_path = public as $$
declare v_ws uuid; v_n int; b record; v_novo uuid;
begin
  select workspace_id into v_ws from campanhas where id = p_campanha;
  if v_ws is null then raise exception 'Campanha não encontrada.'; end if;
  if not exists (select 1 from funis where id = p_funil and workspace_id = v_ws) then raise exception 'Estratégia não encontrada.'; end if;
  update campanhas set funil_id = p_funil where id = p_campanha;
  if p_substituir then
    delete from campanha_etapas where campanha_id = p_campanha;
    delete from campanha_blocos where campanha_id = p_campanha;
  end if;
  -- blocos que ainda não estão na campanha
  for b in select * from estrategia_blocos where funil_id = p_funil order by ordem loop
    -- só copia o bloco se ele ainda não está na campanha e se pelo menos uma etapa dele vai entrar (chave nova)
    if not exists (select 1 from campanha_blocos where campanha_id = p_campanha and bloco_origem_id = b.id)
       and exists (select 1 from estrategia_etapas e where e.bloco_id = b.id
                   and not exists (select 1 from campanha_etapas x where x.campanha_id = p_campanha and x.chave = e.chave)) then
      insert into campanha_blocos (workspace_id, campanha_id, bloco_origem_id, ordem, fase, tipo, nome, origem_ref)
      values (v_ws, p_campanha, b.id, b.ordem, b.fase, b.tipo, b.nome, b.origem_ref);
    end if;
  end loop;
  insert into campanha_etapas (workspace_id, campanha_id, ordem, fase, chave, nome, unidade, origem, metrica, origem_ref, conta_como, taxa_esperada, bloco_id, papel, fonte)
  select v_ws, p_campanha, e.ordem, e.fase, e.chave, e.nome, e.unidade, e.origem, e.metrica, e.origem_ref, e.conta_como, e.taxa_esperada,
         (select cb.id from campanha_blocos cb where cb.campanha_id = p_campanha and cb.bloco_origem_id = e.bloco_id limit 1), e.papel, e.fonte
  from estrategia_etapas e where e.funil_id = p_funil
  on conflict (campanha_id, chave) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke execute on function campanha_aplicar_estrategia(uuid, uuid, boolean) from public, anon;
grant execute on function campanha_aplicar_estrategia(uuid, uuid, boolean) to authenticated;

-- o funil da campanha devolve também bloco, papel e fonte (para agrupar e calcular pela principal)
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.campanha_funil_etapas(uuid,date,date)'::regprocedure);
  if position('''bloco_id''' in d) > 0 then return; end if;
  n := replace(d, '''valor'', coalesce(v, 0), ''tem'', v is not null)', '''valor'', coalesce(v, 0), ''tem'', v is not null, ''bloco_id'', e.bloco_id, ''papel'', e.papel, ''fonte'', e.fonte)');
  if n = d then raise exception 'campanha_funil_etapas: trecho esperado não encontrado — revisar'; end if;
  execute n;
end $$;
revoke execute on function campanha_funil_etapas(uuid, date, date) from public, anon;
grant execute on function campanha_funil_etapas(uuid, date, date) to authenticated;

-- ---------- 2. Simulador de lucro ----------
create table if not exists simulador_cenarios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  dados jsonb not null default '{}'::jsonb check (jsonb_typeof(dados) = 'object'),
  versao_formula text not null default 'gps-1.0',
  status text not null default 'rascunho' check (status in ('rascunho', 'ativo', 'arquivado')),
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists simulador_cenarios_ws on simulador_cenarios (workspace_id);

create table if not exists simulador_snapshots (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  cenario_id uuid not null references simulador_cenarios(id) on delete cascade,
  nome text not null,
  versao_formula text not null,
  premissas jsonb not null check (jsonb_typeof(premissas) = 'object'),
  metricas jsonb not null check (jsonb_typeof(metricas) = 'object'),
  calculado_em timestamptz not null default now(),
  criado_por uuid default auth.uid()
);
create index if not exists simulador_snapshots_cenario on simulador_snapshots (cenario_id);

create or replace function simulador_mesmo_ws() returns trigger language plpgsql set search_path = public as $$
begin
  if not exists (select 1 from simulador_cenarios c where c.id = new.cenario_id and c.workspace_id = new.workspace_id) then
    raise exception 'Cenário de outro workspace.';
  end if;
  return new;
end $$;
revoke execute on function simulador_mesmo_ws() from public, anon;
drop trigger if exists simulador_snapshots_ws on simulador_snapshots;
create trigger simulador_snapshots_ws before insert or update on simulador_snapshots for each row execute function simulador_mesmo_ws();

alter table simulador_cenarios enable row level security;
alter table simulador_snapshots enable row level security;
do $$ declare t text; begin
  foreach t in array array['simulador_cenarios', 'simulador_snapshots'] loop
    execute format('drop policy if exists %1$s_acesso on %1$s', t);
    execute format('drop policy if exists perm_ler on %1$s', t);
    execute format('drop policy if exists perm_inserir on %1$s', t);
    execute format('drop policy if exists perm_alterar on %1$s', t);
    execute format('drop policy if exists perm_excluir on %1$s', t);
    execute format('create policy %1$s_acesso on %1$s for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t);
    execute format('create policy perm_ler on %1$s as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''gro'',''fin'',''adm'']))', t);
    execute format('create policy perm_inserir on %1$s as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''gro'']))', t);
    execute format('create policy perm_alterar on %1$s as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''gro'']))', t);
    execute format('create policy perm_excluir on %1$s as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''gro'']))', t);
  end loop;
end $$;
-- snapshot é foto: não se altera depois de gravado
revoke update on simulador_snapshots from authenticated;


-- ================================================================
-- >>> 20261010220000_desfazer_parcial_junta_saldo.sql
-- ================================================================
-- v0.83 — Desfazer o pagamento de uma baixa parcial junta a parte desfeita com o saldo que ainda não foi pago.
-- Antes: pagar 700 de 10.000 dividia em "700 pago" + "9.300 (saldo)". Desfazer o pagamento deixava duas contas em aberto (700 + 9.300).
-- Agora: se o saldo ainda está em aberto, as duas partes são canceladas (com estorno) e nasce uma conta única de 10.000,
--        com a mesma competência, vencimento, fornecedor, conta contábil e centro de custo. O histórico contábil fica.
-- Se o saldo já foi pago (total ou parcialmente), nada é juntado: a parte desfeita volta para "a pagar" sozinha, como antes.
-- Os estornos dos cancelamentos usam a data da competência de cada parte, para a despesa do mês não mudar.
-- Rode DEPOIS de 20261008230000_seguranca_fase1.sql (usa pode_editar). Idempotente.

-- 1. ligação explícita entre a conta paga em parte e o saldo que ela gerou
alter table contas_pagar add column if not exists saldo_de uuid references contas_pagar(id);
create index if not exists contas_pagar_saldo_de on contas_pagar (saldo_de);

-- contas antigas: o saldo nasceu na mesma transação do lançamento "Divisão por pagamento parcial" da conta original
update contas_pagar s set saldo_de = o.id
from contas_pagar o
join lancamentos l on l.origem_id = o.id and l.origem_tipo = 'cancelamento_pagar' and l.descricao like 'Divisão por pagamento parcial:%'
where s.saldo_de is null and s.workspace_id = o.workspace_id and s.id <> o.id
  and s.descricao = o.descricao || ' (saldo)'
  and s.fornecedor_id is not distinct from o.fornecedor_id and s.competencia = o.competencia
  and s.criado_em = l.criado_em;

-- 2. a baixa parcial passa a gravar a ligação
create or replace function public.registrar_pagamento_parcial(p_conta uuid, p_valor numeric, p_data date default null, p_conta_bancaria uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cp contas_pagar; l0 uuid; l1 uuid; l0_data date; resto numeric; ratio numeric; novo uuid;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar não encontrada'; end if;
  if not pode_editar(cp.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cp.status <> 'previsto' then raise exception 'Conta a pagar já está %', cp.status; end if;
  if cp.estimativa then raise exception 'Confirme o valor real antes de pagar'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor pago'; end if;
  if p_valor >= cp.valor then return registrar_pagamento(p_conta, p_data, p_conta_bancaria); end if;
  resto := round(cp.valor - p_valor, 2);
  ratio := resto / cp.valor;
  select id, data_fato into l0, l0_data from lancamentos where origem_tipo = 'conta_pagar' and origem_id = cp.id order by criado_em desc limit 1;
  if l0 is null then raise exception 'Conta sem lançamento contábil para dividir'; end if;
  -- tira do lançamento original a parte que continua em aberto (estorno parcial, mesma data)
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cp.workspace_id, l0_data, 'Divisão por pagamento parcial: ' || cp.descricao, 'cancelamento_pagar', cp.id, l0) returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, v
  from (select p.*, round(sum(p.valor) over (partition by p.tipo order by p.id) * ratio, 2) - coalesce(round(sum(p.valor) over (partition by p.tipo order by p.id rows between unbounded preceding and 1 preceding) * ratio, 2), 0) as v
        from partidas p where p.lancamento_id = l0) x where v > 0;
  -- a parte que sobra vira uma conta nova, ligada à original (saldo_de), já com a despesa lançada pelo gatilho
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id, campanha_canal_id, rateio_regra_id, forma_pagamento_id, estimativa, provisionada, saldo_de)
  values (cp.workspace_id, cp.fornecedor_id, cp.descricao || ' (saldo)', resto, cp.competencia, cp.vencimento, cp.conta_despesa_id, cp.centro_custo_id, cp.campanha_id, cp.campanha_canal_id, cp.rateio_regra_id, cp.forma_pagamento_id, false, false, cp.id)
  returning id into novo;
  update contas_pagar set valor = p_valor where id = cp.id;
  return registrar_pagamento(cp.id, p_data, p_conta_bancaria);
end $$;

-- 3. desfazer pagamento: estorna o pagamento e, se for uma baixa parcial com saldo em aberto, junta as duas partes
create or replace function public.desfazer_pagamento(p_conta uuid, p_data date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cp contas_pagar; s contas_pagar; l0 uuid; l1 uuid; m movimentacoes_bancarias; d date; novo uuid; dc date; ds date;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar não encontrada'; end if;
  if not pode_editar(cp.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cp.status <> 'pago' then raise exception 'Só dá para desfazer pagamento de conta paga (esta está %)', cp.status; end if;
  select l.id into l0 from lancamentos l
   where l.origem_tipo = 'pagamento' and l.origem_id = cp.id
     and not exists (select 1 from lancamentos e where e.estorno_de = l.id)
   order by l.criado_em desc limit 1;
  if l0 is null then raise exception 'Pagamento sem lançamento contábil para desfazer'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cp.workspace_id, d, 'Pagamento desfeito: ' || cp.descricao, 'cancelamento_pagar', cp.id, l0)
  returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = l0;
  select * into m from movimentacoes_bancarias where lancamento_id = l0 limit 1;
  if found then
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    values (m.workspace_id, m.conta_bancaria_id, d, 'entrada', m.valor, 'Pagamento desfeito: ' || cp.descricao, 'pagamento', cp.id, l1);
  end if;
  update contas_pagar set status = 'previsto', data_pagamento = null, conta_bancaria_id = null where id = cp.id;

  -- baixa parcial: o saldo que ela gerou ainda está em aberto? junta tudo numa conta só
  select * into s from contas_pagar
   where saldo_de = cp.id and status = 'previsto' and substituida_por is null and workspace_id = cp.workspace_id
   order by criado_em desc limit 1 for update;
  if found then
    select data_fato into dc from lancamentos where origem_tipo = 'conta_pagar' and origem_id = cp.id order by criado_em limit 1;
    select data_fato into ds from lancamentos where origem_tipo = 'conta_pagar' and origem_id = s.id order by criado_em limit 1;
    perform cancelar_conta_pagar(cp.id, coalesce(dc, cp.competencia));
    perform cancelar_conta_pagar(s.id, coalesce(ds, s.competencia));
    insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id, campanha_canal_id,
                              rateio_regra_id, forma_pagamento_id, estimativa, provisionada, recorrencia_id, saldo_de)
    values (cp.workspace_id, cp.fornecedor_id, cp.descricao, round(cp.valor + s.valor, 2), cp.competencia, cp.vencimento, cp.conta_despesa_id, cp.centro_custo_id, cp.campanha_id, cp.campanha_canal_id,
            cp.rateio_regra_id, cp.forma_pagamento_id, false, false, cp.recorrencia_id, cp.saldo_de)
    returning id into novo;
    update contas_pagar set substituida_por = novo where id in (cp.id, s.id);
  end if;
  return l1;
end $$;

revoke execute on function public.registrar_pagamento_parcial(uuid, numeric, date, uuid) from public, anon;
revoke execute on function public.desfazer_pagamento(uuid, date) from public, anon;
grant execute on function public.registrar_pagamento_parcial(uuid, numeric, date, uuid) to authenticated, service_role;
grant execute on function public.desfazer_pagamento(uuid, date) to authenticated, service_role;


-- ================================================================
-- >>> 20261010230000_pacotes_acesso.sql
-- ================================================================
-- v0.85 — Pacotes de acesso por cliente (ex.: Disparo, Consultoria, Mentoria).
-- A equipe interna (Mathisa) monta pacotes com as telas liberadas e escolhe um pacote para cada cliente (workspace),
-- podendo ligar ou desligar telas só para aquele cliente. As funções e permissões de cada pessoa continuam valendo por cima:
-- o pacote define o que o cliente contratou; a função define o que cada pessoa do cliente pode fazer.
-- No banco: um módulo sem nenhuma tela liberada fica "nenhum" para todos do cliente (inclusive administradores), pela nivel_modulo.
-- Configurações e Cadastros nunca são bloqueados no banco (são usados por todos os módulos); as telas deles são escondidas só na tela.
-- Equipe e acessos e Funções e permissões ficam sempre liberadas para o administrador do cliente.
-- Cliente sem pacote e sem ajustes = sem restrição (como hoje). Rode depois de 20261008230000_seguranca_fase1.sql. Idempotente.

-- catálogo das telas (o mesmo do menu do sistema)
create table if not exists acesso_telas (
  tela text primary key,
  modulo text not null,
  nome text not null,
  grupo text,
  ordem int not null default 0
);
insert into acesso_telas (tela, modulo, nome, grupo, ordem) values
('adm-painel', 'adm', 'Dashboard', 'Administrativo', 1),
('adm-dash', 'adm', 'Dashboard Growth', 'Administrativo', 2),
('ia-perguntar', 'adm', 'Pergunte aos dados', 'Administrativo', 3),
('adm-plano', 'adm', 'Planejamento da empresa', 'Administrativo', 4),
('adm-empresa', 'adm', 'Cadastro da empresa', 'Administrativo', 5),
('mkt-dash', 'mkt', 'Dashboard', 'Marketing', 6),
('mkt-midia', 'mkt', 'Dashboard de mídia', 'Marketing', 7),
('mkt-camp', 'mkt', 'Campanhas e planejamento', 'Marketing', 8),
('mkt-trafego', 'mkt', 'Mídia paga', 'Marketing', 9),
('mkt-video', 'mkt', 'Vídeos e webinários', 'Marketing', 10),
('mkt-cont', 'mkt', 'Planejamento de conteúdo', 'Marketing', 11),
('crm-dash', 'vendas', 'Dashboard', 'Vendas', 12),
('crm-leads', 'vendas', 'Funil comercial', 'Vendas', 13),
('crm-oport', 'vendas', 'Oportunidades', 'Vendas', 14),
('crm-vendas', 'vendas', 'Vendas', 'Vendas', 15),
('crm-contratos', 'vendas', 'Contratos', 'Vendas', 16),
('mkt-origem', 'vendas', 'Leads por origem', 'Vendas', 17),
('ho-dash', 'revops', 'Dashboard', 'RevOps', 18),
('ho-ascensao', 'revops', 'Ascensão da escada', 'RevOps', 19),
('ho-cohort', 'revops', 'Cohorts', 'RevOps', 20),
('crm-alunos', 'revops', 'Alunos', 'RevOps', 21),
('fin-dash', 'fin', 'Dashboard', 'Financeiro', 22),
('fin-receber', 'fin', 'Contas a receber', 'Financeiro', 23),
('fin-pagar', 'fin', 'Contas a pagar', 'Financeiro', 24),
('fin-lanc', 'fin', 'Lançamentos contábeis', 'Financeiro', 25),
('prj-lista', 'prj', 'Projetos', 'Projetos', 26),
('prj-minhas', 'prj', 'Minhas atividades', 'Projetos', 27),
('prj-modelos', 'prj', 'Modelos de projeto', 'Projetos', 28),
('prj-avisos', 'prj', 'Avisos', 'Projetos', 29),
('gro-diag', 'gro', 'Diagnóstico Growth', 'Growth', 30),
('gro-modelo', 'gro', 'Growth Loops', 'Growth', 31),
('gro-lucro', 'gro', 'Unit Economics', 'Growth', 32),
('gro-analise', 'gro', 'Análise de funil', 'Growth', 33),
('gro-pesq', 'gro', 'Pesquisas', 'Growth', 34),
('gro-ciclo', 'gro', 'Ciclo de Growth (Kanban)', 'Growth', 35),
('cfg-importar', 'cfg', 'Importar e validar dados', 'Configurações / Dados e integrações', 36),
('cfg-integracoes', 'cfg', 'Integrações', 'Configurações / Dados e integrações', 37),
('cfg-uso', 'cfg', 'Uso da plataforma', 'Configurações / Dados e integrações', 38),
('cad-equipe', 'cad', 'Equipe e acessos', 'Configurações / Pessoas e acessos', 39),
('cad-funcoes', 'cad', 'Funções e permissões', 'Configurações / Pessoas e acessos', 40),
('cad-clientes', 'cad', 'Clientes', 'Configurações / Comercial e produtos', 41),
('cad-produtos', 'cad', 'Produtos', 'Configurações / Comercial e produtos', 42),
('cad-plataformas', 'cad', 'Plataformas', 'Configurações / Comercial e produtos', 43),
('cad-canais', 'cad', 'Canais', 'Configurações / Comercial e produtos', 44),
('cad-funis', 'cad', 'Estratégias e funis', 'Configurações / Comercial e produtos', 45),
('cad-motivos', 'cad', 'Motivos de ganho e perda', 'Configurações / Comercial e produtos', 46),
('cad-planocontas', 'cad', 'Plano de contas', 'Configurações / Financeiro e contabilidade', 47),
('cad-regras', 'cad', 'Regras contábeis', 'Configurações / Financeiro e contabilidade', 48),
('cad-impostos', 'cad', 'Impostos', 'Configurações / Financeiro e contabilidade', 49),
('cad-bancos', 'cad', 'Contas bancárias', 'Configurações / Financeiro e contabilidade', 50),
('cad-formaspag', 'cad', 'Formas de pagamento', 'Configurações / Financeiro e contabilidade', 51),
('cad-fornecedores', 'cad', 'Fornecedores', 'Configurações / Financeiro e contabilidade', 52),
('cad-centros', 'cad', 'Centros de custo', 'Configurações / Financeiro e contabilidade', 53),
('cad-rateio', 'cad', 'Rateio de custos', 'Configurações / Financeiro e contabilidade', 54),
('st-dash', 'adm', 'Dashboard', 'Growth Starter', 55),
('st-relatorios', 'adm', 'Relatórios', 'Growth Starter', 56)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo, ordem = excluded.ordem;

create table if not exists pacotes_acesso (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  descricao text,
  telas text[] not null default '{}',
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

alter table workspaces add column if not exists pacote_id uuid references pacotes_acesso(id) on delete set null;
alter table workspaces add column if not exists acesso_liga text[] not null default '{}';
alter table workspaces add column if not exists acesso_desliga text[] not null default '{}';

alter table acesso_telas enable row level security;
alter table pacotes_acesso enable row level security;
drop policy if exists acesso_telas_ler on acesso_telas;
create policy acesso_telas_ler on acesso_telas for select to authenticated using (true);
drop policy if exists pacotes_acesso_ler on pacotes_acesso;
create policy pacotes_acesso_ler on pacotes_acesso for select to authenticated using (sou_equipe_interna());
-- escrita só pelas funções abaixo
revoke insert, update, delete on acesso_telas, pacotes_acesso from anon, authenticated;

-- telas liberadas de um cliente (null = sem restrição)
create or replace function public.acesso_telas_ws(p_ws uuid) returns text[]
language sql stable security definer set search_path = public as $$
  select case when w.pacote_id is null and cardinality(w.acesso_liga) = 0 and cardinality(w.acesso_desliga) = 0 then null
    else array(select distinct t from unnest(coalesce(p.telas, case when w.pacote_id is null then (select array_agg(tela) from acesso_telas) else '{}'::text[] end) || w.acesso_liga) t
               where not (t = any (w.acesso_desliga)) or t in ('cad-equipe', 'cad-funcoes')
               union select unnest(array['cad-equipe', 'cad-funcoes'])) end
  from workspaces w left join pacotes_acesso p on p.id = w.pacote_id
  where w.id = p_ws;
$$;
-- o módulo tem alguma tela liberada para o cliente?
create or replace function public.modulo_liberado(p_ws uuid, p_mod text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare t text[];
begin
  if p_mod in ('cfg', 'cad') then return true; end if;
  t := acesso_telas_ws(p_ws);
  if t is null then return true; end if;
  return exists (select 1 from acesso_telas a where a.tela = any (t) and a.modulo = p_mod);
end $$;

-- nivel_modulo passa a respeitar o pacote do cliente (antes de olhar papel e função)
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.nivel_modulo(uuid,text)'::regprocedure);
  if position('modulo_liberado' in d) > 0 then return; end if;
  n := replace(d, 'if coalesce(auth.role(), '''') = ''service_role'' then return ''editar''; end if;',
    'if coalesce(auth.role(), '''') = ''service_role'' then return ''editar''; end if;' || chr(10) || '  if not modulo_liberado(ws, modulo) then return ''nenhum''; end if;');
  if n = d then raise exception 'nivel_modulo: trecho esperado não encontrado — revisar'; end if;
  execute n;
end $$;

-- para a tela do cliente: o que está liberado
create or replace function public.acesso_workspace(p_ws uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare w workspaces; p pacotes_acesso;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  select * into w from workspaces where id = p_ws;
  select * into p from pacotes_acesso where id = w.pacote_id;
  return jsonb_build_object('pacote_id', w.pacote_id, 'pacote', p.nome, 'liga', to_jsonb(w.acesso_liga), 'desliga', to_jsonb(w.acesso_desliga), 'telas', to_jsonb(acesso_telas_ws(p_ws)));
end $$;

-- equipe interna: salvar e excluir pacote
create or replace function public.pacote_salvar(p_id uuid, p_nome text, p_descricao text, p_telas text[], p_ativo boolean default true) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; ruins text[];
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna monta pacotes de acesso'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome ao pacote'; end if;
  select array_agg(t) into ruins from unnest(coalesce(p_telas, '{}')) t where not exists (select 1 from acesso_telas a where a.tela = t);
  if ruins is not null then raise exception 'Telas desconhecidas: %', array_to_string(ruins, ', '); end if;
  if p_id is null then
    insert into pacotes_acesso (nome, descricao, telas, ativo) values (trim(p_nome), p_descricao, coalesce(p_telas, '{}'), coalesce(p_ativo, true)) returning id into v;
  else
    update pacotes_acesso set nome = trim(p_nome), descricao = p_descricao, telas = coalesce(p_telas, '{}'), ativo = coalesce(p_ativo, true), atualizado_em = now() where id = p_id returning id into v;
    if v is null then raise exception 'Pacote não encontrado'; end if;
  end if;
  return v;
end $$;
create or replace function public.pacote_excluir(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna mexe nos pacotes de acesso'; end if;
  select count(*) into n from workspaces where pacote_id = p_id;
  if n > 0 then raise exception 'Este pacote está em % cliente(s). Troque o pacote deles antes de excluir.', n; end if;
  delete from pacotes_acesso where id = p_id;
end $$;

-- equipe interna: lista os clientes com o pacote e os ajustes de cada um
create or replace function public.clientes_acesso() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna vê os pacotes dos clientes'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'nome', w.nome, 'modo_produto', w.modo_produto, 'pacote_id', w.pacote_id, 'liga', to_jsonb(w.acesso_liga), 'desliga', to_jsonb(w.acesso_desliga)) order by w.nome)
                   from workspaces w where not coalesce(w.agencia, false)), '[]'::jsonb);
end $$;
-- equipe interna: define o pacote e os ajustes de um cliente
create or replace function public.workspace_definir_acesso(p_ws uuid, p_pacote uuid, p_liga text[], p_desliga text[]) returns void
language plpgsql security definer set search_path = public as $$
declare ruins text[];
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna define o pacote de um cliente'; end if;
  if exists (select 1 from workspaces where id = p_ws and coalesce(agencia, false)) then raise exception 'O workspace da equipe interna não recebe pacote'; end if;
  if p_pacote is not null and not exists (select 1 from pacotes_acesso where id = p_pacote and ativo) then raise exception 'Pacote não encontrado ou inativo'; end if;
  select array_agg(t) into ruins from unnest(coalesce(p_liga, '{}') || coalesce(p_desliga, '{}')) t where not exists (select 1 from acesso_telas a where a.tela = t);
  if ruins is not null then raise exception 'Telas desconhecidas: %', array_to_string(ruins, ', '); end if;
  update workspaces set pacote_id = p_pacote, acesso_liga = coalesce(p_liga, '{}'), acesso_desliga = coalesce(p_desliga, '{}') where id = p_ws;
  if not found then raise exception 'Cliente não encontrado'; end if;
end $$;

revoke execute on function public.acesso_telas_ws(uuid), public.modulo_liberado(uuid, text), public.acesso_workspace(uuid), public.pacote_salvar(uuid, text, text, text[], boolean),
  public.pacote_excluir(uuid), public.clientes_acesso(), public.workspace_definir_acesso(uuid, uuid, text[], text[]) from public, anon;
grant execute on function public.acesso_workspace(uuid), public.pacote_salvar(uuid, text, text, text[], boolean), public.pacote_excluir(uuid), public.clientes_acesso(),
  public.workspace_definir_acesso(uuid, uuid, text[], text[]) to authenticated;
-- usadas dentro das políticas (via nivel_modulo): authenticated precisa poder executar
grant execute on function public.acesso_telas_ws(uuid), public.modulo_liberado(uuid, text) to authenticated, service_role;

-- pacotes iniciais (pontos de partida; a equipe interna ajusta na tela Configurações → Pacotes de acesso)
insert into pacotes_acesso (nome, descricao, telas) values
('Consultoria', 'Acesso completo a todos os módulos.', (select array_agg(tela order by ordem) from acesso_telas where tela not like 'st-%')),
('Mentoria', 'Marketing, vendas, retenção, growth e projetos. Sem o módulo financeiro.',
  (select array_agg(tela order by ordem) from acesso_telas where tela not like 'st-%' and modulo <> 'fin'
     and tela not in ('cad-planocontas', 'cad-regras', 'cad-impostos', 'cad-bancos', 'cad-formaspag', 'cad-fornecedores', 'cad-centros', 'cad-rateio'))),
('Disparo', 'Campanhas, mídia, leads e funil comercial para operação de disparos.',
  array['adm-painel', 'ia-perguntar', 'mkt-dash', 'mkt-midia', 'mkt-camp', 'mkt-trafego', 'crm-dash', 'crm-leads', 'crm-vendas', 'mkt-origem', 'gro-analise',
        'cfg-importar', 'cfg-integracoes', 'cad-equipe', 'cad-funcoes', 'cad-clientes', 'cad-produtos', 'cad-canais', 'cad-funis'])
on conflict (nome) do nothing;


-- ================================================================
-- >>> 20261010240000_cartao_e_receber_avulso.sql
-- ================================================================
-- v0.86 — Cartão de crédito não é saldo em banco · pagamento de fatura · contas a receber avulsas · pacote "Casa"
-- Rode DEPOIS de 20261010230000_pacotes_acesso.sql (usa pode_editar da v0.80 e pacotes_acesso da v0.85). Idempotente.
--
-- 1. Cartão de crédito
--    Antes: o cartão era cadastrado como uma "conta bancária" e o saldo dele (negativo, porque só tem saídas) era somado
--    ao "Saldo em banco" dos painéis. Cada compra no cartão diminuía o caixa no dia da compra.
--    Agora: contas_bancarias.tipo = 'conta' | 'cartao'. Cartão fica fora do saldo em banco e do caixa projetado.
--    A compra no cartão continua baixando a conta a pagar (o passivo passa do fornecedor para o cartão).
--    O dinheiro só sai do banco quando a fatura é paga: pagar_fatura_cartao (D cartão / C banco).
-- 2. Contas a receber avulsas (sem venda nem contrato), para a casa e para receitas eventuais:
--    receber_avulso_criar / receber_avulso_cancelar; o recebimento lança D banco / C conta de receita escolhida.
-- 3. Pacote "Casa" (só telas do financeiro) e aplicação ao workspace "Casa".

-- ---------- 1. tipo da conta ----------
alter table contas_bancarias add column if not exists tipo text not null default 'conta';
alter table contas_bancarias add column if not exists dia_vencimento int;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'contas_bancarias_tipo_check') then
    alter table contas_bancarias add constraint contas_bancarias_tipo_check check (tipo in ('conta', 'cartao'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'contas_bancarias_dia_venc_check') then
    alter table contas_bancarias add constraint contas_bancarias_dia_venc_check check (dia_vencimento is null or dia_vencimento between 1 and 31);
  end if;
end $$;

-- cartão nunca é a conta padrão de recebimento/pagamento
create or replace function public.contas_bancarias_cartao_padrao() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.tipo = 'cartao' then new.padrao := false; end if;
  return new;
end $$;
revoke execute on function public.contas_bancarias_cartao_padrao() from public, anon;
drop trigger if exists contas_bancarias_cartao_padrao_t on contas_bancarias;
create trigger contas_bancarias_cartao_padrao_t before insert or update on contas_bancarias
  for each row execute function public.contas_bancarias_cartao_padrao();

-- contas já cadastradas cujo nome ou conta contábil indicam cartão
update contas_bancarias cb set tipo = 'cartao', padrao = false
 where cb.tipo = 'conta'
   and (cb.nome ilike '%cart%o%cr%dito%'
        or exists (select 1 from plano_contas pc where pc.id = cb.conta_contabil_id and pc.tipo = 'passivo' and pc.nome ilike '%cart%o%'));

-- saldo em banco: só contas (os painéis fin_dashboard, fin_dashboard_periodo e painel_gerencial leem esta view)
create or replace view v_saldo_contas_bancarias with (security_invoker = true) as
select cb.id as conta_bancaria_id, cb.workspace_id, cb.nome, cb.saldo_inicial,
       cb.saldo_inicial + coalesce(sum(case m.tipo when 'entrada' then m.valor else -m.valor end), 0) as saldo_atual
  from contas_bancarias cb left join movimentacoes_bancarias m on m.conta_bancaria_id = cb.id
 where cb.tipo = 'conta'
 group by cb.id;

-- fatura em aberto de cada cartão (compras − pagamentos de fatura; positivo = devendo)
create or replace view v_cartoes_fatura with (security_invoker = true) as
select cb.id as conta_bancaria_id, cb.workspace_id, cb.nome, cb.banco, cb.dia_vencimento, cb.ativa,
       -(cb.saldo_inicial + coalesce(sum(case m.tipo when 'entrada' then m.valor else -m.valor end), 0)) as fatura_aberta,
       coalesce(sum(m.valor) filter (where m.tipo = 'saida'), 0) as compras,
       coalesce(sum(m.valor) filter (where m.tipo = 'entrada'), 0) as pagamentos
  from contas_bancarias cb left join movimentacoes_bancarias m on m.conta_bancaria_id = cb.id
 where cb.tipo = 'cartao'
 group by cb.id;
grant select on v_cartoes_fatura to authenticated;
revoke all on v_cartoes_fatura from anon;

-- "entrou / saiu" do período no painel gerencial: compra no cartão não é saída de caixa
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.painel_gerencial(uuid, date, date, date)'::regprocedure);
  if position('tipo = ''cartao''' in d) = 0 then
    n := replace(d, 'from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim',
                    'from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and conta_bancaria_id not in (select id from contas_bancarias where tipo = ''cartao'')');
    if n = d then raise exception 'painel_gerencial: trecho de entrou/saiu não encontrado — revisar'; end if;
    execute n;
  end if;
end $$;

-- pagamento de fatura
alter table lancamentos drop constraint if exists lancamentos_origem_tipo_check;
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo = any (array[
  'venda', 'recebimento', 'estorno', 'manual', 'conta_pagar', 'pagamento', 'cancelamento_pagar',
  'contrato_parcela', 'cancelamento_contrato', 'desconto', 'fatura_cartao']));

create or replace function public.pagar_fatura_cartao(p_cartao uuid, p_valor numeric, p_data date default null, p_banco uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c contas_bancarias; b contas_bancarias; d date; l uuid;
begin
  select * into c from contas_bancarias where id = p_cartao;
  if not found or c.tipo <> 'cartao' then raise exception 'Escolha um cartão de crédito'; end if;
  if not pode_editar(c.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor pago da fatura'; end if;
  select * into b from contas_bancarias where id = coalesce(p_banco,
    (select id from contas_bancarias where workspace_id = c.workspace_id and tipo = 'conta' and padrao and ativa limit 1));
  if not found or b.workspace_id <> c.workspace_id or b.tipo <> 'conta' then raise exception 'Escolha a conta bancária que pagou a fatura'; end if;
  if c.conta_contabil_id is null or b.conta_contabil_id is null then raise exception 'Cartão ou conta sem conta contábil no cadastro'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (c.workspace_id, d, 'Pagamento de fatura: ' || c.nome, 'fatura_cartao', c.id) returning id into l;
  perform _partida(l, c.workspace_id, c.conta_contabil_id, null, 'D', round(p_valor, 2));
  perform _partida(l, c.workspace_id, b.conta_contabil_id, null, 'C', round(p_valor, 2));
  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id) values
    (c.workspace_id, b.id, d, 'saida', round(p_valor, 2), 'Pagamento de fatura: ' || c.nome, 'fatura_cartao', c.id, l),
    (c.workspace_id, c.id, d, 'entrada', round(p_valor, 2), 'Pagamento de fatura (de ' || b.nome || ')', 'fatura_cartao', c.id, l);
  return l;
end $$;

create or replace function public.desfazer_fatura_cartao(p_lancamento uuid, p_data date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare l0 lancamentos; l1 uuid; d date;
begin
  select * into l0 from lancamentos where id = p_lancamento;
  if not found or l0.origem_tipo <> 'fatura_cartao' or l0.estorno_de is not null then raise exception 'Pagamento de fatura não encontrado'; end if;
  if not pode_editar(l0.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if exists (select 1 from lancamentos e where e.estorno_de = l0.id) then raise exception 'Este pagamento de fatura já foi desfeito'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (l0.workspace_id, d, 'Desfeito: ' || l0.descricao, 'fatura_cartao', l0.origem_id, l0.id) returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = l0.id;
  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
  select workspace_id, conta_bancaria_id, d, case tipo when 'entrada' then 'saida' else 'entrada' end, valor, 'Desfeito: ' || descricao, 'fatura_cartao', origem_id, l1
    from movimentacoes_bancarias where lancamento_id = l0.id;
  return l1;
end $$;

-- ---------- 2. contas a receber avulsas ----------
alter table contas_receber add column if not exists conta_receita_id uuid references plano_contas(id);

create or replace function public.receber_avulso_criar(p_ws uuid, p_descricao text, p_valor numeric, p_vencimento date,
                                                      p_conta_receita uuid, p_conta_bancaria uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if not pode_editar(p_ws, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if coalesce(trim(p_descricao), '') = '' then raise exception 'Descreva a conta a receber'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor'; end if;
  if p_vencimento is null then raise exception 'Informe a data prevista'; end if;
  if not exists (select 1 from plano_contas where id = p_conta_receita and workspace_id = p_ws and aceita_lancamento and tipo in ('receita', 'ativo', 'passivo', 'patrimonio')) then
    raise exception 'Escolha a conta de receita (plano de contas)';
  end if;
  if p_conta_bancaria is not null and not exists (select 1 from contas_bancarias where id = p_conta_bancaria and workspace_id = p_ws and tipo = 'conta') then
    raise exception 'Conta bancária inválida';
  end if;
  insert into contas_receber (workspace_id, descricao, valor, vencimento, status, conta_bancaria_id, conta_receita_id)
  values (p_ws, trim(p_descricao), round(p_valor, 2), p_vencimento, 'previsto', p_conta_bancaria, p_conta_receita) returning id into v;
  return v;
end $$;

-- avulsa ainda não recebida não tem lançamento (a receita entra no recebimento): cancelar é só marcar
create or replace function public.receber_avulso_cancelar(p_conta_receber uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cr contas_receber;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found or cr.conta_receita_id is null then raise exception 'Conta a receber avulsa não encontrada'; end if;
  if not pode_editar(cr.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cr.status <> 'previsto' then raise exception 'Só dá para cancelar conta ainda não recebida (esta está %)', cr.status; end if;
  update contas_receber set status = 'cancelado' where id = cr.id;
end $$;

-- recebimento de avulsa: D banco / C conta de receita escolhida
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.registrar_recebimento(uuid, date, uuid)'::regprocedure);
  if position('conta_receita_id' in d) = 0 then
    -- busca tolerante a espaços e quebras de linha (o SQL Editor pode trocar \n por \r\n ao colar)
    n := regexp_replace(d, 'if\s+cr\.contrato_id\s+is\s+not\s+null\s+then\s+r\s*:=\s*_regra\(\s*cr\.workspace_id\s*,\s*''contrato_recebimento''\s*\)\s*;',
      'if cr.conta_receita_id is not null then r.conta_debito_id := null; r.conta_credito_id := cr.conta_receita_id; v_desc := ''Recebimento: '' || coalesce(cr.descricao, ''avulso''); '
      || 'elsif cr.contrato_id is not null then r := _regra(cr.workspace_id, ''contrato_recebimento'');');
    if n = d then raise exception 'registrar_recebimento: trecho não encontrado — revisar'; end if;
    -- recebimento não pode cair em cartão
    n := replace(n, 'if v_banco_contabil is null then raise exception ''Conta bancária inválida para este workspace''; end if;',
                    'if v_banco_contabil is null then raise exception ''Conta bancária inválida para este workspace''; end if;
  if (select tipo from contas_bancarias where id = v_banco) = ''cartao'' then raise exception ''Recebimento não pode entrar no cartão de crédito: escolha uma conta bancária''; end if;');
    execute n;
  end if;
end $$;

-- recebimento parcial: avulsa recebe o valor inteiro (mensagem clara)
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.registrar_recebimento_parcial(uuid, numeric, date, uuid)'::regprocedure);
  if position('conta_receita_id' in d) = 0 then
    n := replace(d, '  if cr.contrato_id is null then raise exception',
                    '  if cr.conta_receita_id is not null then raise exception ''Conta avulsa recebe o valor inteiro. Para dividir, cancele e crie duas.''; end if;
  if cr.contrato_id is null then raise exception');
    if n <> d then execute n; end if;
  end if;
end $$;

revoke execute on function public.pagar_fatura_cartao(uuid, numeric, date, uuid), public.desfazer_fatura_cartao(uuid, date),
  public.receber_avulso_criar(uuid, text, numeric, date, uuid, uuid), public.receber_avulso_cancelar(uuid) from public, anon;
grant execute on function public.pagar_fatura_cartao(uuid, numeric, date, uuid), public.desfazer_fatura_cartao(uuid, date),
  public.receber_avulso_criar(uuid, text, numeric, date, uuid, uuid), public.receber_avulso_cancelar(uuid) to authenticated, service_role;

-- ---------- 3. pacote Casa ----------
insert into pacotes_acesso (nome, descricao, telas) values
('Casa', 'Finanças pessoais: só o financeiro (dashboard, contas a receber e a pagar, lançamentos) e os cadastros financeiros.',
  array['fin-dash', 'fin-receber', 'fin-pagar', 'fin-lanc', 'cad-equipe', 'cad-planocontas', 'cad-bancos', 'cad-formaspag', 'cad-fornecedores', 'cad-centros'])
on conflict (nome) do nothing;
update workspaces w set pacote_id = (select id from pacotes_acesso where nome = 'Casa')
 where w.nome = 'Casa' and w.pacote_id is null and not w.agencia;

-- ---------- 4. campanha → projeto: atividades a partir dos blocos da estratégia ----------
-- Cada bloco ativo da campanha vira uma atividade principal no projeto da campanha, com subatividades do tipo do bloco
-- (ex.: Tráfego pago → definir públicos, criativos, configurar campanhas, acompanhar). Idempotente por bloco.
alter table projeto_atividades add column if not exists campanha_bloco_id uuid references campanha_blocos(id) on delete set null;
create index if not exists projeto_atividades_bloco on projeto_atividades (campanha_bloco_id);

create or replace function public._bloco_tarefas(p_tipo text, p_nome text) returns table (ordem int, titulo text, funcao text)
language sql immutable set search_path = public as $$
  select t.ordem, t.titulo, t.funcao from (values
    ('conteudo', 1, 'Planejar o calendário de conteúdo', 'Social media'), ('conteudo', 2, 'Produzir posts, reels e stories', 'Designer'), ('conteudo', 3, 'Colocar o link com UTM na bio e nos stories', 'Social media'),
    ('trafego', 1, 'Definir públicos e orçamento', 'Tráfego'), ('trafego', 2, 'Produzir os criativos dos anúncios', 'Designer'), ('trafego', 3, 'Configurar campanhas, pixel e UTMs', 'Tráfego'), ('trafego', 4, 'Acompanhar métricas e otimizar', 'Tráfego'),
    ('captura', 1, 'Escrever a copy da página', 'Copywriter'), ('captura', 2, 'Montar a página de captura', 'Desenvolvedor'), ('captura', 3, 'Ligar o formulário aos leads do Growths', 'Desenvolvedor'), ('captura', 4, 'Testar a página no celular e no computador', 'Desenvolvedor'),
    ('indicacao', 1, 'Definir regra e recompensa da indicação', 'Gestor'), ('indicacao', 2, 'Criar link de indicação com UTM', 'Tráfego'), ('indicacao', 3, 'Convidar parceiros e indicadores', 'Comercial'),
    ('grupo', 1, 'Criar o grupo e os links de entrada', 'Social media'), ('grupo', 2, 'Escrever as mensagens do grupo', 'Copywriter'), ('grupo', 3, 'Programar o cronograma de mensagens', 'Social media'),
    ('api', 1, 'Montar a lista de contatos', 'Comercial'), ('api', 2, 'Escrever as mensagens do disparo', 'Copywriter'), ('api', 3, 'Configurar e agendar o disparo', 'Social media'),
    ('email', 1, 'Escrever a sequência de e-mails', 'Copywriter'), ('email', 2, 'Configurar a automação de envio', 'Desenvolvedor'), ('email', 3, 'Testar os envios', 'Desenvolvedor'),
    ('pesquisa', 1, 'Montar as perguntas da pesquisa', 'Gestor'), ('pesquisa', 2, 'Publicar a pesquisa e o link', 'Social media'), ('pesquisa', 3, 'Definir o critério de qualificação', 'Comercial'),
    ('aula', 1, 'Definir o roteiro da aula', 'Especialista'), ('aula', 2, 'Preparar a apresentação', 'Designer'), ('aula', 3, 'Configurar a sala ou transmissão', 'Social media'), ('aula', 4, 'Ensaiar e testar áudio e vídeo', 'Especialista'), ('aula', 5, 'Enviar os lembretes', 'Social media'),
    ('vsl', 1, 'Roteirizar o vídeo', 'Copywriter'), ('vsl', 2, 'Gravar', 'Especialista'), ('vsl', 3, 'Editar', 'Editor de vídeo'), ('vsl', 4, 'Publicar a página do vídeo', 'Desenvolvedor'),
    ('checkout', 1, 'Cadastrar produto e oferta na plataforma', 'Gestor'), ('checkout', 2, 'Configurar o checkout e os meios de pagamento', 'Desenvolvedor'), ('checkout', 3, 'Fazer uma compra de teste', 'Gestor'),
    ('comercial', 1, 'Definir o script de abordagem', 'Comercial'), ('comercial', 2, 'Distribuir os leads para SDR e closer', 'Comercial'), ('comercial', 3, 'Acompanhar o funil comercial', 'Comercial'),
    ('recompra', 1, 'Definir a oferta de recompra ou ascensão', 'Gestor'), ('recompra', 2, 'Escrever a comunicação para clientes', 'Copywriter'), ('recompra', 3, 'Disparar e acompanhar', 'Comercial'),
    ('assinatura', 1, 'Configurar a régua de renovação', 'Desenvolvedor'), ('assinatura', 2, 'Escrever as mensagens de renovação', 'Copywriter'), ('assinatura', 3, 'Acompanhar cancelamentos', 'Comercial')
  ) t(tipo, ordem, titulo, funcao)
  where t.tipo = p_tipo
  union all
  select 1, 'Preparar: ' || p_nome, null::text where not exists (select 1 where p_tipo in ('conteudo','trafego','captura','indicacao','grupo','api','email','pesquisa','aula','vsl','checkout','comercial','recompra','assinatura'))
  order by 1;
$$;

create or replace function public._campanha_gerar_atividades(p_campanha uuid) returns int
language plpgsql security definer set search_path = public as $$
declare pj projetos; b record; t record; pai uuid; n int := 0; o int; prev text;
begin
  select * into pj from projetos where campanha_id = p_campanha order by criado_em limit 1;
  if not found then return 0; end if;
  prev := coalesce(current_setting('growths.recalc', true), '');
  perform set_config('growths.recalc', '1', true);
  select coalesce(max(ordem), 0) into o from projeto_atividades where projeto_id = pj.id and pai_id is null;
  for b in select cb.* from campanha_blocos cb
            where cb.campanha_id = p_campanha and cb.ativo
              and not exists (select 1 from projeto_atividades a where a.projeto_id = pj.id and a.campanha_bloco_id = cb.id)
            order by array_position(array['aquisicao','aquecimento','conversao','retencao'], cb.fase), cb.ordem, cb.criado_em loop
    o := o + 10;
    insert into projeto_atividades (workspace_id, projeto_id, titulo, descricao, ordem, depende_de, campanha_bloco_id, status)
    values (pj.workspace_id, pj.id, b.nome, 'Bloco da estratégia (' || b.fase || '). Criada junto com a campanha.', o, '{}', b.id, 'bloqueada')
    returning id into pai;
    n := n + 1;
    for t in select x.ordem as k, x.titulo, x.funcao from _bloco_tarefas(b.tipo, b.nome) x loop
      insert into projeto_atividades (workspace_id, projeto_id, pai_id, titulo, funcao, responsavel_id, ordem, depende_de, status)
      values (pj.workspace_id, pj.id, pai, t.titulo, t.funcao, case when t.funcao is not null then equipe_resolve(pj.workspace_id, t.funcao) end, t.k, '{}', 'bloqueada');
      n := n + 1;
    end loop;
  end loop;
  perform set_config('growths.recalc', prev, true);
  if n > 0 then perform projeto_recalcula(pj.id); end if;
  return n;
end $$;
revoke execute on function public._campanha_gerar_atividades(uuid), public._bloco_tarefas(text, text) from public, anon, authenticated;

create or replace function public.campanha_gerar_atividades(p_campanha uuid) returns int
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  select workspace_id into w from campanhas where id = p_campanha;
  if w is null or not pode_editar(w, '{prj,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  return _campanha_gerar_atividades(p_campanha);
end $$;
revoke execute on function public.campanha_gerar_atividades(uuid) from public, anon;
grant execute on function public.campanha_gerar_atividades(uuid) to authenticated, service_role;

create or replace function public.campanha_blocos_atividades() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform _campanha_gerar_atividades(new.campanha_id);
  return null;
end $$;
revoke execute on function public.campanha_blocos_atividades() from public, anon, authenticated;
drop trigger if exists campanha_blocos_atividades_t on campanha_blocos;
create trigger campanha_blocos_atividades_t after insert on campanha_blocos
  for each row execute function public.campanha_blocos_atividades();


-- ================================================================
-- >>> 20261010250000_casa_modulo.sql
-- ================================================================
-- v0.87 — "Casa" como módulo dentro da Mathisa — Operação
-- A Casa tem livro contábil próprio (plano de contas, bancos, lançamentos, contas a pagar e a receber) e nada se mistura com a empresa.
-- Por trás ela continua sendo um workspace separado (é o que garante a separação no banco), mas fica ligada à operação
-- (workspaces.casa_de) e aparece só como o grupo "Casa" no menu da operação, para quem é membro dela.
-- A única ponte é a transferência da empresa para a Casa: transferir_para_casa paga (no todo ou em parte) uma conta a pagar da
-- empresa, normalmente o pró-labore, ou lança uma retirada contra uma conta contábil escolhida, e na Casa registra o recebimento
-- (conta a receber avulsa já recebida). Cada lado tem o seu lançamento; a tabela transferencias_casa guarda a ligação.
-- Rode DEPOIS de 20261010240000_cartao_e_receber_avulso.sql. Idempotente.

alter table workspaces add column if not exists casa_de uuid references workspaces(id);
create unique index if not exists workspaces_uma_casa on workspaces (casa_de) where casa_de is not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'workspaces_casa_nao_agencia') then
    alter table workspaces add constraint workspaces_casa_nao_agencia check (casa_de is null or (casa_de <> id and not coalesce(agencia, false)));
  end if;
end $$;

-- liga a Casa já criada à operação da Mathisa (o workspace da agência)
update workspaces set casa_de = (select id from workspaces where agencia order by criado_em limit 1)
 where nome = 'Casa' and casa_de is null and not coalesce(agencia, false)
   and (select count(*) from workspaces where agencia) = 1;

-- a Casa não aparece como cliente na tela de pacotes
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.clientes_acesso()'::regprocedure);
  if position('casa_de' in d) = 0 then
    n := replace(d, 'from workspaces w where not coalesce(w.agencia, false)', 'from workspaces w where not coalesce(w.agencia, false) and w.casa_de is null');
    if n = d then raise exception 'clientes_acesso: trecho não encontrado — revisar'; end if;
    execute n;
  end if;
end $$;

alter table lancamentos drop constraint if exists lancamentos_origem_tipo_check;
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo = any (array[
  'venda', 'recebimento', 'estorno', 'manual', 'conta_pagar', 'pagamento', 'cancelamento_pagar',
  'contrato_parcela', 'cancelamento_contrato', 'desconto', 'fatura_cartao', 'transferencia_casa']));

create table if not exists transferencias_casa (
  id uuid primary key default gen_random_uuid(),
  ws_origem uuid not null references workspaces(id) on delete cascade,
  ws_casa uuid not null references workspaces(id) on delete cascade,
  data date not null,
  valor numeric not null check (valor > 0),
  descricao text not null,
  conta_pagar_id uuid references contas_pagar(id),
  lancamento_origem uuid references lancamentos(id),
  conta_receber_casa uuid references contas_receber(id),
  desfeita_em timestamptz,
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now()
);
alter table transferencias_casa enable row level security;
drop policy if exists transferencias_casa_ler on transferencias_casa;
create policy transferencias_casa_ler on transferencias_casa for select to authenticated
  using (pertence_ao_workspace(ws_origem) and pertence_ao_workspace(ws_casa));
revoke insert, update, delete on transferencias_casa from anon, authenticated;
grant select on transferencias_casa to authenticated;

create or replace function public.transferir_para_casa(
  p_ws uuid, p_banco_origem uuid, p_valor numeric, p_data date, p_descricao text,
  p_conta_pagar uuid, p_conta_contabil_origem uuid, p_banco_casa uuid, p_receita_casa uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare casa uuid; cp contas_pagar; b contas_bancarias; l uuid; cr uuid; d date; t uuid; v numeric; descr text;
begin
  select id into casa from workspaces where casa_de = p_ws;
  if casa is null then raise exception 'Esta operação não tem o módulo Casa'; end if;
  if not pode_editar(p_ws, '{fin}'::text[]) or not pode_editar(casa, '{fin}'::text[]) then
    raise exception 'Sem permissão: precisa editar o financeiro da empresa e da Casa'; end if;
  t := gen_random_uuid();
  v := round(p_valor, 2);
  if v is null or v <= 0 then raise exception 'Informe o valor da transferência'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  select * into b from contas_bancarias where id = p_banco_origem and workspace_id = p_ws and tipo = 'conta';
  if not found then raise exception 'Escolha a conta bancária da empresa de onde sai o dinheiro'; end if;
  if not exists (select 1 from contas_bancarias where id = p_banco_casa and workspace_id = casa and tipo = 'conta') then
    raise exception 'Escolha a conta da Casa onde o dinheiro entra'; end if;

  if p_conta_pagar is not null then
    select * into cp from contas_pagar where id = p_conta_pagar and workspace_id = p_ws;
    if not found or cp.status <> 'previsto' then raise exception 'A conta a pagar escolhida não está em aberto'; end if;
    if v > cp.valor then raise exception 'O valor passa do que falta pagar nesta conta (%)', cp.valor; end if;
    descr := coalesce(nullif(trim(p_descricao), ''), cp.descricao);
    if v < cp.valor then l := registrar_pagamento_parcial(cp.id, v, d, b.id); else l := registrar_pagamento(cp.id, d, b.id); end if;
  else
    if not exists (select 1 from plano_contas where id = p_conta_contabil_origem and workspace_id = p_ws and aceita_lancamento) then
      raise exception 'Escolha a conta contábil da empresa (ex.: Distribuição de lucros)'; end if;
    descr := coalesce(nullif(trim(p_descricao), ''), 'Transferência para a Casa');
    insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
    values (p_ws, d, 'Transferência para a Casa: ' || descr, 'transferencia_casa', t) returning id into l;
    perform _partida(l, p_ws, p_conta_contabil_origem, null, 'D', v);
    perform _partida(l, p_ws, b.conta_contabil_id, null, 'C', v);
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    values (p_ws, b.id, d, 'saida', v, 'Transferência para a Casa: ' || descr, 'transferencia_casa', t, l);
  end if;

  -- na Casa: conta a receber avulsa, já recebida (D banco da Casa / C receita escolhida)
  cr := receber_avulso_criar(casa, 'Da empresa: ' || descr, v, d, p_receita_casa, p_banco_casa);
  perform registrar_recebimento(cr, d, p_banco_casa);

  insert into transferencias_casa (id, ws_origem, ws_casa, data, valor, descricao, conta_pagar_id, lancamento_origem, conta_receber_casa)
  values (t, p_ws, casa, d, v, descr, cp.id, l, cr);
  return t;
end $$;

-- desfazer: estorna os dois lados (o histórico fica)
create or replace function public.desfazer_transferencia_casa(p_id uuid, p_data date default null)
returns void language plpgsql security definer set search_path = public as $$
declare t transferencias_casa; d date; l1 uuid; cpid uuid;
begin
  select * into t from transferencias_casa where id = p_id for update;
  if not found then raise exception 'Transferência não encontrada'; end if;
  if t.desfeita_em is not null then raise exception 'Esta transferência já foi desfeita'; end if;
  if not pode_editar(t.ws_origem, '{fin}'::text[]) or not pode_editar(t.ws_casa, '{fin}'::text[]) then
    raise exception 'Sem permissão: precisa editar o financeiro da empresa e da Casa'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  -- Casa
  perform desfazer_recebimento(t.conta_receber_casa, d);
  perform receber_avulso_cancelar(t.conta_receber_casa);
  -- empresa
  if t.conta_pagar_id is not null then
    -- o pagamento ficou na própria conta (pagamento total) ou na parte paga da baixa parcial (mesmo id)
    select origem_id into cpid from lancamentos where id = t.lancamento_origem;
    perform desfazer_pagamento(cpid, d);
  else
    insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
    select workspace_id, d, 'Desfeito: ' || descricao, 'transferencia_casa', t.id, id from lancamentos where id = t.lancamento_origem
    returning id into l1;
    insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
    select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = t.lancamento_origem;
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    select workspace_id, conta_bancaria_id, d, 'entrada', valor, 'Desfeito: ' || descricao, 'transferencia_casa', t.id, l1
      from movimentacoes_bancarias where lancamento_id = t.lancamento_origem;
  end if;
  update transferencias_casa set desfeita_em = now() where id = t.id;
end $$;

revoke execute on function public.transferir_para_casa(uuid, uuid, numeric, date, text, uuid, uuid, uuid, uuid), public.desfazer_transferencia_casa(uuid, date) from public, anon;
grant execute on function public.transferir_para_casa(uuid, uuid, numeric, date, text, uuid, uuid, uuid, uuid), public.desfazer_transferencia_casa(uuid, date) to authenticated, service_role;


-- ================================================================
-- >>> 20261011000000_fase1_confianca_dado.sql
-- ================================================================
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


-- ================================================================
-- >>> 20261011100000_fase2_captacao_vendas.sql
-- ================================================================
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


-- ================================================================
-- >>> 20261011200000_projetos_tags_modelos.sql
-- ================================================================
-- v0.90 — Projetos: tags, painel com gráfico, salvar como modelo, vínculo com campanha · Campanha: meta de CPL por canal
-- 1. projetos.tags e projeto_atividades.tags (filtros por tag).
-- 2. projeto_painel(projeto): situação, responsáveis e série diária planejado (pelo prazo) × concluído (para o gráfico).
-- 3. projeto_salvar_como_modelo(projeto, nome, padrao_campanha): copia atividades, subatividades, dependências, funções e prazos (em dias a partir do início).
-- 4. projeto_vincular_campanha(projeto, campanha) e campanha_criar_projeto(campanha, modelo, nome): projeto da campanha a partir de um modelo, já com as atividades dos blocos.
-- 5. campanha_canais_resultado(campanha): leads, investimento e CPL por canal da campanha contra a meta de leads e de CPL do canal.
-- Rode DEPOIS de 20261011100000_fase2_captacao_vendas.sql (usa campanha_participacoes). Idempotente.

alter table projetos add column if not exists tags text[] not null default '{}';
alter table projeto_atividades add column if not exists tags text[] not null default '{}';
create index if not exists projetos_tags_ix on projetos using gin (tags);
create index if not exists projeto_atividades_tags_ix on projeto_atividades using gin (tags);

-- ============ painel do projeto ============
create or replace function public.projeto_painel(p_projeto uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare p projetos; ini date; fim date; h date := (now() at time zone 'America/Sao_Paulo')::date; r jsonb;
begin
  select * into p from projetos where id = p_projeto;
  if not found or not pertence_ao_workspace(p.workspace_id) or not perm(p.workspace_id, 'ler', '{prj,adm,vendas,revops}'::text[]) then raise exception 'Projeto não encontrado'; end if;
  -- só atividades que são de fato feitas (folhas), sem as canceladas
  select coalesce(p.data_inicio, min((a.criado_em at time zone 'America/Sao_Paulo')::date), h),
         greatest(coalesce(p.data_fim_prevista, h), h, coalesce(max(a.prazo), h))
    into ini, fim
    from projeto_atividades a where a.projeto_id = p.id and a.status <> 'cancelada' and not exists (select 1 from projeto_atividades f where f.pai_id = a.id);
  if fim - ini > 366 then ini := fim - 366; end if;
  with pp as (select a.id, a.status, a.responsavel_id, a.prazo, (a.concluida_em at time zone 'America/Sao_Paulo')::date as concluida_em
                from projeto_atividades a where a.projeto_id = p.id and a.status <> 'cancelada' and not exists (select 1 from projeto_atividades f where f.pai_id = a.id))
  select jsonb_build_object(
    'inicio', ini, 'fim', fim, 'total', (select count(*) from pp),
    'status', coalesce((select jsonb_agg(jsonb_build_object('status', status, 'n', n) order by status) from (select status, count(*) n from pp group by 1) s), '[]'::jsonb),
    'responsaveis', coalesce((select jsonb_agg(x order by x.abertas desc, x.nome) from (
        select coalesce(e.nome, 'Sem responsável') as nome, count(*) filter (where pp.status in ('liberada', 'em_andamento')) as abertas,
               count(*) filter (where pp.status = 'bloqueada') as bloqueadas, count(*) filter (where pp.status = 'concluida') as concluidas,
               count(*) filter (where pp.status <> 'concluida' and pp.prazo < h) as atrasadas
          from pp left join equipe e on e.id = pp.responsavel_id group by 1) x), '[]'::jsonb),
    'serie', coalesce((select jsonb_agg(jsonb_build_object('d', g.d::date,
        'planejado', (select count(*) from pp where pp.prazo <= g.d::date),
        'concluido', case when g.d::date <= h then (select count(*) from pp where pp.status = 'concluida' and pp.concluida_em <= g.d::date) end) order by g.d)
      from generate_series(ini, fim, case when fim - ini > 90 then interval '7 days' else interval '1 day' end) g(d)), '[]'::jsonb),
    'sem_prazo', (select count(*) from pp where pp.prazo is null))
  into r;
  return r;
end $$;
revoke execute on function public.projeto_painel(uuid) from public, anon;
grant execute on function public.projeto_painel(uuid) to authenticated, service_role;

-- ============ salvar como modelo ============
create or replace function public.projeto_salvar_como_modelo(p_projeto uuid, p_nome text, p_padrao_campanha boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare p projetos; m uuid;
begin
  select * into p from projetos where id = p_projeto;
  if not found then raise exception 'Projeto não encontrado'; end if;
  if not pode_editar(p.workspace_id, '{prj}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome ao modelo'; end if;
  if exists (select 1 from projeto_modelos where workspace_id = p.workspace_id and lower(nome) = lower(trim(p_nome)) and ativo) then raise exception 'Já existe um modelo com este nome'; end if;
  if not exists (select 1 from projeto_atividades where projeto_id = p.id and status <> 'cancelada') then raise exception 'O projeto não tem atividades para virar modelo'; end if;
  if coalesce(p_padrao_campanha, false) then update projeto_modelos set padrao_campanha = false where workspace_id = p.workspace_id and padrao_campanha; end if;
  insert into projeto_modelos (workspace_id, nome, descricao, padrao_campanha, ativo)
  values (p.workspace_id, trim(p_nome), 'Criado a partir do projeto "' || p.nome || '"' || coalesce(' — ' || nullif(p.descricao, ''), ''), coalesce(p_padrao_campanha, false), true)
  returning id into m;
  with a as (select x.*, gen_random_uuid() as novo from projeto_atividades x where x.projeto_id = p.id and x.status <> 'cancelada')
  insert into projeto_modelo_atividades (id, workspace_id, modelo_id, pai_id, titulo, descricao, funcao, responsavel_id, ordem, depende_de, prazo_dias)
  select a.novo, a.workspace_id, m, (select y.novo from a y where y.id = a.pai_id), a.titulo, a.descricao, a.funcao, a.responsavel_id, a.ordem,
         coalesce((select array_agg(y.novo) from a y where y.id = any(a.depende_de)), '{}'),
         case when a.prazo is not null and p.data_inicio is not null then greatest(a.prazo - p.data_inicio, 0) end
    from a order by (a.pai_id is not null), a.ordem;
  return m;
end $$;
revoke execute on function public.projeto_salvar_como_modelo(uuid, text, boolean) from public, anon;
grant execute on function public.projeto_salvar_como_modelo(uuid, text, boolean) to authenticated, service_role;

-- ============ vínculo projeto × campanha ============
create or replace function public.projeto_vincular_campanha(p_projeto uuid, p_campanha uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p projetos;
begin
  select * into p from projetos where id = p_projeto;
  if not found then raise exception 'Projeto não encontrado'; end if;
  if not pode_editar(p.workspace_id, '{prj,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_campanha is not null and not exists (select 1 from campanhas where id = p_campanha and workspace_id = p.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  update projetos set campanha_id = p_campanha where id = p.id;
  if p_campanha is not null then perform _campanha_gerar_atividades(p_campanha); end if;
end $$;
revoke execute on function public.projeto_vincular_campanha(uuid, uuid) from public, anon;
grant execute on function public.projeto_vincular_campanha(uuid, uuid) to authenticated, service_role;

create or replace function public.campanha_criar_projeto(p_campanha uuid, p_modelo uuid, p_nome text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c campanhas; novo uuid; resp uuid;
begin
  select * into c from campanhas where id = p_campanha;
  if not found then raise exception 'Campanha não encontrada'; end if;
  if not pode_editar(c.workspace_id, '{prj,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_modelo is not null and not exists (select 1 from projeto_modelos where id = p_modelo and workspace_id = c.workspace_id) then raise exception 'Modelo não encontrado'; end if;
  insert into projetos (workspace_id, nome, descricao, campanha_id, modelo_id, data_inicio, data_fim_prevista)
  values (c.workspace_id, coalesce(nullif(trim(p_nome), ''), 'Campanha: ' || c.nome), 'Criado pela campanha a partir de um modelo.', c.id, p_modelo,
          coalesce(c.data_inicio, (now() at time zone 'America/Sao_Paulo')::date), c.data_fim)
  returning id into novo;
  -- o gatilho do projeto já criou as atividades do modelo; agora as dos blocos da estratégia (no projeto mais antigo da campanha)
  perform _campanha_gerar_atividades(c.id);
  return novo;
end $$;
revoke execute on function public.campanha_criar_projeto(uuid, uuid, text) from public, anon;
grant execute on function public.campanha_criar_projeto(uuid, uuid, text) to authenticated, service_role;

-- ============ leads e CPL por canal da campanha ============
create or replace function public.campanha_canais_resultado(p_campanha uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c campanhas; r jsonb;
begin
  select * into c from campanhas where id = p_campanha;
  if not found or not pertence_ao_workspace(c.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', cc.id, 'canal', cc.canal, 'temperatura', cc.temperatura, 'utm_campaign', cc.utm_campaign,
      'meta_leads', cc.meta_leads, 'meta_cpl', cc.meta_cpl, 'orcamento', cc.orcamento,
      'leads', l.n, 'investimento', i.v,
      'cpl', case when l.n > 0 and i.v is not null then round(i.v / l.n, 2) end,
      'pct_leads', case when cc.meta_leads > 0 then round(l.n * 100.0 / cc.meta_leads, 1) end) order by cc.canal, cc.temperatura nulls first), '[]'::jsonb)
  into r
  from campanha_canais cc
  left join lateral (select count(*) n from campanha_participacoes p where p.campanha_id = c.id and (p.campanha_canal_id = cc.id or (p.campanha_canal_id is null and p.utm_campaign = cc.utm_campaign))) l on true
  left join lateral (select sum(md.custo) v from metricas_anuncio_dia md join anuncios an on an.id = md.anuncio_id where an.campanha_canal_id = cc.id) i on true
  where cc.campanha_id = c.id;
  return r;
end $$;
revoke execute on function public.campanha_canais_resultado(uuid) from public, anon;
grant execute on function public.campanha_canais_resultado(uuid) to authenticated, service_role;

-- ============ tela nova no catálogo de acesso ============
insert into acesso_telas (tela, modulo, nome, grupo, ordem) values ('prj-atividades', 'prj', 'Todas as atividades', 'Projetos', 27)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
update pacotes_acesso set telas = telas || array['prj-atividades'] where telas @> array['prj-lista'] and not telas @> array['prj-atividades'];


-- ================================================================
-- >>> 20261011300000_projeto_auto_opcional.sql
-- ================================================================
-- v0.91 — Projeto automático da campanha passa a ser opcional
-- Antes: toda campanha nova criava sozinha o projeto "Campanha: <nome>" com o modelo padrão de campanha.
-- Agora: a campanha tem projeto_auto (marcado por padrão no formulário) e projeto_modelo_id (o modelo escolhido; vazio = o padrão).
-- Desmarcado, nenhum projeto é criado: depois dá para criar pelo botão Projeto da campanha, com o modelo que quiser.
-- Rode DEPOIS de 20261011200000_projetos_tags_modelos.sql. Idempotente.

alter table campanhas add column if not exists projeto_auto boolean not null default true;
alter table campanhas add column if not exists projeto_modelo_id uuid references projeto_modelos(id) on delete set null;

create or replace function public.campanha_cria_projeto()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare m uuid;
begin
  if not coalesce(new.projeto_auto, true) then return null; end if;
  m := coalesce((select id from projeto_modelos where id = new.projeto_modelo_id and workspace_id = new.workspace_id),
                (select id from projeto_modelos where workspace_id = new.workspace_id and padrao_campanha and ativo limit 1));
  insert into projetos (workspace_id, nome, descricao, campanha_id, modelo_id, data_inicio, data_fim_prevista)
  values (new.workspace_id, 'Campanha: ' || new.nome, 'Projeto criado automaticamente com a campanha.', new.id, m,
          coalesce(new.data_inicio, (now() at time zone 'America/Sao_Paulo')::date), new.data_fim);
  return null;
end $function$;


-- ================================================================
-- >>> 20261011400000_custo_operacional.sql
-- ================================================================
-- v0.93 — Tela Financeiro → Custo operacional no catálogo de acesso
-- A tela calcula tudo no navegador a partir do Contas a pagar, das recorrências e do Contas a receber (sem tabela nova).
-- Aqui só entra no catálogo de telas e nos pacotes que já têm o Contas a pagar (inclusive o da Casa).
-- Rode DEPOIS de 20261010230000_pacotes_acesso.sql. Idempotente.
insert into acesso_telas (tela, modulo, nome, grupo, ordem)
values ('fin-custo', 'fin', 'Custo operacional', 'Financeiro', coalesce((select ordem from acesso_telas where tela = 'fin-pagar'), 0) + 1)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
update pacotes_acesso set telas = telas || array['fin-custo'] where telas @> array['fin-pagar'] and not telas @> array['fin-custo'];


-- ================================================================
-- >>> 20261011500000_margens_indicadores.sql
-- ================================================================
-- v0.94 — Margem de contribuição e margem de lucro líquida como indicadores do Planejamento
-- 1. plano_indicadores aceita as chaves 'margem_lucro' e 'margem_contribuicao' (valor calculado pela DRE do período).
-- 2. Indicadores já criados à mão com esses nomes passam a usar a chave (ex.: "Margem de lucro líquida", meta 30%).
-- 3. valor_indicador calcula as duas margens em % a partir de v_dre_mensal:
--    margem de contribuição = (receitas − deduções − custos) ÷ receitas
--    margem de lucro líquida = (receitas − deduções − custos − despesas) ÷ receitas
-- Rode DEPOIS de 20261011400000_custo_operacional.sql. Idempotente.

alter table plano_indicadores drop constraint if exists plano_indicadores_chave_check;
alter table plano_indicadores add constraint plano_indicadores_chave_check check (chave = any (array[
  'receita', 'mrr', 'leads', 'clientes', 'conversao', 'investimento', 'cac', 'ticket_medio', 'margem_lucro', 'margem_contribuicao']));

update plano_indicadores set chave = 'margem_lucro', unidade = 'pct' where chave is null and nome ilike 'margem de lucro%';
update plano_indicadores set chave = 'margem_contribuicao', unidade = 'pct' where chave is null and nome ilike 'margem de contribui%';

create or replace function public.valor_indicador(p_ws uuid, p_chave text, p_ini date, p_fim date)
 returns numeric language plpgsql stable security definer set search_path to 'public'
as $function$
declare v numeric; cli numeric; rec numeric; lds numeric; inv numeric; ded numeric; cus numeric; des numeric;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este workspace'; end if;
  select coalesce(sum(valor) filter (where tipo = 'receita'), 0), coalesce(sum(valor) filter (where tipo = 'deducao'), 0),
         coalesce(sum(valor) filter (where tipo = 'custo'), 0), coalesce(sum(valor) filter (where tipo = 'despesa'), 0)
    into rec, ded, cus, des
    from v_dre_mensal
   where workspace_id = p_ws and mes >= date_trunc('month', p_ini)::date and mes <= date_trunc('month', p_fim)::date;
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
    when 'margem_contribuicao' then case when rec > 0 then round(100.0 * (rec - ded - cus) / rec, 2) end
    when 'margem_lucro' then case when rec > 0 then round(100.0 * (rec - ded - cus - des) / rec, 2) end
  end;
  return v;
end $function$;

-- a tela de custos ganhou as margens: novo nome no catálogo de acesso
do $$ begin
  if to_regclass('public.acesso_telas') is not null then update acesso_telas set nome = 'Custos e margens' where tela = 'fin-custo'; end if;
end $$;


-- ================================================================
-- >>> 20261011600000_cenarios_indicadores.sql
-- ================================================================
-- v0.95 — Cenários ruim / bom / ótimo nos índices do Planejamento
-- A meta (valor_meta) é o cenário bom. faixa_ruim = abaixo da meta mas aceitável; faixa_otimo = acima da meta.
-- Usado na tela Financeiro → Custos e margens para a margem de lucro líquida (ruim, bom e ótimo definidos pela empresa).
-- Rode DEPOIS de 20261011500000_margens_indicadores.sql. Idempotente.
alter table plano_indicadores add column if not exists faixa_ruim numeric;
alter table plano_indicadores add column if not exists faixa_otimo numeric;
comment on column plano_indicadores.faixa_ruim is 'v0.95: cenário ruim (abaixo da meta, ainda aceitável). A meta é o cenário bom.';
comment on column plano_indicadores.faixa_otimo is 'v0.95: cenário ótimo (acima da meta).';


-- ================================================================
-- >>> 20261011700000_ofertas_esteira_campanha.sql
-- ================================================================
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


-- ================================================================
-- >>> 20261011800000_growth_model_cenarios.sql
-- ================================================================
-- v0.98 — Growth Now, fase B: cenários nomeados do Growth Model, baseline travado e auditoria
-- 1. gm_cenarios: cenário com nome, hipótese, autor, escopo (filtros e período), status (rascunho/aprovado/arquivado), versão, foto do baseline,
--    resultados projetados, premissas financeiras (regime, % variáveis, ajuste de custos fixos), ICE e os dados do Unit Economics (ue).
-- 2. gm_alavancas.cenario passa a aceitar o id do cenário; o antigo 'sim' de cada empresa vira o "Cenário 1".
-- 3. Baseline travado: o que está em cenario = 'base' são as "premissas do baseline"; só um administrador muda, pela função gm_premissas_salvar
--    (com motivo, registrado na auditoria). Cenário aprovado também fica congelado (para mudar, duplica).
-- 4. Cenários do Unit Economics (simulador_cenarios, se existir) viram cenários do Growth Model, com os dados em gm_cenarios.ue.
-- Rode DEPOIS de 20261011700000_ofertas_esteira_campanha.sql. Idempotente.

create table if not exists gm_cenarios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 120),
  hipotese text,
  autor uuid default auth.uid(),
  escopo jsonb not null default '{}'::jsonb check (jsonb_typeof(escopo) = 'object'),
  status text not null default 'rascunho' check (status in ('rascunho', 'aprovado', 'arquivado')),
  versao int not null default 1,
  substitui_id uuid references gm_cenarios(id) on delete set null,
  baseline jsonb,
  resultados jsonb,
  financeiro jsonb not null default '{}'::jsonb check (jsonb_typeof(financeiro) = 'object'),
  ue jsonb,
  impacto int check (impacto is null or impacto between 1 and 10),
  confianca int check (confianca is null or confianca between 1 and 10),
  facilidade int check (facilidade is null or facilidade between 1 and 10),
  ice_justificativa text,
  aprovado_em timestamptz,
  aprovado_por uuid,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists gm_cenarios_ws on gm_cenarios (workspace_id, status);
alter table gm_cenarios enable row level security;
drop policy if exists gm_cenarios_acesso on gm_cenarios;
create policy gm_cenarios_acesso on gm_cenarios for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on gm_cenarios;
create policy perm_ler on gm_cenarios as restrictive for select using (perm(workspace_id, 'ler', '{gro,adm,mkt}'::text[]));
drop policy if exists perm_escrever on gm_cenarios;
create policy perm_escrever on gm_cenarios as restrictive for all using (perm(workspace_id, 'editar', '{gro}'::text[])) with check (perm(workspace_id, 'editar', '{gro}'::text[]));

-- cenário aprovado é congelado: só pode ir para arquivado; arquivado só volta a rascunho se nunca foi aprovado
create or replace function public.gm_cenarios_guarda() returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'aprovado' or old.aprovado_em is not null then raise exception 'Cenário aprovado não pode ser excluído: arquive-o'; end if;
    return old;
  end if;
  if old.status = 'aprovado' or (old.aprovado_em is not null and old.status = 'arquivado') then
    if new.status = 'arquivado' and old.status = 'aprovado'
       and new.nome = old.nome and new.escopo = old.escopo and new.financeiro = old.financeiro and coalesce(new.ue, '{}') = coalesce(old.ue, '{}')
       and coalesce(new.resultados, '{}') = coalesce(old.resultados, '{}') and coalesce(new.baseline, '{}') = coalesce(old.baseline, '{}') then
      new.atualizado_em := now(); return new;
    end if;
    raise exception 'Cenário aprovado está congelado: duplique para criar uma nova versão';
  end if;
  new.atualizado_em := now();
  return new;
end $$;
drop trigger if exists gm_cenarios_guarda_t on gm_cenarios;
create trigger gm_cenarios_guarda_t before update or delete on gm_cenarios for each row execute function gm_cenarios_guarda();

-- alavancas: cenário = 'base' ou id do cenário
alter table gm_alavancas drop constraint if exists gm_alavancas_cenario_check;
do $$
declare w record; novo uuid;
begin
  for w in select distinct workspace_id from gm_alavancas where cenario = 'sim' loop
    insert into gm_cenarios (workspace_id, nome, hipotese, autor) values (w.workspace_id, 'Cenário 1', 'Cenário que já existia no Growth Model antes dos cenários nomeados.', null) returning id into novo;
    update gm_alavancas set cenario = novo::text where workspace_id = w.workspace_id and cenario = 'sim';
  end loop;
end $$;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'gm_alavancas_cenario_ok') then
    alter table gm_alavancas add constraint gm_alavancas_cenario_ok check (cenario = 'base' or cenario ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  end if;
end $$;

create or replace function public.gm_alavancas_guarda() returns trigger language plpgsql set search_path = public as $$
declare r gm_alavancas; st text;
begin
  r := case when tg_op = 'DELETE' then old else new end;
  if r.cenario = 'base' then
    if coalesce(current_setting('growths.gm_premissas', true), '') <> '1' then
      raise exception 'O baseline está travado. Premissas do baseline só mudam por um administrador, em "Premissas do baseline", com motivo.';
    end if;
  else
    select status into st from gm_cenarios where id = r.cenario::uuid;
    if st is null then raise exception 'Cenário não encontrado'; end if;
    if st <> 'rascunho' then raise exception 'Este cenário está %: duplique para criar uma nova versão', st; end if;
    if tg_op = 'UPDATE' and old.cenario <> new.cenario then raise exception 'Não dá para mover ajuste entre cenários'; end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists gm_alavancas_guarda_t on gm_alavancas;
create trigger gm_alavancas_guarda_t before insert or update or delete on gm_alavancas for each row execute function gm_alavancas_guarda();

-- premissas do baseline: só administrador, com motivo (fica na auditoria)
create or replace function public.gm_premissas_salvar(p_ws uuid, p_linhas jsonb, p_remover jsonb, p_motivo text)
returns int language plpgsql security definer set search_path = public as $$
declare n int := 0; e jsonb;
begin
  if not pertence_ao_workspace(p_ws) or not eh_admin(p_ws) then raise exception 'Só um administrador muda as premissas do baseline'; end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Diga o motivo da mudança na premissa do baseline'; end if;
  perform set_config('growths.gm_premissas', '1', true);
  perform set_config('growths.motivo', left(trim(p_motivo), 300), true);
  for e in select * from jsonb_array_elements(coalesce(p_remover, '[]'::jsonb)) loop
    delete from gm_alavancas where workspace_id = p_ws and cenario = 'base' and loop_chave = e ->> 'loop_chave' and alavanca = e ->> 'alavanca' and mes = (e ->> 'mes')::date
      and coalesce(produto_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(nullif(e ->> 'produto_id', '')::uuid, '00000000-0000-0000-0000-000000000000'::uuid);
    n := n + 1;
  end loop;
  for e in select * from jsonb_array_elements(coalesce(p_linhas, '[]'::jsonb)) loop
    delete from gm_alavancas where workspace_id = p_ws and cenario = 'base' and loop_chave = e ->> 'loop_chave' and alavanca = e ->> 'alavanca' and mes = (e ->> 'mes')::date
      and coalesce(produto_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(nullif(e ->> 'produto_id', '')::uuid, '00000000-0000-0000-0000-000000000000'::uuid);
    insert into gm_alavancas (workspace_id, loop_chave, produto_id, alavanca, mes, cenario, valor)
    values (p_ws, e ->> 'loop_chave', nullif(e ->> 'produto_id', '')::uuid, e ->> 'alavanca', (e ->> 'mes')::date, 'base', (e ->> 'valor')::numeric);
    n := n + 1;
  end loop;
  perform set_config('growths.gm_premissas', '', true);
  return n;
end $$;
revoke execute on function public.gm_premissas_salvar(uuid, jsonb, jsonb, text) from public, anon;
grant execute on function public.gm_premissas_salvar(uuid, jsonb, jsonb, text) to authenticated, service_role;

-- cenários do Unit Economics viram cenários do Growth Model (os dados do simulador ficam em gm_cenarios.ue)
do $$ begin
  if to_regclass('public.simulador_cenarios') is not null then
    insert into gm_cenarios (id, workspace_id, nome, hipotese, autor, status, ue, criado_em)
    select s.id, s.workspace_id, s.nome, 'Trazido do Unit Economics.', s.criado_por, case when s.status = 'arquivado' then 'arquivado' else 'rascunho' end, s.dados, s.criado_em
      from simulador_cenarios s where not exists (select 1 from gm_cenarios g where g.id = s.id);
  end if;
end $$;

-- as fotos do Unit Economics passam a apontar para o cenário do Growth Model
do $$ begin
  if to_regclass('public.simulador_snapshots') is not null then
    alter table simulador_snapshots drop constraint if exists simulador_snapshots_cenario_id_fkey;
    if not exists (select 1 from pg_constraint where conname = 'simulador_snapshots_gm_cenario_fk') then
      delete from simulador_snapshots s where not exists (select 1 from gm_cenarios g where g.id = s.cenario_id);
      alter table simulador_snapshots add constraint simulador_snapshots_gm_cenario_fk foreign key (cenario_id) references gm_cenarios(id) on delete cascade;
    end if;
  end if;
end $$;

-- auditoria
do $$
declare t text;
begin
  if to_regprocedure('public.auditar()') is not null then
    foreach t in array array['gm_alavancas', 'gm_cenarios'] loop
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end loop;
  end if;
end $$;


-- ================================================================
-- >>> 20261011900000_decisao_kanban.sql
-- ================================================================
-- v0.99 — Growth Now, fase C: ICE no cenário, aprovação com documento de decisão, Kanban em 7 colunas, ideia ligada ao cenário, experimento ou planejamento
-- 1. gm_decisoes: documento de decisão imutável (contexto, baseline, inputs, projeções, riscos, ICE, responsável, próximos passos).
-- 2. gm_aprovar(cenário, responsável, próximos passos, documento): só administrador; exige hipótese e ICE; congela o cenário e grava o documento.
-- 3. growth_experimentos: colunas novas do Kanban (avaliacao, preparacao, arquivado), vínculo único com o cenário (sem cards duplicados),
--    decisão, tipo (experimento ou planejamento), projeto, público, intervenção, instrumentação, custo previsto, métrica-alvo e justificativa do ICE.
-- 4. gm_ideia_do_cenario(cenário): cria ou devolve a ideia do cenário no Kanban. exp_para_planejamento(experimento): cria o projeto da iniciativa.
-- Rode DEPOIS de 20261011800000_growth_model_cenarios.sql. Idempotente.

create table if not exists gm_decisoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  cenario_id uuid not null references gm_cenarios(id) on delete restrict,
  versao int not null default 1,
  titulo text not null,
  documento jsonb not null check (jsonb_typeof(documento) = 'object'),
  responsavel text,
  proximos_passos text,
  aprovado_por uuid default auth.uid(),
  aprovado_por_email text,
  criado_em timestamptz not null default now()
);
create index if not exists gm_decisoes_cen on gm_decisoes (cenario_id);
alter table gm_decisoes enable row level security;
drop policy if exists gm_decisoes_acesso on gm_decisoes;
create policy gm_decisoes_acesso on gm_decisoes for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on gm_decisoes;
create policy perm_ler on gm_decisoes as restrictive for select using (perm(workspace_id, 'ler', '{gro,adm,mkt}'::text[]));
create or replace function public.gm_decisoes_imutavel() returns trigger language plpgsql as $$
begin raise exception 'Documento de decisão não muda: aprove uma nova versão do cenário'; end $$;
drop trigger if exists gm_decisoes_imutavel_t on gm_decisoes;
create trigger gm_decisoes_imutavel_t before update or delete on gm_decisoes for each row execute function gm_decisoes_imutavel();

create or replace function public.gm_aprovar(p_cenario uuid, p_responsavel text, p_proximos text, p_documento jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare c gm_cenarios; d uuid; doc jsonb; em text;
begin
  select * into c from gm_cenarios where id = p_cenario for update;
  if not found then raise exception 'Cenário não encontrado'; end if;
  if not pertence_ao_workspace(c.workspace_id) or not eh_admin(c.workspace_id) then raise exception 'Só um administrador aprova cenários'; end if;
  if c.status <> 'rascunho' then raise exception 'Só cenário em rascunho pode ser aprovado (este está %)', c.status; end if;
  if coalesce(trim(c.hipotese), '') = '' then raise exception 'Escreva a hipótese do cenário antes de aprovar'; end if;
  if c.impacto is null or c.confianca is null or c.facilidade is null then raise exception 'Preencha o ICE (impacto, confiança e facilidade) antes de aprovar'; end if;
  if coalesce(trim(p_responsavel), '') = '' then raise exception 'Diga quem é o responsável'; end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p_documento -> 'guardrails', '[]'::jsonb)) g where g ->> 'severidade' = 'critico' and g ->> 'situacao' = 'violado')
     and coalesce(trim(p_documento ->> 'justificativa_risco'), '') = '' then
    raise exception 'Há guardrail crítico violado na projeção: registre a justificativa do risco para aprovar'; end if;
  select email into em from auth.users where id = auth.uid();
  doc := coalesce(p_documento, '{}'::jsonb) || jsonb_build_object(
    'cenario', jsonb_build_object('id', c.id, 'nome', c.nome, 'versao', c.versao, 'hipotese', c.hipotese, 'escopo', c.escopo, 'financeiro', c.financeiro),
    'ice', jsonb_build_object('impacto', c.impacto, 'confianca', c.confianca, 'facilidade', c.facilidade, 'score', round((c.impacto + c.confianca + c.facilidade) / 3.0, 1), 'justificativa', c.ice_justificativa),
    'inputs_gravados', coalesce((select jsonb_agg(jsonb_build_object('loop', a.loop_chave, 'produto_id', a.produto_id, 'alavanca', a.alavanca, 'mes', a.mes, 'valor', a.valor) order by a.loop_chave, a.alavanca, a.mes)
                                 from gm_alavancas a where a.cenario = c.id::text), '[]'::jsonb),
    'responsavel', p_responsavel, 'proximos_passos', p_proximos, 'aprovado_em', now());
  update gm_cenarios set status = 'aprovado', aprovado_em = now(), aprovado_por = auth.uid() where id = c.id;
  insert into gm_decisoes (workspace_id, cenario_id, versao, titulo, documento, responsavel, proximos_passos, aprovado_por_email)
  values (c.workspace_id, c.id, c.versao, 'Decisão: ' || c.nome, doc, p_responsavel, p_proximos, em) returning id into d;
  return d;
end $$;
revoke execute on function public.gm_aprovar(uuid, text, text, jsonb) from public, anon;
grant execute on function public.gm_aprovar(uuid, text, text, jsonb) to authenticated, service_role;

-- Kanban
alter table growth_experimentos drop constraint if exists growth_experimentos_etapa_check;
alter table growth_experimentos add constraint growth_experimentos_etapa_check check (etapa in ('ideia', 'avaliacao', 'priorizado', 'preparacao', 'rodando', 'analise', 'concluido', 'arquivado'));
alter table growth_experimentos add column if not exists cenario_id uuid references gm_cenarios(id) on delete set null;
alter table growth_experimentos add column if not exists decisao_id uuid references gm_decisoes(id) on delete set null;
alter table growth_experimentos add column if not exists tipo text not null default 'experimento';
alter table growth_experimentos add column if not exists projeto_id uuid references projetos(id) on delete set null;
alter table growth_experimentos add column if not exists publico text;
alter table growth_experimentos add column if not exists intervencao text;
alter table growth_experimentos add column if not exists instrumentacao text;
alter table growth_experimentos add column if not exists custo_previsto numeric(12,2) check (custo_previsto is null or custo_previsto >= 0);
alter table growth_experimentos add column if not exists metrica_alvo text;
alter table growth_experimentos add column if not exists ice_justificativa text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'growth_experimentos_tipo_check') then
    alter table growth_experimentos add constraint growth_experimentos_tipo_check check (tipo in ('experimento', 'planejamento'));
  end if;
end $$;
create unique index if not exists growth_experimentos_cenario_uq on growth_experimentos (cenario_id) where cenario_id is not null;

create or replace function public.gm_ideia_do_cenario(p_cenario uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare c gm_cenarios; e uuid; d uuid;
begin
  select * into c from gm_cenarios where id = p_cenario;
  if not found then raise exception 'Cenário não encontrado'; end if;
  if not pertence_ao_workspace(c.workspace_id) or not perm(c.workspace_id, 'editar', '{gro}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  select id into e from growth_experimentos where cenario_id = c.id;
  if e is not null then return e; end if;
  select id into d from gm_decisoes where cenario_id = c.id order by criado_em desc limit 1;
  insert into growth_experimentos (workspace_id, titulo, hipotese, etapa, impacto, confianca, facilidade, ice_justificativa, cenario_id, decisao_id, insight)
  values (c.workspace_id, left(c.nome, 200), c.hipotese, case when c.status = 'aprovado' then 'priorizado' else 'ideia' end, c.impacto, c.confianca, c.facilidade, c.ice_justificativa, c.id, d,
          'Cenário do Growth Model: ' || c.nome || ' (v' || c.versao || ')')
  returning id into e;
  return e;
end $$;
revoke execute on function public.gm_ideia_do_cenario(uuid) from public, anon;
grant execute on function public.gm_ideia_do_cenario(uuid) to authenticated, service_role;

create or replace function public.exp_para_planejamento(p_exp uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare e growth_experimentos; p uuid;
begin
  select * into e from growth_experimentos where id = p_exp for update;
  if not found then raise exception 'Ideia não encontrada'; end if;
  if not pertence_ao_workspace(e.workspace_id) or not perm(e.workspace_id, 'editar', '{gro,prj}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if e.projeto_id is not null then return e.projeto_id; end if;
  insert into projetos (workspace_id, nome, descricao, data_inicio, data_fim_prevista)
  values (e.workspace_id, 'Iniciativa: ' || left(e.titulo, 180), coalesce(e.hipotese, '') || case when e.criterio_sucesso is not null then E'\nCritério de sucesso: ' || e.criterio_sucesso else '' end,
          coalesce(e.inicio, (now() at time zone 'America/Sao_Paulo')::date), e.fim_previsto)
  returning id into p;
  update growth_experimentos set projeto_id = p, tipo = 'planejamento', etapa = case when etapa in ('ideia', 'avaliacao', 'priorizado') then 'preparacao' else etapa end where id = e.id;
  return p;
end $$;
revoke execute on function public.exp_para_planejamento(uuid) from public, anon;
grant execute on function public.exp_para_planejamento(uuid) to authenticated, service_role;

do $$
declare t text;
begin
  if to_regprocedure('public.auditar()') is not null then
    foreach t in array array['growth_experimentos', 'gm_decisoes'] loop
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end loop;
  end if;
end $$;


-- ================================================================
-- >>> 20261012000000_guardrails.sql
-- ================================================================
-- v0.100 — Growth Now, fase D: guardrails projetados e monitorados, alertas, acompanhamento contínuo
-- 1. guardrail_definicoes: limite mínimo ou máximo de uma métrica (margem, lucro, ROAS, CAC mídia, CPL, mídia, receita, vendas, leads, conversão, ticket),
--    severidade (atenção ou crítico), escopo, produto, janela de leitura, frequência, ação sugerida e se segue no acompanhamento contínuo.
-- 2. exp_guardrails: quais guardrails cada teste monitora. Quando um card entra em "Em teste", liga sozinho os guardrails ativos (do produto do cenário ou gerais).
-- 3. guardrail_observacoes (antes/durante/depois/contínuo, por dia) e guardrail_alertas (um aberto por teste e guardrail; reconhecer e resolver com nota).
--    Nada é pausado automaticamente: o alerta só sugere a ação.
-- 4. Telas Growth → Guardrails e Growth → Resultados e aprendizados no catálogo de acesso.
-- Rode DEPOIS de 20261011900000_decisao_kanban.sql. Idempotente.

create table if not exists guardrail_definicoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 120),
  metrica text not null check (metrica in ('margem', 'lucro', 'roas', 'cac_midia', 'cpl', 'midia', 'receita', 'vendas', 'leads', 'conv', 'ticket')),
  operador text not null check (operador in ('min', 'max')),
  limite numeric not null,
  severidade text not null default 'atencao' check (severidade in ('atencao', 'critico')),
  escopo text not null default 'negocio' check (escopo in ('negocio', 'recorte')),
  produto_id uuid references produtos(id) on delete set null,
  janela_dias int not null default 14 check (janela_dias between 1 and 180),
  frequencia text not null default 'semanal' check (frequencia in ('diaria', 'semanal')),
  acao_sugerida text,
  descricao text,
  continuo boolean not null default false,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists exp_guardrails (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  experimento_id uuid not null references growth_experimentos(id) on delete cascade,
  guardrail_id uuid not null references guardrail_definicoes(id) on delete cascade,
  ativado_em timestamptz not null default now(),
  unique (experimento_id, guardrail_id)
);
create table if not exists guardrail_observacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  experimento_id uuid references growth_experimentos(id) on delete cascade,
  guardrail_id uuid not null references guardrail_definicoes(id) on delete cascade,
  data date not null,
  periodo text not null check (periodo in ('antes', 'durante', 'depois', 'continuo')),
  janela_ini date, janela_fim date,
  valor numeric,
  limite numeric not null,
  situacao text not null check (situacao in ('ok', 'atencao', 'violado', 'sem_dado')),
  criado_em timestamptz not null default now()
);
create unique index if not exists guardrail_observacoes_uq on guardrail_observacoes (coalesce(experimento_id, '00000000-0000-0000-0000-000000000000'::uuid), guardrail_id, data, periodo);
create table if not exists guardrail_alertas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  experimento_id uuid references growth_experimentos(id) on delete cascade,
  guardrail_id uuid not null references guardrail_definicoes(id) on delete cascade,
  data date not null,
  valor numeric,
  limite numeric not null,
  severidade text not null check (severidade in ('atencao', 'critico')),
  mensagem text not null,
  acao_sugerida text,
  status text not null default 'aberto' check (status in ('aberto', 'reconhecido', 'resolvido')),
  responsavel text,
  nota text,
  criado_em timestamptz not null default now(),
  resolvido_em timestamptz
);
create unique index if not exists guardrail_alertas_aberto_uq on guardrail_alertas (coalesce(experimento_id, '00000000-0000-0000-0000-000000000000'::uuid), guardrail_id) where status <> 'resolvido';

do $r$
declare t text;
begin
  foreach t in array array['guardrail_definicoes', 'exp_guardrails', 'guardrail_observacoes', 'guardrail_alertas'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_acesso', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format('drop policy if exists perm_ler on %I', t);
    execute format('create policy perm_ler on %I as restrictive for select using (perm(workspace_id, ''ler'', array[''gro'',''adm'',''mkt'']))', t);
    execute format('drop policy if exists perm_escrever on %I', t);
    execute format('create policy perm_escrever on %I as restrictive for all using (perm(workspace_id, ''editar'', array[''gro'',''mkt''])) with check (perm(workspace_id, ''editar'', array[''gro'',''mkt'']))', t);
  end loop;
end
$r$;

-- teste que entra em "Em teste" passa a monitorar os guardrails ativos (gerais ou do produto do cenário de origem)
create or replace function public.exp_liga_guardrails() returns trigger language plpgsql security definer set search_path = public as $$
declare prod uuid;
begin
  if new.etapa = 'rodando' and (tg_op = 'INSERT' or old.etapa is distinct from 'rodando')
     and not exists (select 1 from exp_guardrails where experimento_id = new.id) then
    if new.cenario_id is not null then select nullif(escopo ->> 'prod', '')::uuid into prod from gm_cenarios where id = new.cenario_id; end if;
    insert into exp_guardrails (workspace_id, experimento_id, guardrail_id)
    select new.workspace_id, new.id, g.id from guardrail_definicoes g
     where g.workspace_id = new.workspace_id and g.ativo and (g.produto_id is null or g.produto_id = prod)
    on conflict (experimento_id, guardrail_id) do nothing;
  end if;
  return null;
end $$;
drop trigger if exists exp_liga_guardrails_t on growth_experimentos;
create trigger exp_liga_guardrails_t after insert or update of etapa on growth_experimentos for each row execute function exp_liga_guardrails();

do $$
declare t text;
begin
  if to_regprocedure('public.auditar()') is not null then
    foreach t in array array['guardrail_definicoes', 'guardrail_alertas'] loop
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end loop;
  end if;
  if to_regclass('public.acesso_telas') is not null then
    insert into acesso_telas (tela, modulo, nome, grupo, ordem) values
      ('gro-guard', 'gro', 'Guardrails', 'Growth', coalesce((select max(ordem) from acesso_telas where grupo = 'Growth'), 60) + 1),
      ('gro-result', 'gro', 'Resultados e aprendizados', 'Growth', coalesce((select max(ordem) from acesso_telas where grupo = 'Growth'), 60) + 2)
    on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
    update pacotes_acesso set telas = telas || array['gro-guard', 'gro-result'] where telas @> array['gro-ciclo'] and not telas @> array['gro-guard'];
  end if;
end $$;


-- ================================================================
-- >>> 20261012100000_revops_retencao.sql
-- ================================================================
-- v0.105 — RevOps → Retenção & Expansão: coortes, recompra e RFM a partir das compras que já existem (vendas e contratos)
-- Nada duplicado: lê vendas, contratos, contrato_itens, contas_receber, pessoas, produtos e campanhas.
-- 1. produtos.categoria (texto livre) para filtrar por categoria.
-- 2. Funções de base (regra única para todas as telas):
--    revops_itens     → cada produto comprado em uma compra válida (venda aprovada sem reembolso/cancelamento; contrato não cancelado ou com parcela recebida)
--    revops_pedidos   → itens agrupados em pedidos por cliente (mesmo dia = um pedido, ou por pedido_ref, conforme revops_config.simultanea) e numerados (1ª, 2ª, 3ª...)
--    revops_receitas  → receita de cada pedido no tempo: venda aprovada pelo líquido na data da venda; contrato pelas parcelas não canceladas com vencimento (ou recebimento) até hoje
--                       custo do produto (Custos e margens: % da receita + valor por pedido) só quando cadastrado; sem custo, a margem fica indisponível (nunca inventada)
--    revops_clientes  → um registro por cliente com primeira e segunda compra, produtos de entrada, origem e campanha, já com os filtros
--    revops_rfm_clientes → notas R, F e M (1 a 5) e segmento numa data de referência
-- 3. Telas: revops_coortes, revops_recompra, revops_rfm, revops_clientes_de (lista para investigar).
-- 4. revops_config (regra de compras simultâneas, notas e segmentos do RFM) e revops_visoes (filtros salvos por pessoa).
-- 5. Tela ho-retencao no catálogo de acesso, no lugar de Cohorts e Ascensão da escada.
-- Todas as funções rodam com as permissões de quem consulta (RLS das tabelas de origem).
-- Rode DEPOIS de 20261012000000_guardrails.sql. Idempotente.

alter table produtos add column if not exists categoria text;

create table if not exists revops_config (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  simultanea text not null default 'dia' check (simultanea in ('dia', 'pedido')),
  rfm jsonb not null default '{}'::jsonb check (jsonb_typeof(rfm) = 'object'),
  atualizado_em timestamptz not null default now()
);
create table if not exists revops_visoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  usuario_id uuid not null default auth.uid(),
  nome text not null check (char_length(nome) between 1 and 80),
  aba text not null default 'coortes' check (aba in ('coortes', 'recompra', 'rfm')),
  filtros jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
alter table revops_config enable row level security;
alter table revops_visoes enable row level security;
drop policy if exists revops_config_acesso on revops_config;
create policy revops_config_acesso on revops_config for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on revops_config;
create policy perm_ler on revops_config as restrictive for select using (perm(workspace_id, 'ler', array['revops', 'adm']));
drop policy if exists perm_escrever on revops_config;
create policy perm_escrever on revops_config as restrictive for all using (perm(workspace_id, 'editar', array['revops'])) with check (perm(workspace_id, 'editar', array['revops']));
drop policy if exists revops_visoes_acesso on revops_visoes;
create policy revops_visoes_acesso on revops_visoes for all to authenticated using (pertence_ao_workspace(workspace_id) and usuario_id = auth.uid()) with check (pertence_ao_workspace(workspace_id) and usuario_id = auth.uid());

-- ---------- base ----------
create or replace function public.revops_itens(p_ws uuid)
returns table (pessoa_id uuid, dia date, fonte text, ref uuid, produto_id uuid, campanha_id uuid, pedido_ref text)
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  select v.pessoa_id, (coalesce(v.aprovada_em, v.data_venda) at time zone 'America/Sao_Paulo')::date, 'venda', v.id, v.produto_id, v.campanha_id, v.pedido_ref
    from vendas v
   where v.workspace_id = p_ws and v.pessoa_id is not null and v.status = 'aprovada' and v.reembolsada_em is null and v.cancelada_em is null
  union all
  select c.pessoa_id, coalesce(c.data_inicio, (c.ativado_em at time zone 'America/Sao_Paulo')::date, (c.criado_em at time zone 'America/Sao_Paulo')::date), 'contrato', c.id,
         i.produto_id, c.campanha_id, null
    from contratos c left join contrato_itens i on i.contrato_id = c.id
   where c.workspace_id = p_ws and c.pessoa_id is not null
     and (c.status <> 'cancelado' or exists (select 1 from contas_receber r where r.contrato_id = c.id and r.status = 'recebido'))
$$;

create or replace function public.revops_pedidos(p_ws uuid)
returns table (pessoa_id uuid, ord int, dia date, produtos uuid[], campanhas uuid[], fontes text[], refs uuid[])
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  with cfg as (select coalesce((select simultanea from revops_config where workspace_id = p_ws), 'dia') as sim),
  it as (
    select i.*, case when (select sim from cfg) = 'dia' then i.dia::text else coalesce(i.pedido_ref, i.fonte || ':' || i.ref::text) end as chave
      from revops_itens(p_ws) i
  ), g as (
    select it.pessoa_id, it.chave, min(it.dia) as dia,
           array_agg(distinct it.produto_id) filter (where it.produto_id is not null) as produtos,
           array_agg(distinct it.campanha_id) filter (where it.campanha_id is not null) as campanhas,
           array_agg(distinct it.fonte) as fontes, array_agg(distinct it.ref) as refs
      from it group by it.pessoa_id, it.chave
  )
  select g.pessoa_id, (row_number() over (partition by g.pessoa_id order by g.dia, g.chave))::int, g.dia,
         coalesce(g.produtos, '{}'), coalesce(g.campanhas, '{}'), g.fontes, g.refs
    from g
$$;

create or replace function public.revops_receitas(p_ws uuid)
returns table (pessoa_id uuid, ord int, dia_pedido date, dia date, produto_id uuid, valor numeric, custo numeric, fonte text)
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  with p as (select * from revops_pedidos(p_ws)),
  ref as (select p.pessoa_id, p.ord, p.dia, unnest(p.refs) as r from p),
  ev as (
    select v.pessoa_id, v.id as r, (coalesce(v.aprovada_em, v.data_venda) at time zone 'America/Sao_Paulo')::date as dia, v.produto_id,
           coalesce(v.valor_liquido, coalesce(v.valor_bruto, 0) - coalesce(v.taxa_plataforma, 0) - coalesce(v.impostos, 0)) as valor, 'venda' as fonte, 1 as n_prod
      from vendas v
     where v.workspace_id = p_ws and v.pessoa_id is not null and v.status = 'aprovada' and v.reembolsada_em is null and v.cancelada_em is null
    union all
    select c.pessoa_id, c.id, coalesce(r.data_recebimento, r.vencimento), i.produto_id,
           (r.valor - coalesce(r.desconto, 0)) * case when it.tot > 0 then coalesce(i.valor, 0) * coalesce(i.quantidade, 1) / it.tot when it.n > 0 then 1.0 / it.n else 1 end,
           'contrato', 1
      from contratos c
      join contas_receber r on r.contrato_id = c.id and r.venda_id is null and r.status not in ('cancelado', 'estornado') and r.substituida_por is null
           and coalesce(r.data_recebimento, r.vencimento) <= (now() at time zone 'America/Sao_Paulo')::date
      left join lateral (select sum(coalesce(x.valor, 0) * coalesce(x.quantidade, 1)) as tot, count(*) as n from contrato_itens x where x.contrato_id = c.id) it on true
      left join contrato_itens i on i.contrato_id = c.id
     where c.workspace_id = p_ws and c.pessoa_id is not null
  )
  select e.pessoa_id, rf.ord, rf.dia, e.dia, e.produto_id, round(e.valor, 2),
         case when pr.id is null or not (pr.extras ? 'mc_custo_pct' or pr.extras ? 'mc_custo_cliente') then null
              else round(e.valor * coalesce(nullif(pr.extras ->> 'mc_custo_pct', '')::numeric, 0) / 100
                   + case when row_number() over (partition by e.pessoa_id, rf.ord, e.produto_id order by e.dia) = 1 then coalesce(nullif(pr.extras ->> 'mc_custo_cliente', '')::numeric, 0) else 0 end, 2) end,
         e.fonte
    from ev e join ref rf on rf.pessoa_id = e.pessoa_id and rf.r = e.r
    left join produtos pr on pr.id = e.produto_id
$$;

-- ---------- RFM ----------
create or replace function public.revops_rfm_padrao() returns jsonb language sql immutable as $$
  select jsonb_build_object('metodo', 'quintis', 'janela_dias', 365,
    'limites', jsonb_build_object('r', jsonb_build_array(30, 90, 180, 365), 'f', jsonb_build_array(1, 2, 3, 5), 'm', jsonb_build_array(500, 1500, 4000, 10000)),
    'segmentos', jsonb_build_array(
      jsonb_build_object('nome', 'Campeões', 'r', jsonb_build_array(4, 5), 'f', jsonb_build_array(4, 5)),
      jsonb_build_object('nome', 'Clientes leais', 'r', jsonb_build_array(3, 5), 'f', jsonb_build_array(3, 5)),
      jsonb_build_object('nome', 'Novos clientes', 'r', jsonb_build_array(4, 5), 'f', jsonb_build_array(1, 1)),
      jsonb_build_object('nome', 'Potenciais leais', 'r', jsonb_build_array(4, 5), 'f', jsonb_build_array(2, 3)),
      jsonb_build_object('nome', 'Precisam de atenção', 'r', jsonb_build_array(3, 3), 'f', jsonb_build_array(1, 2)),
      jsonb_build_object('nome', 'Em risco', 'r', jsonb_build_array(1, 2), 'f', jsonb_build_array(3, 5)),
      jsonb_build_object('nome', 'Hibernando', 'r', jsonb_build_array(1, 2), 'f', jsonb_build_array(1, 2))))
$$;

/* notas numa data de referência. Recência: dias desde a última compra válida até a referência. Frequência: pedidos na janela (referência − janela_dias, referência].
   Valor: receita na janela. Quintis: nota pela posição (empates ficam juntos); limites: 4 cortes crescentes. Segmento: a primeira regra que bate, na ordem; senão "Outros". */
create or replace function public.revops_rfm_clientes(p_ws uuid, p_ref date default null, p_cfg jsonb default null)
returns table (pessoa_id uuid, ultima date, dias int, f int, m numeric, sr int, sf int, sm int, segmento text)
language plpgsql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
#variable_conflict use_column
declare cfg jsonb; ref date := coalesce(p_ref, (now() at time zone 'America/Sao_Paulo')::date); jan int; met text; lr jsonb; lf jsonb; lm jsonb;
begin
  cfg := revops_rfm_padrao() || coalesce((select rfm from revops_config where workspace_id = p_ws), '{}'::jsonb) || coalesce(p_cfg, '{}'::jsonb);
  jan := greatest(30, coalesce((cfg ->> 'janela_dias')::int, 365)); met := coalesce(cfg ->> 'metodo', 'quintis');
  lr := cfg -> 'limites' -> 'r'; lf := cfg -> 'limites' -> 'f'; lm := cfg -> 'limites' -> 'm';
  return query
  with p as (select * from revops_pedidos(p_ws) x where x.dia <= ref),
  rc as (select * from revops_receitas(p_ws) x where x.dia <= ref and x.dia > ref - jan),
  rm as (select rc.pessoa_id, sum(rc.valor) as m from rc group by rc.pessoa_id),
  b as (
    select pp.pessoa_id, pp.ultima, pp.dias, pp.f, coalesce(rm.m, 0) as m
      from (select p.pessoa_id, max(p.dia) as ultima, (ref - max(p.dia))::int as dias, (count(*) filter (where p.dia > ref - jan))::int as f from p group by p.pessoa_id) pp
      left join rm on rm.pessoa_id = pp.pessoa_id
  ), s as (
    select b.*,
      case when met = 'quintis' then 5 - least(4, floor(percent_rank() over (order by b.dias) * 5))::int
           else case when b.dias <= (lr ->> 0)::numeric then 5 when b.dias <= (lr ->> 1)::numeric then 4 when b.dias <= (lr ->> 2)::numeric then 3 when b.dias <= (lr ->> 3)::numeric then 2 else 1 end end as sr,
      case when met = 'quintis' then 1 + least(4, floor(percent_rank() over (order by b.f) * 5))::int
           else case when b.f <= (lf ->> 0)::numeric then 1 when b.f <= (lf ->> 1)::numeric then 2 when b.f <= (lf ->> 2)::numeric then 3 when b.f <= (lf ->> 3)::numeric then 4 else 5 end end as sf,
      case when met = 'quintis' then 1 + least(4, floor(percent_rank() over (order by b.m) * 5))::int
           else case when b.m <= (lm ->> 0)::numeric then 1 when b.m <= (lm ->> 1)::numeric then 2 when b.m <= (lm ->> 2)::numeric then 3 when b.m <= (lm ->> 3)::numeric then 4 else 5 end end as sm
    from b
  )
  select s.pessoa_id, s.ultima, s.dias, s.f, round(s.m, 2), s.sr, s.sf, s.sm,
    coalesce((select g ->> 'nome' from jsonb_array_elements(cfg -> 'segmentos') with ordinality as t(g, o)
              where s.sr between coalesce((g -> 'r' ->> 0)::int, 1) and coalesce((g -> 'r' ->> 1)::int, 5)
                and s.sf between coalesce((g -> 'f' ->> 0)::int, 1) and coalesce((g -> 'f' ->> 1)::int, 5)
                and s.sm between coalesce((g -> 'm' ->> 0)::int, 1) and coalesce((g -> 'm' ->> 1)::int, 5)
              order by o limit 1), 'Outros')
    from s;
end $$;

/* filtros (p_f): ini, fim (primeira compra), produto e categoria (produto de entrada), canal (pessoas.canal_origem), origem (pessoas.utm_source),
   campanha (da pessoa ou da primeira compra), segmento (RFM na data de hoje) */
create or replace function public.revops_clientes(p_ws uuid, p_f jsonb default '{}')
returns table (pessoa_id uuid, primeira date, segunda date, ultima date, n int, entrada uuid[], canal text, origem text, campanha uuid)
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  with p as (select * from revops_pedidos(p_ws)),
  c as (
    select g.*, p1.produtos as entrada, p1.campanhas as camp1
      from (select p.pessoa_id, min(p.dia) filter (where p.ord = 1) as primeira, min(p.dia) filter (where p.ord = 2) as segunda, max(p.dia) as ultima, count(*)::int as n
              from p group by p.pessoa_id) g
      join p p1 on p1.pessoa_id = g.pessoa_id and p1.ord = 1
  )
  select c.pessoa_id, c.primeira, c.segunda, c.ultima, c.n, c.entrada, coalesce(nullif(pe.canal_origem, ''), '(sem origem)'), coalesce(nullif(pe.utm_source, ''), '(sem utm_source)'),
         coalesce(pe.campanha_id, c.camp1[1])
    from c join pessoas pe on pe.id = c.pessoa_id
   where (nullif(p_f ->> 'ini', '') is null or c.primeira >= (p_f ->> 'ini')::date)
     and (nullif(p_f ->> 'fim', '') is null or c.primeira <= (p_f ->> 'fim')::date)
     and (nullif(p_f ->> 'produto', '') is null or (p_f ->> 'produto')::uuid = any (c.entrada))
     and (nullif(p_f ->> 'categoria', '') is null or exists (select 1 from produtos x where x.id = any (c.entrada) and x.categoria = p_f ->> 'categoria'))
     and (nullif(p_f ->> 'canal', '') is null or coalesce(nullif(pe.canal_origem, ''), '(sem origem)') = p_f ->> 'canal')
     and (nullif(p_f ->> 'origem', '') is null or coalesce(nullif(pe.utm_source, ''), '(sem utm_source)') = p_f ->> 'origem')
     and (nullif(p_f ->> 'campanha', '') is null or coalesce(pe.campanha_id, c.camp1[1]) = (p_f ->> 'campanha')::uuid)
     and (nullif(p_f ->> 'segmento', '') is null or c.pessoa_id in (select s.pessoa_id from revops_rfm_clientes(p_ws, null, null) s where s.segmento = p_f ->> 'segmento'))
$$;

-- ---------- coortes ----------
create or replace function public.revops_coortes(p_ws uuid, p_f jsonb default '{}', p_gran text default 'mes', p_agrupar text default 'periodo', p_hz int default 12)
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date; gran text := case when p_gran in ('trimestre', 'ano') then p_gran else 'mes' end;
  passo int := case gran when 'trimestre' then 3 when 'ano' then 12 else 1 end; hz int := least(greatest(coalesce(p_hz, 12), 3), 36); r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with cl as materialized (select * from revops_clientes(p_ws, p_f)),
  m as materialized (
    select cl.*, case when p_agrupar = 'produto' then e.pid::text
                      else to_char(date_trunc(case gran when 'trimestre' then 'quarter' when 'ano' then 'year' else 'month' end, cl.primeira), 'YYYY-MM-DD') end as gk,
           (cl.segunda - cl.primeira) as d2,
           case when cl.segunda is not null then ((date_part('year', age(cl.segunda, cl.primeira)) * 12 + date_part('month', age(cl.segunda, cl.primeira)))::int / passo) end as k2
      from cl left join lateral (select unnest(case when p_agrupar = 'produto' then coalesce(nullif(cl.entrada, '{}'), array[null::uuid]) else array[null::uuid] end) as pid) e on true
  ),
  mt as materialized (select distinct cl.pessoa_id, cl.primeira, cl.segunda - cl.primeira as d2, cl.n from cl),
  rc as materialized (select x.* from revops_receitas(p_ws) x join cl on cl.pessoa_id = x.pessoa_id),
  rcm as (select m.gk, rc.valor, rc.custo, rc.ord, ((date_part('year', age(rc.dia, m.primeira)) * 12 + date_part('month', age(rc.dia, m.primeira)))::int / passo) as k
            from m join rc on rc.pessoa_id = m.pessoa_id),
  ped as (select distinct m.gk, m.pessoa_id, ((date_part('year', age(p.dia, m.primeira)) * 12 + date_part('month', age(p.dia, m.primeira)))::int / passo) as k
            from m join revops_pedidos(p_ws) p on p.pessoa_id = m.pessoa_id),
  g as materialized (
    select m.gk, count(*) as n, min(m.primeira) as ini, max(m.primeira) as fim,
      count(*) filter (where m.d2 is not null) as rec, count(*) filter (where m.n >= 2) as dois,
      round(avg(m.d2) filter (where m.d2 is not null), 1) as d2_media, percentile_cont(0.5) within group (order by m.d2) filter (where m.d2 is not null) as d2_mediana
      from m group by m.gk
  ),
  hzs as (select unnest(array[30, 60, 90, 180, 365]) as h),
  dias as (select generate_series(0, 365, 5) as d),
  ks as (select generate_series(0, hz) as k),
  taxa as (
    select m.gk, h.h, count(*) filter (where hoje - m.primeira >= h.h) as el, count(*) filter (where hoje - m.primeira >= h.h and m.d2 <= h.h) as sim, count(*) as n
      from m cross join hzs h group by m.gk, h.h
  ),
  curva as (
    select m.gk, d.d, count(*) filter (where m.d2 <= d.d) as sim from m cross join dias d group by m.gk, d.d
  ),
  rcg as (select rcm.gk, sum(rcm.valor) as rec, sum(rcm.valor) filter (where rcm.ord > 1) as exist, sum(rcm.valor - rcm.custo) filter (where rcm.custo is not null) as mc,
                 sum(rcm.valor) filter (where rcm.custo is not null) as com_custo from rcm group by rcm.gk),
  mk as (
    select m.gk, ks.k, count(*) filter (where (m.primeira + make_interval(months => ks.k * passo))::date <= hoje) as el,
           count(*) filter (where m.k2 is not null and m.k2 <= ks.k) as rec
      from m cross join ks group by m.gk, ks.k
  ),
  rk as (select gk, k, sum(valor) as v from rcm group by gk, k),
  ak as (select gk, k, count(*) as a from ped group by gk, k),
  mat as (
    select g.gk, mk.k, (g.fim + make_interval(months => (mk.k + 1) * passo))::date <= hoje as completo, mk.el, mk.rec,
           coalesce(sum(rk.v) over (partition by g.gk order by mk.k), 0) as receita, coalesce(ak.a, 0) as ativos, g.n
      from g join mk on mk.gk is not distinct from g.gk
      left join rk on rk.gk is not distinct from g.gk and rk.k = mk.k
      left join ak on ak.gk is not distinct from g.gk and ak.k = mk.k
  ),
  tt as (select h.h, count(*) filter (where hoje - z.primeira >= h.h) as el, count(*) filter (where hoje - z.primeira >= h.h and z.d2 <= h.h) as sim, count(*) as n
           from mt z cross join hzs h group by h.h),
  -- curva de todas as coortes juntas: em cada dia, entre os clientes que já têm aquele tempo de observação
  tc as (select d.d, count(*) filter (where hoje - z.primeira >= d.d) as n, count(*) filter (where hoje - z.primeira >= d.d and z.d2 <= d.d) as sim from mt z cross join dias d group by d.d)
  select jsonb_build_object(
    'gran', gran, 'agrupar', p_agrupar, 'hz', hz, 'hoje', hoje,
    'total', jsonb_build_object(
      'clientes', (select count(*) from mt), 'recompraram', (select count(*) from mt where d2 is not null), 'dois_mais', (select count(*) from mt where n >= 2),
      'd2_media', (select round(avg(d2), 1) from mt where d2 is not null), 'd2_mediana', (select percentile_cont(0.5) within group (order by d2) from mt where d2 is not null),
      'receita', (select coalesce(sum(valor), 0) from rc), 'receita_exist', (select coalesce(sum(valor), 0) from rc where ord > 1),
      'mc', (select sum(valor - custo) from rc where custo is not null), 'com_custo', (select coalesce(sum(valor), 0) from rc where custo is not null),
      'taxas', (select coalesce(jsonb_agg(jsonb_build_object('h', h, 'el', el, 'sim', sim, 'n', n, 'taxa', case when el = n and n > 0 then round(sim::numeric / n * 100, 1) end,
                  'parcial', case when el > 0 then round(sim::numeric / el * 100, 1) end) order by h), '[]') from tt),
      'curva', (select coalesce(jsonb_agg(jsonb_build_object('d', d, 'n', n, 'sim', sim, 'pct', case when n > 0 and sim is not null then round(sim::numeric / n * 100, 1) end) order by d), '[]') from tc)),
    'coortes', coalesce((select jsonb_agg(jsonb_build_object(
        'gk', g.gk, 'rotulo', case when p_agrupar = 'produto' then coalesce((select nome from produtos where id::text = g.gk), '(sem produto)') else g.gk end,
        'n', g.n, 'ini', g.ini, 'fim', g.fim, 'obs_dias', hoje - g.fim, 'recompraram', g.rec, 'dois_mais', g.dois, 'd2_media', g.d2_media, 'd2_mediana', g.d2_mediana,
        'receita', coalesce(rcg.rec, 0), 'receita_cli', round(coalesce(rcg.rec, 0) / g.n, 2), 'receita_exist', coalesce(rcg.exist, 0),
        'mc', rcg.mc, 'com_custo', coalesce(rcg.com_custo, 0),
        'taxas', (select jsonb_agg(jsonb_build_object('h', t.h, 'el', t.el, 'sim', t.sim, 'taxa', case when t.el = t.n then round(t.sim::numeric / t.n * 100, 1) end,
                    'parcial', case when t.el > 0 then round(t.sim::numeric / t.el * 100, 1) end) order by t.h) from taxa t where t.gk is not distinct from g.gk),
        'curva', (select jsonb_agg(jsonb_build_object('d', c.d, 'sim', case when hoje - g.fim >= c.d then c.sim end,
                    'pct', case when hoje - g.fim >= c.d then round(c.sim::numeric / g.n * 100, 1) end) order by c.d) from curva c where c.gk is not distinct from g.gk),
        'matriz', (select jsonb_agg(jsonb_build_object('k', x.k, 'completo', x.completo, 'el', x.el,
                    'recompra', round(x.rec::numeric / x.n * 100, 1), 'receita_cli', round(x.receita / x.n, 2), 'ativos', round(x.ativos::numeric / x.n * 100, 1)) order by x.k)
                   from mat x where x.gk is not distinct from g.gk and x.el > 0)
      ) order by case when p_agrupar = 'produto' then lpad((1000000 - g.n)::text, 8, '0') else g.gk end) from g left join rcg on rcg.gk is not distinct from g.gk), '[]')
  ) into r;
  return r;
end $$;

-- ---------- recompra ----------
create or replace function public.revops_recompra(p_ws uuid, p_f jsonb default '{}')
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date; r jsonb;
  ini date := coalesce(nullif(p_f ->> 'ini', '')::date, (date_trunc('month', hoje) - interval '11 months')::date); fim date := coalesce(nullif(p_f ->> 'fim', '')::date, hoje);
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with cl as materialized (select * from revops_clientes(p_ws, p_f)),
  -- para novos × existentes vale o mesmo filtro, menos a data da primeira compra (a janela é a das receitas)
  cl_todos as (select * from revops_clientes(p_ws, p_f - 'ini' - 'fim')),
  p as materialized (select x.* from revops_pedidos(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rc as materialized (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rcj as (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from cl_todos) and x.dia between ini and fim),
  rco as (select pessoa_id, ord, sum(valor) as v from rc group by 1, 2),
  rpos as (select pessoa_id, sum(valor) as v from rc where ord >= 2 group by 1),
  pv as (select p.*, rco.v as receita from p left join rco on rco.pessoa_id = p.pessoa_id and rco.ord = p.ord),
  inter as (select (p.dia - lag(p.dia) over (partition by p.pessoa_id order by p.ord)) as d from p),
  d2 as (select cl.pessoa_id, cl.segunda - cl.primeira as d from cl where cl.segunda is not null),
  ent as (select cl.pessoa_id, unnest(coalesce(nullif(cl.entrada, '{}'), array[null::uuid])) as de from cl),
  depois as (select distinct p.pessoa_id, unnest(p.produtos) as para from p where p.ord >= 2),
  seg as (select distinct p.pessoa_id, unnest(p.produtos) as prod from p where p.ord = 2)
  select jsonb_build_object('ini', ini, 'fim', fim,
    'kpi', jsonb_build_object(
      'primeira', (select count(*) from cl), 'segunda', (select count(*) from cl where segunda is not null),
      'intervalo_media', (select round(avg(d), 1) from inter where d is not null), 'intervalo_mediana', (select percentile_cont(0.5) within group (order by d) from inter where d is not null),
      'frequencia', (select round(avg(n), 2) from cl), 'pedidos_recompra', (select count(*) from pv where ord >= 2),
      'receita_recompra', (select coalesce(sum(receita), 0) from pv where ord >= 2),
      'receita_2', (select coalesce(sum(valor), 0) from rc where ord = 2), 'receita_3mais', (select coalesce(sum(valor), 0) from rc where ord >= 3),
      'mc_recorrente', (select sum(valor - custo) from rc where ord >= 2 and custo is not null), 'com_custo_recorrente', (select coalesce(sum(valor), 0) from rc where ord >= 2 and custo is not null),
      'receita_recorrente', (select coalesce(sum(valor), 0) from rc where ord >= 2)),
    'curva', (select coalesce(jsonb_agg(jsonb_build_object('d', d.d, 'n', z.n, 'sim', z.sim, 'pct', case when z.n > 0 then round(z.sim::numeric / z.n * 100, 1) end) order by d.d), '[]')
              from generate_series(0, 365, 5) d(d) cross join lateral (select count(*) filter (where hoje - cl.primeira >= d.d) as n,
                    count(*) filter (where hoje - cl.primeira >= d.d and cl.segunda - cl.primeira <= d.d) as sim from cl) z),
    'distribuicao', (select coalesce(jsonb_agg(jsonb_build_object('faixa', f.rot, 'min', f.a, 'max', f.b, 'n', (select count(*) from d2 where d2.d between f.a and f.b))
                     order by f.o), '[]')
                     from (values (1, 'Até 7 dias', 0, 7), (2, '8 a 30', 8, 30), (3, '31 a 60', 31, 60), (4, '61 a 90', 61, 90), (5, '91 a 180', 91, 180), (6, '181 a 365', 181, 365), (7, 'Mais de 365', 366, 100000)) f(o, rot, a, b)),
    'novos_existentes', (select coalesce(jsonb_agg(jsonb_build_object('mes', x.mes, 'novos', x.nov, 'existentes', x.ex) order by x.mes), '[]')
                         from (select to_char(date_trunc('month', dia), 'YYYY-MM') as mes, coalesce(sum(valor) filter (where ord = 1), 0) as nov, coalesce(sum(valor) filter (where ord > 1), 0) as ex
                                 from rcj group by 1) x),
    'reconciliacao', jsonb_build_object('vendas', (select coalesce(sum(valor), 0) from rcj where fonte = 'venda'), 'contratos', (select coalesce(sum(valor), 0) from rcj where fonte = 'contrato')),
    'segunda_produtos', (select coalesce(jsonb_agg(jsonb_build_object('produto', s.prod, 'nome', pr.nome, 'clientes', s.n,
                            'receita', (select coalesce(sum(valor), 0) from rc where rc.ord = 2 and rc.produto_id = s.prod)) order by s.n desc), '[]')
                         from (select prod, count(*) as n from seg group by prod) s left join produtos pr on pr.id = s.prod),
    'entrada', (select coalesce(jsonb_agg(jsonb_build_object('produto', e.de, 'nome', coalesce(pr.nome, '(sem produto)'), 'clientes', e.n, 'recompraram', e.rec,
                    'pct', round(e.rec::numeric / e.n * 100, 1), 'receita_depois', e.rd, 'receita_depois_cli', round(e.rd / e.n, 2)) order by e.n desc), '[]')
                from (select ent.de, count(*) as n, count(*) filter (where cl.segunda is not null) as rec,
                             coalesce(sum(rpos.v), 0) as rd
                        from ent join cl on cl.pessoa_id = ent.pessoa_id left join rpos on rpos.pessoa_id = ent.pessoa_id group by ent.de) e left join produtos pr on pr.id = e.de),
    'transicao', (select coalesce(jsonb_agg(jsonb_build_object('de', t.de, 'para', t.para, 'n', t.n,
                    'pct', round(t.n::numeric / nullif((select count(*) from ent e2 where e2.de is not distinct from t.de), 0) * 100, 1)) order by t.n desc), '[]')
                  from (select ent.de, depois.para, count(*) as n from ent join depois on depois.pessoa_id = ent.pessoa_id group by 1, 2) t),
    'produtos', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'nome', nome, 'nivel', nivel_escada, 'categoria', categoria) order by nivel_escada nulls last, nome), '[]') from produtos where workspace_id = p_ws)
  ) into r;
  return r;
end $$;

-- ---------- RFM (tela) ----------
create or replace function public.revops_rfm(p_ws uuid, p_f jsonb default '{}', p_ref date default null, p_cfg jsonb default null, p_cruzar text default 'produto')
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare ref date := coalesce(p_ref, (now() at time zone 'America/Sao_Paulo')::date); cfg jsonb; r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  cfg := revops_rfm_padrao() || coalesce((select rfm from revops_config where workspace_id = p_ws), '{}'::jsonb) || coalesce(p_cfg, '{}'::jsonb);
  with cl as materialized (select * from revops_clientes(p_ws, (p_f - 'ini' - 'fim' - 'segmento'))),
  s as materialized (select x.* from revops_rfm_clientes(p_ws, ref, cfg) x where x.pessoa_id in (select pessoa_id from cl)),
  ent as (select cl.pessoa_id, coalesce(string_agg(pr.nome, ' + ' order by pr.nome), '(sem produto)') as nome from cl left join produtos pr on pr.id = any (cl.entrada) group by cl.pessoa_id),
  jan as (select (cfg ->> 'janela_dias')::int as j),
  rc as materialized (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from s) and x.dia <= ref and x.dia > ref - (select j from jan)),
  pj as materialized (select x.* from revops_pedidos(p_ws) x where x.pessoa_id in (select pessoa_id from s) and x.dia <= ref and x.dia > ref - (select j from jan)),
  cz as (
    select s.segmento, case p_cruzar when 'campanha' then coalesce((select nome from campanhas where id = cl.campanha), '(sem campanha)')
                                     when 'canal' then cl.canal when 'origem' then cl.origem
                                     else ent.nome end as chave, count(*) as n
      from s join cl on cl.pessoa_id = s.pessoa_id join ent on ent.pessoa_id = s.pessoa_id group by 1, 2
  )
  select jsonb_build_object('ref', ref, 'config', cfg, 'cruzar', p_cruzar,
    'clientes', (select count(*) from s), 'receita', (select coalesce(sum(valor), 0) from rc),
    'segmentos', (select coalesce(jsonb_agg(jsonb_build_object('nome', g.segmento, 'clientes', g.n, 'receita', g.rec,
          'pct_receita', round(g.rec / nullif((select sum(valor) from rc), 0) * 100, 1), 'ticket', round(g.rec / nullif(g.ped, 0), 2), 'frequencia', round(g.ped::numeric / g.n, 2),
          'receita_cli', round(g.rec / g.n, 2), 'dias', g.dias, 'mc', g.mc, 'com_custo', g.cc,
          'produtos', (select jsonb_agg(z) from (select pr.nome, count(*) as n from pj join s s2 on s2.pessoa_id = pj.pessoa_id and s2.segmento = g.segmento
                         cross join unnest(pj.produtos) u(pid) join produtos pr on pr.id = u.pid group by pr.nome order by count(*) desc limit 3) z))
          order by g.rec desc), '[]')
      from (select s.segmento, count(*) as n, round(avg(s.dias)) as dias,
                   coalesce((select sum(valor) from rc where rc.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)), 0) as rec,
                   (select count(*) from pj where pj.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)) as ped,
                   (select sum(valor - custo) from rc where custo is not null and rc.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)) as mc,
                   (select coalesce(sum(valor), 0) from rc where custo is not null and rc.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)) as cc
              from s group by s.segmento) g),
    'grade', (select coalesce(jsonb_agg(jsonb_build_object('r', sr, 'f', sf, 'n', n)), '[]') from (select sr, sf, count(*) as n from s group by sr, sf) x),
    'cruzamento', (select coalesce(jsonb_agg(jsonb_build_object('segmento', segmento, 'chave', chave, 'n', n)), '[]') from cz)
  ) into r;
  return r;
end $$;

-- ---------- lista para investigar ----------
/* p_sel: coorte + gran + agrupar | recomprou (sim/nao) | ate_dias | d2_min/d2_max | segunda_produto | de + para | segmento (+ ref, cfg) | mes_receita + tipo (novos/existentes) */
create or replace function public.revops_clientes_de(p_ws uuid, p_f jsonb default '{}', p_sel jsonb default '{}', p_limite int default 500)
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare r jsonb; gran text := coalesce(p_sel ->> 'gran', 'mes'); hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  ref date := coalesce(nullif(p_sel ->> 'ref', '')::date, hoje);
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with cl as materialized (select * from revops_clientes(p_ws, case when p_sel ? 'segmento' or p_sel ? 'mes_receita' then p_f - 'ini' - 'fim' - 'segmento' else p_f end)),
  p as materialized (select x.* from revops_pedidos(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rc as materialized (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rco as materialized (select pessoa_id, ord, sum(valor) as v from rc group by 1, 2),
  rfm as (select x.* from revops_rfm_clientes(p_ws, ref, p_sel -> 'cfg') x where p_sel ? 'segmento'),
  sel as (
    select cl.* from cl
     where (not p_sel ? 'coorte' or (case when p_sel ->> 'agrupar' = 'produto' then (p_sel ->> 'coorte')::uuid = any (cl.entrada)
             else to_char(date_trunc(case gran when 'trimestre' then 'quarter' when 'ano' then 'year' else 'month' end, cl.primeira), 'YYYY-MM-DD') = p_sel ->> 'coorte' end))
       and (not p_sel ? 'recomprou' or ((p_sel ->> 'recomprou') = 'sim') = (cl.segunda is not null and (not p_sel ? 'ate_dias' or cl.segunda - cl.primeira <= (p_sel ->> 'ate_dias')::int)))
       and (not p_sel ? 'd2_min' or (cl.segunda is not null and cl.segunda - cl.primeira between (p_sel ->> 'd2_min')::int and (p_sel ->> 'd2_max')::int))
       and (not p_sel ? 'segunda_produto' or exists (select 1 from p where p.pessoa_id = cl.pessoa_id and p.ord = 2 and (p_sel ->> 'segunda_produto')::uuid = any (p.produtos)))
       and (not p_sel ? 'de' or (case when p_sel ->> 'de' = '' then cl.entrada = '{}' else (p_sel ->> 'de')::uuid = any (cl.entrada) end))
       and (not p_sel ? 'para' or exists (select 1 from p where p.pessoa_id = cl.pessoa_id and p.ord >= 2 and (p_sel ->> 'para')::uuid = any (p.produtos)))
       and (not p_sel ? 'segmento' or exists (select 1 from rfm where rfm.pessoa_id = cl.pessoa_id and rfm.segmento = p_sel ->> 'segmento'))
       and (not p_sel ? 'mes_receita' or exists (select 1 from rc where rc.pessoa_id = cl.pessoa_id and to_char(rc.dia, 'YYYY-MM') = p_sel ->> 'mes_receita'
                and ((p_sel ->> 'tipo') = 'existentes') = (rc.ord > 1)))
     order by cl.primeira desc
  )
  select jsonb_build_object('total', (select count(*) from sel), 'limite', p_limite,
    'clientes', coalesce((select jsonb_agg(x order by x ->> 'primeira' desc) from (
      select jsonb_build_object('id', sel.pessoa_id, 'nome', pe.nome, 'email', pe.email, 'telefone', pe.telefone, 'primeira', sel.primeira, 'segunda', sel.segunda, 'ultima', sel.ultima,
        'pedidos', sel.n, 'dias_ultima', hoje - sel.ultima, 'canal', sel.canal, 'origem', sel.origem, 'campanha', (select nome from campanhas where id = sel.campanha),
        'receita', (select coalesce(sum(v), 0) from rco where rco.pessoa_id = sel.pessoa_id),
        'entrada', (select string_agg(nome, ' + ' order by nome) from produtos where id = any (sel.entrada)),
        'segmento', (select segmento from rfm where rfm.pessoa_id = sel.pessoa_id), 'rfm', (select sr || '' || sf || '' || sm from rfm where rfm.pessoa_id = sel.pessoa_id),
        'historico', (select jsonb_agg(jsonb_build_object('ord', p.ord, 'dia', p.dia, 'produtos', (select string_agg(nome, ' + ' order by nome) from produtos where id = any (p.produtos)),
                        'receita', (select coalesce(sum(v), 0) from rco where rco.pessoa_id = p.pessoa_id and rco.ord = p.ord)) order by p.ord) from p where p.pessoa_id = sel.pessoa_id)) as x
        from (select * from sel limit greatest(1, least(coalesce(p_limite, 500), 5000))) sel join pessoas pe on pe.id = sel.pessoa_id) z), '[]')
  ) into r;
  return r;
end $$;

do $$
declare f text;
begin
  foreach f in array array['revops_itens(uuid)', 'revops_pedidos(uuid)', 'revops_receitas(uuid)', 'revops_clientes(uuid,jsonb)', 'revops_rfm_clientes(uuid,date,jsonb)',
                           'revops_coortes(uuid,jsonb,text,text,integer)', 'revops_recompra(uuid,jsonb)', 'revops_rfm(uuid,jsonb,date,jsonb,text)', 'revops_clientes_de(uuid,jsonb,jsonb,integer)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
  if to_regprocedure('public.auditar()') is not null then
    execute 'drop trigger if exists auditoria_t on public.revops_config';
    execute 'create trigger auditoria_t after insert or update or delete on public.revops_config for each row execute function public.auditar()';
  end if;
  if to_regclass('public.acesso_telas') is not null then
    insert into acesso_telas (tela, modulo, nome, grupo, ordem)
    values ('ho-retencao', 'revops', 'Retenção & Expansão', 'RevOps', coalesce((select min(ordem) from acesso_telas where tela in ('ho-cohort', 'ho-ascensao')), 40))
    on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
    update pacotes_acesso set telas = telas || array['ho-retencao'] where (telas @> array['ho-cohort'] or telas @> array['ho-ascensao']) and not telas @> array['ho-retencao'];
  end if;
end $$;


commit;

-- Conferência: deve listar as contas; o Cartão de Crédito com tipo = cartao, fora do saldo em banco.
select nome, tipo, padrao from contas_bancarias order by tipo, nome;
