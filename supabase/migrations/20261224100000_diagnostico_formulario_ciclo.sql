-- v0.232 — Correção: escolher o formulário no diagnóstico dava erro em produção e o link não era gerado.
-- Causa: diagnostico_formulario usava "on conflict (pesquisa_id, pessoa_id)", mas desde os check-ins (v0.163) a trava única de
-- pesquisa_envios é (pesquisa_id, pessoa_id, ciclo). O Postgres recusava com "there is no unique or exclusion constraint matching".
-- Aditivo e idempotente: só troca a função. Rode depois de 20261223100000_clientes_workspace_contrato.sql (ou a qualquer momento depois da v0.228).

create or replace function public.diagnostico_formulario(p_diag uuid, p_pesquisa uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ws uuid := diag_pode(p_diag); d diagnosticos; v_p pesquisas; v_e pesquisa_envios;
begin
  select * into d from diagnosticos where id = p_diag;
  if d.resposta_id is not null then raise exception 'O cliente já respondeu: o formulário não pode mais ser trocado.'; end if;
  if d.pessoa_id is null then raise exception 'Escolha o cliente do diagnóstico antes do formulário.'; end if;
  select * into v_p from pesquisas where id = p_pesquisa and workspace_id = v_ws;
  if not found or v_p.tipo <> 'diagnostico' then raise exception 'Escolha um formulário de diagnóstico.'; end if;
  if not v_p.ativa then raise exception 'Este formulário está desativado. Ative em Pesquisas antes de enviar.'; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (v_ws, v_p.id, d.pessoa_id, 'manual')
    on conflict do nothing;
  select * into v_e from pesquisa_envios where pesquisa_id = v_p.id and pessoa_id = d.pessoa_id order by ciclo, gerado_em limit 1;
  update diagnosticos set envio_id = v_e.id where id = p_diag;
  insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto) values (v_ws, p_diag, 'status', 'Formulário escolhido: ' || v_p.nome);
  return jsonb_build_object('envio_id', v_e.id, 'token', v_e.token, 'status', v_e.status);
end $$;
revoke all on function public.diagnostico_formulario(uuid, uuid) from public, anon;
grant execute on function public.diagnostico_formulario(uuid, uuid) to authenticated;
