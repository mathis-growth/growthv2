-- v0.236 — Diagnóstico: reabrir o formulário para o cliente continuar.
-- Pedido da Rebecka (02/11): o link do formulário tem que continuar aparecendo no diagnóstico, para mandar de novo se o cliente perder,
-- e o cliente conseguir continuar.
-- · diagnostico_formulario_reabrir(diag): o link volta a aceitar respostas, com o que o cliente já tinha preenchido (o rascunho fica guardado);
--   o prazo do link passa a ser pelo menos 30 dias a partir de hoje. A resposta anterior continua no diagnóstico até chegar a nova.
-- · quando o cliente envia de novo, a resposta nova passa a ser a do diagnóstico (antes, só a primeira valia).
-- Aditivo e idempotente. Rode depois de 20261227100000_qualificacao_blocos.sql.

create or replace function public.diagnostico_formulario_reabrir(p_diag uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ws uuid := diag_pode(p_diag); d diagnosticos; v_e pesquisa_envios;
begin
  select * into d from diagnosticos where id = p_diag;
  if d.envio_id is null then raise exception 'Este diagnóstico ainda não tem o link do formulário: gere o link antes.'; end if;
  select * into v_e from pesquisa_envios where id = d.envio_id;
  update pesquisa_envios set status = case when enviado_em is not null then 'enviado' else 'pendente' end, respondido_em = null,
         expira_em = greatest(coalesce(expira_em, now()), now() + interval '30 days')
   where id = v_e.id returning * into v_e;
  insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto) values (v_ws, p_diag, 'status', 'Formulário reaberto para o cliente continuar');
  return jsonb_build_object('envio_id', v_e.id, 'token', v_e.token, 'status', v_e.status, 'expira_em', v_e.expira_em);
end $$;
revoke all on function public.diagnostico_formulario_reabrir(uuid) from public, anon;
grant execute on function public.diagnostico_formulario_reabrir(uuid) to authenticated;

-- a resposta mais nova do mesmo link passa a ser a do diagnóstico
create or replace function public.pesquisa_respostas_diag() returns trigger language plpgsql security definer set search_path = public as $$
declare v_novo boolean;
begin
  if new.envio_id is not null then
    select resposta_id is not null into v_novo from diagnosticos where envio_id = new.envio_id limit 1;
    update diagnosticos set resposta_id = new.id where envio_id = new.envio_id and resposta_id is distinct from new.id;
    if found then
      insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto, autor)
      select workspace_id, id, 'status', case when v_novo then 'O cliente enviou o formulário de novo' else 'O cliente respondeu o formulário' end, null from diagnosticos where resposta_id = new.id;
    end if;
  end if;
  return null;
end $$;

notify pgrst, 'reload schema';

-- Para desfazer: drop function diagnostico_formulario_reabrir(uuid); e voltar pesquisa_respostas_diag da 20261220100000 (só a primeira resposta vale).
