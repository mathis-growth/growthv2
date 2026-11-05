-- v0.261: bruto dos anúncios, numa tabela por plataforma: meta_ads_bruto, google_ads_bruto e youtube_ads_bruto.
-- Cada linha é o que a plataforma devolveu para um anúncio em um dia. Os dias recentes são regravados, porque as plataformas ajustam os números.
-- Aditiva: ads_externo_dia e o tratamento atual não mudam. Para desfazer: drop da função conexao_gravar_bruto e das três tabelas.
do $m$
declare t text;
begin
  foreach t in array array['meta_ads_bruto', 'google_ads_bruto', 'youtube_ads_bruto'] loop
    execute format($f$create table if not exists public.%1$I (
      id uuid primary key default gen_random_uuid(),
      workspace_id uuid not null references public.workspaces(id) on delete cascade,
      conta_id uuid not null references public.conexao_contas(id) on delete cascade,
      data date not null,
      anuncio_ext text not null,
      payload jsonb not null,
      recebido_em timestamptz not null default now(),
      atualizado_em timestamptz not null default now(),
      unique (conta_id, anuncio_ext, data))$f$, t);
    execute format('create index if not exists %I on public.%I (workspace_id, data)', t || '_ws_ix', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $m$;

-- só a função conexoes grava (papel service_role). p_linhas: [{ data, anuncio_ext, payload }]
create or replace function public.conexao_gravar_bruto(p_conta uuid, p_prov text, p_linhas jsonb) returns int language plpgsql security definer set search_path = public as $$
declare k conexao_contas; tb text; n int;
begin
  tb := case p_prov when 'meta_ads' then 'meta_ads_bruto' when 'google_ads' then 'google_ads_bruto' when 'youtube_ads' then 'youtube_ads_bruto' end;
  if tb is null then raise exception 'Plataforma inválida: %', p_prov; end if;
  select * into k from conexao_contas where id = p_conta;
  if k.id is null then raise exception 'Conta não encontrada'; end if;
  execute format($f$with lin as (select distinct on (x ->> 'anuncio_ext', x ->> 'data') (x ->> 'data')::date as data, x ->> 'anuncio_ext' as an, x -> 'payload' as pl
      from jsonb_array_elements(coalesce($1, '[]'::jsonb)) x where nullif(x ->> 'data', '') is not null and nullif(x ->> 'anuncio_ext', '') is not null and x -> 'payload' is not null),
    g as (insert into %I (workspace_id, conta_id, data, anuncio_ext, payload) select $2, $3, data, an, pl from lin
      on conflict (conta_id, anuncio_ext, data) do update set payload = excluded.payload, atualizado_em = now() returning 1)
    select count(*) from g$f$, tb) into n using p_linhas, k.workspace_id, k.id;
  return n;
end $$;
revoke execute on function public.conexao_gravar_bruto(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.conexao_gravar_bruto(uuid, text, jsonb) to service_role;
notify pgrst, 'reload schema';
