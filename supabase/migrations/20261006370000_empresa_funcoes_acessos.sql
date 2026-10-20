-- v0.22: cadastro da empresa, funções (perfis de acesso), pessoas com acesso e permissões por módulo
-- aplicadas NO BANCO (políticas restritivas), não só escondidas no menu.
-- Níveis: nenhum | ler (consultar) | editar (consultar e alterar). Módulos: adm, mkt, vendas, revops, fin, prj, gro, cfg, cad.

-- ---------- Empresa ----------
create or replace function public.cnpj_valido(p text) returns boolean language plpgsql immutable as $$
declare d text := regexp_replace(coalesce(p, ''), '\D', '', 'g'); s int; i int; dv1 int; dv2 int;
  p1 int[] := array[5,4,3,2,9,8,7,6,5,4,3,2]; p2 int[] := array[6,5,4,3,2,9,8,7,6,5,4,3,2];
begin
  if length(d) <> 14 or d ~ '^(\d)\1{13}$' then return false; end if;
  s := 0; for i in 1..12 loop s := s + substr(d, i, 1)::int * p1[i]; end loop;
  dv1 := case when s % 11 < 2 then 0 else 11 - s % 11 end;
  s := 0; for i in 1..13 loop s := s + substr(d, i, 1)::int * p2[i]; end loop;
  dv2 := case when s % 11 < 2 then 0 else 11 - s % 11 end;
  return dv1 = substr(d, 13, 1)::int and dv2 = substr(d, 14, 1)::int;
end $$;

create table if not exists public.empresa (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  nome text, razao_social text, cnpj text, telefone text, email_contato text, endereco text,
  responsavel_nome text, responsavel_email text, responsavel_telefone text,
  financeiro_nome text, financeiro_email text, financeiro_telefone text,
  regime_tributario text check (regime_tributario in ('mei','simples_nacional','lucro_presumido','lucro_real','outro')),
  regime_apuracao text check (regime_apuracao in ('competencia','caixa')),
  exercicio_inicio date, exercicio_fim date,
  periodicidade_fechamento text check (periodicidade_fechamento in ('mensal','trimestral','anual')),
  observacoes text, atualizado_em timestamptz not null default now(), atualizado_por uuid,
  check (exercicio_fim is null or exercicio_inicio is null or exercicio_fim >= exercicio_inicio));
alter table public.empresa enable row level security;

create or replace function public.empresa_valida() returns trigger language plpgsql as $$
begin
  if coalesce(new.cnpj, '') <> '' then
    if not cnpj_valido(new.cnpj) then raise exception 'CNPJ inválido: confira os dígitos'; end if;
    new.cnpj := regexp_replace(new.cnpj, '\D', '', 'g');
  else new.cnpj := null; end if;
  new.atualizado_em := now(); new.atualizado_por := auth.uid();
  return new;
end $$;
create trigger empresa_valida_t before insert or update on public.empresa for each row execute function public.empresa_valida();

-- ---------- Funções (perfis) ----------
create table if not exists public.funcoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null, descricao text,
  administrador boolean not null default false,
  permissoes jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  unique (workspace_id, nome));
alter table public.funcoes enable row level security;

create or replace function public.funcoes_valida() returns trigger language plpgsql as $$
declare k text; v text;
begin
  for k, v in select key, value from jsonb_each_text(coalesce(new.permissoes, '{}'::jsonb)) loop
    if k not in ('adm','mkt','vendas','revops','fin','prj','gro','cfg','cad') then raise exception 'Módulo desconhecido: %', k; end if;
    if v not in ('nenhum','ler','editar') then raise exception 'Nível inválido para %: %', k, v; end if;
  end loop;
  return new;
end $$;
create trigger funcoes_valida_t before insert or update on public.funcoes for each row execute function public.funcoes_valida();

