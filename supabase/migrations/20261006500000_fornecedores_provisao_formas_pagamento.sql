-- APLICADA em 06/10/2026 (em partes), exceto o gatilho, que está em 20261006500100_bloqueia_pagar_estimativa.sql
-- v0.32: formas de pagamento, fornecedor fixo/variável com padrões, provisão automática de contas a pagar e correção de valor estimado.

-- 1) Formas de pagamento (inclui cartão de terceiros e a conta bancária de onde sai)
create table if not exists formas_pagamento (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  tipo text not null default 'outro' check (tipo in ('pix','boleto','cartao','debito_automatico','transferencia','dinheiro','outro')),
  titular_terceiro text,
  conta_bancaria_id uuid references contas_bancarias(id) on delete set null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  unique (workspace_id, nome)
);
comment on column formas_pagamento.titular_terceiro is 'Quando o pagamento sai do cartão/conta de outra pessoa (ex.: Tio Lutero); a conta a pagar vira dívida com ela.';
alter table formas_pagamento enable row level security;
create policy formas_pagamento_acesso on formas_pagamento for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on formas_pagamento as restrictive for select to authenticated using (perm(workspace_id, 'ler', array['fin','adm','cad']));
create policy perm_inserir on formas_pagamento as restrictive for insert to authenticated with check (perm(workspace_id, 'editar', array['fin','cad']));
create policy perm_alterar on formas_pagamento as restrictive for update to authenticated using (perm(workspace_id, 'editar', array['fin','cad'])) with check (perm(workspace_id, 'editar', array['fin','cad']));
create policy perm_excluir on formas_pagamento as restrictive for delete to authenticated using (perm(workspace_id, 'editar', array['fin','cad']));

-- 2) Fornecedor: fixo ou variável + padrões para preencher e provisionar
alter table fornecedores
  add column if not exists tipo_custo text check (tipo_custo in ('fixo','variavel')),
  add column if not exists valor_padrao numeric(14,2) check (valor_padrao is null or valor_padrao > 0),
  add column if not exists dia_vencimento smallint check (dia_vencimento is null or dia_vencimento between 1 and 31),
  add column if not exists conta_despesa_id uuid references plano_contas(id) on delete set null,
  add column if not exists centro_custo_id uuid references centros_custo(id) on delete set null,
  add column if not exists forma_pagamento_id uuid references formas_pagamento(id) on delete set null,
  add column if not exists provisionar boolean not null default false;

-- 3) Conta a pagar: forma de pagamento, estimativa e origem da provisão
alter table contas_pagar
  add column if not exists forma_pagamento_id uuid references formas_pagamento(id) on delete set null,
  add column if not exists estimativa boolean not null default false,
  add column if not exists provisionada boolean not null default false,
  add column if not exists substituida_por uuid references contas_pagar(id) on delete set null;
create unique index if not exists contas_pagar_provisao_uq on contas_pagar (workspace_id, fornecedor_id, competencia) where provisionada;

-- 4) Provisão automática (idempotente): gera os próximos vencimentos dos fornecedores marcados
create or replace function provisionar_contas_pagar(p_ws uuid, p_meses int default 2, p_hoje date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare h date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
        f fornecedores; m date; ult date; v date; v_valor numeric; media numeric; novas int := 0; sem_dia int := 0; sem_valor int := 0; sem_conta int := 0; gerados int := 0; cid uuid;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  if p_meses is null or p_meses < 1 or p_meses > 12 then raise exception 'Informe de 1 a 12 meses'; end if;
  for f in select * from fornecedores where workspace_id = p_ws and ativo and provisionar order by nome loop
    if f.dia_vencimento is null then sem_dia := sem_dia + 1; continue; end if;
    if f.conta_despesa_id is null then sem_conta := sem_conta + 1; continue; end if;
    gerados := 0; m := date_trunc('month', h)::date;
    while gerados < p_meses and m < (h + interval '25 months')::date loop
      ult := (date_trunc('month', m) + interval '1 month - 1 day')::date;
      v := m + (least(f.dia_vencimento, extract(day from ult)::int) - 1);
      if v >= h then
        gerados := gerados + 1;
        if not exists (select 1 from contas_pagar where workspace_id = p_ws and fornecedor_id = f.id and competencia = m and provisionada) then
          v_valor := f.valor_padrao;
          if f.tipo_custo = 'variavel' then
            select round(avg(valor), 2) into media from (select valor from contas_pagar where workspace_id = p_ws and fornecedor_id = f.id
              and status <> 'cancelado' and not estimativa order by vencimento desc limit 3) x;
            v_valor := coalesce(media, f.valor_padrao);
          end if;
          if v_valor is null then sem_valor := sem_valor + 1;
          else
            insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, forma_pagamento_id, estimativa, provisionada)
            values (p_ws, f.id, f.nome || ' — ' || to_char(m, 'MM/YYYY'), v_valor, m, v, f.conta_despesa_id, f.centro_custo_id, f.forma_pagamento_id, coalesce(f.tipo_custo = 'variavel', false), true);
            novas := novas + 1;
          end if;
        end if;
      end if;
      m := (m + interval '1 month')::date;
    end loop;
  end loop;
  return jsonb_build_object('criadas', novas, 'fornecedores_sem_dia', sem_dia, 'fornecedores_sem_conta', sem_conta, 'sem_valor', sem_valor);
