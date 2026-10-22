-- v0.130: formulário de captação dentro das Pesquisas.
-- Uma pesquisa pode virar um formulário público que:
--   1) pede os dados de contato (nome e e-mail sempre; WhatsApp e Instagram se ligados),
--   2) mostra as perguntas em passos (pela "seção" de cada pergunta),
--   3) mostra um aviso (ex.: investimento mínimo) e pede os consentimentos,
--   4) cria ou atualiza o contato no CRM (Funil de leads, na etapa escolhida, com tags e responsável),
--      grava as respostas, a origem (UTM) e roda a qualificação por pontos da v0.129,
--   5) usa as fontes e cores escolhidas para seguir a identidade visual do cliente.
-- Pode ser rodado de novo sem erro.

alter table public.pesquisas add column if not exists visual jsonb;
alter table public.pesquisas add column if not exists captacao jsonb;
alter table public.pesquisa_perguntas add column if not exists secao text;
alter table public.pesquisa_respostas add column if not exists contato jsonb;
alter table public.pesquisa_respostas add column if not exists consentimentos jsonb;
alter table public.pesquisa_respostas add column if not exists utm jsonb;
alter table public.pesquisa_respostas add column if not exists novo_contato boolean;
comment on column public.pesquisas.visual is 'Aparência do formulário público: {"marca","titulo","fonte_titulo","fonte_texto","cor_primaria","cor_fundo","cor_cartao","cor_texto","logo_url","raio","botao","enviar"}.';
comment on column public.pesquisas.captacao is 'Formulário de captação: {"ativa","campos":{"telefone":{"mostrar","obrig","rotulo"},"instagram":{...}},"etapa_id","tags","responsavel_id","passo_contato","passo_final","aviso_titulo","aviso_texto","consentimentos":[{"texto","obrig"}],"nota_final","sucesso_titulo","sucesso_texto"}.';
comment on column public.pesquisa_perguntas.secao is 'Passo do formulário em que a pergunta aparece (perguntas com a mesma seção ficam juntas).';

