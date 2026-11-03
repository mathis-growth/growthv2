-- v0.244 — Aviso de lead novo para toda a equipe e "Gerar novo link" das pesquisas.
-- Decisões da Rebecka (02/11): o aviso vai para todos da equipe, para todos os leads; o WhatsApp sai pelo número da empresa (Zernio);
-- "Gerar novo link" com as duas opções: atualizar o endereço (mesmo código) e trocar o código (o link antigo para de funcionar).
-- · equipe.avisar_lead_novo (padrão: sim): cada pessoa pode desligar o aviso de lead novo; os canais seguem avisar_app / avisar_email / avisar_whatsapp.
-- · gatilho por comando em pessoas: até 5 leads novos de uma vez, um aviso por lead; mais que isso (importação), um aviso só com o total.
-- · pesquisa_trocar_link(pesquisa): troca o código do link aberto.
-- Aditivo e idempotente. Rode depois de 20261230100000_atendimento_template_mapeamentos.sql.

alter table public.equipe add column if not exists avisar_lead_novo boolean not null default true;

create or replace function public.lead_novo_avisar() returns trigger
language plpgsql security definer set search_path = public as $$
declare r record; p record; e record; v_tit text; v_msg text;
begin
  for r in select workspace_id, count(*) n from novos where coalesce(status_funil, 'lead') = 'lead' group by workspace_id loop
    if r.n <= 5 then
      for p in select * from novos where workspace_id = r.workspace_id and coalesce(status_funil, 'lead') = 'lead' loop
        v_tit := 'Novo lead: ' || left(coalesce(nullif(btrim(p.nome), ''), 'sem nome'), 80);
        v_msg := 'Chegou ' || coalesce('por ' || nullif(btrim(coalesce(p.canal_origem, p.utm_source, '')), ''), 'sem origem informada')
                 || coalesce(' · campanha ' || nullif(btrim(p.utm_campaign), ''), '') || '. Abra o CRM para ver.';
        for e in select id from equipe where workspace_id = r.workspace_id and ativo and avisar_lead_novo loop
          perform equipe_avisa(r.workspace_id, e.id, p.id, v_tit, v_msg);
        end loop;
      end loop;
    else
      for e in select id from equipe where workspace_id = r.workspace_id and ativo and avisar_lead_novo loop
        perform equipe_avisa(r.workspace_id, e.id, null, r.n || ' leads novos', 'Entraram ' || r.n || ' leads novos de uma vez (por exemplo, uma importação). Veja no Funil de leads.');
      end loop;
    end if;
  end loop;
  return null;
end $$;
revoke all on function public.lead_novo_avisar() from public, anon, authenticated;
drop trigger if exists pessoas_lead_novo_t on public.pessoas;
create trigger pessoas_lead_novo_t after insert on public.pessoas referencing new table as novos
  for each statement execute function public.lead_novo_avisar();

-- "Gerar novo link" → trocar o código do link aberto (o link antigo para de funcionar)
create or replace function public.pesquisa_trocar_link(p_pesquisa uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v_ws uuid; v_tok text;
begin
  select workspace_id into v_ws from pesquisas where id = p_pesquisa;
  if v_ws is null or not pode_editar(v_ws, '{gro,mkt}'::text[]) then raise exception 'Pesquisa não encontrada ou sem permissão.'; end if;
  v_tok := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  update pesquisas set token_aberto = v_tok where id = p_pesquisa;
  return v_tok;
end $$;
revoke all on function public.pesquisa_trocar_link(uuid) from public, anon;
grant execute on function public.pesquisa_trocar_link(uuid) to authenticated;

notify pgrst, 'reload schema';

-- Para desfazer: drop trigger pessoas_lead_novo_t on pessoas; drop function lead_novo_avisar(), pesquisa_trocar_link(uuid);
-- a coluna equipe.avisar_lead_novo pode ficar.
