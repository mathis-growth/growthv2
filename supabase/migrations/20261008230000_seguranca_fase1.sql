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
