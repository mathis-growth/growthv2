-- v0.129: regra de qualificação por pontos nas pesquisas.
-- Cada pergunta pode valer pontos (por opção, ou nota × peso) e colocar tags; a pesquisa soma (ou tira a média),
-- compara com a nota de corte e grava na pessoa: pontuação, qualificado / não qualificado, e as tags.
-- Roda sozinha quando a pessoa responde (pesquisa_responder) e pelo botão "Recalcular quem já respondeu".
-- Pode ser rodado de novo sem erro.

alter table public.pesquisa_perguntas add column if not exists pontos jsonb;
alter table public.pesquisas add column if not exists qualif jsonb;
comment on column public.pesquisa_perguntas.pontos is 'Pontos da pergunta: {"opcoes": {"<opção>": {"p": 10, "tag": "x"}}, "peso": 1} (escolha/múltipla/sim_não usam opcoes; nps/escala usam peso: nota × peso).';
comment on column public.pesquisas.qualif is 'Regra: {"ativa": true, "modo": "soma"|"media", "corte": 30, "faixas": [{"min": 0, "tag": "frio"}, {"min": 50, "tag": "quente"}]}.';

-- calcula a pontuação de uma resposta e grava na pessoa (uso interno: chamada por pesquisa_responder e pesquisa_requalificar)
create or replace function public.pesquisa_qualificar(p_resposta uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_r pesquisa_respostas; v_p pesquisas; q record; it record; v_cfg jsonb; v_pts numeric := 0; v_n int := 0; v_tags text[] := '{}'; v_tag text;
        v_cont boolean; v_um numeric; v_final numeric; v_corte numeric; v_qual text; v_faixa jsonb; v_ftag text; v_ftodas text[] := '{}';
begin
  select * into v_r from pesquisa_respostas where id = p_resposta; if not found or v_r.pessoa_id is null then return null; end if;
  select * into v_p from pesquisas where id = v_r.pesquisa_id; v_cfg := v_p.qualif;
  if v_cfg is null or coalesce((v_cfg ->> 'ativa')::boolean, false) is false then return null; end if;
  for q in select * from pesquisa_perguntas where pesquisa_id = v_p.id and pontos is not null loop
    v_cont := false; v_um := 0;
    for it in select * from pesquisa_resposta_itens where resposta_id = v_r.id and pergunta_id = q.id loop
      if q.tipo in ('nps', 'escala') and it.valor_num is not null and (q.pontos ? 'peso') then
        v_um := v_um + it.valor_num * coalesce((q.pontos ->> 'peso')::numeric, 0); v_cont := true;
      elsif q.tipo in ('escolha', 'multipla', 'sim_nao') and it.valor_texto is not null and (q.pontos -> 'opcoes') ? it.valor_texto then
        v_um := v_um + coalesce((q.pontos -> 'opcoes' -> it.valor_texto ->> 'p')::numeric, 0); v_cont := true;
        v_tag := nullif(trim(q.pontos -> 'opcoes' -> it.valor_texto ->> 'tag'), '');
        if v_tag is not null then v_tags := array_append(v_tags, v_tag); end if;
      elsif q.tipo in ('escolha', 'multipla', 'sim_nao') and it.valor_texto is not null then
        v_cont := true;   -- respondeu uma opção que não vale ponto: conta na média como zero
      end if;
    end loop;
    if v_cont then v_pts := v_pts + v_um; v_n := v_n + 1; end if;
  end loop;
  v_final := case when coalesce(v_cfg ->> 'modo', 'soma') = 'media' then case when v_n > 0 then round(v_pts / v_n, 2) else 0 end else v_pts end;
  v_corte := nullif(v_cfg ->> 'corte', '')::numeric;
  v_qual := case when v_corte is null then null when v_final >= v_corte then 'qualificado' else 'nao_qualificado' end;
  -- faixa: a de maior "min" que a pontuação alcança; as tags das outras faixas saem da pessoa
  for v_faixa in select * from jsonb_array_elements(coalesce(v_cfg -> 'faixas', '[]'::jsonb)) order by (value ->> 'min')::numeric loop
    if nullif(trim(v_faixa ->> 'tag'), '') is not null then v_ftodas := array_append(v_ftodas, trim(v_faixa ->> 'tag')); end if;
    if v_final >= coalesce((v_faixa ->> 'min')::numeric, 0) and nullif(trim(v_faixa ->> 'tag'), '') is not null then v_ftag := trim(v_faixa ->> 'tag'); end if;
  end loop;
  update pessoas set pontuacao_qualificacao = least(v_final, 9999.99),
         qualificacao = coalesce(v_qual, qualificacao),
         tags = (select array(select distinct t from unnest(array_cat(array(select x from unnest(coalesce(tags, '{}')) x where not (x = any (v_ftodas))), array_cat(v_tags, case when v_ftag is null then '{}'::text[] else array[v_ftag] end))) t where t is not null and t <> ''))
   where id = v_r.pessoa_id and workspace_id = v_p.workspace_id;
  return jsonb_build_object('pontos', v_final, 'qualificacao', v_qual, 'tags', to_jsonb(v_tags), 'faixa', v_ftag);
end $$;
revoke all on function public.pesquisa_qualificar(uuid) from public, anon, authenticated;

-- recalcula todos que já responderam (a última resposta de cada pessoa)
create or replace function public.pesquisa_requalificar(p_pesquisa uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas; r record; n int := 0; nq int := 0; res jsonb;
begin
  select * into v_p from pesquisas where id = p_pesquisa;
  if not found or not pertence_ao_workspace(v_p.workspace_id) then raise exception 'Pesquisa não encontrada'; end if;
  for r in select distinct on (pessoa_id) id from pesquisa_respostas where pesquisa_id = p_pesquisa and pessoa_id is not null order by pessoa_id, respondida_em desc loop
    res := pesquisa_qualificar(r.id); n := n + 1; if res ->> 'qualificacao' = 'qualificado' then nq := nq + 1; end if;
  end loop;
  return jsonb_build_object('pessoas', n, 'qualificados', nq);
end $$;
revoke all on function public.pesquisa_requalificar(uuid) from public, anon;
grant execute on function public.pesquisa_requalificar(uuid) to authenticated;

-- quem responde pela pesquisa passa a ser qualificado na hora
do $$ declare d text; begin
  d := pg_get_functiondef('public.pesquisa_responder(text, jsonb, text)'::regprocedure);
  if position('pesquisa_qualificar' in d) = 0 then
    d := replace(d, '  return jsonb_build_object(''ok'', true);', '  if v_pessoa is not null then perform pesquisa_qualificar(v_resp); end if;' || chr(10) || '  return jsonb_build_object(''ok'', true);');
    if position('pesquisa_qualificar' in d) = 0 then raise exception 'não achei onde ligar a qualificação em pesquisa_responder'; end if;
    execute d;
  end if;
end $$;

notify pgrst, 'reload schema';
