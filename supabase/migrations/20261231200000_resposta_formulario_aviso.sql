-- v0.245 — Aviso de formulário respondido para toda a equipe.
-- Pedido da Rebecka (02/11): receber o alerta de que chegou um lead novo E de que ele respondeu o formulário,
-- e também quando o cliente responde uma pesquisa ou o diagnóstico.
-- · equipe.avisar_resposta (padrão: sim): cada pessoa pode desligar; os canais seguem avisar_app / avisar_email / avisar_whatsapp.
-- · gatilho adiado (roda no fim da gravação da resposta, depois da pontuação): título "<nome> respondeu o formulário",
--   mensagem com o nome do formulário e, quando houver, a pontuação e as faixas da qualificação.
-- · formulários de diagnóstico apontam para o diagnóstico.
-- Aditivo e idempotente. Rode depois de 20261231100000_lead_novo_aviso_e_novo_link.sql.

alter table public.equipe add column if not exists avisar_resposta boolean not null default true;

create or replace function public.resposta_formulario_avisar() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas; r pesquisa_respostas; v_nome text; v_tit text; v_msg text; v_q jsonb; v_g text; e record;
begin
  select * into r from pesquisa_respostas where id = new.id;
  if not found then return null; end if;
  select * into v_p from pesquisas where id = r.pesquisa_id;
  if not found then return null; end if;
  select nullif(btrim(nome), '') into v_nome from pessoas where id = r.pessoa_id;
  v_nome := coalesce(v_nome, nullif(btrim(r.email), ''), 'Alguém');
  v_tit := left(v_nome, 80) || ' respondeu o formulário';
  v_msg := '"' || left(v_p.nome, 80) || '"';
  v_q := r.qualif_det;
  if v_q is not null and coalesce((v_q ->> 'eliminado')::boolean, false) then
    v_msg := v_msg || ' · fora do perfil';
  elsif v_q is not null and v_q ? 'total' then
    v_msg := v_msg || ' · ' || round((v_q ->> 'total')::numeric) || ' pontos';
    select string_agg(key || ': ' || value, ' · ') into v_g from jsonb_each_text(coalesce(v_q -> 'grupos', '{}'::jsonb));
    if v_g is not null then v_msg := v_msg || ' · ' || v_g; end if;
  end if;
  v_msg := v_msg || case when v_p.tipo = 'diagnostico' then '. Abra o diagnóstico para ver as respostas.' else '. Abra a ficha para ver as respostas.' end;
  for e in select id from equipe where workspace_id = r.workspace_id and ativo and avisar_resposta loop
    perform equipe_avisa(r.workspace_id, e.id, r.pessoa_id, v_tit, v_msg);
  end loop;
  return null;
end $$;
revoke all on function public.resposta_formulario_avisar() from public, anon, authenticated;
drop trigger if exists pesquisa_respostas_aviso_t on public.pesquisa_respostas;
create constraint trigger pesquisa_respostas_aviso_t after insert on public.pesquisa_respostas
  deferrable initially deferred for each row execute function public.resposta_formulario_avisar();

notify pgrst, 'reload schema';

-- Para desfazer: drop trigger pesquisa_respostas_aviso_t on pesquisa_respostas; drop function resposta_formulario_avisar();
-- a coluna equipe.avisar_resposta pode ficar.
