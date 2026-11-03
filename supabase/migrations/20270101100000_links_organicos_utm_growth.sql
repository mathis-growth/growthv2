-- Links orgânicos no escopo da campanha, sem criar anúncios de mídia paga.
create table if not exists public.campanha_links_organicos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  campanha_id uuid not null references public.campanhas(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 160),
  url_destino text not null check (url_destino ~* '^https?://'),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create index if not exists campanha_links_organicos_campanha_idx
  on public.campanha_links_organicos (workspace_id, campanha_id, criado_em desc);

create or replace function public.campanha_link_organico_valida()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.campanhas c
    where c.id = new.campanha_id and c.workspace_id = new.workspace_id
  ) then
    raise exception 'A campanha precisa pertencer ao mesmo workspace';
  end if;
  return new;
end $$;

drop trigger if exists campanha_link_organico_valida_t on public.campanha_links_organicos;
create trigger campanha_link_organico_valida_t
  before insert or update of workspace_id, campanha_id on public.campanha_links_organicos
  for each row execute function public.campanha_link_organico_valida();

alter table public.campanha_links_organicos enable row level security;
drop policy if exists campanha_links_organicos_acesso on public.campanha_links_organicos;
create policy campanha_links_organicos_acesso on public.campanha_links_organicos
  for all to authenticated
  using (pertence_ao_workspace(workspace_id))
  with check (pertence_ao_workspace(workspace_id));
grant select, insert, update, delete on public.campanha_links_organicos to authenticated;

