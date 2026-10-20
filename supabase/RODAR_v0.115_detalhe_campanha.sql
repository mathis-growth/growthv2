-- JÁ APLICADO em produção em 19/10/2026 (via Supabase). Guardado para registro / para outro projeto. Pode rodar de novo sem problema.
-- v0.115 — Detalhe dos indicadores da campanha (clicar no card abre o detalhe)
-- campanha_detalhe(campanha, hoje) devolve, num jsonb só, tudo o que os detalhes de Leads, Investimento, Custo por lead,
-- Vendas, CAC, Receita, ROAS e Lead → venda mostram: por canal, por dia, qualificação, produtos, anúncios e as últimas pessoas.
-- Regras (as mesmas do resto da campanha):
--   lead = pessoa que entrou na campanha (campanha_participacoes), uma vez cada; "nova" = cadastro criado pela campanha
--          (pessoas.campanha_id = campanha), o resto já estava na base;
--   canal do lead = campanha_canal_id da participação; a venda vai para o canal da participação de quem comprou
--          (sem participação: utm_campaign da pessoa; sem nada: "sem canal");
--   investimento = custo dos anúncios (Tráfego pago) quando a campanha tem anúncio com custo; senão, contas a pagar e custos de CAC
--          ligados ao canal (o mesmo critério de campanha_series);
--   vendas = vendas aprovadas da campanha; clientes = pessoas distintas que compraram.
-- Só leitura. Roda como dono (sem o custo das políticas linha a linha), mas exige ser do workspace e poder ler o Marketing.