end $$;

-- 5) Confirmar o valor real de uma conta estimada: cancela a provisão (estorno contábil) e lança a conta correta
create or replace function confirmar_valor_conta_pagar(p_conta uuid, p_valor numeric, p_vencimento date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cp contas_pagar; novo uuid;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar não encontrada'; end if;
  if not pode_operar(cp.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cp.status <> 'previsto' then raise exception 'Só dá para corrigir conta ainda não paga (esta está %)', cp.status; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe um valor maior que zero'; end if;
  if p_valor = cp.valor and coalesce(p_vencimento, cp.vencimento) = cp.vencimento then
    update contas_pagar set estimativa = false where id = cp.id;
    return cp.id;
  end if;
  perform cancelar_conta_pagar(cp.id);
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id, campanha_canal_id, rateio_regra_id, forma_pagamento_id, estimativa, provisionada)
  values (cp.workspace_id, cp.fornecedor_id, cp.descricao, p_valor, cp.competencia, coalesce(p_vencimento, cp.vencimento), cp.conta_despesa_id, cp.centro_custo_id, cp.campanha_id, cp.campanha_canal_id, cp.rateio_regra_id, cp.forma_pagamento_id, false, false)
  returning id into novo;
  update contas_pagar set substituida_por = novo where id = cp.id;
  return novo;
end $$;

revoke all on function provisionar_contas_pagar(uuid,int,date), confirmar_valor_conta_pagar(uuid,numeric,date) from public, anon;
grant execute on function provisionar_contas_pagar(uuid,int,date), confirmar_valor_conta_pagar(uuid,numeric,date) to authenticated;

-- ============================================================================
-- 6) Contas novas e formas de pagamento da operação "Mathisa — Operação" (idempotente). Os fornecedores foram cadastrados à mão.
-- ============================================================================
do $$
declare ws uuid := '8fd51ed1-0843-49d8-a2aa-b9bb99c59171'; pai62 uuid; pai6 uuid; pai63 uuid; banco uuid;
begin
  if not exists (select 1 from workspaces where id = ws) then raise notice 'Workspace Mathisa não encontrado; cadastro inicial ignorado.'; return; end if;
  select id into pai6 from plano_contas where workspace_id = ws and codigo = '6';
  select id into pai62 from plano_contas where workspace_id = ws and codigo = '6.2';
  if pai6 is null or pai62 is null then raise notice 'Plano de contas base não encontrado; cadastro inicial ignorado.'; return; end if;

  -- contas novas
  insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento, ativo)
  values (ws, '6.2.04', 'Pró-labore', 'despesa', 'devedora', pai62, true, true) on conflict (workspace_id, codigo) do nothing;
  insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento, ativo)
  values (ws, '6.3', 'Administrativas', 'despesa', 'devedora', pai6, false, true) on conflict (workspace_id, codigo) do nothing;
  select id into pai63 from plano_contas where workspace_id = ws and codigo = '6.3';
  insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento, ativo) values
    (ws, '6.3.01', 'Contabilidade', 'despesa', 'devedora', pai63, true, true),
    (ws, '6.3.02', 'Energia elétrica', 'despesa', 'devedora', pai63, true, true),
    (ws, '6.3.03', 'Água e esgoto', 'despesa', 'devedora', pai63, true, true),
    (ws, '6.3.04', 'Internet e telefonia', 'despesa', 'devedora', pai63, true, true),
    (ws, '6.3.05', 'Treinamento e cursos', 'despesa', 'devedora', pai63, true, true),
    (ws, '6.3.06', 'Equipamentos', 'despesa', 'devedora', pai63, true, true)
  on conflict (workspace_id, codigo) do nothing;

  -- formas de pagamento
  select id into banco from contas_bancarias where workspace_id = ws order by padrao desc nulls last, nome limit 1;
  insert into formas_pagamento (workspace_id, nome, tipo, titular_terceiro, conta_bancaria_id) values
    (ws, 'PIX', 'pix', null, banco), (ws, 'Boleto', 'boleto', null, banco), (ws, 'Débito automático', 'debito_automatico', null, banco),
    (ws, 'Cartão da empresa', 'cartao', null, null), (ws, 'Cartão do Tio Lutero', 'cartao', 'Tio Lutero', null)
  on conflict (workspace_id, nome) do nothing;
  
end $$;
