create extension if not exists pgcrypto;
create table workspaces (id uuid primary key default gen_random_uuid(), nome text);
create table plano_contas (id uuid primary key default gen_random_uuid(), workspace_id uuid, codigo text, nome text, tipo text, natureza text, conta_pai_id uuid, aceita_lancamento boolean default true, ativo boolean default true, cac_grupo text, rateio_regra_id uuid, conta_passivo_id uuid);
create table regras_contabilizacao (id uuid primary key default gen_random_uuid(), workspace_id uuid, evento text, descricao text, conta_debito_id uuid, conta_credito_id uuid, ativo boolean default true, nome text, personalizada boolean default false);
create table contas_bancarias (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text, banco text, saldo_inicial numeric default 0, conta_contabil_id uuid, padrao boolean default false, ativa boolean default true);
create table contas_pagar (id uuid primary key default gen_random_uuid(), workspace_id uuid, fornecedor_id uuid, descricao text, valor numeric, competencia date, vencimento date, conta_despesa_id uuid, centro_custo_id uuid, campanha_id uuid, campanha_canal_id uuid, status text default 'previsto', data_pagamento date, conta_bancaria_id uuid, criado_em timestamptz default now(), rateio_regra_id uuid, forma_pagamento_id uuid, estimativa boolean default false, provisionada boolean default false, substituida_por uuid, recorrencia_id uuid);
create table lancamentos (id uuid primary key default gen_random_uuid(), workspace_id uuid, data_fato date, descricao text, origem_tipo text, origem_id uuid, estorno_de uuid, criado_em timestamptz default now());
create table partidas (id uuid primary key default gen_random_uuid(), workspace_id uuid, lancamento_id uuid, conta_id uuid, centro_custo_id uuid, tipo text, valor numeric);
create table movimentacoes_bancarias (id uuid primary key default gen_random_uuid(), workspace_id uuid, conta_bancaria_id uuid, data date, tipo text, valor numeric, descricao text, origem_tipo text, origem_id uuid, lancamento_id uuid);
create function pode_operar(ws uuid) returns boolean language sql as $$ select true $$;
create function pode_editar(ws uuid, mods text[]) returns boolean language sql as $$ select true $$;
create or replace function public._partida(p_lanc uuid, p_ws uuid, p_conta uuid, p_cc uuid, p_tipo text, p_valor numeric) returns void language plpgsql as $f$
begin if p_conta is null then raise exception 'Conta contábil não definida'; end if;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor) values (p_ws, p_lanc, p_conta, p_cc, p_tipo, p_valor); end $f$;
create or replace function public._regra(p_ws uuid, p_evento text) returns regras_contabilizacao language plpgsql stable as $f$
declare r regras_contabilizacao; begin select * into r from regras_contabilizacao where workspace_id = p_ws and evento = p_evento and ativo; if not found then raise exception 'Regra % não configurada', p_evento; end if; return r; end $f$;
create or replace function public.checa_lancamento_balanceado() returns trigger language plpgsql as $f$
declare saldo numeric; begin select coalesce(sum(case tipo when 'D' then valor else -valor end), 0) into saldo from partidas where lancamento_id = new.lancamento_id;
  if saldo <> 0 then raise exception 'Lançamento % desbalanceado em %', new.lancamento_id, saldo; end if; return null; end $f$;
create constraint trigger partidas_balanceadas after insert on partidas deferrable initially deferred for each row execute function checa_lancamento_balanceado();
create or replace function public.contas_pagar_depois() returns trigger language plpgsql as $f$
declare r regras_contabilizacao; l uuid; pass uuid;
begin r := _regra(new.workspace_id, 'conta_pagar'); select conta_passivo_id into pass from plano_contas where id = new.conta_despesa_id;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id) values (new.workspace_id, new.competencia, 'Despesa: ' || new.descricao, 'conta_pagar', new.id) returning id into l;
  perform _partida(l, new.workspace_id, coalesce(r.conta_debito_id, new.conta_despesa_id), new.centro_custo_id, 'D', new.valor);
  perform _partida(l, new.workspace_id, coalesce(pass, r.conta_credito_id), new.centro_custo_id, 'C', new.valor); return null; end $f$;
create trigger contas_pagar_depois after insert on contas_pagar for each row execute function contas_pagar_depois();
CREATE OR REPLACE FUNCTION public.registrar_pagamento(p_conta uuid, p_data date DEFAULT NULL::date, p_conta_bancaria uuid DEFAULT NULL::uuid) RETURNS uuid LANGUAGE plpgsql AS $function$
declare cp contas_pagar; r regras_contabilizacao; v_banco uuid; v_banco_contabil uuid; l uuid; d date; v_pass uuid;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar % não encontrada', p_conta; end if;
  if not pode_operar(cp.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cp.status <> 'previsto' then raise exception 'Conta a pagar já está %', cp.status; end if;
  v_banco := coalesce(p_conta_bancaria, (select id from contas_bancarias where workspace_id = cp.workspace_id and padrao and ativa limit 1));
  select conta_contabil_id into v_banco_contabil from contas_bancarias where id = v_banco and workspace_id = cp.workspace_id;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  r := _regra(cp.workspace_id, 'pagamento');
  select pa.conta_id into v_pass from partidas pa join lancamentos lo on lo.id = pa.lancamento_id where lo.origem_tipo = 'conta_pagar' and lo.origem_id = cp.id and pa.tipo = 'C' order by lo.criado_em desc limit 1;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id) values (cp.workspace_id, d, 'Pagamento: ' || cp.descricao, 'pagamento', cp.id) returning id into l;
  perform _partida(l, cp.workspace_id, coalesce(v_pass, r.conta_debito_id), null, 'D', cp.valor);
  perform _partida(l, cp.workspace_id, coalesce(r.conta_credito_id, v_banco_contabil), null, 'C', cp.valor);
  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id) values (cp.workspace_id, v_banco, d, 'saida', cp.valor, 'Pagamento: ' || cp.descricao, 'pagamento', cp.id, l);
  update contas_pagar set status = 'pago', data_pagamento = d, conta_bancaria_id = v_banco where id = cp.id;
  return l;
