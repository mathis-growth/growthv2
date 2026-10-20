-- v0.118 — Árvore dos números, parte 3
-- Nós novos (_arv_extra2): fin.caixa30 (Caixa projetado em 30 dias), ven.venda (uma venda: valores, parcelas, lançamentos),
--   fin.conta_pagar (uma conta a pagar e seus lançamentos), crm.novos (pessoas cadastradas no período, todas as origens),
--   crm.a_qualificar (qualificação "pendente").
--   mkt.camp_total (tabela Campanhas ativas do Painel: investido, CAC de mídia e ROAS da campanha desde o início).
-- Ligações novas (trechos trocados nas funções existentes, com conferência):
--   venda na lista de vendas → ven.venda; conta na lista de contas a pagar → fin.conta_pagar; lançamento → a venda ou a conta de origem.
-- Rode depois de 20261020200000_arvore_numeros_2.sql. Idempotente: pode rodar de novo, inclusive colado no editor do Supabase (cada troca confere uma marca de "já aplicado" e ignora quebras de linha do Windows).

create or replace function public._arv_extra2(p_ws uuid, p_no text, p_par jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare ini date := _arv_d(p_par, 'ini'); fim date := _arv_d(p_par, 'fim'); h date := _arv_d(p_par, 'hoje', (now() at time zone 'America/Sao_Paulo')::date);
  a jsonb; b jsonb; c jsonb; r jsonb; v vendas; cp contas_pagar; f text;
begin
  if p_no = 'fin.caixa30' then  -- mesma conta do Dashboard financeiro: saldo + a receber até d+30 (inclui atrasados) − a pagar até d+30
    a := _arv_caixa(p_ws, 'fin.saldo', '{}'::jsonb);
    b := _arv_caixa(p_ws, 'fin.receber', jsonb_build_object('ini', '1900-01-01', 'fim', h + 30, 'hoje', h, 'situacao', 'previsto'));
    c := _arv_caixa(p_ws, 'fin.pagar', jsonb_build_object('ini', '1900-01-01', 'fim', h + 30, 'hoje', h, 'situacao', 'previsto'));
    return jsonb_build_object('titulo', 'Caixa projetado em 30 dias', 'valor', (a ->> 'valor')::numeric + (b ->> 'valor')::numeric - (c ->> 'valor')::numeric, 'un', 'brl',
      'explica', 'Saldo de hoje + tudo o que está previsto para receber até ' || to_char(h + 30, 'DD/MM/YYYY') || ' (inclusive o que já venceu) − tudo o que está previsto para pagar até a mesma data.',
      'formula', jsonb_build_array(_arv_item('Saldo em banco', (a ->> 'valor')::numeric, 'fin.saldo', '{}'::jsonb),
        _arv_item('+ A receber até ' || to_char(h + 30, 'DD/MM'), (b ->> 'valor')::numeric, 'fin.receber', jsonb_build_object('ini', '1900-01-01', 'fim', h + 30, 'hoje', h, 'situacao', 'previsto')),
        _arv_item('− A pagar até ' || to_char(h + 30, 'DD/MM'), (c ->> 'valor')::numeric, 'fin.pagar', jsonb_build_object('ini', '1900-01-01', 'fim', h + 30, 'hoje', h, 'situacao', 'previsto'))));
  end if;
  if p_no = 'ven.venda' then
    select * into v from vendas where id = _arv_u(p_par, 'venda') and workspace_id = p_ws;
    if not found then raise exception 'Venda não encontrada'; end if;
    return jsonb_build_object('titulo', 'Venda: ' || coalesce((select nome from produtos where id = v.produto_id), 'sem produto') || ' · ' || coalesce((select nome from pessoas where id = v.pessoa_id), ''),
      'valor', v.valor_bruto, 'un', 'brl',
      'explica', 'Venda de ' || to_char((v.data_venda at time zone 'America/Sao_Paulo')::date, 'DD/MM/YYYY') || ', ' || v.status || coalesce(', ' || v.forma_pagamento, '') || coalesce(', ' || v.parcelas || 'x', '')
                 || coalesce(', campanha ' || (select nome from campanhas where id = v.campanha_id), '') || coalesce(', utm ' || v.utm_campaign, '') || '.',
      'pessoa', (select jsonb_build_object('id', p.id, 'nome', p.nome) from pessoas p where p.id = v.pessoa_id),
      'quebras', jsonb_build_array(jsonb_build_object('titulo', 'Do bruto ao líquido', 'itens', jsonb_build_array(_arv_item('Valor bruto', v.valor_bruto, null, null), _arv_item('− Taxa da plataforma', coalesce(v.taxa_plataforma, 0), null, null),
        _arv_item('− Impostos', coalesce(v.impostos, 0), null, null), _arv_item('= Líquido', v.valor_liquido, null, null))),
        jsonb_build_object('titulo', 'Lançamentos contábeis desta venda', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(l.descricao, 'Lançamento') || ' · ' || to_char(l.data_fato, 'DD/MM/YYYY'),
          (select sum(valor) from partidas where lancamento_id = l.id and tipo = 'D'), 'fin.lancamento', jsonb_build_object('lancamento', l.id)) order by l.data_fato)
        from lancamentos l where l.workspace_id = p_ws and ((l.origem_tipo in ('venda', 'estorno') and l.origem_id = v.id)
          or (l.origem_tipo = 'recebimento' and l.origem_id in (select id from contas_receber where venda_id = v.id)))), '[]'::jsonb))),
      'registros', jsonb_build_object('titulo', 'Parcelas a receber', 'total', (select count(*) from contas_receber where venda_id = v.id), 'cols', jsonb_build_array('Vencimento', 'Parcela', 'Situação', 'Recebido em', 'Valor'), 'un', jsonb_build_array('d', 'n', 't', 'd', 'brl'),
        'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(vencimento, parcela, status, data_recebimento, valor)) order by vencimento) from contas_receber where venda_id = v.id), '[]'::jsonb)));
  end if;
  if p_no = 'fin.conta_pagar' then
    select * into cp from contas_pagar where id = _arv_u(p_par, 'conta') and workspace_id = p_ws;
    if not found then raise exception 'Conta a pagar não encontrada'; end if;
    return jsonb_build_object('titulo', 'Conta a pagar: ' || coalesce(nullif(cp.descricao, ''), 'sem descrição'), 'valor', cp.valor, 'un', 'brl',
      'explica', coalesce((select nome from fornecedores where id = cp.fornecedor_id), 'Sem fornecedor') || ' · vence em ' || to_char(cp.vencimento, 'DD/MM/YYYY') || ' · ' || cp.status
                 || coalesce(' em ' || to_char(cp.data_pagamento, 'DD/MM/YYYY'), '') || coalesce(' · competência ' || to_char(cp.competencia, 'MM/YYYY'), '')
                 || coalesce(' · conta ' || (select codigo || ' ' || nome from plano_contas where id = cp.conta_despesa_id), '')
                 || coalesce(' · centro ' || (select nome from centros_custo where id = cp.centro_custo_id), '')
                 || coalesce(' · campanha ' || (select nome from campanhas where id = cp.campanha_id), '') || '.',
      'quebras', jsonb_build_array(jsonb_build_object('titulo', 'Lançamentos contábeis desta conta', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(l.descricao, 'Lançamento') || ' · ' || to_char(l.data_fato, 'DD/MM/YYYY'),
          (select sum(valor) from partidas where lancamento_id = l.id and tipo = 'D'), 'fin.lancamento', jsonb_build_object('lancamento', l.id)) order by l.data_fato)
        from lancamentos l where l.workspace_id = p_ws and l.origem_tipo in ('conta_pagar', 'pagamento') and l.origem_id = cp.id), '[]'::jsonb))));
  end if;
  if p_no in ('crm.novos', 'crm.a_qualificar') then  -- Dashboard de vendas
    with p as (select p.* from pessoas p where p.workspace_id = p_ws
                 and (p_no <> 'crm.novos' or (p.criado_em at time zone 'America/Sao_Paulo')::date >= ini)
                 and (p_no <> 'crm.a_qualificar' or p.qualificacao = 'pendente'))
    select jsonb_build_object('titulo', case p_no when 'crm.novos' then 'Pessoas novas' else 'A qualificar' end, 'valor', (select count(*) from p), 'un', 'n',
      'explica', case p_no when 'crm.novos' then 'Pessoas cadastradas desde ' || to_char(ini, 'DD/MM/YYYY') || ', de qualquer origem.' else 'Pessoas com qualificação pendente (pesquisa ainda não respondida).' end,
      'quebras', jsonb_build_array(jsonb_build_object('titulo', 'Por canal de origem', 'itens', coalesce((select jsonb_agg(_arv_item(k, n, null, null) order by n desc)
        from (select coalesce(nullif(canal_origem, ''), '(sem canal)') k, count(*) n from p group by 1) z), '[]'::jsonb)),
        jsonb_build_object('titulo', 'Por campanha', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(c.nome, 'Sem campanha'), n, null, null) order by n desc)
        from (select campanha_id, count(*) n from p group by 1) z left join campanhas c on c.id = z.campanha_id), '[]'::jsonb))),
      'registros', jsonb_build_object('titulo', 'Pessoas', 'total', (select count(*) from p), 'cols', jsonb_build_array('Entrou em', 'Nome', 'Origem'), 'un', jsonb_build_array('dt', 't', 't'),
        'linhas', coalesce((select jsonb_agg(jsonb_build_object('c', jsonb_build_array(criado_em, nome, coalesce(utm_campaign, canal_origem)), 'abrir', jsonb_build_object('tipo', 'pessoa', 'id', id)) order by criado_em desc) from (select * from p order by criado_em desc limit 200) z), '[]'::jsonb)))
      into r;
    return r;
  end if;
  if p_no = 'mkt.camp_total' then  -- tabela "Campanhas ativas" do Painel (v_marketing_campanha): totais desde o início, investimento = contas a pagar + custos de aquisição da campanha
    declare camp uuid := _arv_u(p_par, 'campanha'); f text := coalesce(p_par ->> 'campo', 'investimento'); inv numeric; cli bigint; rb numeric; nome text;
    begin
      select c.nome into nome from campanhas c where c.id = camp and c.workspace_id = p_ws;
      if not found then raise exception 'Campanha não encontrada'; end if;
      inv := coalesce((select sum(valor) from contas_pagar where campanha_id = camp and status <> 'cancelado'), 0) + coalesce((select sum(valor) from custos_cac where campanha_id = camp), 0);
      select count(distinct pessoa_id), coalesce(sum(valor_bruto), 0) into cli, rb from vendas where campanha_id = camp and status = 'aprovada';
      a := jsonb_build_array(jsonb_build_object('titulo', 'Contas a pagar da campanha', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(nullif(descricao, ''), 'Conta') || ' · ' || to_char(vencimento, 'DD/MM/YYYY'), valor, 'fin.conta_pagar', jsonb_build_object('conta', id)) order by vencimento)
          from contas_pagar where campanha_id = camp and status <> 'cancelado'), '[]'::jsonb)),
        jsonb_build_object('titulo', 'Custos de aquisição lançados na campanha', 'itens', coalesce((select jsonb_agg(_arv_item(coalesce(nullif(descricao, ''), grupo) || ' · ' || to_char(competencia, 'MM/YYYY'), valor, null, null) order by competencia) from custos_cac where campanha_id = camp), '[]'::jsonb)));
      if f = 'investimento' then
        return jsonb_build_object('titulo', 'Investido: ' || nome, 'valor', inv, 'un', 'brl', 'quebras', a,
          'explica', 'Tudo o que foi lançado para a campanha desde o início: contas a pagar ligadas a ela (menos as canceladas) e custos de aquisição. É o investimento da tabela de campanhas ativas do Painel; o gasto de anúncios importado das plataformas aparece em Mídia paga.');
      elsif f = 'cac' then
        return jsonb_build_object('titulo', 'CAC de mídia: ' || nome, 'valor', round(inv / nullif(cli, 0), 2), 'un', 'brl', 'explica', 'Investido na campanha ÷ clientes (pessoas com venda aprovada na campanha).',
          'formula', jsonb_build_array(_arv_item('Investido', inv, 'mkt.camp_total', jsonb_build_object('campanha', camp, 'campo', 'investimento')),
            _arv_item('÷ Clientes (pessoas distintas nas vendas aprovadas)', cli, 'ven.soma', jsonb_build_object('campanha', camp, 'campo', 'qtd')) || jsonb_build_object('un', 'n')));
      elsif f = 'roas' then
        return jsonb_build_object('titulo', 'ROAS: ' || nome, 'valor', round(rb / nullif(inv, 0), 2), 'un', 'x', 'explica', 'Receita bruta das vendas aprovadas da campanha ÷ investido na campanha.',
          'formula', jsonb_build_array(_arv_item('Receita bruta', rb, 'ven.soma', jsonb_build_object('campanha', camp, 'campo', 'bruto')),
            _arv_item('÷ Investido', inv, 'mkt.camp_total', jsonb_build_object('campanha', camp, 'campo', 'investimento'))));
      end if;
    end;
  end if;
  return null;
