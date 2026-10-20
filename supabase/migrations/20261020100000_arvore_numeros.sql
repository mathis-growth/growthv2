-- v0.116 — Árvore dos números: "De onde vem este número"
-- arvore_no(ws, no, par) devolve um nó da árvore: o valor, a conta que o gerou (fórmula com as partes clicáveis),
-- as quebras (por canal, por conta, por mês, por produto...) com cada item clicável, e os registros que formam o número.
-- O front só desenha: clicar numa parte ou num item chama arvore_no de novo com o nó e os filtros daquele item.
-- par (jsonb): ini, fim (datas), hoje, e filtros: campanha, canal (campanha_canais.id), utm, produto, conta (plano_contas.id),
--   grupo (receita|deducao|custo|despesa), origem, banco, fornecedor, anuncio, status, campo, filtro, coorte.
-- As regras são as mesmas das telas:
--   resultado = partidas dos lançamentos com data_fato no período (DRE, Dashboard, Dashboard financeiro, Custos e margens);
--   vendas = tabela vendas pela data da venda (fuso de São Paulo); caixa = v_saldo_contas_bancarias; a receber/pagar = contas previstas;
--   leads do período = pessoas captadas criadas no período (Dashboard de marketing); leads da campanha = participações;
--   investimento = custo dos anúncios; numa campanha sem anúncio, contas a pagar ligadas à campanha.
-- Roda como dona (rápido) e confere o acesso: ser do workspace e poder ler o módulo do nó (fin, vendas ou mkt).

create or replace function public._arv_item(p_rot text, p_valor numeric, p_no text, p_par jsonb, p_sub text default null) returns jsonb
language sql immutable as $$ select jsonb_build_object('rotulo', p_rot, 'valor', p_valor, 'no', p_no, 'par', p_par, 'sub', p_sub) $$;

create or replace function public._arv_d(p jsonb, k text, def date default null) returns date
language sql immutable as $$ select coalesce(nullif(p ->> k, '')::date, def) $$;

create or replace function public._arv_u(p jsonb, k text) returns uuid
language sql immutable as $$ select nullif(p ->> k, '')::uuid $$;

-- meses do período, para a quebra "Por mês" (cada item vira o mesmo nó com ini/fim do mês)
create or replace function public._arv_meses(p_no text, p_par jsonb, p_ini date, p_fim date, p_vals jsonb) returns jsonb
language sql immutable as $$
  select case when date_trunc('month', p_ini) = date_trunc('month', p_fim) then null else
    jsonb_build_object('titulo', 'Por mês', 'itens', coalesce((select jsonb_agg(_arv_item(
        to_char(m, 'MM/YYYY'), coalesce((p_vals ->> to_char(m, 'YYYY-MM'))::numeric, 0), p_no,
        p_par || jsonb_build_object('ini', greatest(m::date, p_ini), 'fim', least((m + interval '1 month - 1 day')::date, p_fim))) order by m)
      from generate_series(date_trunc('month', p_ini), date_trunc('month', p_fim), interval '1 month') m), '[]'::jsonb)) end $$;

-- ===================== Financeiro: razão (partidas) =====================
create or replace function public._arv_razao(p_ws uuid, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  ini date := _arv_d(p_par, 'ini'); fim date := _arv_d(p_par, 'fim'); g text := p_par ->> 'grupo';
  conta uuid := _arv_u(p_par, 'conta'); org text := nullif(p_par ->> 'origem', ''); cc uuid := _arv_u(p_par, 'centro');
  tit text; r jsonb;
begin
  tit := case g when 'receita' then 'Receitas' when 'deducao' then 'Deduções da receita (taxas e impostos)' when 'custo' then 'Custos' when 'despesa' then 'Despesas' else 'Lançamentos' end;
  with pt as (
    select pa.id, l.id lanc, l.data_fato, l.descricao, l.origem_tipo, l.origem_id, pc.id conta_id, pc.codigo, pc.nome conta_nome, pa.centro_custo_id,
           case when pc.tipo = 'receita' then case when pa.tipo = 'C' then pa.valor else -pa.valor end else case when pa.tipo = 'D' then pa.valor else -pa.valor end end v
      from partidas pa join plano_contas pc on pc.id = pa.conta_id join lancamentos l on l.id = pa.lancamento_id
     where pa.workspace_id = p_ws and l.data_fato between ini and fim and pc.tipo = g
       and (conta is null or pc.id = conta) and (org is null or l.origem_tipo = org) and (cc is null or pa.centro_custo_id = cc)),
  pes as (  -- pessoa por trás do lançamento (venda, estorno, parcela de contrato, recebimento)
    select pt.id, coalesce(ve.pessoa_id, ct.pessoa_id, ve2.pessoa_id, ct2.pessoa_id) pessoa_id,
           coalesce(fo.nome, fo2.nome) fornecedor
      from pt left join vendas ve on pt.origem_tipo in ('venda', 'estorno') and ve.id = pt.origem_id
      left join contas_receber cr on pt.origem_tipo in ('contrato_parcela', 'cancelamento_contrato', 'desconto', 'recebimento') and cr.id = pt.origem_id
      left join contratos ct on ct.id = cr.contrato_id left join vendas ve2 on ve2.id = cr.venda_id left join contratos ct2 on false
      left join contas_pagar cp on pt.origem_tipo in ('conta_pagar', 'pagamento') and cp.id = pt.origem_id left join fornecedores fo on fo.id = cp.fornecedor_id
      left join fornecedores fo2 on false)
  select jsonb_build_object(
    'titulo', tit || case when conta is not null then ' · ' || (select codigo || ' ' || nome from plano_contas where id = conta) else '' end
                  || case when org is not null then ' · origem: ' || org else '' end,
    'valor', (select coalesce(sum(v), 0) from pt), 'un', 'brl',
    'explica', 'Soma das partidas dos lançamentos contábeis com data entre ' || to_char(ini, 'DD/MM/YYYY') || ' e ' || to_char(fim, 'DD/MM/YYYY')
               || ' nas contas do tipo "' || g || '" (a mesma regra da DRE).',
    'quebras', jsonb_build_array(
      case when conta is null then jsonb_build_object('titulo', 'Por conta contábil', 'itens', coalesce((select jsonb_agg(_arv_item(codigo || ' ' || conta_nome, s, 'fin.razao', p_par || jsonb_build_object('conta', conta_id)) order by s desc)
        from (select conta_id, codigo, conta_nome, sum(v) s from pt group by 1, 2, 3) x), '[]'::jsonb)) end,
      case when org is null then jsonb_build_object('titulo', 'Por origem', 'itens', coalesce((select jsonb_agg(_arv_item(case origem_tipo when 'venda' then 'Vendas' when 'estorno' then 'Estornos de venda'
          when 'contrato_parcela' then 'Parcelas de contrato' when 'conta_pagar' then 'Contas a pagar' when 'pagamento' then 'Pagamentos' when 'recebimento' then 'Recebimentos'
          when 'cancelamento_contrato' then 'Cancelamentos de contrato' when 'desconto' then 'Descontos' else coalesce(origem_tipo, 'Manual') end, s, 'fin.razao', p_par || jsonb_build_object('origem', origem_tipo)) order by s desc)
        from (select origem_tipo, sum(v) s from pt group by 1) x), '[]'::jsonb)) end,
      (select case when count(*) > 1 then jsonb_build_object('titulo', 'Por centro de custo', 'itens', jsonb_agg(_arv_item(coalesce(nome, 'Sem centro de custo'), s, 'fin.razao', p_par || jsonb_build_object('centro', centro_custo_id)) order by s desc)) end
        from (select pt.centro_custo_id, c.nome, sum(v) s from pt left join centros_custo c on c.id = pt.centro_custo_id where cc is null group by 1, 2) x),
      _arv_meses('fin.razao', p_par, ini, fim, (select jsonb_object_agg(k, s) from (select to_char(data_fato, 'YYYY-MM') k, sum(v) s from pt group by 1) x))),
    'registros', jsonb_build_object('titulo', 'Lançamentos', 'total', (select count(*) from pt),
      'cols', jsonb_build_array('Data', 'Histórico', 'Conta', 'Quem', 'Valor'), 'un', jsonb_build_array('d', 't', 't', 't', 'brl'),
      'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(pt.data_fato, pt.descricao, pt.codigo || ' ' || pt.conta_nome, coalesce(p.nome, pes.fornecedor), pt.v),
          'abrir', case when pes.pessoa_id is not null then jsonb_build_object('tipo', 'pessoa', 'id', pes.pessoa_id) end) order by pt.data_fato desc, abs(pt.v) desc)
        from (select * from pt order by data_fato desc, abs(v) desc limit 200) pt join pes on pes.id = pt.id left join pessoas p on p.id = pes.pessoa_id), '[]'::jsonb))
  ) into r;
  return r;
