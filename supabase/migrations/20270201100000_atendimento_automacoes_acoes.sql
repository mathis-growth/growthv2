-- Auditoria e deduplicação das ações externas e alterações do CRM no canvas.
create table if not exists public.atd_automacao_acoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  execucao_id uuid not null references public.atd_automacao_execucoes(id) on delete cascade,
  node_id uuid not null,
  pessoa_id uuid not null references public.pessoas(id),
  tipo text not null check (tipo in ('tag','campo','campanha','formulario','email')),
  status text not null default 'processando' check (status in ('processando','feito','erro','incerto')),
  resumo text,
  externo_id text,
  erro text,
  criado_em timestamptz not null default now(),
  concluido_em timestamptz,
  unique (execucao_id,node_id)
);
create index if not exists atd_automacao_acoes_pessoa on public.atd_automacao_acoes(workspace_id,pessoa_id,criado_em desc);
alter table public.atd_automacao_acoes enable row level security;
revoke all on public.atd_automacao_acoes from public,anon,authenticated;
grant all on public.atd_automacao_acoes to service_role;
drop policy if exists atd_automacao_acoes_ler on public.atd_automacao_acoes;
create policy atd_automacao_acoes_ler on public.atd_automacao_acoes for select to authenticated
  using (public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
grant select on public.atd_automacao_acoes to authenticated;

-- Atualização serializada para duas automações não sobrescreverem tags ou extras.
create or replace function public.atd_automacao_pessoa_atualizar(
  p_ws uuid,p_pessoa uuid,p_tipo text,p_chave text,p_valor text
) returns jsonb language plpgsql security invoker set search_path=public as $$
declare atual public.pessoas; novas_tags text[]; novos_extras jsonb; field_kind text; field_value jsonb;
begin
  select * into atual from public.pessoas where id=p_pessoa and workspace_id=p_ws for update;
  if not found then raise exception 'Contato não encontrado no workspace.'; end if;
  if p_tipo='tag_adicionar' then
    novas_tags := array(select distinct x from unnest(coalesce(atual.tags,'{}'::text[]) || array[p_valor]) x where x<>'');
    if cardinality(novas_tags)>50 then raise exception 'Limite de 50 tags por contato.'; end if;
    update public.pessoas set tags=novas_tags where id=p_pessoa;
  elsif p_tipo='tag_remover' then
    novas_tags := array(select x from unnest(coalesce(atual.tags,'{}'::text[])) x where x<>p_valor);
    update public.pessoas set tags=novas_tags where id=p_pessoa;
  elsif p_tipo='campo' then
    select tipo into field_kind from public.campos_personalizados where workspace_id=p_ws and entidade='pessoas' and chave=p_chave;
    if field_kind is null then
      raise exception 'Campo personalizado não encontrado.';
    end if;
    field_value := case field_kind when 'number' then to_jsonb(p_valor::numeric) when 'date' then to_jsonb(p_valor::date) else to_jsonb(p_valor) end;
    novas_extras := jsonb_set(coalesce(atual.extras,'{}'::jsonb),array[p_chave],field_value,true);
    update public.pessoas set extras=novas_extras where id=p_pessoa;
  else raise exception 'Operação inválida.';
  end if;
  return jsonb_build_object('tags',coalesce(novas_tags,atual.tags),'extras',coalesce(novos_extras,atual.extras));
end $$;
revoke all on function public.atd_automacao_pessoa_atualizar(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.atd_automacao_pessoa_atualizar(uuid,uuid,text,text,text) to service_role;
