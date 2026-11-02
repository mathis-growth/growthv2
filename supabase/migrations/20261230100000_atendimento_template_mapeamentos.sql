-- Mapeamento central de variáveis dos templates por conta e evento.
-- Evita repetir a seleção de campos em campanhas, produtos e formulários.
create table if not exists public.atd_template_mapeamentos (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  canal_id uuid not null,
  template_name text not null,
  idioma text not null,
  mapeamentos jsonb not null default '{}'::jsonb check (jsonb_typeof(mapeamentos) = 'object'),
  atualizado_em timestamptz not null default now(),
  primary key (workspace_id, canal_id, template_name, idioma),
  foreign key (workspace_id, canal_id) references public.atd_canais(workspace_id, id) on delete cascade
);
alter table public.atd_template_mapeamentos enable row level security;
revoke all on public.atd_template_mapeamentos from public, anon, authenticated;
grant all on public.atd_template_mapeamentos to service_role;

-- O formulário de origem agora salva somente conta e template. Os campos são
-- resolvidos pelo mapeamento do template no instante em que o evento entra na fila.
create or replace function public._atd_tx_enfileirar(
  p_workspace uuid, p_pessoa uuid, p_origem text, p_origem_id uuid,
  p_config jsonb, p_evento jsonb
) returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare
  canal uuid; nome text; idioma text; vals jsonb; novo uuid; pj jsonb; mapa jsonb;
begin
  if p_config is null or jsonb_typeof(p_config) <> 'object' then return null; end if;
  begin canal := (p_config->>'canal_id')::uuid; exception when others then return null; end;
  nome := trim(coalesce(p_config->>'template_name',''));
  idioma := trim(coalesce(p_config->>'idioma',''));
  if nome = '' or idioma = '' or p_origem not in ('cadastro','venda','pesquisa') then return null; end if;
  if not exists(select 1 from public.atd_canais c where c.id=canal and c.workspace_id=p_workspace and c.provedor='zernio' and c.canal='whatsapp') then return null; end if;
  select to_jsonb(p) into pj from public.pessoas p where p.id=p_pessoa and p.workspace_id=p_workspace;
  if pj is null then return null; end if;
  select m.mapeamentos->p_origem into mapa from public.atd_template_mapeamentos m
    where m.workspace_id=p_workspace and m.canal_id=canal and m.template_name=nome and m.idioma=idioma;
  -- Mantém compatibilidade com configurações antigas já salvas na campanha/produto/pesquisa.
  if mapa is null then
    mapa := case when jsonb_typeof(p_config->'parametros')='array' then p_config->'parametros' else '[]'::jsonb end;
  elsif jsonb_typeof(mapa)='array' and jsonb_array_length(mapa)=0
      and jsonb_typeof(p_config->'parametros')='array' and jsonb_array_length(p_config->'parametros')>0 then
    mapa := p_config->'parametros';
  end if;
  select coalesce(jsonb_agg(to_jsonb(coalesce(public._atd_tx_valor(pj,coalesce(p_evento,'{}'::jsonb),x.value),'')) order by x.ordinality),'[]'::jsonb)
    into vals
    from jsonb_array_elements_text(case when jsonb_typeof(mapa)='array' then mapa else '[]'::jsonb end) with ordinality x(value,ordinality);
  insert into public.atd_envios_transacionais(workspace_id,pessoa_id,canal_id,origem,origem_id,template_name,idioma,parametros)
    values (p_workspace,p_pessoa,canal,p_origem,p_origem_id,nome,idioma,vals)
  on conflict(workspace_id,origem,origem_id) do nothing
  returning id into novo;
  return novo;
end $$;
revoke all on function public._atd_tx_enfileirar(uuid,uuid,text,uuid,jsonb,jsonb) from public,anon,authenticated;
