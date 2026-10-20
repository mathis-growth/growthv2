-- v0.28 — (1) cliente cadastrado direto não conta como lead de marketing;
--         (2) onboarding (aluno) nasce sozinho também na ativação de contrato e no cadastro de cliente antigo;
--         (3) histórico de pagamentos anteriores ao sistema (não mexe em banco, DRE nem a receber).

-- 1) Marca de captação
alter table pessoas add column if not exists captada boolean not null default true;
comment on column pessoas.captada is 'false = cadastrada já como cliente (importação/legado): não entra na contagem de leads do marketing.';

do $mig$
declare d text; n text;
begin
  foreach n in array array['funil_analise', 'funil_cohorts', 'funil_membros'] loop
    select pg_get_functiondef(p.oid) into d from pg_proc p where proname = n and pronamespace = 'public'::regnamespace;
    d := regexp_replace(d, 'from pessoas p(\s+)where p\.workspace_id = p_ws', 'from pessoas p\1where p.captada and p.workspace_id = p_ws', 'g');
    execute d;
  end loop;
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'growth_metricas_auto' and pronamespace = 'public'::regnamespace;
  d := replace(d, 'select count(*) into leads from pessoas where workspace_id = p_ws and', 'select count(*) into leads from pessoas where captada and workspace_id = p_ws and');
  execute d;
end $mig$;

-- 2) Onboarding automático
alter table alunos alter column venda_id drop not null;
alter table alunos add column if not exists contrato_id uuid references contratos(id) on delete set null;
alter table alunos add column if not exists origem text not null default 'venda';
create unique index if not exists alunos_contrato_uq on alunos (contrato_id);

do $mig$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'ativar_contrato' and pronamespace = 'public'::regnamespace;
  d := replace(d, '  return c.num_parcelas;', $b$  insert into alunos (workspace_id, pessoa_id, produto_id, contrato_id, tag, etapa_kanban_id, origem)
  select c.workspace_id, c.pessoa_id, it.produto_id, c.id, pr.tag,
         (select id from etapas_kanban where workspace_id = c.workspace_id and quadro = 'alunos' order by ordem limit 1), 'contrato'
  from contrato_itens it join produtos pr on pr.id = it.produto_id where it.contrato_id = c.id order by pr.nome limit 1
  on conflict (contrato_id) do nothing;
  return c.num_parcelas;$b$);
  execute d;
end $mig$;

-- 3) Pagamentos de antes do sistema (somente histórico)
create table if not exists pagamentos_historicos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  produto_id uuid references produtos(id) on delete set null,
  valor numeric(14,2) not null check (valor > 0),
  periodo_inicio date, periodo_fim date, descricao text,
  criado_em timestamptz not null default now(), criado_por uuid default auth.uid());
comment on table pagamentos_historicos is 'Quanto o cliente já pagou antes de entrar no sistema. Não gera lançamento contábil, movimentação de banco nem conta a receber.';
alter table pagamentos_historicos enable row level security;
do $$ declare t text := 'pagamentos_historicos'; begin
  execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id))', t || '_leitura', t);
  execute format('create policy %I on public.%I for insert to authenticated with check (pode_operar(workspace_id))', t || '_insercao', t);
  execute format('create policy %I on public.%I for update to authenticated using (pode_operar(workspace_id)) with check (pode_operar(workspace_id))', t || '_edicao', t);
  execute format('create policy %I on public.%I for delete to authenticated using (pode_operar(workspace_id))', t || '_exclusao', t);
  execute format('create policy perm_ler on public.%I as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''vendas'',''fin'',''revops'']))', t);
  execute format('create policy perm_inserir on public.%I as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''vendas'',''fin'']))', t);
  execute format('create policy perm_alterar on public.%I as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''vendas'',''fin''])) with check (perm(workspace_id, ''editar'', array[''vendas'',''fin'']))', t);
  execute format('create policy perm_excluir on public.%I as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''vendas'',''fin'']))', t);
end $$;

create or replace function public.cadastrar_cliente_historico(p_ws uuid, p_nome text, p_email text, p_telefone text, p_data_entrada date, p_produto uuid,
  p_valor_pago numeric default 0, p_situacao text default 'ativo', p_canal text default null, p_cs uuid default null)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare pid uuid; pr produtos; em timestamptz := ((p_data_entrada::timestamp + time '12:00') at time zone 'America/Sao_Paulo');
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Informe o nome'; end if;
  if p_data_entrada is null then raise exception 'Informe a data de entrada'; end if;
  if p_data_entrada > current_date then raise exception 'A data de entrada não pode ser futura'; end if;
  if p_situacao not in ('ativo', 'inativo') then raise exception 'Situação inválida'; end if;
  select * into pr from produtos where id = p_produto and workspace_id = p_ws;
  if not found then raise exception 'Escolha o produto do cliente'; end if;
  insert into pessoas (workspace_id, nome, email, telefone, status_funil, status_cliente, canal_origem, criado_em, convertido_em, captada,
                       etapa_kanban_id, responsavel_comercial_id)
  values (p_ws, trim(p_nome), nullif(lower(trim(p_email)), ''), nullif(trim(p_telefone), ''), 'cliente', p_situacao, nullif(p_canal, ''), em, em, false,
          (select id from etapas_kanban where workspace_id = p_ws and quadro = 'leads' and nome = 'Cliente'), null)
  returning id into pid;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id, entrou_em, responsavel_cs_id, status, origem)
  values (p_ws, pid, pr.id, pr.tag, (select id from etapas_kanban where workspace_id = p_ws and quadro = 'alunos' order by ordem limit 1), em, p_cs, p_situacao, 'historico');
  if coalesce(p_valor_pago, 0) > 0 then
    insert into pagamentos_historicos (workspace_id, pessoa_id, produto_id, valor, periodo_inicio, periodo_fim, descricao)
    values (p_ws, pid, pr.id, p_valor_pago, p_data_entrada, current_date, 'Pago antes do sistema, desde a entrada');
  end if;
  return pid;
end $function$;
grant execute on function public.cadastrar_cliente_historico(uuid, text, text, text, date, uuid, numeric, text, text, uuid) to authenticated;
revoke execute on function public.cadastrar_cliente_historico(uuid, text, text, text, date, uuid, numeric, text, text, uuid) from public, anon;

-- 4) Ajuste dos dados já cadastrados na operação real (Mathisa — Operação)
update pessoas set captada = false
where workspace_id = '8fd51ed1-0843-49d8-a2aa-b9bb99c59171' and status_funil = 'cliente' and campanha_id is null and utm_campaign is null;
insert into alunos (workspace_id, pessoa_id, produto_id, contrato_id, tag, etapa_kanban_id, entrou_em, origem)
select c.workspace_id, c.pessoa_id, (array_agg(it.produto_id order by pr.nome))[1], c.id, (array_agg(pr.tag order by pr.nome))[1],
       (select id from etapas_kanban where workspace_id = c.workspace_id and quadro = 'alunos' order by ordem limit 1), coalesce(c.ativado_em, now()), 'contrato'
from contratos c join contrato_itens it on it.contrato_id = c.id join produtos pr on pr.id = it.produto_id
where c.workspace_id = '8fd51ed1-0843-49d8-a2aa-b9bb99c59171' and c.ativado_em is not null
  and not exists (select 1 from alunos a where a.contrato_id = c.id)
group by c.id
on conflict (contrato_id) do nothing;
