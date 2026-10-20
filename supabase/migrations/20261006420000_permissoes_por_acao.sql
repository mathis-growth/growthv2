-- v0.24: permissões por ação (ver, criar, criar só lead, editar, excluir) por função e por pessoa. Já aplicado no projeto.
-- Resolução: ação da pessoa (equipe.acoes_ind) > ação da função (funcoes.acoes) > nível do módulo (como antes).
-- Nível de módulo individual (equipe.permissoes_ind) vence o nível da função.
alter table funcoes add column if not exists acoes jsonb not null default '{}'::jsonb;
alter table equipe add column if not exists permissoes_ind jsonb not null default '{}'::jsonb;
alter table equipe add column if not exists acoes_ind jsonb not null default '{}'::jsonb;

create or replace function public.pode(ws uuid, recurso text, acao text, mods text[]) returns boolean language plpgsql stable security definer set search_path to 'public' as $f$
declare v text;
begin
  if coalesce(auth.role(), '') = 'service_role' or eh_admin(ws) then return true; end if;
  select e.acoes_ind -> recurso ->> acao into v from equipe e where e.workspace_id = ws and e.user_id = auth.uid() and e.acesso_ativo limit 1;
  if v is null then
    select fu.acoes -> recurso ->> acao into v from workspace_membros mm join funcoes fu on fu.id = mm.funcao_id
    where mm.workspace_id = ws and mm.user_id = auth.uid() and fu.workspace_id = ws;
  end if;
  if v is not null then return v = 'true'; end if;
  return perm(ws, case when acao = 'ver' then 'ler' else 'editar' end, mods);
end $f$;

create or replace function public.nivel_modulo(ws uuid, modulo text) returns text language plpgsql stable security definer set search_path to 'public' as $f$
declare m record; p text; o text;
begin
  if coalesce(auth.role(), '') = 'service_role' then return 'editar'; end if;
  select mm.papel, mm.funcao_id into m from workspace_membros mm where mm.workspace_id = ws and mm.user_id = auth.uid();
  if not found then return 'nenhum'; end if;
  if m.papel = 'admin' then return 'editar'; end if;
  select e.permissoes_ind ->> modulo into o from equipe e where e.workspace_id = ws and e.user_id = auth.uid() and e.acesso_ativo limit 1;
  if o in ('nenhum','ler','editar') then return o; end if;
  if m.funcao_id is not null then
    select coalesce(f.permissoes ->> modulo, 'nenhum') into p from funcoes f where f.id = m.funcao_id and f.workspace_id = ws;
    return coalesce(p, 'nenhum');
  end if;
  return case m.papel when 'editor' then 'editar' else 'ler' end;
end $f$;

-- equipe_guarda: também bloqueia não-administrador de mexer em permissoes_ind e acoes_ind (ver função aplicada no banco).
create or replace function public.equipe_guarda() returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if auth.uid() is not null and coalesce(current_setting('growths.sync', true), '') <> '1' and not eh_admin(new.workspace_id) then
    if tg_op = 'INSERT' then
      new.funcao_id := null; new.acesso_ativo := false; new.user_id := null; new.permissoes_ind := '{}'::jsonb; new.acoes_ind := '{}'::jsonb;
    else
      if new.funcao_id is distinct from old.funcao_id or new.acesso_ativo is distinct from old.acesso_ativo
         or new.user_id is distinct from old.user_id or (new.email is distinct from old.email and old.acesso_ativo)
         or new.permissoes_ind is distinct from old.permissoes_ind or new.acoes_ind is distinct from old.acoes_ind then
        raise exception 'Só administradores podem alterar acessos';
      end if;
    end if;
  end if;
  return new;
end $f$;

-- Recursos com ação detalhada: pessoas(clientes), vendas, contratos, alunos, contas_receber, contas_pagar, campanhas, produtos, projetos.
-- As políticas perm_* destas tabelas passaram a chamar pode(); exemplo (pessoas):
alter policy perm_ler on public.pessoas using (pode(workspace_id, 'clientes', 'ver', array['vendas','mkt','revops','fin','prj','gro','adm']));
alter policy perm_inserir on public.pessoas with check (pode(workspace_id, 'clientes', 'criar', array['vendas','revops','mkt']) or (status_funil = 'lead' and pode(workspace_id, 'clientes', 'criar_lead', array['vendas','revops','mkt'])));
alter policy perm_alterar on public.pessoas using (pode(workspace_id, 'clientes', 'editar', array['vendas','revops','mkt'])) with check (pode(workspace_id, 'clientes', 'editar', array['vendas','revops','mkt']));
alter policy perm_excluir on public.pessoas using (pode(workspace_id, 'clientes', 'excluir', array['vendas','revops','mkt']));
-- Demais tabelas: mesmo padrão de alter policy, com (recurso, módulos): vendas [vendas,fin]; contratos [vendas]; alunos [revops,vendas];
-- contas_receber [fin]; contas_pagar [fin]; campanhas [mkt] (sem ver); produtos [cad] (sem ver); projetos [prj].
-- Leitura (ver): vendas [vendas,fin,mkt,revops,adm,gro,prj]; contratos [vendas,fin,adm,prj,revops]; alunos [revops,vendas,adm,prj,fin,gro];
-- contas_receber [fin,adm,vendas,revops]; contas_pagar [fin,adm,mkt]; projetos [prj,adm,vendas,revops].

create or replace function public.valida_acoes(a jsonb) returns void language plpgsql immutable as $f$
declare k text; v jsonb; ak text; av jsonb;
begin
  if a is null or a = '{}'::jsonb then return; end if;
  if jsonb_typeof(a) <> 'object' then raise exception 'Ações inválidas'; end if;
  for k, v in select key, value from jsonb_each(a) loop
    if k not in ('clientes','vendas','contratos','alunos','contas_receber','contas_pagar','campanhas','produtos','projetos') then raise exception 'Recurso desconhecido: %', k; end if;
    if jsonb_typeof(v) <> 'object' then raise exception 'Ações inválidas para %', k; end if;
    for ak, av in select key, value from jsonb_each(v) loop
      if ak not in ('ver','criar','criar_lead','editar','excluir') or jsonb_typeof(av) <> 'boolean' then raise exception 'Ação inválida em %: %', k, ak; end if;
    end loop;
  end loop;
end $f$;
-- funcoes_valida() passou a chamar valida_acoes(new.acoes); minhas_permissoes() devolve também 'acoes' (função mesclada com a pessoa).
-- Observação: a validação do conteúdo de equipe.permissoes_ind/acoes_ind por trigger foi recusada pela ferramenta; só administradores gravam e a tela envia valores válidos.
