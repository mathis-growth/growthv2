-- v0.177 — Diagnóstico 360° (G1b): formulário curto do cliente.
-- Plano: docs/diagnostico-360-plano.md, seção 8. Depois do teste da G1, a parte técnica sai do formulário do cliente e vai para a
-- reunião (G3). Aqui:
-- 1. metricas_definicoes.natureza: 'valor' (soma ou contagem: investimento, leads, faturamento) ou 'taxa' (conta: CPL, CAC,
--    conversão, churn, ROAS, LTV). A reunião pergunta coisas diferentes para cada uma.
-- 2. pesquisa_envios.rascunho e rascunho_em: o cliente salva e continua depois, pelo mesmo link.
-- 3. pesquisa_rascunho_salvar(token, dados): só no diagnóstico, só link individual, válido e ainda não respondido.
-- 4. pesquisa_publica devolve o rascunho (troca de texto; erro se o trecho não for encontrado).
-- Rode depois de 20261128100000_diagnostico_g1.sql. Idempotente.

-- ---------- 1. natureza da métrica ----------
alter table metricas_definicoes add column if not exists natureza text;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'metricas_definicoes_natureza_check') then
    alter table metricas_definicoes add constraint metricas_definicoes_natureza_check check (natureza in ('valor', 'taxa'));
  end if;
end $c$;
update metricas_definicoes set natureza = case
    when codigo in ('investimento', 'impressoes', 'leads', 'leads_canal', 'organico', 'receita', 'cliente', 'mrr', 'arr', 'receita_novos_base',
                    'expansao', 'lucro', 'indicacoes', 'receita_indicacao', 'depoimentos', 'resultado_mes', 'caixa_projetado', 'a_receber',
                    'saldo_banco', 'a_pagar') then 'valor'
    when coalesce(unidade, '') <> 'texto' then 'taxa' end
  where natureza is null;

-- ---------- 2. rascunho do link individual ----------
alter table pesquisa_envios add column if not exists rascunho jsonb;
alter table pesquisa_envios add column if not exists rascunho_em timestamptz;

-- ---------- 3. salvar e continuar depois ----------
create or replace function public.pesquisa_rascunho_salvar(p_token text, p_dados jsonb) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare v_e pesquisa_envios; v_p pesquisas;
begin
  if p_token is null or length(p_token) < 32 then raise exception 'Link inválido.'; end if;
  select * into v_e from pesquisa_envios where token = p_token;
  if not found then raise exception 'Link inválido.'; end if;
  select * into v_p from pesquisas where id = v_e.pesquisa_id;
  if v_p.tipo <> 'diagnostico' or not v_p.ativa then raise exception 'Este formulário não guarda rascunho.'; end if;
  if v_e.expira_em is not null and v_e.expira_em < now() then raise exception 'Este link venceu. Peça um novo link a quem enviou.'; end if;
  if v_e.status = 'respondido' then raise exception 'Você já enviou as respostas.'; end if;
  if p_dados is null or jsonb_typeof(p_dados) <> 'object' or length(p_dados::text) > 400000 then raise exception 'Rascunho em formato inválido.'; end if;
  update pesquisa_envios set rascunho = p_dados, rascunho_em = now() where id = v_e.id;
  return now();
end $$;
revoke all on function public.pesquisa_rascunho_salvar(text, jsonb) from public;
grant execute on function public.pesquisa_rascunho_salvar(text, jsonb) to anon, authenticated;

-- ---------- 4. o formulário público devolve o rascunho ----------
do $m$
declare def text; novo text;
begin
  select pg_get_functiondef('public.pesquisa_publica(text)'::regprocedure) into def;
  def := replace(def, E'\r\n', E'\n');
  if position('''rascunho''' in def) = 0 then
    if position('''expira_em'', case when v_aberto then null else v_e.expira_em end' in def) = 0 then
      raise exception 'v0.177: trecho esperado de pesquisa_publica não encontrado; nada foi alterado.';
    end if;
    novo := replace(def, '''expira_em'', case when v_aberto then null else v_e.expira_em end',
      '''expira_em'', case when v_aberto then null else v_e.expira_em end, ''rascunho'', case when v_aberto or v_e.status = ''respondido'' then null else v_e.rascunho end');
    execute novo;
  end if;
end $m$;

-- Para desfazer: reaplicar pesquisa_publica de 20261128100000_diagnostico_g1.sql; drop function pesquisa_rascunho_salvar(text, jsonb);
-- alter table pesquisa_envios drop column rascunho, drop column rascunho_em;
-- alter table metricas_definicoes drop constraint metricas_definicoes_natureza_check, drop column natureza.
