-- v0.233 — Qualificação por pontos em blocos, com regras de produto e respostas eliminatórias.
-- Pedido da Rebecka (02/11): pontuar a qualificação do lead para saber a qual produto ele é mais elegível (Starter, Strategy, Full Brain)
-- e criar as tags.
-- O que muda na regra de pontos (pesquisas.qualif e pesquisa_perguntas.pontos), tudo opcional (regras antigas continuam iguais):
--   pontos.bloco                 nome do bloco da pergunta (ex.: "Porte", "Estrutura", "Momento"); a pontuação de cada bloco é somada à parte
--   pontos.opcoes.<op>.elim      resposta eliminatória: a pessoa fica "não qualificada" e não recebe as tags das regras (só a tag da opção)
--   qualif.grupos                [{nome, regras: [{tag, se: {"<bloco>"|"total": {min, max}}}]}] — em cada grupo vale a primeira regra que bater;
--                                as tags das outras regras do grupo saem da pessoa
--   qualif.confere               {pediu: "pediu: ", indicado: "qualif: ", tag: "qualif: revisar"} — quando o que a pessoa pediu
--                                ("pediu: strategy") não bate com o indicado ("qualif: starter"), põe a tag de revisar
-- A conta de cada resposta fica em pesquisa_respostas.qualif_det (blocos, total, regras que bateram), para mostrar na tela.
-- Aditivo e idempotente. Rode depois de 20261226100000_atendimento_canal_avatar.sql (ou a qualquer momento depois da v0.129).

alter table public.pesquisa_respostas add column if not exists qualif_det jsonb;

