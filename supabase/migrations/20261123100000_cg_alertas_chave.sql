-- v0.163 — Alertas de CS só depois de ligados, e fora do resumo do dia e do "Pergunte ao Growths".
-- Motivo: em produção, a primeira passada criou centenas de alertas de CS (alunos parados e sem CS) de uma vez. A tela antiga
-- "Alertas e resumo do dia" mostra os 200 mais recentes de todos os tipos e o resumo do dia lista todos os do dia: os de CS
-- tomariam o lugar dos alertas de negócio.
-- 1. sistema_config 'cg_alertas' ('sim' | 'nao', padrão 'nao'): o agendador só gera alertas de CS com 'sim'. Os check-ins continuam.
-- 2. cg_ligar_alertas(): registra em silêncio o que já está acontecendo (sem avisar ninguém) e liga. Rodar quando a tela
--    RevOps → Customer Growth estiver no ar.
-- 3. Os alertas de CS saem do resumo do dia (growths_fatos_dia) e dos alertas abertos do "Pergunte ao Growths" (growths_ia_extra);
--    eles têm a tela própria em Customer Growth.
-- 4. Apaga os alertas de CS gerados antes de ligar (eram só o acúmulo da primeira passada; nada aponta para eles).
-- Rode depois de 20261122100000_customer_growth_indicadores.sql. Idempotente.

insert into sistema_config (chave, valor) values ('cg_alertas', 'nao') on conflict (chave) do nothing;

create or replace function public.cg_rodar_agendado(p_ref timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = public as $$
declare w record; n int := 0; ck int := 0; liga boolean := coalesce((select valor from sistema_config where chave = 'cg_alertas'), 'nao') = 'sim';
begin
  begin ck := pesquisa_checkins_gerar(p_ref, null); exception when others then raise warning 'cg_rodar_agendado (check-ins): %', sqlerrm; end;
  if liga then
    for w in select distinct workspace_id from alunos where status = 'ativo' and saiu_em is null loop
      begin perform cg_verificar_alertas(w.workspace_id, p_ref, true); n := n + 1;
      exception when others then raise warning 'cg_rodar_agendado %: %', w.workspace_id, sqlerrm; end;
    end loop;
  end if;
  return jsonb_build_object('clientes', n, 'checkins', ck, 'alertas_cs', liga);
end $$;
revoke all on function public.cg_rodar_agendado(timestamptz) from public, anon, authenticated;

create or replace function public.cg_ligar_alertas() returns jsonb
language plpgsql security definer set search_path = public as $$
declare w record; n int := 0;
begin
  if not (session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role' or sou_equipe_interna()) then raise exception 'Só a equipe interna liga os alertas de CS'; end if;
  for w in select distinct workspace_id from alunos where status = 'ativo' and saiu_em is null loop
    begin perform cg_verificar_alertas(w.workspace_id, now(), false); n := n + 1;
    exception when others then raise warning 'cg_ligar_alertas %: %', w.workspace_id, sqlerrm; end;
  end loop;
  insert into sistema_config (chave, valor) values ('cg_alertas', 'sim') on conflict (chave) do update set valor = 'sim';
  return jsonb_build_object('clientes', n, 'alertas_abertos', (select count(*) from alertas where tipo = 'cs' and resolvido_em is null));
end $$;
revoke all on function public.cg_ligar_alertas() from public, anon;
grant execute on function public.cg_ligar_alertas() to authenticated;

do $m$
declare d text; n text;
begin
  select replace(pg_get_functiondef('public.growths_fatos_dia(uuid, date)'::regprocedure), E'\r\n', E'\n') into d;
  if position('tipo <> ''cs''' in d) = 0 then
    n := replace(d, 'from alertas where workspace_id = p_ws and dia = p_dia)', 'from alertas where workspace_id = p_ws and dia = p_dia and tipo <> ''cs'')');
    if n = d then raise exception 'growths_fatos_dia: trecho dos alertas do dia não encontrado'; end if;
    execute n;
  end if;
  select replace(pg_get_functiondef('public.growths_ia_extra(uuid, date, date)'::regprocedure), E'\r\n', E'\n') into d;
  if position('tipo <> ''cs''' in d) = 0 then
    n := replace(d, 'from alertas where workspace_id = p_ws and resolvido_em is null order by', 'from alertas where workspace_id = p_ws and resolvido_em is null and tipo <> ''cs'' order by');
    if n = d then raise exception 'growths_ia_extra: trecho dos alertas abertos não encontrado'; end if;
    execute n;
  end if;
end $m$;

delete from alertas a where a.tipo = 'cs' and coalesce((select valor from sistema_config where chave = 'cg_alertas'), 'nao') <> 'sim'
  and not exists (select 1 from cs_intervencoes i where i.alerta_id = a.id);

-- Para desfazer: cg_rodar_agendado de 20261121100000 (sem a chave); drop function cg_ligar_alertas(); tirar "and tipo <> 'cs'" das duas funções;
-- delete from sistema_config where chave = 'cg_alertas'.