end $$;

-- ===================== Vendas =====================
create or replace function public._arv_vendas(p_ws uuid, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  ini date := _arv_d(p_par, 'ini', '2000-01-01'); fim date := _arv_d(p_par, 'fim', '2100-12-31');
  campo text := coalesce(p_par ->> 'campo', 'bruto'); st text := coalesce(p_par ->> 'status', 'aprovada');
  camp uuid := _arv_u(p_par, 'campanha'); prod uuid := _arv_u(p_par, 'produto'); canal uuid := _arv_u(p_par, 'canal');
  forma text := nullif(p_par ->> 'forma', ''); vend uuid := _arv_u(p_par, 'vendedor'); coorte boolean := coalesce((p_par ->> 'coorte')::boolean, false);
  semdata boolean := p_par ->> 'ini' is null; tit text; un text; r jsonb;
begin
  tit := case campo when 'qtd' then 'Vendas' when 'bruto' then 'Receita bruta das vendas' when 'liquido' then 'Receita líquida das vendas'
                    when 'taxas' then 'Taxas das plataformas' when 'impostos' then 'Impostos das vendas' else campo end
         || case st when 'aprovada' then '' when 'reembolsos' then ' reembolsadas, canceladas ou em chargeback' else ' (' || st || ')' end;
  un := case when campo = 'qtd' then 'n' else 'brl' end;
  with vb as (  -- vendas + (opcional) contratos fechados, que a tela de Vendas mostra como venda
    select v.id, v.pessoa_id, v.produto_id, v.campanha_id, v.forma_pagamento, v.vendedor_id, v.status, v.data_venda, v.valor_bruto, v.valor_liquido, v.taxa_plataforma, v.impostos, 'venda' tipo
      from vendas v where v.workspace_id = p_ws
    union all
    select c.id, c.pessoa_id, (select i.produto_id from contrato_itens i where i.contrato_id = c.id limit 1), c.campanha_id, c.forma_pagamento, c.vendedor_id, 'aprovada',
           coalesce(c.ativado_em, c.data_inicio::timestamp at time zone 'America/Sao_Paulo', c.criado_em),
           t.tot, t.tot, 0, 0, 'contrato'
      from contratos c cross join lateral (select coalesce(sum(cr.valor), 0) tot from contas_receber cr where cr.contrato_id = c.id and cr.status <> 'cancelado' and cr.substituida_por is null) t
     where coalesce((p_par ->> 'contratos')::boolean, false) and c.workspace_id = p_ws and c.status in ('ativo', 'encerrado')),
  v as (
    select v.*, (v.data_venda at time zone 'America/Sao_Paulo')::date d,
           case campo when 'qtd' then 1 when 'bruto' then v.valor_bruto when 'liquido' then v.valor_liquido when 'taxas' then coalesce(v.taxa_plataforma, 0) when 'impostos' then coalesce(v.impostos, 0) end x,
           (select cp.campanha_canal_id from campanha_participacoes cp where cp.campanha_id = v.campanha_id and cp.pessoa_id = v.pessoa_id limit 1) cid
      from vb v
     where true
       and (case when st = 'reembolsos' then v.status in ('reembolsada', 'cancelada', 'chargeback') when st = 'todas' then true else v.status = st end)
       and (coorte or semdata or (v.data_venda at time zone 'America/Sao_Paulo')::date between ini and fim)
       and (not coorte or v.pessoa_id in (select id from pessoas p where p.workspace_id = p_ws and p.captada
              and p.criado_em >= (ini::timestamp at time zone 'America/Sao_Paulo') and p.criado_em < ((fim + 1)::timestamp at time zone 'America/Sao_Paulo')
              and (camp is null or p.campanha_id = camp)))
       and (camp is null or coorte or v.campanha_id = camp) and (prod is null or v.produto_id = prod)
       and (forma is null or v.forma_pagamento = forma) and (vend is null or v.vendedor_id = vend)),
  vf as (select * from v where canal is null or cid = canal)
  select jsonb_build_object('titulo', tit || case when coorte then ' (dos leads do período)' else '' end, 'valor', (select coalesce(sum(x), 0) from vf), 'un', un,
    'explica', case when coorte then 'Vendas aprovadas, em qualquer data, das pessoas que viraram lead entre ' || to_char(ini, 'DD/MM/YYYY') || ' e ' || to_char(fim, 'DD/MM/YYYY') || ' (o mesmo grupo do Dashboard de marketing).'
                    else 'Vendas ' || case st when 'aprovada' then 'aprovadas' else st end || case when semdata then '' else ' com data entre ' || to_char(ini, 'DD/MM/YYYY') || ' e ' || to_char(fim, 'DD/MM/YYYY') end
                         || case campo when 'qtd' then ', uma por venda.' when 'bruto' then ', valor bruto (o que o cliente pagou).' when 'liquido' then ', valor líquido (depois de taxas e impostos).' else '.' end end,
    'formula', case when campo = 'liquido' then jsonb_build_array(
        _arv_item('Receita bruta', (select coalesce(sum(valor_bruto), 0) from vf), 'ven.soma', p_par || '{"campo":"bruto"}'),
        _arv_item('− Taxas das plataformas', (select coalesce(sum(taxa_plataforma), 0) from vf), 'ven.soma', p_par || '{"campo":"taxas"}'),
        _arv_item('− Impostos', (select coalesce(sum(impostos), 0) from vf), 'ven.soma', p_par || '{"campo":"impostos"}'),
        _arv_item('− Outros ajustes', (select coalesce(sum(valor_bruto - coalesce(taxa_plataforma, 0) - coalesce(impostos, 0) - valor_liquido), 0) from vf), null, null)) end,
    'quebras', jsonb_build_array(
      case when prod is null then jsonb_build_object('titulo', 'Por produto', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(pr.nome, 'Sem produto'), s, 'ven.soma', p_par || jsonb_build_object('produto', produto_id), n || ' venda(s)') order by s desc)
        from (select produto_id, sum(x) s, count(*) n from vf group by 1) z left join produtos pr on pr.id = z.produto_id), '[]'::jsonb)) end,
      case when camp is null and not coorte then jsonb_build_object('titulo', 'Por campanha', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(c.nome, 'Sem campanha'), s, 'ven.soma', p_par || jsonb_build_object('campanha', campanha_id)) order by s desc)
        from (select campanha_id, sum(x) s from vf group by 1) z left join campanhas c on c.id = z.campanha_id), '[]'::jsonb)) end,
      case when camp is not null and canal is null then jsonb_build_object('titulo', 'Por canal (por onde o comprador entrou)', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(cc.utm_campaign, cc.canal, 'Sem canal'), s, 'ven.soma', p_par || jsonb_build_object('canal', cid), cc.canal) order by s desc)
        from (select cid, sum(x) s from vf group by 1) z left join campanha_canais cc on cc.id = z.cid), '[]'::jsonb)) end,
      case when forma is null then jsonb_build_object('titulo', 'Por forma de pagamento', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(forma_pagamento, 'Não informada'), s, 'ven.soma', p_par || jsonb_build_object('forma', forma_pagamento)) order by s desc)
        from (select forma_pagamento, sum(x) s from vf group by 1) z), '[]'::jsonb)) end,
      case when vend is null then (select case when count(*) > 1 then jsonb_build_object('titulo', 'Por vendedor', 'itens', jsonb_agg(_arv_item(coalesce(e.nome, 'Sem vendedor'), s, 'ven.soma', p_par || jsonb_build_object('vendedor', vendedor_id)) order by s desc)) end
        from (select vendedor_id, sum(x) s from vf group by 1) z left join equipe e on e.user_id = z.vendedor_id and e.workspace_id = p_ws) end,
      case when not semdata and not coorte then _arv_meses('ven.soma', p_par, ini, fim, (select jsonb_object_agg(k, s) from (select to_char(d, 'YYYY-MM') k, sum(x) s from vf group by 1) z)) end),
    'registros', jsonb_build_object('titulo', 'Vendas', 'total', (select count(*) from vf),
      'cols', jsonb_build_array('Data', 'Pessoa', 'Produto', 'Status', 'Bruto', 'Líquido'), 'un', jsonb_build_array('d', 't', 't', 't', 'brl', 'brl'),
      'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(vf.d, p.nome, pr.nome, case when vf.tipo = 'contrato' then 'contrato' else vf.status end, vf.valor_bruto, vf.valor_liquido),
          'abrir', jsonb_build_object('tipo', 'pessoa', 'id', vf.pessoa_id)) order by vf.data_venda desc)
        from (select * from vf order by data_venda desc limit 200) vf left join pessoas p on p.id = vf.pessoa_id left join produtos pr on pr.id = vf.produto_id), '[]'::jsonb))
  ) into r;
  return r;
