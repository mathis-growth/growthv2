-- Anexos privados das atividades dos projetos.
create table if not exists public.projeto_atividade_arquivos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  projeto_id uuid not null references public.projetos(id) on delete cascade,
  atividade_id uuid not null references public.projeto_atividades(id) on delete cascade,
  nome text not null check (length(nome) between 1 and 255),
  caminho text not null unique,
  tamanho bigint not null check (tamanho > 0 and tamanho <= 20971520),
  tipo text,
  criado_por uuid not null default auth.uid(),
  criado_em timestamptz not null default now()
);
create index if not exists projeto_atividade_arquivos_atividade_ix
  on public.projeto_atividade_arquivos (atividade_id, criado_em desc);

create or replace function public.projeto_atividade_arquivo_validar() returns trigger
language plpgsql set search_path = public as $$
begin
  if not exists (select 1 from public.projeto_atividades a
    where a.id = new.atividade_id and a.projeto_id = new.projeto_id and a.workspace_id = new.workspace_id) then
    raise exception 'Atividade fora do projeto ou workspace';
  end if;
  if new.caminho !~ ('^' || new.workspace_id::text || '/' || new.atividade_id::text || '/[0-9a-f-]{36}$') then
    raise exception 'Caminho do anexo inválido';
  end if;
  return new;
end $$;
drop trigger if exists projeto_atividade_arquivo_validar_tg on public.projeto_atividade_arquivos;
create trigger projeto_atividade_arquivo_validar_tg before insert or update on public.projeto_atividade_arquivos
  for each row execute function public.projeto_atividade_arquivo_validar();

alter table public.projeto_atividade_arquivos enable row level security;
drop policy if exists projeto_atividade_arquivos_acesso on public.projeto_atividade_arquivos;
create policy projeto_atividade_arquivos_acesso on public.projeto_atividade_arquivos
  for all to authenticated using (public.pertence_ao_workspace(workspace_id))
  with check (public.pertence_ao_workspace(workspace_id));
grant select, insert, delete on public.projeto_atividade_arquivos to authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('projeto-anexos', 'projeto-anexos', false, 20971520)
on conflict (id) do update set public = false, file_size_limit = 20971520;

drop policy if exists projeto_anexos_ler on storage.objects;
drop policy if exists projeto_anexos_enviar on storage.objects;
drop policy if exists projeto_anexos_apagar on storage.objects;
create policy projeto_anexos_ler on storage.objects for select to authenticated using (
  bucket_id = 'projeto-anexos' and exists (
    select 1 from public.projeto_atividades a
    where a.workspace_id::text = (storage.foldername(name))[1]
      and a.id::text = (storage.foldername(name))[2]
      and public.pertence_ao_workspace(a.workspace_id)
  )
);
create policy projeto_anexos_enviar on storage.objects for insert to authenticated with check (
  bucket_id = 'projeto-anexos' and exists (
    select 1 from public.projeto_atividades a
    where a.workspace_id::text = (storage.foldername(name))[1]
      and a.id::text = (storage.foldername(name))[2]
      and public.pertence_ao_workspace(a.workspace_id)
  )
);
create policy projeto_anexos_apagar on storage.objects for delete to authenticated using (
  bucket_id = 'projeto-anexos' and exists (
    select 1 from public.projeto_atividades a
    where a.workspace_id::text = (storage.foldername(name))[1]
      and a.id::text = (storage.foldername(name))[2]
      and public.pertence_ao_workspace(a.workspace_id)
  )
);