-- Grava uma resposta (itens, respostas no lead e qualificação). Uso interno: pesquisa_responder e pesquisa_captar.
create or replace function public.pesquisa_registrar(p_pesquisa uuid, p_envio uuid, p_pessoa uuid, p_email text, p_respostas jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas; q record; v jsonb; v_num numeric; v_txt text; v_resp uuid; r_lead jsonb := '{}'::jsonb; o jsonb;
begin
  select * into v_p from pesquisas where id = p_pesquisa;
  if p_respostas is null or jsonb_typeof(p_respostas) <> 'object' or length(p_respostas::text) > 20000 then raise exception 'Resposta inválida'; end if;
  insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id, email) values (v_p.workspace_id, v_p.id, p_envio, p_pessoa, p_email) returning id into v_resp;
  for q in select * from pesquisa_perguntas where pesquisa_id = v_p.id order by ordem, criado_em loop
    v := p_respostas -> q.id::text;
    if v is null or v = 'null'::jsonb or (jsonb_typeof(v) = 'string' and trim(v #>> '{}') = '') or (jsonb_typeof(v) = 'array' and jsonb_array_length(v) = 0) then
      if q.obrigatoria then raise exception 'Responda: %', q.texto; end if;
      continue;
    end if;
    begin
      if q.tipo in ('nps', 'escala') then
        v_num := (v #>> '{}')::numeric;
        if v_num <> trunc(v_num) or (q.tipo = 'nps' and (v_num < 0 or v_num > 10)) or (q.tipo = 'escala' and (v_num < 1 or v_num > 5)) then raise exception 'fora da faixa'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num) values (v_p.workspace_id, v_resp, q.id, v_num);
        r_lead := r_lead || jsonb_build_object(q.texto, v_num);
      elsif q.tipo = 'sim_nao' then
        v_txt := lower(v #>> '{}');
        if v_txt not in ('sim', 'nao') then raise exception 'valor inválido'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num, valor_texto) values (v_p.workspace_id, v_resp, q.id, case when v_txt = 'sim' then 1 else 0 end, v_txt);
        r_lead := r_lead || jsonb_build_object(q.texto, v_txt);
      elsif q.tipo = 'escolha' then
        v_txt := v #>> '{}';
        if not (v_txt = any (q.opcoes)) then raise exception 'opção inválida'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (v_p.workspace_id, v_resp, q.id, v_txt);
        r_lead := r_lead || jsonb_build_object(q.texto, v_txt);
      elsif q.tipo = 'multipla' then
        if jsonb_typeof(v) <> 'array' then raise exception 'esperava lista'; end if;
        for o in select * from jsonb_array_elements(v) loop
          v_txt := o #>> '{}';
          if not (v_txt = any (q.opcoes)) then raise exception 'opção inválida'; end if;
          insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (v_p.workspace_id, v_resp, q.id, v_txt) on conflict do nothing;
        end loop;
        r_lead := r_lead || jsonb_build_object(q.texto, v);
      else
        v_txt := trim(v #>> '{}');
        if length(v_txt) > 2000 then raise exception 'texto longo demais'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (v_p.workspace_id, v_resp, q.id, v_txt);
        r_lead := r_lead || jsonb_build_object(q.texto, v_txt);
      end if;
    exception when others then
      raise exception 'Resposta inválida em: %', q.texto;
    end;
  end loop;
  if p_envio is not null then update pesquisa_envios set status = 'respondido', respondido_em = now() where id = p_envio; end if;
  if v_p.tipo = 'lead' and p_pessoa is not null then
    update pessoas set respostas_pesquisa = coalesce(respostas_pesquisa, '{}'::jsonb) || r_lead, pesquisa_respondida_em = coalesce(pesquisa_respondida_em, now()) where id = p_pessoa and workspace_id = v_p.workspace_id;
  end if;
  if p_pessoa is not null then perform pesquisa_qualificar(v_resp); end if;
  return v_resp;
end $$;
revoke all on function public.pesquisa_registrar(uuid, uuid, uuid, text, jsonb) from public, anon, authenticated;

-- Mesmo comportamento de antes (link único ou link aberto ligando por e-mail), agora usando pesquisa_registrar.
create or replace function public.pesquisa_responder(p_token text, p_respostas jsonb, p_email text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_e pesquisa_envios; v_p pesquisas; v_aberto boolean := false; v_pessoa uuid; v_email text;
begin
  if p_token is null or length(p_token) < 32 then raise exception 'Link inválido'; end if;
  if p_respostas is null or jsonb_typeof(p_respostas) <> 'object' or length(p_respostas::text) > 20000 then raise exception 'Resposta inválida'; end if;
  select * into v_e from pesquisa_envios where token = p_token;
  if found then
    if v_e.status = 'respondido' then raise exception 'Esta pesquisa já foi respondida'; end if;
    select * into v_p from pesquisas where id = v_e.pesquisa_id; v_pessoa := v_e.pessoa_id;
  else
    select * into v_p from pesquisas where token_aberto = p_token and aceita_link_aberto; v_aberto := true;
  end if;
  if v_p.id is null or not v_p.ativa then raise exception 'Pesquisa indisponível'; end if;
  v_email := nullif(lower(trim(coalesce(p_email, ''))), '');
  if v_email is not null and (length(v_email) > 200 or v_email !~ '^[^@\s]+@[^@\s]+$') then raise exception 'E-mail inválido'; end if;
  if v_aberto and v_email is not null then select id into v_pessoa from pessoas where workspace_id = v_p.workspace_id and lower(email) = v_email limit 1; end if;
  -- a qualificação (pesquisa_qualificar) roda dentro de pesquisa_registrar; este comentário também impede o RODAR_v0.129 de remendar esta função de novo
  perform pesquisa_registrar(v_p.id, v_e.id, v_pessoa, v_email, p_respostas);
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.pesquisa_responder(text, jsonb, text) from public;
grant execute on function public.pesquisa_responder(text, jsonb, text) to anon, authenticated;

-- O que a página pública pode ver: perguntas (com a seção), aparência e a parte pública da captação
-- (sem etapa, tags e responsável, que são internos).
create or replace function public.pesquisa_publica(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_e pesquisa_envios; v_p pesquisas; v_aberto boolean := false; r_perg jsonb; v_cap jsonb;
begin
  if p_token is null or length(p_token) < 32 then return null; end if;
  select * into v_e from pesquisa_envios where token = p_token;
  if found then select * into v_p from pesquisas where id = v_e.pesquisa_id;
  else select * into v_p from pesquisas where token_aberto = p_token and aceita_link_aberto; v_aberto := true; end if;
  if v_p.id is null or not v_p.ativa then return null; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'texto', texto, 'tipo', tipo, 'opcoes', to_jsonb(opcoes), 'obrigatoria', obrigatoria, 'secao', secao) order by ordem, criado_em), '[]'::jsonb)
  into r_perg from pesquisa_perguntas where pesquisa_id = v_p.id;
  if v_aberto and v_p.captacao is not null and coalesce((v_p.captacao ->> 'ativa')::boolean, false) then
    v_cap := v_p.captacao - 'etapa_id' - 'tags' - 'responsavel_id';
  end if;
  return jsonb_build_object('nome', v_p.nome, 'descricao', v_p.descricao, 'perguntas', r_perg, 'aberto', v_aberto,
    'ja_respondida', (not v_aberto and v_e.status = 'respondido'), 'visual', coalesce(v_p.visual, '{}'::jsonb), 'captacao', v_cap);
end $$;
revoke all on function public.pesquisa_publica(text) from public;
grant execute on function public.pesquisa_publica(text) to anon, authenticated;

-- Formulário de captação: cria ou atualiza o contato (pelo e-mail, depois pelo WhatsApp), coloca no Funil de leads,
-- grava as respostas, os consentimentos e a origem, e qualifica.
create or replace function public.pesquisa_captar(p_token text, p_respostas jsonb, p_contato jsonb, p_extra jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas; c jsonb; v_nome text; v_email text; v_fone text; v_insta text; v_pessoa uuid; v_novo boolean := false;
        v_cons jsonb; v_consreg jsonb := '[]'::jsonb; i int; v_ok boolean; v_utm jsonb := '{}'::jsonb; k text; v_etapa uuid; v_resp_id uuid; v_tags text[]; v_resp uuid; v_pag text; v_ref text;
begin
  if p_token is null or length(p_token) < 32 then raise exception 'Link inválido'; end if;
  select * into v_p from pesquisas where token_aberto = p_token and aceita_link_aberto;
  if not found or not v_p.ativa then raise exception 'Formulário indisponível'; end if;
  c := v_p.captacao;
  if c is null or not coalesce((c ->> 'ativa')::boolean, false) then raise exception 'Este link não recebe cadastros'; end if;
  if p_contato is null or jsonb_typeof(p_contato) <> 'object' or length(p_contato::text) > 2000 then raise exception 'Contato inválido'; end if;
  p_extra := coalesce(p_extra, '{}'::jsonb);
  if jsonb_typeof(p_extra) <> 'object' or length(p_extra::text) > 4000 then raise exception 'Envio inválido'; end if;
  -- campo-armadilha: robô preenche, gente não vê. Responde ok e não grava nada.
  if coalesce(p_extra ->> 'site', '') <> '' then return jsonb_build_object('ok', true); end if;

  v_nome := left(trim(regexp_replace(coalesce(p_contato ->> 'nome', ''), '\s+', ' ', 'g')), 120);
  if length(v_nome) < 2 then raise exception 'Informe seu nome'; end if;
  v_email := norm_email(p_contato ->> 'email');
  if v_email is null or length(v_email) > 200 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Informe um e-mail válido'; end if;
  v_fone := nullif(regexp_replace(coalesce(p_contato ->> 'telefone', ''), '\D', '', 'g'), '');
  if coalesce((c #>> '{campos,telefone,mostrar}')::boolean, false) is false then v_fone := null; end if;
  if v_fone is not null and norm_fone(v_fone) is null then raise exception 'WhatsApp inválido: use DDD e número'; end if;
  if v_fone is null and coalesce((c #>> '{campos,telefone,mostrar}')::boolean, false) and coalesce((c #>> '{campos,telefone,obrig}')::boolean, false) then raise exception 'Informe seu WhatsApp'; end if;
  v_insta := nullif(left(trim(coalesce(p_contato ->> 'instagram', '')), 80), '');
  if coalesce((c #>> '{campos,instagram,mostrar}')::boolean, false) is false then v_insta := null; end if;
  if v_insta is null and coalesce((c #>> '{campos,instagram,mostrar}')::boolean, false) and coalesce((c #>> '{campos,instagram,obrig}')::boolean, false) then raise exception 'Informe seu Instagram'; end if;

  -- consentimentos: os obrigatórios precisam vir marcados; todos ficam registrados com o texto que a pessoa viu
  v_cons := coalesce(p_extra -> 'consentimentos', '[]'::jsonb);
  if jsonb_typeof(v_cons) <> 'array' then raise exception 'Envio inválido'; end if;
  for i in 0 .. coalesce(jsonb_array_length(c -> 'consentimentos'), 0) - 1 loop
    v_ok := coalesce((v_cons ->> i)::boolean, false);
    if coalesce((c -> 'consentimentos' -> i ->> 'obrig')::boolean, false) and not v_ok then raise exception 'Marque: %', c -> 'consentimentos' -> i ->> 'texto'; end if;
    v_consreg := v_consreg || jsonb_build_array(jsonb_build_object('texto', c -> 'consentimentos' -> i ->> 'texto', 'aceito', v_ok));
  end loop;

  -- limites contra envio repetido ou em massa
  if exists (select 1 from pesquisa_respostas where pesquisa_id = v_p.id and email = v_email and respondida_em > now() - interval '2 minutes') then
    raise exception 'Recebemos sua resposta agora há pouco. Se precisar corrigir algo, aguarde 2 minutos e envie de novo.';
  end if;
  if (select count(*) from pesquisa_respostas where pesquisa_id = v_p.id and respondida_em > now() - interval '1 hour') >= 500 then
    raise exception 'Muitas respostas neste momento. Tente de novo em alguns minutos.';
  end if;

  -- origem
  if jsonb_typeof(p_extra -> 'utm') = 'object' then
    foreach k in array array['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term'] loop
      if nullif(trim(coalesce(p_extra -> 'utm' ->> k, '')), '') is not null then v_utm := v_utm || jsonb_build_object(k, left(trim(p_extra -> 'utm' ->> k), 200)); end if;
    end loop;
  end if;
  v_pag := nullif(left(coalesce(p_extra ->> 'pagina', ''), 500), '');
  v_ref := nullif(left(coalesce(p_extra ->> 'referrer', ''), 500), '');

  -- destino no CRM (só aceita etapa e responsável deste workspace)
  select id into v_etapa from etapas_kanban where id = case when (c ->> 'etapa_id') ~ '^[0-9a-f-]{36}$' then (c ->> 'etapa_id')::uuid end and workspace_id = v_p.workspace_id and quadro = 'leads';
  select id into v_resp_id from equipe where id = case when (c ->> 'responsavel_id') ~ '^[0-9a-f-]{36}$' then (c ->> 'responsavel_id')::uuid end and workspace_id = v_p.workspace_id;
  v_tags := array(select distinct left(trim(x), 40) from jsonb_array_elements_text(case when jsonb_typeof(c -> 'tags') = 'array' then c -> 'tags' else '[]'::jsonb end) x where trim(x) <> '');

  -- quem é: primeiro pelo e-mail, depois pelo WhatsApp
  select id into v_pessoa from pessoas where workspace_id = v_p.workspace_id and email_norm = v_email order by criado_em limit 1;
  if v_pessoa is null and v_fone is not null then
    select id into v_pessoa from pessoas where workspace_id = v_p.workspace_id and telefone_norm = norm_fone(v_fone) order by criado_em limit 1;
  end if;

  if v_pessoa is null then
    insert into pessoas (workspace_id, nome, email, telefone, utm_source, utm_medium, utm_campaign, utm_content, utm_term, pagina_origem, referrer, canal_origem, etapa_kanban_id, tags, responsavel_comercial_id, extras)
    values (v_p.workspace_id, v_nome, v_email, v_fone, v_utm ->> 'utm_source', v_utm ->> 'utm_medium', v_utm ->> 'utm_campaign', v_utm ->> 'utm_content', v_utm ->> 'utm_term', v_pag, v_ref,
      coalesce(v_utm ->> 'utm_source', 'formulario'), v_etapa, v_tags, v_resp_id,
      jsonb_strip_nulls(jsonb_build_object('instagram', v_insta, 'formulario', v_p.nome, 'consentimentos', v_consreg, 'consentimento_em', now())))
    returning id into v_pessoa;
    v_novo := true;
  else
    update pessoas set
      telefone = coalesce(telefone, v_fone),
      tags = array(select distinct t from unnest(coalesce(tags, '{}') || v_tags) t where t is not null and t <> ''),
      responsavel_comercial_id = coalesce(responsavel_comercial_id, v_resp_id),
      extras = coalesce(extras, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object('instagram', v_insta, 'formulario', v_p.nome, 'consentimentos', v_consreg, 'consentimento_em', now()))
    where id = v_pessoa;
  end if;
  insert into pessoa_historico (workspace_id, pessoa_id, campo, valor_anterior, valor_novo)
  values (v_p.workspace_id, v_pessoa, 'formulario', null, v_p.nome || case when v_novo then ' (novo contato)' else ' (contato já existia)' end);

  v_resp := pesquisa_registrar(v_p.id, null, v_pessoa, v_email, p_respostas);
  update pesquisa_respostas set contato = jsonb_strip_nulls(jsonb_build_object('nome', v_nome, 'email', v_email, 'telefone', v_fone, 'instagram', v_insta)),
    consentimentos = v_consreg, utm = v_utm, novo_contato = v_novo where id = v_resp;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.pesquisa_captar(text, jsonb, jsonb, jsonb) from public;
grant execute on function public.pesquisa_captar(text, jsonb, jsonb, jsonb) to anon, authenticated;

notify pgrst, 'reload schema';