end $$;

-- ===================== Pessoas (CRM e leads) =====================
create or replace function public._arv_pessoas(p_ws uuid, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  f text := coalesce(p_par ->> 'filtro', 'todos'); ini date := _arv_d(p_par, 'ini'); fim date := _arv_d(p_par, 'fim');
  camp uuid := _arv_u(p_par, 'campanha'); utm text := nullif(p_par ->> 'utm', ''); canal_o text := nullif(p_par ->> 'canal_origem', '');
  st text := nullif(p_par ->> 'status', ''); q text := nullif(p_par ->> 'qualificacao', ''); tit text; r jsonb;
begin
  if _arv_u(p_par, 'canal') is not null then select utm_campaign into utm from campanha_canais where id = _arv_u(p_par, 'canal'); end if;
  tit := case f when 'leads_periodo' then 'Leads do período' when 'novos_campanha' then 'Leads novos da campanha' when 'qualificados' then 'Leads qualificados'
                when 'clientes' then 'Clientes' when 'ativos' then 'Clientes ativos' when 'leads' then 'Leads (ainda não clientes)' else 'Pessoas no funil' end;
  with p as (
    select p.*, case when p.status_funil = 'cliente' then case when p.status_cliente = 'ativo' then 'Cliente ativo' else 'Cliente inativo' end else 'Lead' end st_rot
      from pessoas p where p.workspace_id = p_ws
       and (f <> 'leads_periodo' or (p.captada and p.criado_em >= (ini::timestamp at time zone 'America/Sao_Paulo') and p.criado_em < ((fim + 1)::timestamp at time zone 'America/Sao_Paulo')))
       and (f <> 'novos_campanha' or p.campanha_id = camp)
       and (f <> 'qualificados' or p.qualificacao = 'qualificado')
       and (f <> 'clientes' or p.status_funil = 'cliente')
       and (f <> 'ativos' or (p.status_funil = 'cliente' and p.status_cliente = 'ativo'))
       and (f <> 'leads' or p.status_funil <> 'cliente')
       and (camp is null or p.campanha_id = camp) and (utm is null or p.utm_campaign = utm) and (canal_o is null or coalesce(nullif(p.canal_origem, ''), '(sem canal)') = canal_o)
       and (st is null or (case when p.status_funil = 'cliente' then case when p.status_cliente = 'ativo' then 'Cliente ativo' else 'Cliente inativo' end else 'Lead' end) = st)
       and (q is null or coalesce(p.qualificacao, 'pendente') = q))
  select jsonb_build_object('titulo', tit, 'valor', (select count(*) from p), 'un', 'n',
    'explica', case f when 'leads_periodo' then 'Pessoas captadas com cadastro criado entre ' || to_char(ini, 'DD/MM/YYYY') || ' e ' || to_char(fim, 'DD/MM/YYYY') || ' (a regra do Dashboard de marketing).'
                      when 'novos_campanha' then 'Cadastros criados pela campanha (pessoas que não estavam na base).'
                      else 'Pessoas cadastradas no workspace' || case f when 'qualificados' then ' com qualificação "qualificado".' when 'clientes' then ' que já são clientes.' when 'ativos' then ' que são clientes ativos.' when 'leads' then ' que ainda não compraram.' else ' (leads e clientes).' end end,
    'quebras', jsonb_build_array(
      case when st is null and f in ('todos', 'clientes') then jsonb_build_object('titulo', 'Por situação', 'itens', coalesce((select jsonb_agg(_arv_item(st_rot, n, 'crm.pessoas', p_par || jsonb_build_object('status', st_rot)) order by n desc) from (select st_rot, count(*) n from p group by 1) z), '[]'::jsonb)) end,
      case when q is null and f not in ('qualificados') then jsonb_build_object('titulo', 'Por qualificação', 'itens', coalesce((select jsonb_agg(_arv_item(case k when 'qualificado' then 'Qualificado' when 'nao_qualificado' then 'Não qualificado' else 'Pendente' end, n, 'crm.pessoas', p_par || jsonb_build_object('qualificacao', k)) order by n desc) from (select coalesce(qualificacao, 'pendente') k, count(*) n from p group by 1) z), '[]'::jsonb)) end,
      case when camp is null then jsonb_build_object('titulo', 'Por campanha', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(c.nome, 'Sem campanha'), n, 'crm.pessoas', p_par || jsonb_build_object('campanha', campanha_id)) order by n desc) from (select campanha_id, count(*) n from p group by 1) z left join campanhas c on c.id = z.campanha_id), '[]'::jsonb)) end,
      case when utm is null then jsonb_build_object('titulo', case when camp is null then 'Por canal de origem' else 'Por canal (utm_campaign)' end, 'itens', coalesce((select jsonb_agg(_arv_item(k, n, 'crm.pessoas', p_par || case when camp is null then jsonb_build_object('canal_origem', k) else jsonb_build_object('utm', nullif(k, '(sem utm)')) end) order by n desc)
        from (select case when camp is null then coalesce(nullif(canal_origem, ''), '(sem canal)') else coalesce(utm_campaign, '(sem utm)') end k, count(*) n from p group by 1) z), '[]'::jsonb)) end,
      case when ini is not null then _arv_meses('crm.pessoas', p_par, ini, fim, (select jsonb_object_agg(k, n) from (select to_char((criado_em at time zone 'America/Sao_Paulo')::date, 'YYYY-MM') k, count(*) n from p group by 1) z)) end),
    'registros', jsonb_build_object('titulo', 'Pessoas', 'total', (select count(*) from p),
      'cols', jsonb_build_array('Entrou em', 'Nome', 'Situação', 'Qualificação', 'Origem'), 'un', jsonb_build_array('dt', 't', 't', 't', 't'),
      'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(criado_em, nome, st_rot, coalesce(qualificacao, 'pendente'), coalesce(utm_campaign, canal_origem)),
          'abrir', jsonb_build_object('tipo', 'pessoa', 'id', id)) order by criado_em desc) from (select * from p order by criado_em desc limit 200) z), '[]'::jsonb))
  ) into r;
  return r;
