-- Dados de mídia paga e de vídeo só entram por integração (service role) ou por importação
-- controlada. Ninguém escreve direto nessas tabelas; a importação passa por regras fixas e fica registrada.

create table importacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  tipo text not null check (tipo in ('trafego', 'video_metricas', 'video_presenca')),
  escopo_id uuid not null,                 -- campanha_canal (tráfego) ou vídeo (fonte_video)
  motivo text not null check (motivo in ('primeira_carga', 'recuperacao_falha')),
  justificativa text not null,
  arquivo_nome text,
  arquivo_hash text not null,
  linhas int not null,
  periodo_ini date,
  periodo_fim date,
  totais jsonb not null default '{}'::jsonb,
  status text not null default 'aplicada' check (status in ('aplicada', 'revertida')),
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  revertida_em timestamptz,
  revertida_por uuid,
  motivo_reversao text
);
create unique index importacoes_hash_uq on importacoes (workspace_id, arquivo_hash) where status = 'aplicada';
create index importacoes_ix on importacoes (workspace_id, criado_em desc);
alter table importacoes enable row level security;
create policy importacoes_leitura on importacoes for select to authenticated using (pertence_ao_workspace(workspace_id));
revoke insert, update, delete on importacoes from authenticated;

-- origem de cada linha de métrica
alter table metricas_anuncio_dia add column origem text not null default 'legado' check (origem in ('integracao', 'importacao', 'legado'));
alter table metricas_anuncio_dia add column importacao_id uuid references importacoes(id);
alter table metricas_anuncio_dia alter column origem set default 'integracao';
alter table video_metricas_dia add column origem text not null default 'legado' check (origem in ('integracao', 'importacao', 'legado'));
alter table video_metricas_dia add column importacao_id uuid references importacoes(id);
alter table video_metricas_dia alter column origem set default 'integracao';
alter table presencas_video add column origem text not null default 'legado' check (origem in ('integracao', 'importacao', 'legado'));
alter table presencas_video add column importacao_id uuid references importacoes(id);
alter table presencas_video alter column origem set default 'integracao';

-- ninguém escreve direto: só integração (service role) e as funções abaixo
revoke insert, update, delete on metricas_anuncio_dia from authenticated;
revoke insert, update, delete on video_metricas_dia from authenticated;
revoke insert, update, delete on presencas_video from authenticated;
revoke execute on function registrar_presenca_video(uuid, uuid, text, int, boolean, timestamptz) from authenticated;

