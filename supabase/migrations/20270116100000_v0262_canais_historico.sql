-- v0.262: resultado por canal das campanhas escolhidas, para servir de base às metas do passo Canais.
-- Aditiva. Respeita as permissões de quem consulta. Para desfazer: drop function campanhas_canais_historico.
create or replace function public.campanhas_canais_historico(p_ids uuid[]) returns jsonb language sql stable set search_path = public as $$
  with part as (
    select distinct on (p.campanha_id, p.pessoa_id) p.campanha_id, p.pessoa_id, coalesce(nullif(p.canal, ''), cc.canal, 'sem_origem') as canal
    from campanha_participacoes p left join campanha_canais cc on cc.id = p.campanha_canal_id
    where p.campanha_id = any(p_ids) order by p.campanha_id, p.pessoa_id, p.entrou_em),
  l as (select campanha_id, canal, count(*) as n from part group by 1, 2),
  v as (select s.campanha_id, coalesce(pa.canal, 'sem_origem') as canal, count(*) as n from vendas s left join part pa on pa.campanha_id = s.campanha_id and pa.pessoa_id = s.pessoa_id
        where s.campanha_id = any(p_ids) and s.status = 'aprovada' group by 1, 2),
  i as (select campanha_id, canal, sum(custo) as n from v_trafego_anuncio_dia where campanha_id = any(p_ids) group by 1, 2 having sum(custo) > 0),
  t as (select campanha_id, canal from l union select campanha_id, canal from v union select campanha_id, canal from i)
  select coalesce(jsonb_agg(jsonb_build_object('campanha_id', t.campanha_id, 'canal', t.canal, 'leads', coalesce(l.n, 0), 'vendas', coalesce(v.n, 0), 'investimento', coalesce(i.n, 0))), '[]'::jsonb)
  from t left join l on l.campanha_id = t.campanha_id and l.canal = t.canal left join v on v.campanha_id = t.campanha_id and v.canal = t.canal left join i on i.campanha_id = t.campanha_id and i.canal = t.canal;
$$;
revoke execute on function public.campanhas_canais_historico(uuid[]) from public, anon;
grant execute on function public.campanhas_canais_historico(uuid[]) to authenticated, service_role;
notify pgrst, 'reload schema';