end $$;

-- ===================== Leads da campanha (participações) =====================
create or replace function public._arv_participacoes(p_ws uuid, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare camp uuid := _arv_u(p_par, 'campanha'); v_canal uuid := _arv_u(p_par, 'canal'); nova text := nullif(p_par ->> 'nova', ''); q text := nullif(p_par ->> 'qualificacao', '');
  ini date := _arv_d(p_par, 'ini'); fim date := _arv_d(p_par, 'fim'); r jsonb;
begin
  with lp as (select cp.*, p.nome, p.qualificacao, (p.campanha_id = cp.campanha_id) eh_nova, (cp.entrou_em at time zone 'America/Sao_Paulo')::date d
                from campanha_participacoes cp join pessoas p on p.id = cp.pessoa_id
               where cp.workspace_id = p_ws and cp.campanha_id = camp and (v_canal is null or cp.campanha_canal_id = v_canal)
                 and (nova is null or (p.campanha_id = cp.campanha_id) = (nova = 'sim')) and (q is null or coalesce(p.qualificacao, 'pendente') = q)
                 and (ini is null or (cp.entrou_em at time zone 'America/Sao_Paulo')::date between ini and fim))
  select jsonb_build_object('titulo', 'Leads da campanha' || coalesce(' · ' || (select utm_campaign from campanha_canais where id = v_canal), ''), 'valor', (select count(*) from lp), 'un', 'n',
    'explica', 'Pessoas que entraram na campanha, uma vez cada (inclusive quem já estava na base). É a conta de Captação e metas e da meta de leads.',
    'quebras', jsonb_build_array(
      case when v_canal is null then jsonb_build_object('titulo', 'Por canal', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(cc.utm_campaign, 'Sem canal'), n, 'mkt.leads_campanha', p_par || jsonb_build_object('canal', cid), cc.canal) order by n desc)
        from (select campanha_canal_id cid, count(*) n from lp group by 1) z left join campanha_canais cc on cc.id = z.cid), '[]'::jsonb)) end,
      case when nova is null then jsonb_build_object('titulo', 'Novos ou da base', 'itens', jsonb_build_array(
        _arv_item('Novos na base', (select count(*) from lp where eh_nova), 'mkt.leads_campanha', p_par || '{"nova":"sim"}'),
        _arv_item('Já estavam na base', (select count(*) from lp where not eh_nova), 'mkt.leads_campanha', p_par || '{"nova":"nao"}'))) end,
      case when q is null then jsonb_build_object('titulo', 'Por qualificação', 'itens', coalesce((select jsonb_agg(_arv_item(case k when 'qualificado' then 'Qualificado' when 'nao_qualificado' then 'Não qualificado' else 'Pendente' end, n, 'mkt.leads_campanha', p_par || jsonb_build_object('qualificacao', k)) order by n desc)
        from (select coalesce(qualificacao, 'pendente') k, count(*) n from lp group by 1) z), '[]'::jsonb)) end,
      (select case when min(d) < max(d) then _arv_meses('mkt.leads_campanha', p_par, min(d), max(d), (select jsonb_object_agg(k, n) from (select to_char(d, 'YYYY-MM') k, count(*) n from lp group by 1) z)) end from lp)),
    'registros', jsonb_build_object('titulo', 'Pessoas', 'total', (select count(*) from lp),
      'cols', jsonb_build_array('Entrou em', 'Nome', 'Canal', 'Qualificação', 'Novo?', 'Cadastros'), 'un', jsonb_build_array('dt', 't', 't', 't', 't', 'n'),
      'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(lp.entrou_em, lp.nome, cc.utm_campaign, coalesce(lp.qualificacao, 'pendente'), case when lp.eh_nova then 'novo' else 'base' end, lp.tentativas),
          'abrir', jsonb_build_object('tipo', 'pessoa', 'id', lp.pessoa_id)) order by lp.entrou_em desc)
        from (select * from lp order by entrou_em desc limit 200) lp left join campanha_canais cc on cc.id = lp.campanha_canal_id), '[]'::jsonb))
  ) into r;
  return r;
end $$;

-- ===================== Anúncios (investimento, impressões, cliques...) =====================
create or replace function public._arv_ads(p_ws uuid, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare campo text := coalesce(p_par ->> 'campo', 'custo'); ini date := _arv_d(p_par, 'ini', '2000-01-01'); fim date := _arv_d(p_par, 'fim', '2100-12-31');
  camp uuid := _arv_u(p_par, 'campanha'); utm text := nullif(p_par ->> 'utm', ''); an uuid := _arv_u(p_par, 'anuncio'); plat text := nullif(p_par ->> 'plataforma', ''); tem_ads boolean; r jsonb;
begin
  if _arv_u(p_par, 'canal') is not null then select utm_campaign into utm from campanha_canais where id = _arv_u(p_par, 'canal'); end if;
  select exists (select 1 from v_trafego_anuncio_dia t where t.workspace_id = p_ws and (camp is null or t.campanha_id = camp) and t.custo > 0) into tem_ads;
  -- investimento de campanha sem anúncio: contas a pagar e custos de CAC ligados à campanha
  if campo = 'custo' and camp is not null and not tem_ads then
    with cp as (select c.id, coalesce(c.competencia, c.vencimento) d, c.valor, c.descricao, c.campanha_canal_id cid, f.nome forn
                  from contas_pagar c left join fornecedores f on f.id = c.fornecedor_id
                 where c.workspace_id = p_ws and c.campanha_id = camp and c.status <> 'cancelado' and coalesce(c.competencia, c.vencimento) between ini and fim
                   and (_arv_u(p_par, 'canal') is null or c.campanha_canal_id = _arv_u(p_par, 'canal'))
                union all select k.id, k.competencia, k.valor, k.descricao, k.campanha_canal_id, null from custos_cac k
                 where k.workspace_id = p_ws and k.campanha_id = camp and k.competencia between ini and fim and (_arv_u(p_par, 'canal') is null or k.campanha_canal_id = _arv_u(p_par, 'canal')))
    select jsonb_build_object('titulo', 'Investimento da campanha', 'valor', (select coalesce(sum(valor), 0) from cp), 'un', 'brl',
      'explica', 'A campanha não tem custo de anúncio importado: o investimento são as contas a pagar e os custos de CAC ligados a ela.',
      'quebras', jsonb_build_array(jsonb_build_object('titulo', 'Por canal', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(cc.utm_campaign, 'Sem canal'), s, 'mkt.ads', p_par || jsonb_build_object('canal', cid)) order by s desc)
        from (select cid, sum(valor) s from cp group by 1) z left join campanha_canais cc on cc.id = z.cid), '[]'::jsonb))),
      'registros', jsonb_build_object('titulo', 'Contas a pagar', 'total', (select count(*) from cp), 'cols', jsonb_build_array('Competência', 'Descrição', 'Fornecedor', 'Valor'), 'un', jsonb_build_array('d', 't', 't', 'brl'),
        'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(d, descricao, forn, valor)) order by d desc) from cp), '[]'::jsonb))) into r;
    return r;
  end if;
  with t as (select t.*, case campo when 'custo' then t.custo when 'impressoes' then t.impressoes when 'cliques' then t.cliques when 'visualizacoes' then t.visualizacoes_pagina
                                     when 'leads' then t.leads when 'alcance' then t.alcance when 'vendas' then t.vendas when 'receita' then t.receita when 'clientes' then t.clientes end x
               from v_trafego_anuncio_dia t where t.workspace_id = p_ws and t.data between ini and fim
                and (camp is null or t.campanha_id = camp) and (utm is null or t.utm_campaign = utm) and (an is null or t.anuncio_id = an) and (plat is null or t.canal = plat))
  select jsonb_build_object('titulo', case campo when 'custo' then 'Investimento em anúncios' when 'impressoes' then 'Impressões' when 'cliques' then 'Cliques'
                                                 when 'visualizacoes' then 'Visitas à página' when 'leads' then 'Leads atribuídos aos anúncios' when 'vendas' then 'Vendas atribuídas aos anúncios'
                                                 when 'receita' then 'Receita atribuída aos anúncios' when 'clientes' then 'Clientes atribuídos aos anúncios' else campo end
                                      || coalesce(' · ' || (select max(anuncio) from t where an is not null), ''),
    'valor', (select coalesce(sum(x), 0) from t), 'un', case when campo in ('custo', 'receita') then 'brl' else 'n' end,
    'explica', 'Soma dos números diários dos anúncios (Mídia paga), de ' || to_char(greatest(ini, (select min(data) from t)), 'DD/MM/YYYY') || ' a ' || to_char(least(fim, (select max(data) from t)), 'DD/MM/YYYY') || '.',
    'quebras', jsonb_build_array(
      case when camp is null then jsonb_build_object('titulo', 'Por campanha', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(campanha, 'Sem campanha'), s, 'mkt.ads', p_par || jsonb_build_object('campanha', campanha_id)) order by s desc)
        from (select campanha_id, campanha, sum(x) s from t group by 1, 2) z), '[]'::jsonb)) end,
      case when utm is null then jsonb_build_object('titulo', 'Por canal (utm_campaign)', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(utm_campaign, 'Sem utm'), s, 'mkt.ads', p_par || jsonb_build_object('utm', utm_campaign), canal) order by s desc)
        from (select utm_campaign, max(canal) canal, sum(x) s from t group by 1) z), '[]'::jsonb)) end,
      case when an is null then jsonb_build_object('titulo', 'Por anúncio', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(anuncio, utm_content, '—'), s, 'mkt.ads', p_par || jsonb_build_object('anuncio', anuncio_id), utm_campaign) order by s desc)
        from (select anuncio_id, anuncio, utm_content, max(utm_campaign) utm_campaign, sum(x) s from t group by 1, 2, 3 order by 5 desc limit 40) z), '[]'::jsonb)) end,
      (select case when min(data) < max(data) then _arv_meses('mkt.ads', p_par, greatest(ini, min(data)), least(fim, max(data)), (select jsonb_object_agg(k, s) from (select to_char(data, 'YYYY-MM') k, sum(x) s from t group by 1) z)) end from t)),
    'registros', jsonb_build_object('titulo', 'Anúncio por dia', 'total', (select count(*) from t),
      'cols', jsonb_build_array('Dia', 'Anúncio', 'Canal', 'Investido', 'Impressões', 'Cliques', 'Leads'), 'un', jsonb_build_array('d', 't', 't', 'brl', 'n', 'n', 'n'),
      'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(data, anuncio, utm_campaign, custo, impressoes, cliques, leads)) order by data desc, custo desc)
        from (select * from t order by data desc, custo desc limit 200) z), '[]'::jsonb))
  ) into r;
  return r;
