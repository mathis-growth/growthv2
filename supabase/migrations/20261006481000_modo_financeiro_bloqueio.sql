-- v0.29 (parte 2, PRECISA SER EXECUTADA POR VOCÊ no SQL Editor do Supabase; a ferramenta recusou aplicar).
-- Liga o modo financeiro simplificado de verdade: o banco passa a BLOQUEAR contas bancárias, movimentações, contas a pagar,
-- lançamentos e partidas nos workspaces em modo "simplificado". Em "completo" (padrão) nada muda.
create or replace function public.fin_completo(p_ws uuid) returns boolean
language sql stable security definer set search_path to 'public' as $$
  select coalesce((select modo_financeiro = 'completo' from workspaces where id = p_ws), true)
$$;
grant execute on function public.fin_completo(uuid) to authenticated;

do $$ declare t text; begin
  foreach t in array array['contas_bancarias', 'movimentacoes_bancarias', 'contas_pagar', 'lancamentos', 'partidas'] loop
    execute format('drop policy if exists fin_modo on public.%I', t);
    execute format('create policy fin_modo on public.%I as restrictive for all to authenticated using (fin_completo(workspace_id)) with check (fin_completo(workspace_id))', t);
  end loop; end $$;

-- Troca de modo (só administrador). Ao simplificar, garante uma conta de controle interna para as baixas de recebimento.
create or replace function public.definir_modo_financeiro(p_ws uuid, p_modo text) returns text
language plpgsql security definer set search_path to 'public' as $function$
declare cc uuid;
begin
  if not eh_admin(p_ws) then raise exception 'Só administrador troca o modo financeiro'; end if;
  if p_modo not in ('completo', 'simplificado') then raise exception 'Modo inválido'; end if;
  if p_modo = 'simplificado' and not exists (select 1 from contas_bancarias where workspace_id = p_ws and padrao and ativa) then
    select id into cc from plano_contas where workspace_id = p_ws and codigo like '1.1.%' and aceita_lancamento order by codigo limit 1;
    if cc is null then raise exception 'Cadastre uma conta de caixa/banco no plano de contas antes de simplificar'; end if;
    insert into contas_bancarias (workspace_id, nome, banco, saldo_inicial, conta_contabil_id, padrao, ativa)
    values (p_ws, 'Recebimentos (controle interno)', null, 0, cc, true, true);
  end if;
  update workspaces set modo_financeiro = p_modo where id = p_ws;
  return p_modo;
end $function$;
grant execute on function public.definir_modo_financeiro(uuid, text) to authenticated;
revoke execute on function public.definir_modo_financeiro(uuid, text) from public, anon;

-- Baixa de recebimento: no modo simplificado usa a conta de controle (o usuário não escolhe banco)
do $mig$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'registrar_recebimento' and pronamespace = 'public'::regnamespace;
  d := replace(d, 'v_banco := coalesce(p_conta_bancaria, cr.conta_bancaria_id);',
    $b$v_banco := coalesce(p_conta_bancaria, cr.conta_bancaria_id,
    case when not fin_completo(cr.workspace_id) then (select id from contas_bancarias where workspace_id = cr.workspace_id and padrao and ativa limit 1) end);$b$);
  execute d;
end $mig$;