-- ---------- regras comuns ----------
create or replace function _importacao_checa(p_ws uuid, p_categoria text, p_tipo text, p_escopo uuid, p_motivo text, p_just text, p_hash text)
returns date language plpgsql security definer set search_path = public as $$
declare ult timestamptz; falha boolean; n int; ini date;
begin
  if not (session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role'
          or exists (select 1 from workspace_membros where workspace_id = p_ws and user_id = auth.uid() and papel = 'admin')) then
    raise exception 'Só quem é administrador do workspace pode importar planilhas';
  end if;
  if p_motivo not in ('primeira_carga', 'recuperacao_falha') then raise exception 'Escolha o motivo: primeira carga ou recuperação de falha'; end if;
  if length(trim(coalesce(p_just, ''))) < 20 then raise exception 'Explique o motivo da importação (mínimo de 20 caracteres)'; end if;
  if coalesce(length(p_hash), 0) < 16 then raise exception 'Arquivo inválido'; end if;
  if exists (select 1 from importacoes where workspace_id = p_ws and arquivo_hash = p_hash and status = 'aplicada') then
    raise exception 'Este mesmo arquivo já foi importado. Reverta a importação anterior se precisar refazer';
  end if;
  if (select count(*) from importacoes where workspace_id = p_ws and criado_em > now() - interval '24 hours') >= 10 then
    raise exception 'Limite de 10 importações por dia neste workspace';
  end if;
  select max(ultima_sincronizacao), coalesce(bool_or(status = 'erro'), false), count(*) into ult, falha, n
    from integracoes where workspace_id = p_ws and categoria = p_categoria;
  if p_motivo = 'primeira_carga' then
    if ult is not null then raise exception 'Esta fonte já sincronizou pela integração. Planilha só vale para recuperar falha de conexão'; end if;
    if exists (select 1 from importacoes where workspace_id = p_ws and tipo = p_tipo and escopo_id = p_escopo and motivo = 'primeira_carga' and status = 'aplicada') then
      raise exception 'A primeira carga deste item já foi feita. Reverta a anterior para refazer';
    end if;
    return null;
  end if;
  if n = 0 then raise exception 'Não há integração registrada para esta categoria. Use "primeira carga"'; end if;
  if ult is null then raise exception 'A integração ainda não sincronizou nenhuma vez. Use "primeira carga"'; end if;
  if not (falha or ult < now() - interval '48 hours') then
    raise exception 'A integração está funcionando (última sincronização em %). Recuperação só vale com falha ou 48 horas sem sincronizar',
      to_char(ult at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI');
  end if;
  ini := (ult at time zone 'America/Sao_Paulo')::date - 1;
  return ini;
end $$;

create or replace function _importacao_registra(p_ws uuid, p_tipo text, p_escopo uuid, p_motivo text, p_just text, p_arquivo text, p_hash text,
                                                p_linhas int, p_ini date, p_fim date, p_totais jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  insert into importacoes (workspace_id, tipo, escopo_id, motivo, justificativa, arquivo_nome, arquivo_hash, linhas, periodo_ini, periodo_fim, totais)
  values (p_ws, p_tipo, p_escopo, p_motivo, trim(p_just), p_arquivo, p_hash, p_linhas, p_ini, p_fim, p_totais) returning id into v_id;
  return v_id;
end $$;

-- ---------- Tráfego ----------
create or replace function importar_trafego(p_ws uuid, p_campanha_canal uuid, p_motivo text, p_just text, p_arquivo text, p_hash text,
                                            p_linhas jsonb, p_simular boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare cc campanha_canais; camp campanhas; gap date; r jsonb; i int := 0; erros text[] := '{}'; hoje date := (now() at time zone 'America/Sao_Paulo')::date;
        d date; u text; imp numeric; clq numeric; cst numeric; lpv numeric; alc numeric; vistos text[] := '{}'; k text;
        dmin date; dmax date; tot_c numeric := 0; tot_i numeric := 0; id_imp uuid; aid uuid;
begin
  select * into cc from campanha_canais where id = p_campanha_canal and workspace_id = p_ws;
  if not found then raise exception 'Campanha e canal não encontrados neste workspace'; end if;
  select * into camp from campanhas where id = cc.campanha_id;
  gap := _importacao_checa(p_ws, 'anuncios', 'trafego', p_campanha_canal, p_motivo, p_just, p_hash);
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'A planilha não tem linhas'; end if;
  if jsonb_array_length(p_linhas) > 5000 then raise exception 'Máximo de 5.000 linhas por importação'; end if;
  for r in select * from jsonb_array_elements(p_linhas) loop
    i := i + 1;
    begin
      d := (r ->> 'data')::date; u := nullif(trim(r ->> 'utm_content'), '');
      imp := (r ->> 'impressoes')::numeric; clq := (r ->> 'cliques')::numeric; cst := (r ->> 'custo')::numeric;
      lpv := (r ->> 'visualizacoes_pagina')::numeric; alc := nullif(r ->> 'alcance', '')::numeric;
    exception when others then erros := erros || ('Linha ' || i || ': valor inválido'); continue; end;
    if u is null then erros := erros || ('Linha ' || i || ': utm_content vazio'); continue; end if;
    if least(imp, clq, cst, lpv) < 0 or coalesce(alc, 0) < 0 then erros := erros || ('Linha ' || i || ': valor negativo'); continue; end if;
    if d > hoje then erros := erros || ('Linha ' || i || ': data no futuro (' || d || ')'); end if;
    if gap is not null and d < gap then erros := erros || ('Linha ' || i || ': data ' || d || ' anterior ao período da falha (a partir de ' || gap || ')'); end if;
    if camp.data_inicio is not null and d < camp.data_inicio - 7 then erros := erros || ('Linha ' || i || ': data ' || d || ' bem antes do início da campanha'); end if;
    if camp.data_fim is not null and d > camp.data_fim + 7 then erros := erros || ('Linha ' || i || ': data ' || d || ' bem depois do fim da campanha'); end if;
    if clq > imp then erros := erros || ('Linha ' || i || ': cliques maiores que impressões'); end if;
    if lpv > clq then erros := erros || ('Linha ' || i || ': visualizações da página maiores que cliques'); end if;
    if alc is not null and alc > imp then erros := erros || ('Linha ' || i || ': alcance maior que impressões'); end if;
    if cst > 50000 then erros := erros || ('Linha ' || i || ': custo diário acima de R$ 50.000 em um anúncio'); end if;
    k := u || '|' || d;
    if k = any(vistos) then erros := erros || ('Linha ' || i || ': anúncio e dia repetidos na planilha'); end if;
    vistos := vistos || k;
    if exists (select 1 from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id
               where a.campanha_canal_id = p_campanha_canal and a.utm_content = u and m.data = d) then
      erros := erros || ('Linha ' || i || ': já existe dado de ' || u || ' em ' || d || ' (reverta a importação anterior se for corrigir)');
    end if;
    dmin := least(dmin, d); dmax := greatest(dmax, d); tot_c := tot_c + cst; tot_i := tot_i + imp;
    exit when array_length(erros, 1) >= 20;
  end loop;
  if dmax - dmin > 400 then erros := erros || 'O período da planilha passa de 400 dias'; end if;
  if array_length(erros, 1) > 0 then return jsonb_build_object('ok', false, 'erros', to_jsonb(erros)); end if;
  r := jsonb_build_object('linhas', i, 'periodo_ini', dmin, 'periodo_fim', dmax, 'custo_total', tot_c, 'impressoes_total', tot_i,
                          'anuncios', (select count(distinct x ->> 'utm_content') from jsonb_array_elements(p_linhas) x));
  if p_simular then return jsonb_build_object('ok', true, 'simulado', true, 'resumo', r); end if;

  id_imp := _importacao_registra(p_ws, 'trafego', p_campanha_canal, p_motivo, p_just, p_arquivo, p_hash, i, dmin, dmax, r);
  for r in select * from jsonb_array_elements(p_linhas) loop
    u := trim(r ->> 'utm_content');
    select an.id into aid from anuncios an where an.campanha_canal_id = p_campanha_canal and an.utm_content = u;
    if aid is null then
      insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content) values (p_ws, p_campanha_canal, u, u) returning id into aid;
    end if;
    insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina, alcance, origem, importacao_id)
    values (p_ws, aid, (r ->> 'data')::date, (r ->> 'impressoes')::int, (r ->> 'cliques')::int, (r ->> 'custo')::numeric,
            (r ->> 'visualizacoes_pagina')::int, nullif(r ->> 'alcance', '')::int, 'importacao', id_imp);
  end loop;
  return jsonb_build_object('ok', true, 'simulado', false, 'importacao_id', id_imp,
    'resumo', (select totais from importacoes where id = id_imp));
end $$;

-- ---------- Métricas de vídeo ----------
create or replace function importar_video_metricas(p_ws uuid, p_fonte uuid, p_motivo text, p_just text, p_arquivo text, p_hash text,
                                                   p_linhas jsonb, p_simular boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f fontes_video; gap date; r jsonb; i int := 0; erros text[] := '{}'; hoje date := (now() at time zone 'America/Sao_Paulo')::date;
        d date; pl numeric; es numeric; mn numeric; rt numeric; co numeric; ct numeric; pk numeric; vistos date[] := '{}';
        dmin date; dmax date; tot_p numeric := 0; id_imp uuid;
begin
  select * into f from fontes_video where id = p_fonte and workspace_id = p_ws;
  if not found then raise exception 'Vídeo não encontrado neste workspace'; end if;
  gap := _importacao_checa(p_ws, 'video', 'video_metricas', p_fonte, p_motivo, p_just, p_hash);
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'A planilha não tem linhas'; end if;
  if jsonb_array_length(p_linhas) > 1000 then raise exception 'Máximo de 1.000 linhas por importação'; end if;
  for r in select * from jsonb_array_elements(p_linhas) loop
    i := i + 1;
    begin
      d := (r ->> 'data')::date; pl := (r ->> 'plays')::numeric; es := (r ->> 'espectadores')::numeric; mn := (r ->> 'minutos_assistidos')::numeric;
      rt := nullif(r ->> 'retencao_pct', '')::numeric; co := (r ->> 'conclusoes')::numeric; ct := (r ->> 'cliques_cta')::numeric; pk := (r ->> 'pico')::numeric;
    exception when others then erros := erros || ('Linha ' || i || ': valor inválido'); continue; end;
    if least(pl, es, mn, co, ct, pk) < 0 then erros := erros || ('Linha ' || i || ': valor negativo'); continue; end if;
    if d > hoje then erros := erros || ('Linha ' || i || ': data no futuro (' || d || ')'); end if;
    if gap is not null and d < gap then erros := erros || ('Linha ' || i || ': data ' || d || ' anterior ao período da falha (a partir de ' || gap || ')'); end if;
    if f.data_evento is not null and (d < f.data_evento - 30 or d > f.data_evento + 120) then erros := erros || ('Linha ' || i || ': data ' || d || ' muito longe do evento (' || f.data_evento || ')'); end if;
    if es > pl then erros := erros || ('Linha ' || i || ': espectadores maiores que plays'); end if;
    if co > es then erros := erros || ('Linha ' || i || ': conclusões maiores que espectadores'); end if;
    if rt is not null and (rt < 0 or rt > 100) then erros := erros || ('Linha ' || i || ': retenção fora de 0 a 100'); end if;
    if es > 0 and mn * 60 / es > 86400 then erros := erros || ('Linha ' || i || ': tempo assistido por espectador impossível'); end if;
    if d = any(vistos) then erros := erros || ('Linha ' || i || ': dia repetido na planilha'); end if;
    vistos := vistos || d;
    if exists (select 1 from video_metricas_dia vm where vm.fonte_id = p_fonte and vm.data = d) then
      erros := erros || ('Linha ' || i || ': já existe dado de ' || d || ' (reverta a importação anterior se for corrigir)');
    end if;
    dmin := least(dmin, d); dmax := greatest(dmax, d); tot_p := tot_p + pl;
    exit when array_length(erros, 1) >= 20;
  end loop;
  if array_length(erros, 1) > 0 then return jsonb_build_object('ok', false, 'erros', to_jsonb(erros)); end if;
  r := jsonb_build_object('linhas', i, 'periodo_ini', dmin, 'periodo_fim', dmax, 'plays_total', tot_p);
  if p_simular then return jsonb_build_object('ok', true, 'simulado', true, 'resumo', r); end if;
  id_imp := _importacao_registra(p_ws, 'video_metricas', p_fonte, p_motivo, p_just, p_arquivo, p_hash, i, dmin, dmax, r);
  insert into video_metricas_dia (workspace_id, fonte_id, data, plays, espectadores, tempo_assistido_seg, retencao_pct, conclusoes, cliques_cta, pico_simultaneo, origem, importacao_id)
  select p_ws, p_fonte, (x ->> 'data')::date, (x ->> 'plays')::int, (x ->> 'espectadores')::int, round((x ->> 'minutos_assistidos')::numeric * 60),
         nullif(x ->> 'retencao_pct', '')::numeric, (x ->> 'conclusoes')::int, (x ->> 'cliques_cta')::int, (x ->> 'pico')::int, 'importacao', id_imp
  from jsonb_array_elements(p_linhas) x;
  return jsonb_build_object('ok', true, 'simulado', false, 'importacao_id', id_imp, 'resumo', r);
end $$;

-- ---------- Presença em vídeo ----------
create or replace function importar_video_presenca(p_ws uuid, p_fonte uuid, p_motivo text, p_just text, p_arquivo text, p_hash text,
                                                   p_linhas jsonb, p_simular boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare f fontes_video; r jsonb; i int := 0; erros text[] := '{}'; em text; mn numeric; pid uuid; vistos text[] := '{}'; id_imp uuid; gap date;
begin
  select * into f from fontes_video where id = p_fonte and workspace_id = p_ws;
  if not found then raise exception 'Vídeo não encontrado neste workspace'; end if;
  gap := _importacao_checa(p_ws, 'video', 'video_presenca', p_fonte, p_motivo, p_just, p_hash);
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'A planilha não tem linhas'; end if;
  if jsonb_array_length(p_linhas) > 5000 then raise exception 'Máximo de 5.000 linhas por importação'; end if;
  for r in select * from jsonb_array_elements(p_linhas) loop
    i := i + 1; em := lower(trim(coalesce(r ->> 'email', '')));
    begin mn := (r ->> 'minutos')::numeric; exception when others then erros := erros || ('Linha ' || i || ': minutos inválidos'); continue; end;
    if em = '' or mn < 0 or mn > 600 then erros := erros || ('Linha ' || i || ': e-mail vazio ou minutos fora de 0 a 600'); continue; end if;
    if em = any(vistos) then erros := erros || ('Linha ' || i || ': e-mail repetido (' || em || ')'); end if;
    vistos := vistos || em;
    select pe.id into pid from pessoas pe where pe.workspace_id = p_ws and lower(pe.email) = em;
    if pid is null then erros := erros || ('Linha ' || i || ': ' || em || ' não está no cadastro de pessoas'); 
    elsif exists (select 1 from presencas_video pv where pv.fonte_id = p_fonte and pv.pessoa_id = pid) then erros := erros || ('Linha ' || i || ': ' || em || ' já tem presença registrada');
    end if;
    exit when array_length(erros, 1) >= 20;
  end loop;
  if array_length(erros, 1) > 0 then return jsonb_build_object('ok', false, 'erros', to_jsonb(erros)); end if;
  r := jsonb_build_object('linhas', i);
  if p_simular then return jsonb_build_object('ok', true, 'simulado', true, 'resumo', r); end if;
  id_imp := _importacao_registra(p_ws, 'video_presenca', p_fonte, p_motivo, p_just, p_arquivo, p_hash, i, null, null, r);
  insert into presencas_video (workspace_id, fonte_id, pessoa_id, assistiu_seg, ao_vivo, origem, importacao_id)
  select p_ws, p_fonte, (select pe.id from pessoas pe where pe.workspace_id = p_ws and lower(pe.email) = lower(trim(x ->> 'email'))),
         round((x ->> 'minutos')::numeric * 60), coalesce((x ->> 'ao_vivo')::boolean, false), 'importacao', id_imp
  from jsonb_array_elements(p_linhas) x;
  return jsonb_build_object('ok', true, 'simulado', false, 'importacao_id', id_imp, 'resumo', r);
end $$;

-- ---------- Reverter uma importação ----------
create or replace function reverter_importacao(p_id uuid, p_motivo text) returns int
language plpgsql security definer set search_path = public as $$
declare im importacoes; n int;
begin
  select * into im from importacoes where id = p_id for update;
  if not found then raise exception 'Importação não encontrada'; end if;
  if not (session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role'
          or exists (select 1 from workspace_membros where workspace_id = im.workspace_id and user_id = auth.uid() and papel = 'admin')) then
    raise exception 'Só quem é administrador do workspace pode reverter importações';
  end if;
  if im.status <> 'aplicada' then raise exception 'Esta importação já foi revertida'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 10 then raise exception 'Explique por que está revertendo (mínimo de 10 caracteres)'; end if;
  if im.tipo = 'trafego' then delete from metricas_anuncio_dia where importacao_id = im.id;
  elsif im.tipo = 'video_metricas' then delete from video_metricas_dia where importacao_id = im.id;
  else delete from presencas_video where importacao_id = im.id; end if;
  get diagnostics n = row_count;
  update importacoes set status = 'revertida', revertida_em = now(), revertida_por = auth.uid(), motivo_reversao = trim(p_motivo) where id = im.id;
  return n;
end $$;

revoke execute on function _importacao_checa(uuid, text, text, uuid, text, text, text) from public, anon, authenticated;
revoke execute on function _importacao_registra(uuid, text, uuid, text, text, text, text, int, date, date, jsonb) from public, anon, authenticated;
revoke execute on function importar_trafego(uuid, uuid, text, text, text, text, jsonb, boolean) from public, anon;
revoke execute on function importar_video_metricas(uuid, uuid, text, text, text, text, jsonb, boolean) from public, anon;
revoke execute on function importar_video_presenca(uuid, uuid, text, text, text, text, jsonb, boolean) from public, anon;
revoke execute on function reverter_importacao(uuid, text) from public, anon;
grant execute on function importar_trafego(uuid, uuid, text, text, text, text, jsonb, boolean) to authenticated;
grant execute on function importar_video_metricas(uuid, uuid, text, text, text, text, jsonb, boolean) to authenticated;
grant execute on function importar_video_presenca(uuid, uuid, text, text, text, text, jsonb, boolean) to authenticated;
grant execute on function reverter_importacao(uuid, text) to authenticated;