end $$;

-- ===================== Clientes (quem comprou) =====================
create or replace function public._arv_clientes(p_ws uuid, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare camp uuid := _arv_u(p_par, 'campanha'); v_canal uuid := _arv_u(p_par, 'canal'); coorte boolean := coalesce((p_par ->> 'coorte')::boolean, false);
  ini date := _arv_d(p_par, 'ini'); fim date := _arv_d(p_par, 'fim'); r jsonb;
begin
  with v as (select v.pessoa_id, min(v.data_venda) primeira, count(*) n, sum(v.valor_bruto) rec,
                    (select cp.campanha_canal_id from campanha_participacoes cp where cp.campanha_id = camp and cp.pessoa_id = v.pessoa_id limit 1) cid
               from vendas v where v.workspace_id = p_ws and v.status = 'aprovada'
                and (camp is null or coorte or v.campanha_id = camp)
                and (not coorte or v.pessoa_id in (select id from pessoas p where p.workspace_id = p_ws and p.captada
                       and p.criado_em >= (ini::timestamp at time zone 'America/Sao_Paulo') and p.criado_em < ((fim + 1)::timestamp at time zone 'America/Sao_Paulo')
                       and (camp is null or p.campanha_id = camp)))
               group by v.pessoa_id),
  vf as (select * from v where v_canal is null or cid = v_canal)
  select jsonb_build_object('titulo', 'Clientes' || case when coorte then ' (leads do período que compraram)' when camp is not null then ' da campanha' else '' end, 'valor', (select count(*) from vf), 'un', 'n',
    'explica', case when coorte then 'Pessoas que viraram lead no período e têm venda aprovada (em qualquer data).' else 'Pessoas diferentes com venda aprovada' || case when camp is not null then ' desta campanha.' else '.' end end,
    'quebras', jsonb_build_array(case when camp is not null and v_canal is null then jsonb_build_object('titulo', 'Por canal (por onde entrou)', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(cc.utm_campaign, 'Sem canal'), n, 'mkt.clientes', p_par || jsonb_build_object('canal', cid), cc.canal) order by n desc)
      from (select cid, count(*) n from vf group by 1) z left join campanha_canais cc on cc.id = z.cid), '[]'::jsonb)) end),
    'registros', jsonb_build_object('titulo', 'Clientes', 'total', (select count(*) from vf), 'cols', jsonb_build_array('Primeira compra', 'Nome', 'Compras', 'Valor'), 'un', jsonb_build_array('dt', 't', 'n', 'brl'),
      'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(vf.primeira, p.nome, vf.n, vf.rec), 'abrir', jsonb_build_object('tipo', 'pessoa', 'id', vf.pessoa_id)) order by vf.primeira desc)
        from (select * from vf order by primeira desc limit 200) vf left join pessoas p on p.id = vf.pessoa_id), '[]'::jsonb))
  ) into r;
  return r;
end $$;

