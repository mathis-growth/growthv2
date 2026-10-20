-- JÁ APLICADO em produção em 17/10/2026 (via Supabase). Guardado para registro / para outro projeto. Pode rodar de novo sem problema.
-- v0.113 — Captura de leads por endereço (edge function "leads")
-- 1. chaves_api ganha o escopo 'leads': uma chave só para receber leads (pode ficar no HTML da página de captura).
--    Ela não serve para ideias nem para ler nada; a de ideias não serve para leads.
-- 2. lead_por_chave(chave, dados): grava o lead no workspace da chave, do mesmo jeito que o cadastro manual.
--    Pessoa nova entra pelo cadastro (com UTMs); quem já existe (mesmo telefone ou e-mail) ganha um toque de "captura",
--    e nova tentativa na mesma campanha soma em "repetidas". A campanha vem do utm_campaign (canal da campanha).
--    As respostas ficam em pessoas.extras.formulario (somadas; a mais nova vence) e extras.formularios (os 10 últimos envios).
-- 3. campanha_religar_leads(campanha): liga à campanha os leads que chegaram ANTES de ela existir (pelo utm_campaign).
-- Rode DEPOIS de 20261012300000_ideias_chatgpt.sql. Idempotente.

alter table chaves_api drop constraint if exists chaves_api_escopo_check;
alter table chaves_api add constraint chaves_api_escopo_check check (escopo in ('ideias', 'leads', 'vendas'));

create or replace function public.chave_api_criar_escopo(p_ws uuid, p_nome text, p_escopo text) returns text
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  if p_escopo not in ('ideias', 'leads', 'vendas') then raise exception 'Escopo inválido'; end if;
  if auth.uid() is null or not perm(p_ws, 'editar', '{mkt}'::text[]) then raise exception 'Só quem edita o Marketing deste workspace pode gerar chave'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome para a chave (ex.: Página de captura)'; end if;
  k := 'gw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into chaves_api (workspace_id, nome, escopo, prefixo, hash) values (p_ws, trim(p_nome), p_escopo, left(k, 9), chave_api_hash(k));
  return k;
end $$;

create or replace function public.chave_api_ws_escopo(p_chave text, p_escopo text) returns uuid
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  update chaves_api set ultimo_uso = now(), usos = usos + 1
   where hash = chave_api_hash(p_chave) and revogada_em is null and escopo = p_escopo
  returning workspace_id into w;
  if w is null then raise exception 'Chave inválida ou revogada' using errcode = '28000'; end if;
  return w;
end $$;

