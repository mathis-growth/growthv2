-- RODAR no SQL Editor do Supabase (cópia de migrations/20261210100000_brain_trajetoria.sql). Depende do RODAR_v0.215 (já rodado).
-- O que muda em produção: cria a função metas_trajetoria (só leitura) e tira o número de impacto dos riscos de qualidade dos dados (era um percentual mostrado como quantidade).
-- v0.216 — Growth's Brain: trajetória de cada meta (para o gráfico do Cockpit).
-- metas_trajetoria(ws, metrica, ini, fim, hoje, escopo, ref): dia a dia, a meta acumulada e o realizado acumulado (até hoje),
-- mais a avaliação da meta (projeção, método, status) — os mesmos números da faixa de metas, só que no tempo.
-- Com cobertura parcial, o realizado só soma nos dias que têm meta (a mesma regra de metas_avaliar).
-- Também corrige o impacto dos riscos de qualidade (v0.215). Depende do RODAR_v0.215. Pode rodar de novo sem erro.

create or replace function public.metas_trajetoria(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date,
  p_escopo text default 'empresa', p_ref uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare av jsonb; ate date := least(p_fim, p_hoje); pts jsonb; parcial boolean;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini or p_fim - p_ini > 400 then raise exception 'Período inválido (até 400 dias)'; end if;
  av := metas_avaliar(p_ws, p_metrica, p_ini, p_fim, p_hoje, p_escopo, p_ref);
  parcial := coalesce((av->>'parcial')::boolean, false);
  with sr as (select x.dia, x.meta from metas_serie(p_ws, p_metrica, p_escopo, p_ref, p_ini, p_fim) x),
       rr as (select y.dia, sum(y.v) v from metas_realizado_dia(p_ws, p_metrica, p_escopo, p_ref, p_ini, ate) y group by y.dia),
       j as (select sr.dia, sr.meta, case when parcial and sr.meta is null then 0 else coalesce(rr.v, 0) end v from sr left join rr on rr.dia = sr.dia),
       a as (select dia, sum(coalesce(meta, 0)) over (order by dia) ma, sum(v) over (order by dia) ra from j)
  select jsonb_agg(jsonb_build_array(dia, round(ma, 2), case when dia <= ate then round(ra, 2) end) order by dia) into pts from a;
  return jsonb_build_object('avaliacao', av, 'pontos', coalesce(pts, '[]'::jsonb));
end $$;
revoke all on function public.metas_trajetoria(uuid, text, date, date, date, text, uuid) from public, anon;
grant execute on function public.metas_trajetoria(uuid, text, date, date, date, text, uuid) to authenticated;

-- correção da v0.215: o "qtd" das regras de qualidade às vezes é um percentual (ex.: 73,4% de diferença), não uma quantidade de avisos;
-- o risco de qualidade fica sem impacto em número (a evidência já traz o texto da regra)
create or replace function public.riscos_qualidade_sem_impacto() returns trigger language plpgsql as $$
begin
  if new.fonte = 'qualidade' then new.impacto := null; new.impacto_unidade := null; end if;
  return new;
end $$;
drop trigger if exists riscos_qualidade_sem_impacto on public.riscos;
create trigger riscos_qualidade_sem_impacto before insert or update on public.riscos for each row execute function public.riscos_qualidade_sem_impacto();
update public.riscos set impacto = null, impacto_unidade = null where fonte = 'qualidade' and impacto is not null;

notify pgrst, 'reload schema';