alter table public.workspace_membros add column if not exists funcao_id uuid references public.funcoes(id) on delete restrict;
alter table public.equipe add column if not exists funcao_id uuid references public.funcoes(id) on delete restrict;
alter table public.equipe add column if not exists acesso_ativo boolean not null default false;
alter table public.equipe add column if not exists user_id uuid references auth.users(id) on delete set null;

-- ---------- Quem é admin e qual o nível em cada módulo ----------
create or replace function public.eh_admin(ws uuid) returns boolean language sql stable security definer set search_path to 'public' as $$
  select coalesce(auth.role(), '') = 'service_role'
      or exists (select 1 from workspace_membros m where m.workspace_id = ws and m.user_id = auth.uid() and m.papel = 'admin');
$$;

create or replace function public.nivel_modulo(ws uuid, modulo text) returns text language plpgsql stable security definer set search_path to 'public' as $$
declare m record; p text;
begin
  if coalesce(auth.role(), '') = 'service_role' then return 'editar'; end if;
  select mm.papel, mm.funcao_id into m from workspace_membros mm where mm.workspace_id = ws and mm.user_id = auth.uid();
  if not found then return 'nenhum'; end if;
  if m.papel = 'admin' then return 'editar'; end if;
  if m.funcao_id is not null then
    select coalesce(f.permissoes ->> modulo, 'nenhum') into p from funcoes f where f.id = m.funcao_id and f.workspace_id = ws;
    return coalesce(p, 'nenhum');
  end if;
  return case m.papel when 'editor' then 'editar' else 'ler' end;  -- membro antigo, sem função
end $$;

create or replace function public.perm(ws uuid, req text, mods text[]) returns boolean language plpgsql stable security definer set search_path to 'public' as $$
declare m text; n text;
begin
  foreach m in array mods loop
    n := nivel_modulo(ws, m);
    if n = 'editar' or (req = 'ler' and n = 'ler') then return true; end if;
  end loop;
  return false;
end $$;

create or replace function public.minhas_permissoes(p_ws uuid) returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare m text; r jsonb := '{}'; f text;
begin
  foreach m in array array['adm','mkt','vendas','revops','fin','prj','gro','cfg','cad'] loop r := r || jsonb_build_object(m, nivel_modulo(p_ws, m)); end loop;
  select fu.nome into f from workspace_membros mm join funcoes fu on fu.id = mm.funcao_id where mm.workspace_id = p_ws and mm.user_id = auth.uid();
  return jsonb_build_object('admin', eh_admin(p_ws), 'funcao', f, 'modulos', r);
end $$;

-- ---------- Políticas das tabelas novas e de membros ----------
create policy empresa_leitura on public.empresa for select using (pertence_ao_workspace(workspace_id));
create policy empresa_insercao on public.empresa for insert with check (eh_admin(workspace_id));
create policy empresa_edicao on public.empresa for update using (eh_admin(workspace_id)) with check (eh_admin(workspace_id));
create policy funcoes_leitura on public.funcoes for select using (pertence_ao_workspace(workspace_id));
create policy funcoes_insercao on public.funcoes for insert with check (eh_admin(workspace_id));
create policy funcoes_edicao on public.funcoes for update using (eh_admin(workspace_id)) with check (eh_admin(workspace_id));
create policy funcoes_exclusao on public.funcoes for delete using (eh_admin(workspace_id));
create policy membros_admin_leitura on public.workspace_membros for select using (eh_admin(workspace_id));

create or replace function public.equipe_guarda() returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is not null and coalesce(current_setting('growths.sync', true), '') <> '1' and not eh_admin(new.workspace_id) then
    if tg_op = 'INSERT' then
      new.funcao_id := null; new.acesso_ativo := false; new.user_id := null;
    else
      if new.funcao_id is distinct from old.funcao_id or new.acesso_ativo is distinct from old.acesso_ativo
         or new.user_id is distinct from old.user_id or (new.email is distinct from old.email and old.acesso_ativo) then
        raise exception 'Só administradores podem alterar acessos';
      end if;
    end if;
  end if;
  return new;