end $$;
revoke execute on function public._arv_extra2(uuid, text, jsonb) from public, anon, authenticated;

-- trocas nas funções existentes: cada uma confere se o trecho antigo existe (ou se a troca já foi feita)
do $do$ declare d text; antes text; depois text; fn text; i int;  -- trocas: função, trecho antigo, trecho novo, marca de que já foi aplicado
  trocas text[][] := array[
    ['public.arvore_no(uuid,text,jsonb)',
     $q$else r := _arv_extra(p_ws, p_no, par); if r is null then raise exception$q$,
     $q$else r := coalesce(_arv_extra(p_ws, p_no, par), _arv_extra2(p_ws, p_no, par)); if r is null then raise exception$q$,
     $q$_arv_extra2(p_ws, p_no, par)$q$],
    ['public._arv_vendas(uuid,jsonb)',
     $q$'abrir', jsonb_build_object('tipo', 'pessoa', 'id', vf.pessoa_id)) order by vf.data_venda desc)$q$,
     $q$'ir', case when vf.tipo = 'venda' then jsonb_build_object('no', 'ven.venda', 'par', jsonb_build_object('venda', vf.id)) end, 'rotulo', 'Venda', 'abrir', jsonb_build_object('tipo', 'pessoa', 'id', vf.pessoa_id)) order by vf.data_venda desc)$q$,
     $q$'no', 'ven.venda'$q$],
    ['public._arv_caixa(uuid,text,jsonb)',
     $q$jsonb_build_object('c', jsonb_build_array(vencimento, descricao, forn, conta, status, valor)) order by vencimento)$q$,
     $q$jsonb_build_object('c', jsonb_build_array(vencimento, descricao, forn, conta, status, valor), 'ir', jsonb_build_object('no', 'fin.conta_pagar', 'par', jsonb_build_object('conta', id)), 'rotulo', coalesce(descricao, 'Conta a pagar')) order by vencimento)$q$,
     $q$'no', 'fin.conta_pagar'$q$],
    ['public._arv_extra(uuid,text,jsonb)',
     $q$'pessoa', case when pid is not null then jsonb_build_object('id', pid, 'nome', pnome) end,$q$,
     $q$'quebras', jsonb_build_array(case when l.origem_tipo in ('venda', 'estorno') then jsonb_build_object('titulo', 'Origem', 'itens', jsonb_build_array(_arv_item('Venda', (select valor_bruto from vendas where id = l.origem_id), 'ven.venda', jsonb_build_object('venda', l.origem_id))))
        when l.origem_tipo in ('conta_pagar', 'pagamento') then jsonb_build_object('titulo', 'Origem', 'itens', jsonb_build_array(_arv_item('Conta a pagar', (select valor from contas_pagar where id = l.origem_id), 'fin.conta_pagar', jsonb_build_object('conta', l.origem_id)))) end),
      'pessoa', case when pid is not null then jsonb_build_object('id', pid, 'nome', pnome) end,$q$,
     $q$'titulo', 'Origem'$q$]];
begin
  for i in 1 .. array_length(trocas, 1) loop
    fn := trocas[i][1]; antes := replace(trocas[i][2], E'\r', ''); depois := replace(trocas[i][3], E'\r', '');
    -- quebras de linha do Windows (CRLF) ao colar no editor não podem atrapalhar a conferência
    d := replace(pg_get_functiondef(fn::regprocedure), E'\r', '');
    if position(depois in d) > 0 or position(replace(trocas[i][4], E'\r', '') in d) > 0 then continue; end if;  -- já trocado
    if position(antes in d) = 0 then raise exception 'Trecho não encontrado em %', fn; end if;
    execute replace(d, antes, depois);
  end loop;
end $do$;
