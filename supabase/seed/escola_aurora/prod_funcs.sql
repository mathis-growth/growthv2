-- Versões de PRODUÇÃO (17/10/2026) das funções que diferem do repositório e que o seed da escola usa.
CREATE OR REPLACE FUNCTION public.bloqueia_alteracao_contabil()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'DELETE' and not exists (select 1 from workspaces where id = old.workspace_id) then
    return old;
  end if;
  raise exception 'Lançamentos contábeis não podem ser alterados nem apagados. Cancele a operação de origem para gerar o estorno.';
end $function$
;

CREATE OR REPLACE FUNCTION public.calcular_taxa_venda(p_produto uuid, p_plataforma uuid, p_forma text, p_bruto numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pr produtos; fp plataforma_formas_pagamento; pl plataformas_venda; pct numeric; fixo numeric;
begin
  select * into pr from produtos where id = p_produto;
  select * into fp from plataforma_formas_pagamento
    where plataforma_id = p_plataforma and forma_pagamento = p_forma and ativa;
  select * into pl from plataformas_venda where id = p_plataforma;
  pct := coalesce(pr.taxa_percentual_override, fp.taxa_percentual, pl.taxa_percentual, 0);
  fixo := coalesce(pr.taxa_fixa_override, fp.taxa_fixa, pl.taxa_fixa, 0);
  return round(p_bruto * pct / 100 + fixo, 2);
end $function$
;

CREATE OR REPLACE FUNCTION public.contas_pagar_depois()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r regras_contabilizacao; l uuid; pass uuid;
begin
  r := _regra(new.workspace_id, 'conta_pagar');
  select conta_passivo_id into pass from plano_contas where id = new.conta_despesa_id;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (new.workspace_id, new.competencia, 'Despesa: ' || new.descricao, 'conta_pagar', new.id)
  returning id into l;
  perform _partida(l, new.workspace_id, coalesce(r.conta_debito_id, new.conta_despesa_id), new.centro_custo_id, 'D', new.valor);
  perform _partida(l, new.workspace_id, coalesce(pass, r.conta_credito_id), new.centro_custo_id, 'C', new.valor);
  return null;
end $function$
;

CREATE OR REPLACE FUNCTION public.pessoas_negocio_antes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.status_funil = 'cliente' and old.status_funil = 'lead' and new.negocio_status = 'aberto' then
    new.negocio_status := 'ganho';
  end if;
  if new.negocio_status is distinct from old.negocio_status then
    new.negocio_fechado_em := case when new.negocio_status = 'aberto' then null else now() end;
    if new.negocio_status = 'aberto' then new.negocio_motivo_id := null; end if;
  end if;
  if new.negocio_motivo_id is not null and not exists (
       select 1 from motivos_resultado where id = new.negocio_motivo_id and workspace_id = new.workspace_id
         and tipo = new.negocio_status) then
    raise exception 'O motivo precisa ser do tipo "%" e do mesmo workspace', new.negocio_status;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.processar_venda(p_venda uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v vendas; pr produtos; l uuid; r regras_contabilizacao;
begin
  select * into v from vendas where id = p_venda for update;
  if not found then raise exception 'Venda % não encontrada', p_venda; end if;
  if not pode_editar(v.workspace_id, '{vendas,fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if v.status <> 'aprovada' then raise exception 'Só vendas aprovadas geram partidas'; end if;

  select id into l from lancamentos where origem_tipo = 'venda' and origem_id = v.id;
  if l is not null then return l; end if;

  select * into pr from produtos where id = v.produto_id;

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (v.workspace_id, (v.data_venda at time zone 'America/Sao_Paulo')::date,
          'Venda: ' || pr.nome, 'venda', v.id)
  returning id into l;

  r := _regra(v.workspace_id, 'venda_receita');
  perform _partida(l, v.workspace_id, r.conta_debito_id, pr.centro_custo_id, 'D', v.valor_bruto);
  perform _partida(l, v.workspace_id, r.conta_credito_id, pr.centro_custo_id, 'C', v.valor_bruto);

  if v.taxa_plataforma > 0 then
    r := _regra(v.workspace_id, 'venda_taxa_plataforma');
    perform _partida(l, v.workspace_id, r.conta_debito_id, pr.centro_custo_id, 'D', v.taxa_plataforma);
    perform _partida(l, v.workspace_id, r.conta_credito_id, pr.centro_custo_id, 'C', v.taxa_plataforma);
  end if;

  if v.impostos > 0 then
    r := _regra(v.workspace_id, 'venda_imposto');
    perform _partida(l, v.workspace_id, r.conta_debito_id, pr.centro_custo_id, 'D', v.impostos);
    perform _partida(l, v.workspace_id, r.conta_credito_id, pr.centro_custo_id, 'C', v.impostos);
  end if;

  insert into contas_receber (workspace_id, venda_id, valor, vencimento, conta_bancaria_id)
  values (v.workspace_id, v.id, v.valor_a_receber, v.data_prevista_recebimento, v.conta_bancaria_id);

  update pessoas set
    status_funil = 'cliente',
    status_cliente = 'ativo',
    convertido_em = coalesce(convertido_em, now()),
    etapa_kanban_id = coalesce(
      (select id from etapas_kanban where workspace_id = v.workspace_id and quadro = 'leads' and nome = 'Cliente'),
      etapa_kanban_id)
  where id = v.pessoa_id;

  insert into alunos (workspace_id, pessoa_id, produto_id, venda_id, tag, etapa_kanban_id)
  values (v.workspace_id, v.pessoa_id, v.produto_id, v.id, pr.tag,
          (select id from etapas_kanban where workspace_id = v.workspace_id and quadro = 'alunos'
           order by ordem limit 1))
  on conflict (venda_id) do nothing;

  return l;
end $function$
;

CREATE OR REPLACE FUNCTION public.ativar_contrato(p_contrato uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c contratos; r regras_contabilizacao; total numeric; por_parcela numeric; passo int;
        i int; v numeric; venc date; l uuid; cr uuid; cc uuid; nome_prod text; ultimo date;
        np int; soma_plano numeric; usa_plano boolean := false;
begin
  select * into c from contratos where id = p_contrato for update;
  if not found then raise exception 'Contrato não encontrado'; end if;
  if not pode_editar(c.workspace_id, '{vendas,fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if c.status <> 'rascunho' then raise exception 'Contrato já está %', c.status; end if;

  select coalesce(sum(quantidade * valor), 0) into total from contrato_itens where contrato_id = c.id;
  if total <= 0 then raise exception 'Inclua ao menos um produto com valor no contrato'; end if;
  select string_agg(p.nome, ', ' order by p.nome), (array_agg(p.centro_custo_id))[1]
    into nome_prod, cc from contrato_itens it join produtos p on p.id = it.produto_id where it.contrato_id = c.id;

  if not c.recorrente then
    select count(*), coalesce(sum(valor),0) into np, soma_plano from contrato_parcelas_plano where contrato_id = c.id;
    if np > 0 then
      if np <> c.num_parcelas then raise exception 'O plano de parcelas tem % parcela(s), mas o contrato diz %', np, c.num_parcelas; end if;
      if soma_plano <> total then raise exception 'As parcelas somam R$ %, mas o total do contrato é R$ %', soma_plano, total; end if;
      usa_plano := true;
    end if;
  end if;

  passo := case when c.recorrente then
             case c.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end
           else 1 end;
  por_parcela := case when c.recorrente then total else round(total / c.num_parcelas, 2) end;
  r := _regra(c.workspace_id, 'contrato_receita');

  for i in 1..c.num_parcelas loop
    if usa_plano then
      select pp.vencimento, pp.valor into venc, v from contrato_parcelas_plano pp where pp.contrato_id = c.id and pp.numero = i;
    else
      venc := (c.primeiro_vencimento + ((i - 1) * passo) * interval '1 month')::date;
      v := case when not c.recorrente and i = c.num_parcelas then total - por_parcela * (c.num_parcelas - 1) else por_parcela end;
    end if;

    insert into contas_receber (workspace_id, contrato_id, parcela, descricao, valor, vencimento, conta_bancaria_id)
    values (c.workspace_id, c.id, i, 'Contrato #' || c.numero || ' – parcela ' || i || '/' || c.num_parcelas, v, venc,
            coalesce(c.conta_bancaria_id, (select id from contas_bancarias
                     where workspace_id = c.workspace_id and padrao and ativa limit 1)))
    returning id into cr;

    insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
    values (c.workspace_id, venc, 'Contrato #' || c.numero || ' (' || nome_prod || ') – parcela ' || i || '/' || c.num_parcelas,
            'contrato_parcela', cr)
    returning id into l;
    perform _partida(l, c.workspace_id, r.conta_debito_id, cc, 'D', v);
    perform _partida(l, c.workspace_id, r.conta_credito_id, cc, 'C', v);
    ultimo := greatest(coalesce(ultimo, venc), venc);
  end loop;

  update contratos set status = 'ativo', ativado_em = now(),
         data_fim = coalesce(data_fim, ultimo)
   where id = c.id;

  update pessoas set status_funil = 'cliente', status_cliente = 'ativo',
         convertido_em = coalesce(convertido_em, now()),
         etapa_kanban_id = coalesce(
           (select id from etapas_kanban where workspace_id = c.workspace_id and quadro = 'leads' and nome = 'Cliente'),
           etapa_kanban_id)
   where id = c.pessoa_id;
  insert into alunos (workspace_id, pessoa_id, produto_id, contrato_id, tag, etapa_kanban_id, origem)
  select c.workspace_id, c.pessoa_id, it.produto_id, c.id, pr.tag,
         (select id from etapas_kanban where workspace_id = c.workspace_id and quadro = 'alunos' order by ordem limit 1), 'contrato'
  from contrato_itens it join produtos pr on pr.id = it.produto_id where it.contrato_id = c.id order by pr.nome limit 1
  on conflict (contrato_id) do nothing;
  return c.num_parcelas;
end $function$
;

CREATE OR REPLACE FUNCTION public.campanha_link_valida()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a uuid;
begin
  if not exists (select 1 from campanha_canais where id = new.campanha_canal_id and workspace_id = new.workspace_id) then
    raise exception 'O canal da campanha precisa pertencer ao mesmo workspace'; end if;
  select id into a from anuncios where campanha_canal_id = new.campanha_canal_id and utm_content = new.utm_content;
  if a is null then
    insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, angulo)
    values (new.workspace_id, new.campanha_canal_id, new.nome, new.utm_content, new.angulo) returning id into a;
  end if;
  new.anuncio_id := a;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.registrar_pagamento(p_conta uuid, p_data date DEFAULT NULL::date, p_conta_bancaria uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cp contas_pagar; r regras_contabilizacao; v_banco uuid; v_banco_contabil uuid; l uuid; d date; v_pass uuid;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar % não encontrada', p_conta; end if;
  if not pode_editar(cp.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cp.status <> 'previsto' then raise exception 'Conta a pagar já está %', cp.status; end if;

  v_banco := coalesce(p_conta_bancaria,
    (select id from contas_bancarias where workspace_id = cp.workspace_id and padrao and ativa limit 1));
  if v_banco is null then raise exception 'Informe a conta bancária do pagamento'; end if;
  select conta_contabil_id into v_banco_contabil from contas_bancarias
    where id = v_banco and workspace_id = cp.workspace_id;
  if v_banco_contabil is null then raise exception 'Conta bancária inválida para este workspace'; end if;

  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  r := _regra(cp.workspace_id, 'pagamento');
  -- baixa o mesmo passivo que a despesa criou (fornecedores a pagar, pró-labore a pagar...)
  select pa.conta_id into v_pass from partidas pa join lancamentos lo on lo.id = pa.lancamento_id
   where lo.origem_tipo = 'conta_pagar' and lo.origem_id = cp.id and pa.tipo = 'C'
   order by lo.criado_em desc limit 1;

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (cp.workspace_id, d, 'Pagamento: ' || cp.descricao, 'pagamento', cp.id)
  returning id into l;
  perform _partida(l, cp.workspace_id, coalesce(v_pass, r.conta_debito_id), null, 'D', cp.valor);
  perform _partida(l, cp.workspace_id, coalesce(r.conta_credito_id, v_banco_contabil), null, 'C', cp.valor);

  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
  values (cp.workspace_id, v_banco, d, 'saida', cp.valor, 'Pagamento: ' || cp.descricao, 'pagamento', cp.id, l);

  update contas_pagar set status = 'pago', data_pagamento = d, conta_bancaria_id = v_banco where id = cp.id;
  return l;
end $function$
;

CREATE OR REPLACE FUNCTION public.registrar_recebimento(p_conta_receber uuid, p_data date DEFAULT NULL::date, p_conta_bancaria uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cr contas_receber; r regras_contabilizacao; v_banco uuid; v_banco_contabil uuid; l uuid; d date; v_desc text;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber % não encontrada', p_conta_receber; end if;
  if not pode_editar(cr.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cr.status <> 'previsto' then raise exception 'Conta a receber já está %', cr.status; end if;

  v_banco := coalesce(p_conta_bancaria, cr.conta_bancaria_id);
  if v_banco is null then raise exception 'Informe a conta bancária do recebimento'; end if;
  select conta_contabil_id into v_banco_contabil from contas_bancarias
    where id = v_banco and workspace_id = cr.workspace_id;
  if v_banco_contabil is null then raise exception 'Conta bancária inválida para este workspace'; end if;
  if (select tipo from contas_bancarias where id = v_banco) = 'cartao' then raise exception 'Recebimento não pode entrar no cartão de crédito: escolha uma conta bancária'; end if;

  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  if cr.conta_receita_id is not null then r.conta_debito_id := null; r.conta_credito_id := cr.conta_receita_id; v_desc := 'Recebimento: ' || coalesce(cr.descricao, 'avulso'); elsif cr.contrato_id is not null then r := _regra(cr.workspace_id, 'contrato_recebimento');
    v_desc := 'Recebimento: ' || coalesce(cr.descricao, 'contrato');
  else
    r := _regra(cr.workspace_id, 'recebimento');
    v_desc := 'Recebimento de venda';
  end if;

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (cr.workspace_id, d, v_desc, 'recebimento', cr.id)
  returning id into l;
  perform _partida(l, cr.workspace_id, coalesce(r.conta_debito_id, v_banco_contabil), null, 'D', cr.valor);
  perform _partida(l, cr.workspace_id, coalesce(r.conta_credito_id, v_banco_contabil), null, 'C', cr.valor);

  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
  values (cr.workspace_id, v_banco, d, 'entrada', cr.valor, v_desc, 'recebimento', cr.id, l);

  update contas_receber set status = 'recebido', data_recebimento = d, conta_bancaria_id = v_banco where id = cr.id;
  return l;
end $function$
;