end $$;
create trigger equipe_guarda_t before insert or update on public.equipe for each row execute function public.equipe_guarda();

create or replace function public.acessos_do_workspace(p_ws uuid) returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not eh_admin(p_ws) then raise exception 'Só administradores veem os acessos'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'email', u.email, 'papel', m.papel, 'funcao_id', m.funcao_id,
      'funcao', f.nome, 'equipe_id', e.id, 'nome', e.nome) order by u.email)
    from workspace_membros m join auth.users u on u.id = m.user_id
    left join funcoes f on f.id = m.funcao_id
    left join equipe e on e.user_id = m.user_id and e.workspace_id = m.workspace_id
    where m.workspace_id = p_ws), '[]');
end $$;

-- ---------- Permissões por módulo, impostas pelo banco (políticas restritivas) ----------
-- tabela | quem LÊ (null = qualquer membro) | quem EDITA
do $$
declare r record;
begin
  for r in select * from (values
    ('planos', array['adm','mkt'], array['adm']), ('plano_objetivos', array['adm','mkt'], array['adm']),
    ('plano_indicadores', array['adm','mkt'], array['adm']), ('plano_metas', array['adm','mkt'], array['adm']),
    ('planejamento_mensal', array['adm','fin','mkt'], array['adm','fin']),
    ('campanhas', null, array['mkt']),
    ('campanha_canais', array['mkt','adm','gro','vendas'], array['mkt']), ('campanha_debriefing', array['mkt','adm','gro','vendas'], array['mkt']),
    ('campanha_fechamentos', array['mkt','adm','gro','vendas'], array['mkt']), ('campanha_links', array['mkt','adm','gro','vendas'], array['mkt']),
    ('campanha_melhorias', array['mkt','adm','gro','vendas'], array['mkt']),
    ('anuncios', array['mkt','adm','gro'], array['mkt']), ('metricas_anuncio_dia', array['mkt','adm','gro'], array['mkt']),
    ('fontes_video', array['mkt','adm','gro'], array['mkt']), ('video_metricas_dia', array['mkt','adm','gro'], array['mkt']),
    ('presencas_video', array['mkt','adm','gro','vendas','revops'], array['mkt']),
    ('conteudo_config', array['mkt','adm'], array['mkt']), ('conteudo_conta_dia', array['mkt','adm'], array['mkt']), ('conteudo_linhas', array['mkt','adm'], array['mkt']),
    ('conteudo_metas_semanais', array['mkt','adm'], array['mkt']), ('conteudo_publicacoes', array['mkt','adm'], array['mkt']),
    ('conteudo_temas', array['mkt','adm'], array['mkt']), ('conteudos', array['mkt','adm'], array['mkt']),
    ('funis', array['mkt','vendas','gro','adm'], array['mkt']), ('funil_etapas', array['mkt','vendas','gro','adm'], array['mkt']), ('funil_listas', array['mkt','vendas','gro','adm'], array['mkt']),
    ('pessoa_funil', array['mkt','vendas','gro','adm','revops'], array['mkt','vendas']), ('pessoa_funil_historico', array['mkt','vendas','gro','adm','revops'], array['mkt','vendas']),
    ('pessoa_lista', array['mkt','vendas','gro','adm','revops'], array['mkt','vendas']),
    ('pessoas', array['vendas','mkt','revops','fin','prj','gro','adm'], array['vendas','revops','mkt']),
    ('pessoa_historico', array['vendas','mkt','revops','adm','prj'], array['vendas','revops','mkt']), ('pessoa_notas', array['vendas','mkt','revops','adm','prj'], array['vendas','revops','mkt']),
    ('motivos_resultado', null, array['vendas','cad']),
    ('contratos', array['vendas','fin','adm','prj','revops'], array['vendas']), ('contrato_itens', array['vendas','fin','adm','prj','revops'], array['vendas']),
    ('vendas', array['vendas','fin','mkt','revops','adm','gro','prj'], array['vendas','fin']),
    ('alunos', array['revops','vendas','adm','prj','fin','gro'], array['revops','vendas']), ('aluno_historico', array['revops','vendas','adm','prj','fin','gro'], array['revops','vendas']),
    ('heavyops_metas', array['revops','adm'], array['revops']),
    ('etapas_kanban', null, array['vendas','revops']),
    ('contas_receber', array['fin','adm','vendas','revops'], array['fin']), ('contas_pagar', array['fin','adm','mkt'], array['fin']), ('plano_contas', array['fin','adm','mkt'], array['fin']),
    ('lancamentos', array['fin','adm'], array['fin']), ('partidas', array['fin','adm'], array['fin']), ('estornos', array['fin','adm'], array['fin']),
    ('movimentacoes_bancarias', array['fin','adm'], array['fin']), ('contas_bancarias', array['fin','adm','vendas'], array['fin']),
    ('regras_contabilizacao', array['fin','adm'], array['fin']), ('impostos_config', array['fin','adm'], array['fin']), ('centros_custo', array['fin','adm','cad'], array['fin','cad']),
    ('produtos', null, array['cad']), ('fornecedores', array['fin','adm','cad','mkt'], array['cad','fin']),
    ('plataformas_venda', array['fin','adm','cad','vendas'], array['cad','fin']), ('plataforma_formas_pagamento', array['fin','adm','cad','vendas'], array['cad','fin']),
    ('produto_plataforma', array['fin','adm','cad','vendas'], array['cad','fin']), ('canais', null, array['cad','mkt']),
    ('projetos', array['prj','adm','vendas','revops'], array['prj']), ('projeto_atividades', array['prj','adm','vendas','revops'], array['prj']),
    ('projeto_modelos', array['prj','adm','vendas','revops'], array['prj']), ('projeto_modelo_atividades', array['prj','adm','vendas','revops'], array['prj']),
    ('growth_experimentos', array['gro','adm','mkt'], array['gro']), ('growth_metricas', array['gro','adm','mkt'], array['gro']),
    ('pesquisas', array['gro','adm','mkt'], array['gro']), ('pesquisa_perguntas', array['gro','adm','mkt'], array['gro']), ('pesquisa_envios', array['gro','adm','mkt'], array['gro']),
    ('pesquisa_respostas', array['gro','adm','mkt'], array['gro']), ('pesquisa_resposta_itens', array['gro','adm','mkt'], array['gro']), ('pesquisa_insights', array['gro','adm','mkt'], array['gro']),
    ('integracoes', array['cfg'], array['cfg']), ('importacoes', array['cfg'], array['cfg']),
    ('equipe', null, array['cad'])
  ) as t(tabela, ler, editar) loop
    if r.ler is not null and not exists (select 1 from pg_policies where schemaname = 'public' and tablename = r.tabela and policyname = 'perm_ler') then
      execute format('create policy perm_ler on public.%I as restrictive for select to authenticated using (perm(workspace_id, ''ler'', %L::text[]))', r.tabela, r.ler::text);
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = r.tabela and policyname = 'perm_inserir') then
      execute format('create policy perm_inserir on public.%I as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', %L::text[]))', r.tabela, r.editar::text);
      execute format('create policy perm_alterar on public.%I as restrictive for update to authenticated using (perm(workspace_id, ''editar'', %L::text[])) with check (perm(workspace_id, ''editar'', %L::text[]))', r.tabela, r.editar::text, r.editar::text);
      execute format('create policy perm_excluir on public.%I as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', %L::text[]))', r.tabela, r.editar::text);
    end if;
  end loop;
end $$;

grant execute on function public.minhas_permissoes(uuid), public.acessos_do_workspace(uuid), public.cnpj_valido(text) to authenticated;
