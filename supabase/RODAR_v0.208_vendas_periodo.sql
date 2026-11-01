-- RODAR no SQL Editor do Supabase (cópia de migrations/20261205100000_vendas_periodo.sql). Rode antes o RODAR_v0.206_historico_vendas.sql.
-- v0.208 — Dashboard de vendas no padrão: os números do período escolhido (de, até), com a comparação com o período anterior
-- do mesmo tamanho. Depende do RODAR_v0.206 (v_vendas_todas: "cliente novo" considera também o histórico importado).
-- Pode rodar de novo sem erro.
create or replace function public.vendas_periodo(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare n int := p_fim - p_ini + 1; a0 date := p_ini - (p_fim - p_ini + 1); a1 date := p_ini - 1;
  r jsonb; f jsonb;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini then raise exception 'Período inválido'; end if;
  -- um bloco de números por período
  select jsonb_build_object(
    'vendas', count(*) filter (where status = 'aprovada' and dia between p_ini and p_fim),
    'valor', coalesce(sum(valor) filter (where status = 'aprovada' and dia between p_ini and p_fim), 0),
    'reembolsos', count(*) filter (where status = 'reembolsada' and dia between p_ini and p_fim),
    'valor_reembolsado', coalesce(sum(valor) filter (where status = 'reembolsada' and dia between p_ini and p_fim), 0),
    'vendas_ant', count(*) filter (where status = 'aprovada' and dia between a0 and a1),
    'valor_ant', coalesce(sum(valor) filter (where status = 'aprovada' and dia between a0 and a1), 0))
  into r from v_vendas_todas where workspace_id = p_ws and dia between a0 and p_fim;
  select jsonb_build_object(
    'clientes_novos', count(*) filter (where d between p_ini and p_fim),
    'clientes_novos_ant', count(*) filter (where d between a0 and a1))
  into f from (select pessoa_id, min(dia) d from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and pessoa_id is not null group by pessoa_id) x;
  r := r || f;
  -- leads do período (cadastros captados) e quantos deles já viraram cliente
  r := r || (select jsonb_build_object('leads', count(*), 'leads_clientes', count(*) filter (where status_funil = 'cliente'))
             from pessoas where workspace_id = p_ws and coalesce(captada, true) and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim);
  r := r || (select jsonb_build_object('clientes_ativos', count(*) filter (where status_cliente = 'ativo'), 'clientes_inativos', count(*) filter (where status_cliente = 'inativo'))
             from pessoas where workspace_id = p_ws and status_funil = 'cliente');
  return r || jsonb_build_object('ini', p_ini, 'fim', p_fim, 'dias', n, 'ini_ant', a0, 'fim_ant', a1);
end $$;
revoke all on function public.vendas_periodo(uuid, date, date) from public, anon;
grant execute on function public.vendas_periodo(uuid, date, date) to authenticated;
notify pgrst, 'reload schema';