-- ===================== Caixa, a receber, a pagar, recorrência =====================
create or replace function public._arv_caixa(p_ws uuid, p_no text, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare h date := _arv_d(p_par, 'hoje', (now() at time zone 'America/Sao_Paulo')::date); ini date := _arv_d(p_par, 'ini'); fim date := _arv_d(p_par, 'fim');
  banco uuid := _arv_u(p_par, 'banco'); forn uuid := _arv_u(p_par, 'fornecedor'); atraso boolean := coalesce((p_par ->> 'atraso')::boolean, false); r jsonb;
begin
  if p_no = 'fin.saldo' then
    if banco is null then
      select jsonb_build_object('titulo', 'Saldo em banco', 'valor', coalesce(sum(saldo_atual), 0), 'un', 'brl', 'explica', 'Saldo inicial de cada conta bancária mais as entradas menos as saídas registradas.',
        'quebras', jsonb_build_array(jsonb_build_object('titulo', 'Por conta bancária', 'itens', coalesce(jsonb_agg(_arv_item(nome, saldo_atual, 'fin.saldo', p_par || jsonb_build_object('banco', conta_bancaria_id)) order by saldo_atual desc), '[]'::jsonb))))
        into r from v_saldo_contas_bancarias where workspace_id = p_ws;
    else
      with mv as (select * from movimentacoes_bancarias where workspace_id = p_ws and conta_bancaria_id = banco)
      select jsonb_build_object('titulo', 'Saldo · ' || s.nome, 'valor', s.saldo_atual, 'un', 'brl', 'explica', 'Saldo inicial + entradas − saídas desta conta.',
        'formula', jsonb_build_array(_arv_item('Saldo inicial', s.saldo_inicial, null, null),
          _arv_item('+ Entradas', (select coalesce(sum(valor), 0) from mv where tipo = 'entrada'), null, null),
          _arv_item('− Saídas', (select coalesce(sum(valor), 0) from mv where tipo = 'saida'), null, null)),
        'registros', jsonb_build_object('titulo', 'Movimentações', 'total', (select count(*) from mv), 'cols', jsonb_build_array('Data', 'Descrição', 'Tipo', 'Valor'), 'un', jsonb_build_array('d', 't', 't', 'brl'),
          'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(data, descricao, tipo, case when tipo = 'saida' then -valor else valor end)) order by data desc) from (select * from mv order by data desc limit 200) z), '[]'::jsonb)))
        into r from v_saldo_contas_bancarias s where s.workspace_id = p_ws and s.conta_bancaria_id = banco;
    end if;
    return r;
  end if;
  if p_no = 'fin.receber' then
    with cr as (select cr.*, coalesce(pv.id, pc.id) pessoa_id, coalesce(pv.nome, pc.nome, '—') nome, coalesce(nullif(cr.descricao, ''), pr.nome, '') descr
                  from contas_receber cr left join vendas ve on ve.id = cr.venda_id left join pessoas pv on pv.id = ve.pessoa_id left join produtos pr on pr.id = ve.produto_id
                  left join contratos ct on ct.id = cr.contrato_id left join pessoas pc on pc.id = ct.pessoa_id
                 where cr.workspace_id = p_ws and cr.status = 'previsto' and (case when atraso then cr.vencimento < h else cr.vencimento between ini and fim end))
    select jsonb_build_object('titulo', case when atraso then 'A receber em atraso' else 'A receber' end, 'valor', (select coalesce(sum(valor), 0) from cr), 'un', 'brl',
      'explica', case when atraso then 'Parcelas previstas com vencimento antes de hoje.' else 'Parcelas previstas com vencimento entre ' || to_char(ini, 'DD/MM/YYYY') || ' e ' || to_char(fim, 'DD/MM/YYYY') || '.' end,
      'quebras', jsonb_build_array(jsonb_build_object('titulo', 'Por cliente', 'itens', coalesce((select jsonb_agg(_arv_item(nome, s, null, null, n || ' parcela(s)') order by s desc) from (select nome, sum(valor) s, count(*) n from cr group by 1 order by 2 desc limit 30) z), '[]'::jsonb)),
        case when not atraso then _arv_meses('fin.receber', p_par, ini, fim, (select jsonb_object_agg(k, s) from (select to_char(vencimento, 'YYYY-MM') k, sum(valor) s from cr group by 1) z)) end),
      'registros', jsonb_build_object('titulo', 'Parcelas', 'total', (select count(*) from cr), 'cols', jsonb_build_array('Vencimento', 'Cliente', 'Descrição', 'Valor'), 'un', jsonb_build_array('d', 't', 't', 'brl'),
        'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(vencimento, nome, descr, valor), 'abrir', case when pessoa_id is not null then jsonb_build_object('tipo', 'pessoa', 'id', pessoa_id) end) order by vencimento) from (select * from cr order by vencimento limit 200) z), '[]'::jsonb))) into r;
    return r;
  end if;
  if p_no = 'fin.pagar' then
    with cp as (select cp.*, coalesce(f.nome, 'Sem fornecedor') forn, pc.codigo || ' ' || pc.nome conta from contas_pagar cp left join fornecedores f on f.id = cp.fornecedor_id left join plano_contas pc on pc.id = cp.conta_despesa_id
                 where cp.workspace_id = p_ws and cp.status = 'previsto' and (forn is null or cp.fornecedor_id = forn) and (case when atraso then cp.vencimento < h else cp.vencimento between ini and fim end))
    select jsonb_build_object('titulo', case when atraso then 'A pagar em atraso' else 'A pagar' end, 'valor', (select coalesce(sum(valor), 0) from cp), 'un', 'brl',
      'explica', case when atraso then 'Contas previstas com vencimento antes de hoje.' else 'Contas previstas com vencimento entre ' || to_char(ini, 'DD/MM/YYYY') || ' e ' || to_char(fim, 'DD/MM/YYYY') || '.' end,
      'quebras', jsonb_build_array(
        case when forn is null then jsonb_build_object('titulo', 'Por fornecedor', 'itens', coalesce((select jsonb_agg(_arv_item(forn, s, 'fin.pagar', p_par || jsonb_build_object('fornecedor', fornecedor_id)) order by s desc) from (select fornecedor_id, forn, sum(valor) s from cp group by 1, 2) z), '[]'::jsonb)) end,
        jsonb_build_object('titulo', 'Por conta de despesa', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(conta, 'Sem conta'), s, null, null) order by s desc) from (select conta, sum(valor) s from cp group by 1) z), '[]'::jsonb)),
        case when not atraso then _arv_meses('fin.pagar', p_par, ini, fim, (select jsonb_object_agg(k, s) from (select to_char(vencimento, 'YYYY-MM') k, sum(valor) s from cp group by 1) z)) end),
      'registros', jsonb_build_object('titulo', 'Contas', 'total', (select count(*) from cp), 'cols', jsonb_build_array('Vencimento', 'Descrição', 'Fornecedor', 'Conta', 'Valor'), 'un', jsonb_build_array('d', 't', 't', 't', 'brl'),
        'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(vencimento, descricao, forn, conta, valor)) order by vencimento) from (select * from cp order by vencimento limit 200) z), '[]'::jsonb))) into r;
    return r;
  end if;
  if p_no = 'rec.mrr' then
    with ct as (select c.*, p.nome, coalesce((select sum(coalesce(i.quantidade, 1) * coalesce(i.valor, 0)) from contrato_itens i where i.contrato_id = c.id), 0)
                  / case c.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end mrr
                  from contratos c left join pessoas p on p.id = c.pessoa_id
                 where c.workspace_id = p_ws and c.recorrente and c.ativado_em is not null and c.data_inicio <= h and (c.data_fim is null or c.data_fim >= h)
                   and not (c.cancelado_em is not null and (c.cancelado_em at time zone 'America/Sao_Paulo')::date <= h))
    select jsonb_build_object('titulo', 'MRR (receita recorrente mensal)', 'valor', (select coalesce(sum(mrr), 0) from ct), 'un', 'brl',
      'explica', 'Contratos recorrentes ativos hoje: valor dos itens ÷ meses do período de cobrança (mensal 1, trimestral 3, semestral 6, anual 12).',
      'quebras', jsonb_build_array(jsonb_build_object('titulo', 'Por periodicidade', 'itens', coalesce((select jsonb_agg(_arv_item(periodicidade, s, null, null, n || ' contrato(s)') order by s desc) from (select periodicidade, sum(mrr) s, count(*) n from ct group by 1) z), '[]'::jsonb))),
      'registros', jsonb_build_object('titulo', 'Contratos ativos', 'total', (select count(*) from ct), 'cols', jsonb_build_array('Início', 'Cliente', 'Contrato', 'Periodicidade', 'MRR'), 'un', jsonb_build_array('d', 't', 't', 't', 'brl'),
        'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(data_inicio, nome, numero, periodicidade, mrr), 'abrir', jsonb_build_object('tipo', 'pessoa', 'id', pessoa_id)) order by mrr desc) from (select * from ct order by mrr desc limit 200) z), '[]'::jsonb))) into r;
    return r;
  end if;
  return null;
end $$;


-- unidade de um item da fórmula, pelo nó para onde ele leva
create or replace function public._arv_un(p_no text, p_par jsonb, p_rot text) returns text
language sql immutable as $$
  select case
    when p_rot like '× 12%' then 'n'
    when p_no in ('crm.pessoas', 'mkt.leads_campanha', 'mkt.clientes') then 'n'
    when p_no = 'ven.soma' then case when p_par ->> 'campo' = 'qtd' then 'n' else 'brl' end
    when p_no = 'mkt.ads' then case when coalesce(p_par ->> 'campo', 'custo') in ('custo', 'receita') then 'brl' else 'n' end
    else 'brl' end $$;

-- ===================== Dispatcher: nós compostos (fórmulas) e acesso =====================
create or replace function public.arvore_no(p_ws uuid, p_no text, p_par jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare par jsonb := coalesce(p_par, '{}'::jsonb); modulo text; a jsonb; b jsonb; c jsonb; d jsonb; va numeric; vb numeric; r jsonb; camp uuid := _arv_u(par, 'campanha');
  inv jsonb; lds jsonb; cli jsonb; rec jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este workspace'; end if;
  if camp is not null and not exists (select 1 from campanhas where id = camp and workspace_id = p_ws) then raise exception 'Campanha não encontrada'; end if;
  modulo := case split_part(p_no, '.', 1) when 'fin' then 'fin' when 'rec' then 'fin' when 'ven' then 'vendas' when 'crm' then 'vendas' else 'mkt' end;
  if not perm(p_ws, 'ler', case modulo when 'vendas' then '{vendas,mkt,fin}' when 'fin' then '{fin}' else '{mkt,vendas}' end::text[]) then
    raise exception 'Sem acesso a este número (módulo %)', modulo; end if;

  case p_no
  when 'fin.razao' then r := _arv_razao(p_ws, par);
  when 'fin.lucro', 'fin.saidas', 'fin.margem', 'fin.roi' then
    a := _arv_razao(p_ws, par || '{"grupo":"receita"}'); b := _arv_razao(p_ws, par || '{"grupo":"deducao"}');
    c := _arv_razao(p_ws, par || '{"grupo":"custo"}'); d := _arv_razao(p_ws, par || '{"grupo":"despesa"}');
    va := (a ->> 'valor')::numeric; vb := (b ->> 'valor')::numeric + (c ->> 'valor')::numeric + (d ->> 'valor')::numeric;
    r := case p_no
      when 'fin.lucro' then jsonb_build_object('titulo', 'Lucro (resultado)', 'valor', va - vb, 'un', 'brl', 'explica', 'Receitas menos deduções, custos e despesas lançados no período (DRE).',
        'formula', jsonb_build_array(_arv_item('Receitas', va, 'fin.razao', par || '{"grupo":"receita"}'), _arv_item('− Deduções', (b ->> 'valor')::numeric, 'fin.razao', par || '{"grupo":"deducao"}'),
          _arv_item('− Custos', (c ->> 'valor')::numeric, 'fin.razao', par || '{"grupo":"custo"}'), _arv_item('− Despesas', (d ->> 'valor')::numeric, 'fin.razao', par || '{"grupo":"despesa"}')))
      when 'fin.saidas' then jsonb_build_object('titulo', 'Despesas no período', 'valor', vb, 'un', 'brl', 'explica', 'Deduções + custos + despesas lançados no período.',
        'formula', jsonb_build_array(_arv_item('Deduções', (b ->> 'valor')::numeric, 'fin.razao', par || '{"grupo":"deducao"}'), _arv_item('+ Custos', (c ->> 'valor')::numeric, 'fin.razao', par || '{"grupo":"custo"}'),
          _arv_item('+ Despesas', (d ->> 'valor')::numeric, 'fin.razao', par || '{"grupo":"despesa"}')))
      when 'fin.margem' then jsonb_build_object('titulo', 'Margem', 'valor', case when va > 0 then (va - vb) / va end, 'un', 'pct', 'explica', 'Lucro ÷ receitas.',
        'formula', jsonb_build_array(_arv_item('Lucro', va - vb, 'fin.lucro', par), _arv_item('÷ Receitas', va, 'fin.razao', par || '{"grupo":"receita"}')))
      else jsonb_build_object('titulo', 'ROI', 'valor', case when vb > 0 then (va - vb) / vb end, 'un', 'pct', 'explica', 'Lucro ÷ tudo o que saiu (deduções, custos e despesas).',
        'formula', jsonb_build_array(_arv_item('Lucro', va - vb, 'fin.lucro', par), _arv_item('÷ Saídas', vb, 'fin.saidas', par))) end;
  when 'fin.saldo', 'fin.receber', 'fin.pagar', 'rec.mrr' then r := _arv_caixa(p_ws, p_no, par);
  when 'rec.arr' then a := _arv_caixa(p_ws, 'rec.mrr', par);
    r := jsonb_build_object('titulo', 'ARR', 'valor', (a ->> 'valor')::numeric * 12, 'un', 'brl', 'explica', 'MRR × 12.', 'formula', jsonb_build_array(_arv_item('MRR', (a ->> 'valor')::numeric, 'rec.mrr', par), _arv_item('× 12 meses', 12, null, null)));
  when 'ven.soma' then r := _arv_vendas(p_ws, par);
  when 'ven.ticket' then a := _arv_vendas(p_ws, par || '{"campo":"bruto"}'); b := _arv_vendas(p_ws, par || '{"campo":"qtd"}');
    r := jsonb_build_object('titulo', 'Ticket médio', 'valor', case when (b ->> 'valor')::numeric > 0 then (a ->> 'valor')::numeric / (b ->> 'valor')::numeric end, 'un', 'brl', 'explica', 'Receita bruta ÷ número de vendas.',
      'formula', jsonb_build_array(_arv_item('Receita bruta', (a ->> 'valor')::numeric, 'ven.soma', par || '{"campo":"bruto"}'), _arv_item('÷ Vendas', (b ->> 'valor')::numeric, 'ven.soma', par || '{"campo":"qtd"}')));
  when 'crm.pessoas' then r := _arv_pessoas(p_ws, par);
  when 'crm.conv' then a := _arv_pessoas(p_ws, par || '{"filtro":"clientes"}'); b := _arv_pessoas(p_ws, par || '{"filtro":"todos"}');
    r := jsonb_build_object('titulo', 'Lead → cliente', 'valor', case when (b ->> 'valor')::numeric > 0 then (a ->> 'valor')::numeric / (b ->> 'valor')::numeric end, 'un', 'pct', 'explica', 'Clientes ÷ pessoas no funil.',
      'formula', jsonb_build_array(_arv_item('Clientes', (a ->> 'valor')::numeric, 'crm.pessoas', par || '{"filtro":"clientes"}'), _arv_item('÷ Pessoas', (b ->> 'valor')::numeric, 'crm.pessoas', par || '{"filtro":"todos"}')));
  when 'mkt.leads_campanha' then r := _arv_participacoes(p_ws, par);
  when 'mkt.ads' then r := _arv_ads(p_ws, par);
  when 'mkt.clientes' then r := _arv_clientes(p_ws, par);
  when 'mkt.cpl', 'mkt.cac', 'mkt.roas', 'mkt.roi', 'mkt.conv', 'mkt.ctr', 'mkt.cpc', 'mkt.connect' then
    -- campanha: leads novos (cadastro criado pela campanha), clientes e receita da campanha; período: coorte de leads do período (Dashboard de marketing)
    inv := _arv_ads(p_ws, par || '{"campo":"custo"}');
    lds := case when camp is not null and par ->> 'ini' is null then _arv_pessoas(p_ws, par || '{"filtro":"novos_campanha"}') else _arv_pessoas(p_ws, par || '{"filtro":"leads_periodo"}') end;
    cli := _arv_clientes(p_ws, par || case when camp is not null and par ->> 'ini' is null then '{}' else '{"coorte":true}' end::jsonb);
    rec := _arv_vendas(p_ws, par || case when camp is not null and par ->> 'ini' is null then '{"campo":"bruto"}' else '{"campo":"liquido","coorte":true}' end::jsonb);
    va := (inv ->> 'valor')::numeric;
    r := case p_no
      when 'mkt.cpl' then jsonb_build_object('titulo', 'Custo por lead', 'valor', case when (lds ->> 'valor')::numeric > 0 then va / (lds ->> 'valor')::numeric end, 'un', 'brl', 'explica', 'Investimento ÷ leads.',
        'formula', jsonb_build_array(_arv_item('Investimento', va, 'mkt.ads', par || '{"campo":"custo"}'), _arv_item('÷ ' || (lds ->> 'titulo'), (lds ->> 'valor')::numeric, 'crm.pessoas', par || jsonb_build_object('filtro', case when camp is not null and par ->> 'ini' is null then 'novos_campanha' else 'leads_periodo' end))))
      when 'mkt.cac' then jsonb_build_object('titulo', 'CAC', 'valor', case when (cli ->> 'valor')::numeric > 0 then va / (cli ->> 'valor')::numeric end, 'un', 'brl', 'explica', 'Investimento ÷ clientes.',
        'formula', jsonb_build_array(_arv_item('Investimento', va, 'mkt.ads', par || '{"campo":"custo"}'), _arv_item('÷ ' || (cli ->> 'titulo'), (cli ->> 'valor')::numeric, 'mkt.clientes', par || case when camp is not null and par ->> 'ini' is null then '{}' else '{"coorte":true}' end::jsonb)))
      when 'mkt.roas' then jsonb_build_object('titulo', 'ROAS', 'valor', case when va > 0 then (rec ->> 'valor')::numeric / va end, 'un', 'x', 'explica', 'Receita ÷ investimento.',
        'formula', jsonb_build_array(_arv_item(rec ->> 'titulo', (rec ->> 'valor')::numeric, 'ven.soma', par || case when camp is not null and par ->> 'ini' is null then '{"campo":"bruto"}' else '{"campo":"liquido","coorte":true}' end::jsonb), _arv_item('÷ Investimento', va, 'mkt.ads', par || '{"campo":"custo"}')))
      when 'mkt.roi' then jsonb_build_object('titulo', 'ROI da mídia', 'valor', case when va > 0 then ((rec ->> 'valor')::numeric - va) / va end, 'un', 'pct', 'explica', '(Receita − investimento) ÷ investimento.',
        'formula', jsonb_build_array(_arv_item(rec ->> 'titulo', (rec ->> 'valor')::numeric, 'ven.soma', par || '{"campo":"liquido","coorte":true}'), _arv_item('− Investimento', va, 'mkt.ads', par || '{"campo":"custo"}'), _arv_item('÷ Investimento', va, 'mkt.ads', par || '{"campo":"custo"}')))
      when 'mkt.conv' then jsonb_build_object('titulo', 'Lead → venda', 'valor', case when (lds ->> 'valor')::numeric > 0 then (cli ->> 'valor')::numeric / (lds ->> 'valor')::numeric end, 'un', 'pct', 'explica', 'Clientes ÷ leads.',
        'formula', jsonb_build_array(_arv_item(cli ->> 'titulo', (cli ->> 'valor')::numeric, 'mkt.clientes', par || case when camp is not null and par ->> 'ini' is null then '{}' else '{"coorte":true}' end::jsonb), _arv_item('÷ ' || (lds ->> 'titulo'), (lds ->> 'valor')::numeric, 'crm.pessoas', par || jsonb_build_object('filtro', case when camp is not null and par ->> 'ini' is null then 'novos_campanha' else 'leads_periodo' end))))
      else (select jsonb_build_object('titulo', case p_no when 'mkt.ctr' then 'CTR' when 'mkt.cpc' then 'Custo por clique' else 'Connect rate' end,
          'valor', case p_no when 'mkt.ctr' then case when ii > 0 then cq / ii end when 'mkt.cpc' then case when cq > 0 then va / cq end else case when cq > 0 then vv / cq end end,
          'un', case p_no when 'mkt.cpc' then 'brl' else 'pct' end, 'explica', case p_no when 'mkt.ctr' then 'Cliques ÷ impressões.' when 'mkt.cpc' then 'Investimento ÷ cliques.' else 'Visitas à página ÷ cliques.' end,
          'formula', case p_no when 'mkt.ctr' then jsonb_build_array(_arv_item('Cliques', cq, 'mkt.ads', par || '{"campo":"cliques"}'), _arv_item('÷ Impressões', ii, 'mkt.ads', par || '{"campo":"impressoes"}'))
                               when 'mkt.cpc' then jsonb_build_array(_arv_item('Investimento', va, 'mkt.ads', par || '{"campo":"custo"}'), _arv_item('÷ Cliques', cq, 'mkt.ads', par || '{"campo":"cliques"}'))
                               else jsonb_build_array(_arv_item('Visitas à página', vv, 'mkt.ads', par || '{"campo":"visualizacoes"}'), _arv_item('÷ Cliques', cq, 'mkt.ads', par || '{"campo":"cliques"}')) end)
         from (select (_arv_ads(p_ws, par || '{"campo":"cliques"}') ->> 'valor')::numeric cq, (_arv_ads(p_ws, par || '{"campo":"impressoes"}') ->> 'valor')::numeric ii,
                      (_arv_ads(p_ws, par || '{"campo":"visualizacoes"}') ->> 'valor')::numeric vv) z) end;
  when 'mkt.trf_cpl', 'mkt.trf_cac', 'mkt.trf_roas' then  -- Mídia paga: tudo pelos números dos anúncios
    a := _arv_ads(p_ws, par || '{"campo":"custo"}');
    b := _arv_ads(p_ws, par || jsonb_build_object('campo', case p_no when 'mkt.trf_cpl' then 'leads' when 'mkt.trf_cac' then 'clientes' else 'receita' end));
    va := (a ->> 'valor')::numeric; vb := (b ->> 'valor')::numeric;
    r := jsonb_build_object('titulo', case p_no when 'mkt.trf_cpl' then 'CPL dos anúncios' when 'mkt.trf_cac' then 'CAC dos anúncios' else 'ROAS dos anúncios' end,
      'valor', case when p_no = 'mkt.trf_roas' then case when va > 0 then vb / va end else case when vb > 0 then va / vb end end, 'un', case when p_no = 'mkt.trf_roas' then 'x' else 'brl' end,
      'explica', 'Pelos números diários dos anúncios (Mídia paga).',
      'formula', case when p_no = 'mkt.trf_roas' then jsonb_build_array(_arv_item(b ->> 'titulo', vb, 'mkt.ads', par || '{"campo":"receita"}'), _arv_item('÷ Investimento', va, 'mkt.ads', par || '{"campo":"custo"}'))
                      else jsonb_build_array(_arv_item('Investimento', va, 'mkt.ads', par || '{"campo":"custo"}'), _arv_item('÷ ' || (b ->> 'titulo'), vb, 'mkt.ads', par || jsonb_build_object('campo', case p_no when 'mkt.trf_cpl' then 'leads' else 'clientes' end))) end);
  else raise exception 'Número sem árvore: %', p_no;
  end case;
  if jsonb_typeof(r -> 'formula') = 'array' then
    r := jsonb_set(r, '{formula}', (select jsonb_agg(e || jsonb_build_object('un', _arv_un(e ->> 'no', e -> 'par', e ->> 'rotulo')) order by i) from jsonb_array_elements(r -> 'formula') with ordinality x(e, i)));
  end if;
  return r || jsonb_build_object('no', p_no, 'par', par);
end $$;

revoke execute on function public.arvore_no(uuid, text, jsonb) from public, anon;
grant execute on function public.arvore_no(uuid, text, jsonb) to authenticated;
do $$ declare f text; begin
  foreach f in array array['_arv_razao(uuid,jsonb)', '_arv_vendas(uuid,jsonb)', '_arv_pessoas(uuid,jsonb)', '_arv_participacoes(uuid,jsonb)', '_arv_ads(uuid,jsonb)', '_arv_clientes(uuid,jsonb)', '_arv_caixa(uuid,text,jsonb)'] loop
    execute 'revoke execute on function public.' || f || ' from public, anon, authenticated';
  end loop;
end $$;