end $function$;
CREATE OR REPLACE FUNCTION public.cancelar_conta_pagar(p_conta uuid, p_data date DEFAULT NULL::date) RETURNS uuid LANGUAGE plpgsql AS $function$
declare cp contas_pagar; l0 uuid; l1 uuid; d date;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar % não encontrada', p_conta; end if;
  if not pode_operar(cp.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cp.status <> 'previsto' then raise exception 'Só dá para cancelar conta ainda não paga (esta está %)', cp.status; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  select id into l0 from lancamentos where origem_tipo = 'conta_pagar' and origem_id = cp.id order by criado_em desc limit 1;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de) values (cp.workspace_id, d, 'Cancelamento: ' || cp.descricao, 'cancelamento_pagar', cp.id, l0) returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select x.workspace_id, l1, x.conta_id, x.centro_custo_id, case x.tipo when 'D' then 'C' else 'D' end, x.restante
  from (select p.workspace_id, p.conta_id, p.centro_custo_id, p.tipo,
          p.valor - coalesce((select sum(e.valor) from partidas e join lancamentos le on le.id = e.lancamento_id
                              where le.estorno_de = l0 and e.conta_id = p.conta_id and e.centro_custo_id is not distinct from p.centro_custo_id and e.tipo <> p.tipo), 0) as restante
        from partidas p where p.lancamento_id = l0) x where x.restante > 0;
  update contas_pagar set status = 'cancelado' where id = cp.id;
  return l1;
end $function$;
-- versões ANTIGAS (produção hoje), para testar contas criadas antes da migração
CREATE OR REPLACE FUNCTION public.registrar_pagamento_parcial(p_conta uuid, p_valor numeric, p_data date DEFAULT NULL::date, p_conta_bancaria uuid DEFAULT NULL::uuid) RETURNS uuid LANGUAGE plpgsql AS $function$
declare cp contas_pagar; l0 uuid; l1 uuid; l0_data date; resto numeric; ratio numeric; novo uuid;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if cp.status <> 'previsto' then raise exception 'Conta a pagar já está %', cp.status; end if;
  if p_valor >= cp.valor then return registrar_pagamento(p_conta, p_data, p_conta_bancaria); end if;
  resto := round(cp.valor - p_valor, 2); ratio := resto / cp.valor;
  select id, data_fato into l0, l0_data from lancamentos where origem_tipo = 'conta_pagar' and origem_id = cp.id;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de) values (cp.workspace_id, l0_data, 'Divisão por pagamento parcial: ' || cp.descricao, 'cancelamento_pagar', cp.id, l0) returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, v
  from (select p.*, round(sum(p.valor) over (partition by p.tipo order by p.id) * ratio, 2) - coalesce(round(sum(p.valor) over (partition by p.tipo order by p.id rows between unbounded preceding and 1 preceding) * ratio, 2), 0) as v from partidas p where p.lancamento_id = l0) x where v > 0;
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id, campanha_canal_id, rateio_regra_id, forma_pagamento_id, estimativa, provisionada)
  values (cp.workspace_id, cp.fornecedor_id, cp.descricao || ' (saldo)', resto, cp.competencia, cp.vencimento, cp.conta_despesa_id, cp.centro_custo_id, cp.campanha_id, cp.campanha_canal_id, cp.rateio_regra_id, cp.forma_pagamento_id, false, false) returning id into novo;
  update contas_pagar set valor = p_valor where id = cp.id;
  return registrar_pagamento(cp.id, p_data, p_conta_bancaria);
end $function$;
-- dados: workspace, contas 1.1.01 banco, 2.1.03 passivo, 6.2.04 despesa (passivo próprio)
insert into workspaces (id, nome) values ('00000000-0000-0000-0000-000000000001', 'Teste');
insert into plano_contas (id, workspace_id, codigo, nome) values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000001','1.1.01','Banco'),
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000001','2.1.03','Pró-labore a pagar'), ('00000000-0000-0000-0000-0000000000f1','00000000-0000-0000-0000-000000000001','2.1.01','Fornecedores');
insert into plano_contas (id, workspace_id, codigo, nome, conta_passivo_id) values ('00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-000000000001','6.2.04','Pró-labore','00000000-0000-0000-0000-0000000000a1');
insert into regras_contabilizacao (workspace_id, evento, conta_debito_id, conta_credito_id) values ('00000000-0000-0000-0000-000000000001','conta_pagar', null, '00000000-0000-0000-0000-0000000000f1'),
 ('00000000-0000-0000-0000-000000000001','pagamento', null, null);
insert into contas_bancarias (id, workspace_id, nome, conta_contabil_id, padrao) values ('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-000000000001','Inter','00000000-0000-0000-0000-0000000000b1', true);