-- utm_growth carrega o UUID da campanha. Quando presente e válido, ele é a
-- referência direta; as UTMs convencionais seguem sendo preservadas no lead.
create or replace function public.lead_por_chave(p_chave text, p_dados jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  w uuid; d jsonb := coalesce(p_dados, '{}'::jsonb); v_nome text; v_email text; v_fone text; f text; e text; em timestamptz;
  cc campanha_canais; p pessoas; pid uuid; nova boolean := false; ja boolean := false; resp jsonb; v_origem text; v_canal text;
  t text := nullif(trim(coalesce(d->>'utm_campaign', '')), '');
  growth text := nullif(trim(coalesce(d->>'utm_growth', '')), '');
  growth_id uuid; campanha_ref uuid; growth_candidates uuid[] := '{}'::uuid[];
begin
  w := chave_api_ws_escopo(p_chave, 'leads');
  v_nome := nullif(left(trim(coalesce(d->>'nome', '')), 160), '');
  v_email := nullif(lower(left(trim(coalesce(d->>'email', '')), 200)), '');
  v_fone := nullif(left(trim(coalesce(d->>'telefone', '')), 40), '');
  f := norm_fone(v_fone); e := norm_email(v_email);
  if e is not null and e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then e := null; v_email := null; end if;
  if f is null and e is null then raise exception 'O lead precisa de e-mail ou telefone válido'; end if;
  em := coalesce(nullif(d->>'em', '')::timestamptz, now());
  if em > now() + interval '1 hour' or em < now() - interval '400 days' then em := now(); end if;
  v_origem := coalesce(nullif(d->>'origem', ''), 'formulario');
  if growth ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select c.id into growth_id from campanhas c where c.workspace_id = w and c.id = growth::uuid;
  end if;
  if jsonb_typeof(d->'utm_growth_candidates') = 'array' then
    select coalesce(array_agg(x.valor::uuid), '{}'::uuid[]) into growth_candidates
    from jsonb_array_elements_text(d->'utm_growth_candidates') as x(valor)
    where x.valor ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  end if;
  if growth_id is null and coalesce(lower(d->>'utm_growth_detectado') in ('false', 'f', '0', 'no'), growth is null) then
    select c.id into growth_id
    from unnest(growth_candidates) with ordinality as candidato(id, ordem)
    join campanhas c on c.id = candidato.id and c.workspace_id = w
    order by candidato.ordem limit 1;
  end if;
  if growth_id is not null then growth := growth_id::text; end if;
  resp := coalesce(d->'respostas', '{}'::jsonb) || jsonb_build_object(
    '_origem', v_origem, '_em', em,
    '_pagina', coalesce(d->>'growth_pagina', d->>'pagina'),
    '_url_entrada', coalesce(d->>'growth_pagina', d->>'pagina'),
    '_pagina_formulario', d->>'pagina_formulario',
    '_utm_growth', growth
  );
  if t is not null then select * into cc from campanha_canais where workspace_id = w and utm_campaign = t; end if;
  if growth_id is not null and cc.campanha_id is distinct from growth_id then cc := null; end if;
  campanha_ref := coalesce(growth_id, cc.campanha_id);
  v_canal := coalesce(cc.canal, case when v_origem = 'meta_lead_ads' then 'meta_ads' end, _canal_de(w, null, d->>'utm_source'));

  if f is not null then select * into p from pessoas where workspace_id = w and telefone_norm = f; end if;
  if p.id is null and e is not null then select * into p from pessoas where workspace_id = w and email_norm = e; end if;
  if p.id is null then
    insert into pessoas (workspace_id, nome, email, telefone, status_funil, utm_source, utm_medium, utm_campaign, utm_content, utm_term,
                         pagina_origem, canal_origem, campanha_id, criado_em, extras)
    values (w, coalesce(v_nome, v_email, v_fone), v_email, v_fone, 'lead', nullif(d->>'utm_source', ''), nullif(d->>'utm_medium', ''), t, nullif(d->>'utm_content', ''), nullif(d->>'utm_term', ''),
            nullif(left(coalesce(d->>'growth_pagina', d->>'pagina', ''), 500), ''), v_canal, campanha_ref, em,
            jsonb_build_object('formulario', resp, 'formularios', jsonb_build_array(resp)))
    returning id into pid;
    nova := true;
  else
    pid := p.id;
    ja := campanha_ref is not null and exists (select 1 from campanha_participacoes where campanha_id = campanha_ref and pessoa_id = pid);
    update pessoas set
      nome = case when coalesce(trim(pessoas.nome), '') = '' or pessoas.nome = pessoas.email or pessoas.nome = pessoas.telefone then coalesce(v_nome, pessoas.nome) else pessoas.nome end,
      telefone = case when telefone_norm is null and f is not null and not exists (select 1 from pessoas x where x.workspace_id = w and x.telefone_norm = f) then v_fone else pessoas.telefone end,
      email = case when email_norm is null and e is not null and not exists (select 1 from pessoas x where x.workspace_id = w and x.email_norm = e) then v_email else pessoas.email end,
      extras = coalesce(extras, '{}'::jsonb) || jsonb_build_object('formulario', coalesce(extras->'formulario', '{}'::jsonb) || resp,
               'formularios', (select coalesce(jsonb_agg(z), '[]'::jsonb) from (select z from jsonb_array_elements(jsonb_build_array(resp) || coalesce(extras->'formularios', '[]'::jsonb)) z limit 10) y))
    where id = pid;
    insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
    values (w, pid, em, 'captura', v_canal, campanha_ref,
            (case when ja then 'Nova tentativa de cadastro (repetida)' else 'Cadastro pelo formulário' end) ||
            case when coalesce(d->>'growth_pagina', d->>'pagina') is not null then ' · URL de entrada: ' || coalesce(d->>'growth_pagina', d->>'pagina') else '' end,
            nullif(d->>'utm_source', ''), nullif(d->>'utm_medium', ''), t, nullif(d->>'utm_content', ''), 'captura', 'captura', gen_random_uuid());
  end if;
  return jsonb_build_object('ok', true, 'pessoa_id', pid, 'nova', nova, 'repetida', ja,
    'campanha', (select x.nome from campanhas x where x.id = campanha_ref),
    'aviso', case
      when growth is not null and growth_id is null then 'utm_growth não corresponde a uma campanha deste workspace.'
      when t is not null and cc.id is null and growth_id is null then 'utm_campaign "' || t || '" não pertence a nenhuma campanha: o lead entrou sem campanha. Crie o canal com esse utm_campaign e use "Religar leads".'
    end);
end $$;