-- p_dados: { nome, email, telefone, utm_source, utm_medium, utm_campaign, utm_content, utm_term, pagina, origem, em, respostas: {...} }
create or replace function public.lead_por_chave(p_chave text, p_dados jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  w uuid; d jsonb := coalesce(p_dados, '{}'::jsonb); v_nome text; v_email text; v_fone text; f text; e text; em timestamptz;
  cc campanha_canais; p pessoas; pid uuid; nova boolean := false; ja boolean := false; resp jsonb; v_origem text; v_canal text;
  t text := nullif(trim(coalesce(d->>'utm_campaign', '')), '');
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
  resp := coalesce(d->'respostas', '{}'::jsonb) || jsonb_build_object('_origem', v_origem, '_em', em, '_pagina', d->>'pagina');
  if t is not null then select * into cc from campanha_canais where workspace_id = w and utm_campaign = t; end if;
  v_canal := coalesce(cc.canal, case when v_origem = 'meta_lead_ads' then 'meta_ads' end, _canal_de(w, null, d->>'utm_source'));
  -- mesma regra de pessoa_resolver: telefone primeiro, depois e-mail
  if f is not null then select * into p from pessoas where workspace_id = w and telefone_norm = f; end if;
  if p.id is null and e is not null then select * into p from pessoas where workspace_id = w and email_norm = e; end if;
  if p.id is null then
    insert into pessoas (workspace_id, nome, email, telefone, status_funil, utm_source, utm_medium, utm_campaign, utm_content, utm_term,
                         pagina_origem, canal_origem, campanha_id, criado_em, extras)
    values (w, coalesce(v_nome, v_email, v_fone), v_email, v_fone, 'lead', nullif(d->>'utm_source', ''), nullif(d->>'utm_medium', ''), t, nullif(d->>'utm_content', ''), nullif(d->>'utm_term', ''),
            nullif(left(coalesce(d->>'pagina', ''), 500), ''), v_canal, cc.campanha_id, em,
            jsonb_build_object('formulario', resp, 'formularios', jsonb_build_array(resp)))
    returning id into pid;
    nova := true;
  else
    pid := p.id;
    ja := cc.campanha_id is not null and exists (select 1 from campanha_participacoes where campanha_id = cc.campanha_id and pessoa_id = pid);
    update pessoas set
      nome = case when coalesce(trim(pessoas.nome), '') = '' or pessoas.nome = pessoas.email or pessoas.nome = pessoas.telefone then coalesce(v_nome, pessoas.nome) else pessoas.nome end,
      telefone = case when telefone_norm is null and f is not null and not exists (select 1 from pessoas x where x.workspace_id = w and x.telefone_norm = f) then v_fone else pessoas.telefone end,
      email = case when email_norm is null and e is not null and not exists (select 1 from pessoas x where x.workspace_id = w and x.email_norm = e) then v_email else pessoas.email end,
      extras = coalesce(extras, '{}'::jsonb) || jsonb_build_object('formulario', coalesce(extras->'formulario', '{}'::jsonb) || resp,
               'formularios', (select coalesce(jsonb_agg(z), '[]'::jsonb) from (select z from jsonb_array_elements(jsonb_build_array(resp) || coalesce(extras->'formularios', '[]'::jsonb)) z limit 10) y))
    where id = pid;
    insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
    values (w, pid, em, 'captura', v_canal, cc.campanha_id, case when ja then 'Nova tentativa de cadastro (repetida)' else 'Cadastro pelo formulário' end,
            nullif(d->>'utm_source', ''), nullif(d->>'utm_medium', ''), t, nullif(d->>'utm_content', ''), 'captura', 'captura', gen_random_uuid());
  end if;
  return jsonb_build_object('ok', true, 'pessoa_id', pid, 'nova', nova, 'repetida', ja,
    'campanha', (select x.nome from campanhas x where x.id = cc.campanha_id),
    'aviso', case when t is not null and cc.id is null then 'utm_campaign "' || t || '" não pertence a nenhuma campanha: o lead entrou sem campanha. Crie o canal com esse utm_campaign e use "Religar leads".' end);
end $$;

-- leads que chegaram antes de a campanha (ou o canal com o utm_campaign) existir
create or replace function public.campanha_religar_leads(p_campanha uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare c campanhas; n int;
begin
  select * into c from campanhas where id = p_campanha;
  if not found then raise exception 'Campanha não encontrada'; end if;
  if not pode_editar(c.workspace_id, '{mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  with alvo as (
    select p.*, cc.canal cc_canal from pessoas p join campanha_canais cc on cc.workspace_id = p.workspace_id and cc.utm_campaign = p.utm_campaign
     where cc.campanha_id = c.id and p.workspace_id = c.workspace_id
       and not exists (select 1 from campanha_participacoes cp where cp.campanha_id = c.id and cp.pessoa_id = p.id)),
  ins as (
    insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
    select workspace_id, id, criado_em, 'captura', cc_canal, c.id, 'Ligado à campanha depois (religar leads)', utm_source, utm_medium, utm_campaign, utm_content, 'captura', 'religar', gen_random_uuid() from alvo
    returning pessoa_id)
  select count(*) into n from ins;
  update pessoas p set campanha_id = c.id
   where p.workspace_id = c.workspace_id and p.campanha_id is null
     and p.utm_campaign in (select utm_campaign from campanha_canais where campanha_id = c.id);
  return n;
end $$;

revoke execute on function public.chave_api_criar_escopo(uuid, text, text) from public, anon;
grant execute on function public.chave_api_criar_escopo(uuid, text, text) to authenticated;
revoke execute on function public.chave_api_ws_escopo(text, text) from public, anon, authenticated;
revoke execute on function public.lead_por_chave(text, jsonb) from public;
grant execute on function public.lead_por_chave(text, jsonb) to anon, authenticated;
revoke execute on function public.campanha_religar_leads(uuid) from public, anon;
grant execute on function public.campanha_religar_leads(uuid) to authenticated;