create or replace function public.pesquisa_qualificar(p_resposta uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_r pesquisa_respostas; v_p pesquisas; q record; it record; v_cfg jsonb; v_pts numeric := 0; v_n int := 0; v_tags text[] := '{}'; v_tag text;
        v_cont boolean; v_um numeric; v_final numeric; v_corte numeric; v_qual text; v_faixa jsonb; v_ftag text; v_ftodas text[] := '{}';
        v_op jsonb; v_bloco text; v_blocos jsonb := '{}'::jsonb; v_elim boolean := false; g jsonb; rg jsonb; v_ok boolean; c record; v_val numeric;
        v_gtags text[] := '{}'; v_gtodas text[] := '{}'; v_ganhou jsonb := '{}'::jsonb; v_cf jsonb; v_ped text; v_ind text; v_det jsonb;
begin
  select * into v_r from pesquisa_respostas where id = p_resposta; if not found or v_r.pessoa_id is null then return null; end if;
  select * into v_p from pesquisas where id = v_r.pesquisa_id; v_cfg := v_p.qualif;
  if v_cfg is null or coalesce((v_cfg ->> 'ativa')::boolean, false) is false then return null; end if;
  for q in select * from pesquisa_perguntas where pesquisa_id = v_p.id and pontos is not null loop
    v_cont := false; v_um := 0; v_bloco := nullif(btrim(q.pontos ->> 'bloco'), '');
    for it in select * from pesquisa_resposta_itens where resposta_id = v_r.id and pergunta_id = q.id loop
      if q.tipo in ('nps', 'escala') and it.valor_num is not null and (q.pontos ? 'peso') then
        v_um := v_um + it.valor_num * coalesce((q.pontos ->> 'peso')::numeric, 0); v_cont := true;
      elsif q.tipo in ('escolha', 'multipla', 'sim_nao') and it.valor_texto is not null and (q.pontos -> 'opcoes') ? it.valor_texto then
        v_op := q.pontos -> 'opcoes' -> it.valor_texto;
        v_um := v_um + coalesce((v_op ->> 'p')::numeric, 0); v_cont := true;
        v_tag := nullif(trim(v_op ->> 'tag'), '');
        if v_tag is not null then v_tags := array_append(v_tags, v_tag); end if;
        if coalesce((v_op ->> 'elim')::boolean, false) then v_elim := true; end if;
      elsif q.tipo in ('escolha', 'multipla', 'sim_nao') and it.valor_texto is not null then
        v_cont := true;   -- respondeu uma opção que não vale ponto: conta na média como zero
      end if;
    end loop;
    if v_cont then v_pts := v_pts + v_um; v_n := v_n + 1;
      if v_bloco is not null then v_blocos := jsonb_set(v_blocos, array[v_bloco], to_jsonb(coalesce((v_blocos ->> v_bloco)::numeric, 0) + v_um)); end if;
    end if;
  end loop;
  -- blocos que existem na pesquisa mas a pessoa não pontuou valem zero
  for v_bloco in select distinct nullif(btrim(pontos ->> 'bloco'), '') from pesquisa_perguntas where pesquisa_id = v_p.id and pontos is not null loop
    if v_bloco is not null and not (v_blocos ? v_bloco) then v_blocos := jsonb_set(v_blocos, array[v_bloco], '0'::jsonb); end if;
  end loop;
  v_final := case when coalesce(v_cfg ->> 'modo', 'soma') = 'media' then case when v_n > 0 then round(v_pts / v_n, 2) else 0 end else v_pts end;
  v_corte := nullif(v_cfg ->> 'corte', '')::numeric;
  v_qual := case when v_corte is null then null when v_final >= v_corte then 'qualificado' else 'nao_qualificado' end;
  if v_elim then v_qual := 'nao_qualificado'; end if;
  for v_faixa in select * from jsonb_array_elements(coalesce(v_cfg -> 'faixas', '[]'::jsonb)) order by (value ->> 'min')::numeric loop
    if nullif(trim(v_faixa ->> 'tag'), '') is not null then v_ftodas := array_append(v_ftodas, trim(v_faixa ->> 'tag')); end if;
    if not v_elim and v_final >= coalesce((v_faixa ->> 'min')::numeric, 0) and nullif(trim(v_faixa ->> 'tag'), '') is not null then v_ftag := trim(v_faixa ->> 'tag'); end if;
  end loop;
  -- grupos de regras (ex.: Produto, Temperatura): em cada grupo, a primeira regra que bater
  for g in select * from jsonb_array_elements(coalesce(v_cfg -> 'grupos', '[]'::jsonb)) loop
    v_ok := false;
    for rg in select * from jsonb_array_elements(coalesce(g -> 'regras', '[]'::jsonb)) loop
      if nullif(trim(rg ->> 'tag'), '') is not null then v_gtodas := array_append(v_gtodas, trim(rg ->> 'tag')); end if;
      if v_ok or v_elim or nullif(trim(rg ->> 'tag'), '') is null then continue; end if;
      v_ok := true;
      for c in select key, value from jsonb_each(coalesce(rg -> 'se', '{}'::jsonb)) loop
        v_val := case when c.key = 'total' then v_final else coalesce((v_blocos ->> c.key)::numeric, 0) end;
        if nullif(c.value ->> 'min', '') is not null and v_val < (c.value ->> 'min')::numeric then v_ok := false; end if;
        if nullif(c.value ->> 'max', '') is not null and v_val > (c.value ->> 'max')::numeric then v_ok := false; end if;
      end loop;
      if v_ok then v_gtags := array_append(v_gtags, trim(rg ->> 'tag')); v_ganhou := v_ganhou || jsonb_build_object(coalesce(nullif(g ->> 'nome', ''), 'Grupo'), trim(rg ->> 'tag')); end if;
    end loop;
  end loop;
  -- o que a pessoa pediu × o que a regra indicou
  v_cf := v_cfg -> 'confere';
  if v_cf is not null and nullif(v_cf ->> 'tag', '') is not null then
    v_gtodas := array_append(v_gtodas, v_cf ->> 'tag');
    select substr(t, length(v_cf ->> 'pediu') + 1) into v_ped from unnest(v_tags) t where nullif(v_cf ->> 'pediu', '') is not null and t like (v_cf ->> 'pediu') || '%' limit 1;
    select substr(t, length(v_cf ->> 'indicado') + 1) into v_ind from unnest(v_gtags) t where nullif(v_cf ->> 'indicado', '') is not null and t like (v_cf ->> 'indicado') || '%' and t <> v_cf ->> 'tag' limit 1;
    if not v_elim and v_ped is not null and v_ind is not null and lower(btrim(v_ped)) <> lower(btrim(v_ind)) then v_gtags := array_append(v_gtags, v_cf ->> 'tag'); end if;
  end if;
  v_det := jsonb_build_object('total', v_final, 'blocos', v_blocos, 'eliminado', v_elim, 'grupos', v_ganhou, 'qualificacao', v_qual);
  update pesquisa_respostas set qualif_det = v_det where id = v_r.id;
  update pessoas set pontuacao_qualificacao = least(v_final, 9999.99),
         qualificacao = coalesce(v_qual, qualificacao),
         tags = (select array(select distinct t from unnest(array_cat(array(select x from unnest(coalesce(tags, '{}')) x where not (x = any (v_ftodas || v_gtodas))),
                  array_cat(array_cat(v_tags, v_gtags), case when v_ftag is null then '{}'::text[] else array[v_ftag] end))) t where t is not null and t <> ''))
   where id = v_r.pessoa_id and workspace_id = v_p.workspace_id;
  return jsonb_build_object('pontos', v_final, 'qualificacao', v_qual, 'tags', to_jsonb(v_tags || v_gtags), 'faixa', v_ftag, 'blocos', v_blocos, 'eliminado', v_elim, 'grupos', v_ganhou);
end $$;
revoke all on function public.pesquisa_qualificar(uuid) from public, anon, authenticated;

notify pgrst, 'reload schema';

-- Para desfazer: rodar de novo pesquisa_qualificar de 20261026100000_qualificacao_pontos.sql (as regras sem blocos e grupos funcionam igual nas duas).