create or replace function public.campanha_detalhe(p_campanha uuid, p_hoje date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  c campanhas; h date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
  d_ini date; d_fim date; usa_trf boolean; r jsonb;
begin
  select * into c from campanhas where id = p_campanha;
  if not found or not pertence_ao_workspace(c.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  if not perm(c.workspace_id, 'ler', '{mkt}'::text[]) then raise exception 'Sem acesso ao Marketing deste workspace'; end if;
  d_ini := coalesce(c.data_inicio, (select min((entrou_em at time zone 'America/Sao_Paulo')::date) from campanha_participacoes where campanha_id = c.id), h);
  d_fim := least(h, coalesce(c.data_fim, h));
  if d_fim < d_ini then d_fim := d_ini; end if;
  if d_fim - d_ini > 399 then d_ini := d_fim - 399; end if;
  select exists (select 1 from v_trafego_anuncio_dia where workspace_id = c.workspace_id and campanha_id = c.id and custo > 0) into usa_trf;

  with dias as (select (d_ini + i)::date d, i from generate_series(0, d_fim - d_ini) i),
  cn as (select cc.* from campanha_canais cc where cc.campanha_id = c.id),
  -- leads (participações) com dados da pessoa
  lp as (select cp.pessoa_id, cp.campanha_canal_id cid, (cp.entrou_em at time zone 'America/Sao_Paulo')::date d, cp.entrou_em,
                p.nome, p.qualificacao, (p.campanha_id = c.id) nova, cp.era_aluno, cp.era_cliente, cp.tentativas
           from campanha_participacoes cp join pessoas p on p.id = cp.pessoa_id where cp.campanha_id = c.id),
  -- vendas aprovadas da campanha, com o canal de quem comprou
  vd as (select v.id, v.pessoa_id, v.valor_bruto, v.produto_id, (v.data_venda at time zone 'America/Sao_Paulo')::date d, v.data_venda,
                coalesce((select cp.campanha_canal_id from campanha_participacoes cp where cp.campanha_id = c.id and cp.pessoa_id = v.pessoa_id limit 1),
                         (select cn.id from cn join pessoas p on p.id = v.pessoa_id where cn.utm_campaign = p.utm_campaign limit 1)) cid
           from vendas v where v.campanha_id = c.id and v.status = 'aprovada'),
  vd1 as (select vd.*, row_number() over (partition by pessoa_id order by data_venda, id) = 1 primeira from vd),
  -- investimento por canal e dia
  inv as (
    select cn.id cid, t.data d, sum(t.custo) v, sum(t.impressoes) imp, sum(t.cliques) cli
      from v_trafego_anuncio_dia t join cn on cn.utm_campaign = t.utm_campaign
     where usa_trf and t.workspace_id = c.workspace_id and t.campanha_id = c.id group by 1, 2
    union all
    select x.cid, x.d, sum(x.v), null, null from (
      select campanha_canal_id cid, competencia d, valor v from contas_pagar where not usa_trf and campanha_id = c.id and status <> 'cancelado'
      union all select campanha_canal_id, competencia, valor from custos_cac where not usa_trf and campanha_id = c.id) x group by 1, 2),
  ag as (  -- totais por canal e dia
    select cid, d, sum(inv) inv, sum(leads) leads, sum(vendas) vendas, sum(rec) rec, sum(cli) cli from (
      select cid, d, v inv, 0 leads, 0 vendas, 0 rec, 0 cli from inv
      union all select cid, d, 0, count(*), 0, 0, 0 from lp group by 1, 2
      union all select cid, d, 0, 0, count(*), sum(valor_bruto), count(*) filter (where primeira) from vd1 group by 1, 2) x group by 1, 2),
  serie as (  -- por canal (cid null = sem canal) e dia
    select k.cid, jsonb_agg(coalesce(ag.inv, 0) order by dias.i) inv_dia, jsonb_agg(coalesce(ag.leads, 0) order by dias.i) leads_dia,
           jsonb_agg(coalesce(ag.vendas, 0) order by dias.i) vendas_dia, jsonb_agg(coalesce(ag.rec, 0) order by dias.i) receita_dia,
           jsonb_agg(coalesce(ag.cli, 0) order by dias.i) clientes_dia
      from (select id cid from cn union all select null) k cross join dias
      left join ag on ag.cid is not distinct from k.cid and ag.d = dias.d group by k.cid),
  porcanal as (
    select k.cid, cn.canal, cn.utm_campaign, cn.tipo, cn.temperatura, cn.orcamento, cn.meta_leads, cn.meta_vendas, cn.meta_cac, cn.meta_cpl,
      (select coalesce(sum(v), 0) from inv where inv.cid is not distinct from k.cid) investimento,
      (select sum(imp) from inv where inv.cid is not distinct from k.cid) impressoes,
      (select sum(cli) from inv where inv.cid is not distinct from k.cid) cliques,
      (select count(*) from lp where lp.cid is not distinct from k.cid) leads,
      (select count(*) filter (where nova) from lp where lp.cid is not distinct from k.cid) leads_novos,
      (select count(*) filter (where qualificacao = 'qualificado') from lp where lp.cid is not distinct from k.cid) qualificados,
      (select count(*) filter (where qualificacao = 'nao_qualificado') from lp where lp.cid is not distinct from k.cid) nao_qualificados,
      (select count(*) filter (where qualificacao is null or qualificacao not in ('qualificado', 'nao_qualificado')) from lp where lp.cid is not distinct from k.cid) pendentes,
      (select coalesce(sum(tentativas - 1), 0) from lp where lp.cid is not distinct from k.cid and tentativas > 1) repetidas,
      (select count(*) from vd where vd.cid is not distinct from k.cid) vendas,
      (select count(distinct pessoa_id) from vd where vd.cid is not distinct from k.cid) clientes,
      (select coalesce(sum(valor_bruto), 0) from vd where vd.cid is not distinct from k.cid) receita,
      s.inv_dia, s.leads_dia, s.vendas_dia, s.receita_dia, s.clientes_dia
    from (select id cid from cn union all select null) k left join cn on cn.id = k.cid left join serie s on s.cid is not distinct from k.cid)
  select jsonb_build_object(
    'hoje', h, 'de', d_ini, 'ate', d_fim, 'usa_trafego', usa_trf,
    'dias', (select jsonb_agg(d order by i) from dias),
    'canais', (select coalesce(jsonb_agg(jsonb_build_object('id', cid, 'canal', coalesce(canal, 'sem canal'), 'utm_campaign', utm_campaign, 'tipo', tipo, 'temperatura', temperatura,
        'orcamento', orcamento, 'meta_leads', meta_leads, 'meta_vendas', meta_vendas, 'meta_cac', meta_cac, 'meta_cpl', meta_cpl,
        'investimento', investimento, 'impressoes', impressoes, 'cliques', cliques, 'leads', leads, 'leads_novos', leads_novos,
        'qualificados', qualificados, 'nao_qualificados', nao_qualificados, 'pendentes', pendentes, 'repetidas', repetidas,
        'vendas', vendas, 'clientes', clientes, 'receita', receita,
        'inv_dia', inv_dia, 'leads_dia', leads_dia, 'vendas_dia', vendas_dia, 'receita_dia', receita_dia, 'clientes_dia', clientes_dia)
        order by (cid is null), investimento desc, leads desc), '[]'::jsonb)
      from porcanal where cid is not null or leads > 0 or vendas > 0 or investimento > 0),
    'produtos', (select coalesce(jsonb_agg(jsonb_build_object('produto', coalesce(pr.nome, 'sem produto'), 'vendas', n, 'receita', rec) order by rec desc), '[]'::jsonb)
      from (select produto_id, count(*) n, sum(valor_bruto) rec from vd group by 1) x left join produtos pr on pr.id = x.produto_id),
    'anuncios', case when usa_trf then (select coalesce(jsonb_agg(a order by (a->>'custo')::numeric desc), '[]'::jsonb) from (
        select jsonb_build_object('anuncio', t.anuncio, 'utm_campaign', t.utm_campaign, 'utm_content', t.utm_content, 'custo', sum(t.custo), 'impressoes', sum(t.impressoes),
               'cliques', sum(t.cliques), 'leads', sum(t.leads), 'vendas', sum(t.vendas), 'receita', sum(t.receita)) a
          from v_trafego_anuncio_dia t where t.workspace_id = c.workspace_id and t.campanha_id = c.id
         group by t.anuncio_id, t.anuncio, t.utm_campaign, t.utm_content order by sum(t.custo) desc limit 15) z) end,
    'ultimos_leads', (select coalesce(jsonb_agg(jsonb_build_object('pessoa_id', pessoa_id, 'nome', nome, 'em', entrou_em, 'canal', (select coalesce(utm_campaign, canal) from cn where cn.id = lp.cid),
        'qualificacao', qualificacao, 'nova', nova, 'tentativas', tentativas) order by entrou_em desc), '[]'::jsonb)
      from (select * from lp order by entrou_em desc limit 30) lp),
    'ultimas_vendas', (select coalesce(jsonb_agg(jsonb_build_object('pessoa_id', vd.pessoa_id, 'nome', p.nome, 'em', vd.data_venda, 'valor', vd.valor_bruto,
        'produto', pr.nome, 'canal', (select coalesce(utm_campaign, canal) from cn where cn.id = vd.cid)) order by vd.data_venda desc), '[]'::jsonb)
      from (select * from vd order by data_venda desc limit 30) vd join pessoas p on p.id = vd.pessoa_id left join produtos pr on pr.id = vd.produto_id)
  ) into r;
  return r;
end $$;

revoke execute on function public.campanha_detalhe(uuid, date) from public, anon;
grant execute on function public.campanha_detalhe(uuid, date) to authenticated;
