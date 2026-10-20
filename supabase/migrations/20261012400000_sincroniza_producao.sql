-- v0.110 — Auditoria: sincroniza o repositório com o banco de produção.
-- Estas funções e esta coluna existiam só no banco (algumas migrações antigas tinham apenas o comentário "ver definição no banco").
-- Sem elas, o banco não podia ser montado do zero a partir do repositório. Textos copiados do banco de produção em 17/10/2026.
-- Em produção não muda nada (create or replace / if not exists). Idempotente.

alter table plano_contas add column if not exists conta_passivo_id uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid = 'plano_contas'::regclass and conname = 'plano_contas_conta_passivo_id_fkey') then
    alter table plano_contas add constraint plano_contas_conta_passivo_id_fkey foreign key (conta_passivo_id) references plano_contas(id) on delete set null;
  end if;
end $$;

CREATE OR REPLACE FUNCTION public.campanha_metas_mensal(p_ws uuid, p_campanha uuid, p_hoje date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare h date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
  c campanhas; ini date; fim date; m date; dias int; tot_mix int; rec_mix numeric; ticket numeric; ov campanha_metas_mes;
  ml int; mv int; mr numeric; fator numeric; rl int; rv int; rr numeric; prods jsonb; meses jsonb := '[]'::jsonb; mix jsonb; esperado numeric; n int := 0;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  select * into c from campanhas where id = p_campanha and workspace_id = p_ws;
  if not found then return jsonb_build_object('meses', '[]'::jsonb, 'mix', '[]'::jsonb); end if;
  select coalesce(sum(x.vendas_mes), 0), coalesce(sum(x.vendas_mes * pr.preco), 0) into tot_mix, rec_mix
    from campanha_mix x join produtos pr on pr.id = x.produto_id where x.campanha_id = p_campanha;
  ticket := case when tot_mix > 0 then rec_mix / tot_mix end;
  select coalesce(jsonb_agg(jsonb_build_object('produto_id', pr.id, 'nome', pr.nome, 'preco', pr.preco, 'vendas_mes', x.vendas_mes) order by pr.nome), '[]'::jsonb) into mix
    from campanha_mix x join produtos pr on pr.id = x.produto_id where x.campanha_id = p_campanha;
  ini := date_trunc('month', coalesce(c.data_inicio, (select min((criado_em at time zone 'America/Sao_Paulo')::date) from pessoas where workspace_id = p_ws and campanha_id = p_campanha), h))::date;
  fim := case when c.data_fim is not null then date_trunc('month', c.data_fim)::date else greatest((ini + interval '11 months')::date, date_trunc('month', h)::date) end;
  m := ini;
  while m <= fim and n < 36 loop
    n := n + 1;
    dias := extract(day from (m + interval '1 month - 1 day'))::int;
    select * into ov from campanha_metas_mes where campanha_id = p_campanha and mes = m;
    ml := coalesce(ov.meta_leads, c.meta_leads_mes);
    mv := coalesce(ov.meta_vendas, case when tot_mix > 0 then tot_mix end);
    mr := case when ov.meta_vendas is not null then case when ticket is not null then ov.meta_vendas * ticket end when tot_mix > 0 then rec_mix end;
    fator := case when tot_mix > 0 and mv is not null then mv::numeric / tot_mix end;
    select count(*) into rl from pessoas where workspace_id = p_ws and campanha_id = p_campanha and (criado_em at time zone 'America/Sao_Paulo')::date >= m and (criado_em at time zone 'America/Sao_Paulo')::date < (m + interval '1 month')::date;
    select count(*), coalesce(sum(valor_bruto), 0) into rv, rr from vendas where workspace_id = p_ws and campanha_id = p_campanha and status = 'aprovada'
      and (data_venda at time zone 'America/Sao_Paulo')::date >= m and (data_venda at time zone 'America/Sao_Paulo')::date < (m + interval '1 month')::date;
    select coalesce(jsonb_agg(jsonb_build_object('produto_id', t.pid, 'nome', t.nome, 'meta', t.meta, 'real', t.real) order by t.nome), '[]'::jsonb) into prods from (
      select pr.id pid, pr.nome, case when x.vendas_mes is not null and fator is not null then round(x.vendas_mes * fator)::int end meta,
        (select count(*) from vendas v where v.workspace_id = p_ws and v.campanha_id = p_campanha and v.produto_id = pr.id and v.status = 'aprovada'
          and (v.data_venda at time zone 'America/Sao_Paulo')::date >= m and (v.data_venda at time zone 'America/Sao_Paulo')::date < (m + interval '1 month')::date) real
      from produtos pr left join campanha_mix x on x.produto_id = pr.id and x.campanha_id = p_campanha
      where pr.workspace_id = p_ws and (x.id is not null or exists (select 1 from vendas v where v.workspace_id = p_ws and v.campanha_id = p_campanha and v.produto_id = pr.id and v.status = 'aprovada'
          and (v.data_venda at time zone 'America/Sao_Paulo')::date >= m and (v.data_venda at time zone 'America/Sao_Paulo')::date < (m + interval '1 month')::date))) t;
    esperado := case when ml is not null and date_trunc('month', h)::date = m then round(ml::numeric / dias * extract(day from h), 1) end;
    meses := meses || jsonb_build_object('mes', m, 'dias_mes', dias, 'ajustado', ov.id is not null,
      'meta_leads', ml, 'meta_vendas', mv, 'meta_receita', mr, 'meta_leads_dia', case when ml is not null then round(ml::numeric / dias, 2) end,
      'real_leads', rl, 'real_vendas', rv, 'real_receita', rr,
      'conversao_meta', case when ml > 0 and mv is not null then round(mv::numeric / ml * 100, 2) end,
      'conversao_real', case when rl > 0 then round(rv::numeric / rl * 100, 2) end,
      'esperado_leads_hoje', esperado, 'atual', date_trunc('month', h)::date = m, 'produtos', prods);
    m := (m + interval '1 month')::date;
  end loop;
  return jsonb_build_object('meses', meses, 'mix', mix, 'meta_leads_mes', c.meta_leads_mes, 'ticket', ticket);
end $function$;

CREATE OR REPLACE FUNCTION public.papel_da_funcao(f funcoes)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when f.administrador then 'admin'
              when exists (select 1 from jsonb_each_text(f.permissoes) where value = 'editar') then 'editor' else 'leitor' end;
$function$;

CREATE OR REPLACE FUNCTION public.provisionar_recorrencias(p_ws uuid, p_meses integer DEFAULT 2, p_hoje date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare h date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
  r despesas_recorrentes; f fornecedores; m date; ult date; v date; dia int; gerados int; i int; novas int := 0; incompletos int := 0;
  v_valor numeric; media numeric; base numeric; resto numeric;
begin
  if not pode_editar(p_ws, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_meses is null or p_meses < 1 or p_meses > 12 then raise exception 'Informe de 1 a 12 meses'; end if;
  update despesas_recorrentes d set ativo = false where d.workspace_id = p_ws and d.do_fornecedor and d.ativo
    and not exists (select 1 from fornecedores x where x.id = d.fornecedor_id and x.ativo and x.recorrencia is not null);
  for f in select * from fornecedores where workspace_id = p_ws and ativo and recorrencia is not null order by nome loop
    if f.valor_padrao is null or f.valor_padrao <= 0 or f.data_inicio is null or f.conta_despesa_id is null
       or (f.recorrencia = 'parcelada' and f.parcelas is null) then incompletos := incompletos + 1; continue; end if;
    insert into despesas_recorrentes (workspace_id, fornecedor_id, descricao, tipo, valor, parcelas, data_inicio, data_fim, conta_despesa_id, centro_custo_id, forma_pagamento_id, ativo, do_fornecedor)
    values (p_ws, f.id, f.nome, f.recorrencia, f.valor_padrao, case when f.recorrencia = 'parcelada' then f.parcelas end, f.data_inicio,
            case when f.recorrencia = 'parcelada' then null else f.data_fim end, f.conta_despesa_id, f.centro_custo_id, f.forma_pagamento_id, true, true)
    on conflict (fornecedor_id) where do_fornecedor do update set descricao = excluded.descricao, tipo = excluded.tipo, valor = excluded.valor, parcelas = excluded.parcelas,
      data_inicio = excluded.data_inicio, data_fim = excluded.data_fim, conta_despesa_id = excluded.conta_despesa_id, centro_custo_id = excluded.centro_custo_id,
      forma_pagamento_id = excluded.forma_pagamento_id, ativo = true;
  end loop;
  for r in select * from despesas_recorrentes where workspace_id = p_ws and ativo order by descricao loop
    dia := extract(day from r.data_inicio)::int;
    if r.tipo = 'parcelada' then
      base := trunc(r.valor / r.parcelas, 2);
      resto := r.valor - base * r.parcelas;
      for i in 0..r.parcelas - 1 loop
        m := (date_trunc('month', r.data_inicio) + (i || ' months')::interval)::date;
        ult := (m + interval '1 month - 1 day')::date;
        v := m + (least(dia, extract(day from ult)::int) - 1);
        if not exists (select 1 from contas_pagar where recorrencia_id = r.id and competencia = m) then
          v_valor := base + case when i = r.parcelas - 1 then resto else 0 end;
          insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, forma_pagamento_id, estimativa, provisionada, recorrencia_id)
          values (p_ws, r.fornecedor_id, r.descricao || ' (' || (i+1) || '/' || r.parcelas || ')', v_valor, m, v, r.conta_despesa_id, r.centro_custo_id, r.forma_pagamento_id, false, false, r.id);
          novas := novas + 1;
        end if;
      end loop;
    else
      gerados := 0; m := greatest(date_trunc('month', h), date_trunc('month', r.data_inicio))::date;
      while gerados < p_meses and m < (h + interval '25 months')::date loop
        ult := (m + interval '1 month - 1 day')::date;
        v := m + (least(dia, extract(day from ult)::int) - 1);
        exit when r.data_fim is not null and v > r.data_fim;
        if v >= h and v >= r.data_inicio then
          gerados := gerados + 1;
          if not exists (select 1 from contas_pagar where recorrencia_id = r.id and competencia = m) then
            v_valor := r.valor;
            if r.tipo = 'variavel' then
              select round(avg(x.valor), 2) into media from (select c.valor from contas_pagar c where c.recorrencia_id = r.id and c.status <> 'cancelado' and not c.estimativa order by c.vencimento desc limit 3) x;
              v_valor := coalesce(media, r.valor);
            end if;
            insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, forma_pagamento_id, estimativa, provisionada, recorrencia_id)
            values (p_ws, r.fornecedor_id, r.descricao || ' — ' || to_char(m, 'MM/YYYY'), v_valor, m, v, r.conta_despesa_id, r.centro_custo_id, r.forma_pagamento_id, r.tipo = 'variavel', false, r.id);
            novas := novas + 1;
          end if;
        end if;
        m := (m + interval '1 month')::date;
      end loop;
    end if;
  end loop;
  return jsonb_build_object('criadas', novas, 'fornecedores_incompletos', incompletos);
end $function$;

CREATE OR REPLACE FUNCTION public.reabrir_contrato(p_contrato uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c contratos; cr record; l0 uuid; l0_data date; l1 uuid; n int := 0;
begin
  select * into c from contratos where id = p_contrato for update;
  if not found then raise exception 'Contrato não encontrado'; end if;
  if not pode_editar(c.workspace_id, '{vendas,fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if c.status = 'rascunho' then raise exception 'O contrato já está pendente'; end if;
  if exists (select 1 from contas_receber where contrato_id = c.id and status = 'recebido') then
    raise exception 'Este contrato já tem parcela recebida. Para corrigir, cancele e crie outro contrato (ou me peça um ajuste).';
  end if;
  if c.status = 'ativo' then
    for cr in select * from contas_receber where contrato_id = c.id and status = 'previsto' order by parcela loop
      select id, data_fato into l0, l0_data from lancamentos where origem_tipo = 'contrato_parcela' and origem_id = cr.id;
      if l0 is not null then
        -- desfaz a previsão na mesma data em que foi lançada, como se a parcela nunca tivesse existido
        insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
        values (c.workspace_id, l0_data, 'Contrato #' || c.numero || ' voltou para pendente – parcela ' || cr.parcela, 'cancelamento_contrato', cr.id, l0)
        returning id into l1;
        insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
        select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = l0;
      end if;
      update contas_receber set status = 'cancelado' where id = cr.id;
      n := n + 1;
    end loop;
  end if;
  update contratos set status = 'rascunho', ativado_em = null, cancelado_em = null where id = c.id;
  return n;
end $function$;

CREATE OR REPLACE FUNCTION public.vendas_metas_painel(p_ws uuid, p_hoje date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare h date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
  mi date := date_trunc('month', h)::date; mf date := (date_trunc('month', h) + interval '1 month')::date;
  c campanhas; linhas jsonb := '[]'::jsonb; mm jsonb; mes jsonb; mv numeric; mr numeric; rv int; rr numeric; esp numeric;
  tot_q int; tot_r numeric; sem_q int; sem_r numeric; op jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  for c in select * from campanhas where workspace_id = p_ws and status in ('ativa', 'ativo') order by nome loop
    mv := null; mr := null; esp := null;
    if c.modelo = 'perpetuo' then
      mm := campanha_metas_mensal(p_ws, c.id, h);
      select x into mes from jsonb_array_elements(mm->'meses') x where (x->>'atual')::boolean limit 1;
      if mes is not null then
        mv := (mes->>'meta_vendas')::numeric; mr := (mes->>'meta_receita')::numeric;
        rv := (mes->>'real_vendas')::int; rr := (mes->>'real_receita')::numeric;
        esp := case when mv is not null then round(mv * extract(day from h) / (mes->>'dias_mes')::numeric, 1) end;
      else rv := 0; rr := 0; end if;
      linhas := linhas || jsonb_build_object('campanha_id', c.id, 'nome', c.nome, 'modelo', c.modelo, 'janela', 'mês atual',
        'meta_vendas', mv, 'real_vendas', rv, 'meta_receita', mr, 'real_receita', rr, 'esperado_vendas', esp);
    else
      mv := c.meta_vendas; mr := c.meta_receita;
      select count(*), coalesce(sum(valor_bruto), 0) into rv, rr from vendas where workspace_id = p_ws and campanha_id = c.id and status = 'aprovada';
      if mv is not null and c.data_inicio is not null and c.data_fim is not null and c.data_fim >= c.data_inicio then
        esp := round(mv * greatest(0, least(1, (h - c.data_inicio + 1)::numeric / (c.data_fim - c.data_inicio + 1))), 1);
      end if;
      linhas := linhas || jsonb_build_object('campanha_id', c.id, 'nome', c.nome, 'modelo', c.modelo, 'janela', 'campanha toda',
        'meta_vendas', mv, 'real_vendas', rv, 'meta_receita', mr, 'real_receita', rr, 'esperado_vendas', esp);
    end if;
  end loop;
  select count(*), coalesce(sum(valor_bruto), 0) into tot_q, tot_r from vendas where workspace_id = p_ws and status = 'aprovada'
    and (data_venda at time zone 'America/Sao_Paulo')::date >= mi and (data_venda at time zone 'America/Sao_Paulo')::date < mf;
  select count(*), coalesce(sum(valor_bruto), 0) into sem_q, sem_r from vendas where workspace_id = p_ws and status = 'aprovada' and campanha_id is null
    and (data_venda at time zone 'America/Sao_Paulo')::date >= mi and (data_venda at time zone 'America/Sao_Paulo')::date < mf;
  select jsonb_build_object(
    'abertas_qtd', count(*) filter (where status = 'aberta'), 'abertas_valor', coalesce(sum(valor_estimado) filter (where status = 'aberta'), 0),
    'ganhas_mes_qtd', count(*) filter (where status = 'ganha' and (fechado_em at time zone 'America/Sao_Paulo')::date >= mi and (fechado_em at time zone 'America/Sao_Paulo')::date < mf),
    'ganhas_mes_valor', coalesce(sum(valor_estimado) filter (where status = 'ganha' and (fechado_em at time zone 'America/Sao_Paulo')::date >= mi and (fechado_em at time zone 'America/Sao_Paulo')::date < mf), 0))
    into op from oportunidades where workspace_id = p_ws;
  return jsonb_build_object('campanhas', linhas, 'mes_vendas_qtd', tot_q, 'mes_vendas_valor', tot_r, 'mes_sem_campanha_qtd', sem_q, 'mes_sem_campanha_valor', sem_r, 'oportunidades', op);
end $function$;

revoke execute on function public.campanha_metas_mensal(uuid, uuid, date) from public, anon;
grant execute on function public.campanha_metas_mensal(uuid, uuid, date) to authenticated;
revoke execute on function public.provisionar_recorrencias(uuid, integer, date) from public, anon;
grant execute on function public.provisionar_recorrencias(uuid, integer, date) to authenticated;
revoke execute on function public.reabrir_contrato(uuid) from public, anon;
grant execute on function public.reabrir_contrato(uuid) to authenticated;
revoke execute on function public.vendas_metas_painel(uuid, date) from public, anon;
grant execute on function public.vendas_metas_painel(uuid, date) to authenticated;
