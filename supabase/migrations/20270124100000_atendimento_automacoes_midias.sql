-- Arquivos públicos temporários para ações de mídia nos fluxos de Atendimento.
-- Os caminhos começam com o workspace_id; só a equipe daquele workspace pode gravar.
do $storage$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
    values('atd-automacao-assets','atd-automacao-assets',true,8388608,array[
      'image/jpeg','image/png','image/webp','image/gif','video/mp4','application/pdf','application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain','text/csv'
    ]) on conflict(id) do update set public=true,file_size_limit=8388608,allowed_mime_types=array[
      'image/jpeg','image/png','image/webp','image/gif','video/mp4','application/pdf','application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain','text/csv'
    ];
    execute 'drop policy if exists atd_auto_assets_ler on storage.objects';
    execute 'drop policy if exists atd_auto_assets_gravar on storage.objects';
    execute 'drop policy if exists atd_auto_assets_editar on storage.objects';
    execute 'drop policy if exists atd_auto_assets_apagar on storage.objects';
    execute $p$create policy atd_auto_assets_ler on storage.objects for select to public using(bucket_id='atd-automacao-assets')$p$;
    execute $p$create policy atd_auto_assets_gravar on storage.objects for insert to authenticated with check(
      bucket_id='atd-automacao-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas']))$p$;
    execute $p$create policy atd_auto_assets_editar on storage.objects for update to authenticated using(
      bucket_id='atd-automacao-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas'])) with check(
      bucket_id='atd-automacao-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas']))$p$;
    execute $p$create policy atd_auto_assets_apagar on storage.objects for delete to authenticated using(
      bucket_id='atd-automacao-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas']))$p$;
  end if;
end $storage$;
