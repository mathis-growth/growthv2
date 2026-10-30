-- v0.171 — Publicar a estratégia: a função passa a rodar como definidora (security definer), como as outras que publicam (jornada_publicar).
-- Antes ela rodava com o papel de quem chama (authenticated), que não pode executar pode_operar: toda publicação dava 403
-- "permission denied for function pode_operar" e a tela mostrava "Sem permissão para esta alteração".
-- A checagem continua a mesma, dentro da função: pertencer ao workspace e poder editar Marketing ou Growth.
-- Rode depois de 20261124100000_strategy_canvas.sql. Idempotente.
create or replace function public.estrategia_publicar(p_funil uuid, p_nota text default null) returns int
language plpgsql security definer set search_path = public as $$
declare f funis; v int; foto jsonb;
begin
  select * into f from funis where id = p_funil for update;
  if not found then raise exception 'Estratégia não encontrada.'; end if;
  if not pode_operar(f.workspace_id) or not (perm(f.workspace_id, 'editar', array['mkt', 'gro']) or session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role') then
    raise exception 'Sem permissão para publicar esta estratégia.' using errcode = '42501'; end if;
  v := coalesce((select max(versao) from estrategia_versoes where funil_id = p_funil), 0) + 1;
  foto := jsonb_build_object(
    'estrategia', jsonb_build_object('nome', f.nome, 'tipo', f.tipo, 'produto_id', f.produto_id, 'descricao', f.descricao, 'categoria', f.categoria, 'objetivo', f.objetivo, 'criterios', f.criterios),
    'blocos', coalesce((select jsonb_agg(to_jsonb(b) - 'workspace_id' - 'funil_id' order by b.fase, b.ordem) from estrategia_blocos b where b.funil_id = p_funil), '[]'::jsonb),
    'conexoes', coalesce((select jsonb_agg(to_jsonb(c) - 'workspace_id' - 'funil_id' order by c.criado_em) from estrategia_conexoes c where c.funil_id = p_funil), '[]'::jsonb),
    'etapas', coalesce((select jsonb_agg(to_jsonb(e) - 'workspace_id' - 'funil_id' order by e.ordem) from estrategia_etapas e where e.funil_id = p_funil), '[]'::jsonb));
  insert into estrategia_versoes (workspace_id, funil_id, versao, foto, nota, publicada_por) values (f.workspace_id, p_funil, v, foto, nullif(trim(coalesce(p_nota, '')), ''), auth.uid());
  update funis set versao_atual = v, status = case when status = 'rascunho' then 'ativa' else status end where id = p_funil;
  return v;
end $$;
revoke execute on function public.estrategia_publicar(uuid, text) from public, anon;
grant execute on function public.estrategia_publicar(uuid, text) to authenticated;

-- Data de criação das estratégias novas (as antigas ficam sem data: a lista não inventa uma).
alter table funis add column if not exists criado_em timestamptz;
alter table funis alter column criado_em set default now();

-- Para desfazer: a versão de 20261124100000_strategy_canvas.sql (sem security definer); alter table funis drop column criado_em.
