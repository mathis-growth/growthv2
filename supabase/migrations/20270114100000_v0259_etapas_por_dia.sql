-- v0.259: número de cada etapa da estratégia, dia a dia, para os submenus da campanha. Usa as mesmas fontes de campanha_funil_etapas.
-- Aditiva. Para desfazer: drop function campanha_etapas_dia.
create or replace function public.campanha_etapas_dia(p_campanha uuid, p_ini date, p_fim date) returns jsonb language plpgsql stable set search_path = public as $$
declare c record; e record; d jsonb; r jsonb := '[]'::jsonb; v_kanban text;
begin
  select * into c from campanhas where id = p_campanha;
  if c.id is null then return r; end if;
  for e in select * from campanha_etapas where campanha_id = p_campanha and ativa order by ordem, criado_em loop
    d := null;
    if e.origem = 'anuncios' then
      select jsonb_object_agg(x.dia, x.v) into d from (select t.data as dia, case e.metrica when 'investimento' then sum(t.custo) when 'impressoes' then sum(t.impressoes) when 'cliques' then sum(t.cliques) when 'visitas' then sum(t.visualizacoes_pagina) else sum(t.custo) end as v
        from v_trafego_anuncio_dia t where t.campanha_id = p_campanha and t.data between p_ini and p_fim group by t.data) x;
    elsif e.origem = 'leads' then
      select jsonb_object_agg(x.dia, x.v) into d from (select (p.criado_em at time zone 'America/Sao_Paulo')::date as dia, count(*) as v from pessoas p where p.campanha_id = p_campanha and (p.criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1) x;
    elsif e.origem = 'etapa_funil' and e.origem_ref is not null then
      select nome into v_kanban from funil_etapas where id = e.origem_ref;
      select jsonb_object_agg(x.dia, x.v) into d from (select (h.em at time zone 'America/Sao_Paulo')::date as dia, count(distinct h.pessoa_id) as v from pessoa_funil_historico h
        where h.funil_id = c.funil_id and h.tipo = 'etapa' and h.para = v_kanban and (h.em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1) x;
    elsif e.origem = 'lista' and e.origem_ref is not null then
      select jsonb_object_agg(x.dia, x.v) into d from (select (pl.entrou_em at time zone 'America/Sao_Paulo')::date as dia, count(distinct pl.pessoa_id) as v from pessoa_lista pl where pl.lista_id = e.origem_ref and (pl.entrou_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1) x;
    elsif e.origem = 'video' and e.origem_ref is not null then
      select jsonb_object_agg(x.dia, x.v) into d from (select (pv.primeiro_em at time zone 'America/Sao_Paulo')::date as dia, count(distinct pv.pessoa_id) as v from presencas_video pv where pv.fonte_id = e.origem_ref and (e.metrica is distinct from 'ao_vivo' or pv.ao_vivo) and (pv.primeiro_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1) x;
    elsif e.origem = 'vendas' then
      if e.metrica = 'receita' then
        select jsonb_object_agg(x.dia, x.v) into d from (select z.dia, sum(z.v) as v from (
          select (s.data_venda at time zone 'America/Sao_Paulo')::date as dia, s.valor_bruto as v from vendas s where s.campanha_id = p_campanha and s.status = 'aprovada' and (s.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim
          union all select (k.ativado_em at time zone 'America/Sao_Paulo')::date, ci.valor * ci.quantidade from contratos k join contrato_itens ci on ci.contrato_id = k.id where k.campanha_id = p_campanha and k.status in ('ativo', 'encerrado') and k.ativado_em is not null and (k.ativado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim) z group by z.dia) x;
      else
        select jsonb_object_agg(x.dia, x.v) into d from (select z.dia, count(distinct z.pessoa_id) as v from (
          select (s.data_venda at time zone 'America/Sao_Paulo')::date as dia, s.pessoa_id from vendas s where s.campanha_id = p_campanha and s.status = 'aprovada' and (s.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim
          union select (k.ativado_em at time zone 'America/Sao_Paulo')::date, k.pessoa_id from contratos k where k.campanha_id = p_campanha and k.status in ('ativo', 'encerrado') and k.ativado_em is not null and (k.ativado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim) z group by z.dia) x;
      end if;
    end if;
    if e.origem in ('manual', 'disparo') or d is null then
      select jsonb_object_agg(cv.data, cv.valor) into d from campanha_etapa_valores cv where cv.campanha_etapa_id = e.id and cv.data between p_ini and p_fim;
    end if;
    r := r || jsonb_build_object('id', e.id, 'dias', coalesce(d, '{}'::jsonb));
  end loop;
  return r;
end $$;
revoke execute on function public.campanha_etapas_dia(uuid, date, date) from public, anon;
grant execute on function public.campanha_etapas_dia(uuid, date, date) to authenticated, service_role;
notify pgrst, 'reload schema';
