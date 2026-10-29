-- v0.163 — Check-in que se repete (Customer Growth, etapa B6).
-- 1. pesquisa_envios ganha aluno_id (a matrícula do check-in) e ciclo (0 = envio único de sempre; 1, 2, 3… = check-ins).
--    A trava única passa de (pesquisa, pessoa) para (pesquisa, pessoa, ciclo). Envios que já existem ficam no ciclo 0: nada muda para eles.
-- 2. Todas as funções que gravam envios passam a usar a trava nova (pesquisa_enfileira, pesquisa_gerar_envios, pesquisa_enviar_para,
--    pesquisa_enfileira_aluno), na mesma migração.
-- 3. Gatilho novo 'checkin': a cada N dias (pesquisas.checkin_dias) desde a matrícula, enquanto ela estiver ativa, com filtro opcional
--    de produto e um limite de vezes (checkin_max). pesquisa_checkins_gerar(ref) cria os envios do dia; o agendador de hora em hora chama.
-- 4. A resposta de um check-in vale para os marcos daquela matrícula (não para todas as matrículas da pessoa).
-- Rode depois de 20261119100000_jornada_marcos.sql. Idempotente.

alter table pesquisa_envios add column if not exists aluno_id uuid references alunos(id) on delete set null;
alter table pesquisa_envios add column if not exists ciclo int not null default 0 check (ciclo >= 0);
create index if not exists pesquisa_envios_aluno on pesquisa_envios (aluno_id);
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_envios_ciclo_uq') then
    alter table pesquisa_envios add constraint pesquisa_envios_ciclo_uq unique (pesquisa_id, pessoa_id, ciclo);
  end if;
end $c$;

alter table pesquisas add column if not exists checkin_dias int check (checkin_dias is null or checkin_dias between 1 and 365);
alter table pesquisas add column if not exists checkin_max int check (checkin_max is null or checkin_max between 1 and 100);
alter table pesquisas drop constraint if exists pesquisas_gatilho_check;
alter table pesquisas add constraint pesquisas_gatilho_check check (gatilho in ('manual', 'cadastro', 'etapa', 'entrada_aluno', 'etapa_aluno', 'checkin'));
alter table pesquisas drop constraint if exists pesquisas_checkin_ck;
alter table pesquisas add constraint pesquisas_checkin_ck check (gatilho <> 'checkin' or checkin_dias is not null);

-- Troca a trava nas funções que já existem (o corpo pode estar com quebra de linha do Windows).
do $m$
declare f text; d text; n text;
begin
  foreach f in array array['public.pesquisa_enfileira(uuid, uuid, text, text, uuid)', 'public.pesquisa_gerar_envios(uuid)', 'public.pesquisa_enviar_para(uuid, uuid[])'] loop
    select pg_get_functiondef(f::regprocedure) into d;
    d := replace(d, E'\r\n', E'\n');
    if position('on conflict (pesquisa_id, pessoa_id, ciclo)' in d) = 0 then
      n := replace(d, 'on conflict (pesquisa_id, pessoa_id) do nothing', 'on conflict (pesquisa_id, pessoa_id, ciclo) do nothing');
      if n = d then raise exception '%: trava de envio não encontrada', f; end if;
      execute n;
    end if;
  end loop;
end $m$;

-- Pesquisas de aluno (entrada, etapa) guardam a matrícula no envio.
create or replace function public.pesquisa_enfileira_aluno(p_aluno uuid, p_gatilho text, p_etapa uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a alunos;
begin
  select * into a from alunos where id = p_aluno;
  if not found then return; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, aluno_id, status, motivo, origem)
  select s.workspace_id, s.id, a.pessoa_id, a.id,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = a.pessoa_id and x.qualificacao = 'qualificado') then 'dispensado' else 'pendente' end,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = a.pessoa_id and x.qualificacao = 'qualificado') then 'ja_qualificado' end,
    'gatilho'
  from pesquisas s
  where s.workspace_id = a.workspace_id and s.ativa and s.gatilho = p_gatilho
    and (s.produto_id is null or s.produto_id = a.produto_id)
    and (p_gatilho <> 'etapa_aluno' or s.etapa_aluno_id = p_etapa)
  on conflict (pesquisa_id, pessoa_id, ciclo) do nothing;
end $$;
revoke execute on function public.pesquisa_enfileira_aluno(uuid, text, uuid) from public, anon, authenticated;

-- Check-ins do dia: para cada pesquisa de check-in ativa, cada matrícula ativa recebe o ciclo k quando completa k × N dias.
-- Só cria o ciclo de hoje (não recria os que passaram enquanto o agendador estava desligado). Devolve quantos criou.
create or replace function public.pesquisa_checkins_gerar(p_ref timestamptz default now(), p_ws uuid default null) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if p_ws is not null and not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, aluno_id, ciclo, origem)
  select distinct on (s.id, a.pessoa_id) s.workspace_id, s.id, a.pessoa_id, a.id,
    floor(extract(epoch from (p_ref - a.entrou_em)) / 86400 / s.checkin_dias)::int, 'gatilho'
  from pesquisas s
  join alunos a on a.workspace_id = s.workspace_id and a.saiu_em is null and a.status = 'ativo' and (s.produto_id is null or a.produto_id = s.produto_id)
  where s.ativa and s.gatilho = 'checkin' and (p_ws is null or s.workspace_id = p_ws)
    and floor(extract(epoch from (p_ref - a.entrou_em)) / 86400 / s.checkin_dias) >= 1
    and (s.checkin_max is null or floor(extract(epoch from (p_ref - a.entrou_em)) / 86400 / s.checkin_dias) <= s.checkin_max)
  order by s.id, a.pessoa_id, a.entrou_em
  on conflict (pesquisa_id, pessoa_id, ciclo) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.pesquisa_checkins_gerar(timestamptz, uuid) from public, anon, authenticated;

-- A resposta de um envio com matrícula vale para os marcos daquela matrícula.
create or replace function public.marco_trg() returns trigger language plpgsql security definer set search_path = public as $$
declare pid uuid; pq uuid; al uuid;
begin
  begin
    if tg_table_name = 'vendas' then
      if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
        perform _marco_pessoa(new.pessoa_id, 'compra', 'vendas', new.id, jsonb_build_object('produto_id', new.produto_id, 'em', new.data_venda)); end if;
    elsif tg_table_name = 'presencas_video' then
      perform _marco_pessoa(new.pessoa_id, 'video', 'presencas_video', new.id, jsonb_build_object('fonte_id', new.fonte_id, 'segundos', new.assistiu_seg));
    elsif tg_table_name = 'pesquisa_respostas' then
      select aluno_id into al from pesquisa_envios where id = new.envio_id;
      if al is not null then perform _marco_marcar(al, 'pesquisa', 'pesquisa_respostas', new.id, jsonb_build_object('pesquisa_id', new.pesquisa_id, 'em', new.respondida_em));
      elsif new.pessoa_id is not null then perform _marco_pessoa(new.pessoa_id, 'pesquisa', 'pesquisa_respostas', new.id, jsonb_build_object('pesquisa_id', new.pesquisa_id, 'em', new.respondida_em)); end if;
    elsif tg_table_name = 'pesquisa_resposta_itens' then
      select r.pessoa_id, r.pesquisa_id, e.aluno_id into pid, pq, al from pesquisa_respostas r left join pesquisa_envios e on e.id = r.envio_id where r.id = new.resposta_id;
      if al is not null then perform _marco_marcar(al, 'pesquisa', 'pesquisa_respostas', new.resposta_id,
        jsonb_build_object('pesquisa_id', pq, 'pergunta_id', new.pergunta_id, 'valor', coalesce(new.valor_texto, new.valor_num::text)));
      elsif pid is not null then perform _marco_pessoa(pid, 'pesquisa', 'pesquisa_respostas', new.resposta_id,
        jsonb_build_object('pesquisa_id', pq, 'pergunta_id', new.pergunta_id, 'valor', coalesce(new.valor_texto, new.valor_num::text))); end if;
    elsif tg_table_name = 'aluno_historico' then
      if new.tipo in ('etapa', 'jornada') and new.etapa_kanban_id is not null then
        perform _marco_marcar(new.aluno_id, 'etapa', 'aluno_historico', new.id, jsonb_build_object('etapa_kanban_id', new.etapa_kanban_id, 'em', new.em)); end if;
    elsif tg_table_name = 'pessoa_lista' then
      if new.ativo and (tg_op = 'INSERT' or not old.ativo) then perform _marco_pessoa(new.pessoa_id, 'lista', 'pessoa_lista', null, jsonb_build_object('lista_id', new.lista_id)); end if;
    elsif tg_table_name = 'pessoa_toques' then
      if new.tipo = 'outro' and new.chave is not null then perform _marco_pessoa(new.pessoa_id, 'evento', 'pessoa_toques', new.id, jsonb_build_object('evento', new.chave, 'em', new.em)); end if;
    end if;
  exception when others then raise warning 'marco_trg (%): %', tg_table_name, sqlerrm;
  end;
  return null;
end $$;
revoke execute on function public.marco_trg() from public, anon, authenticated;

-- Por último, a trava antiga sai (as funções acima já usam a nova).
alter table pesquisa_envios drop constraint if exists pesquisa_envios_pesquisa_id_pessoa_id_key;

-- Para desfazer: apagar os envios de ciclo > 0 (delete from pesquisa_envios where ciclo > 0), recriar a trava
-- (alter table pesquisa_envios add constraint pesquisa_envios_pesquisa_id_pessoa_id_key unique (pesquisa_id, pessoa_id)), trocar de volta
-- o "on conflict" nas quatro funções, drop function pesquisa_checkins_gerar; update pesquisas set gatilho = 'manual' where gatilho = 'checkin';
-- recriar pesquisas_gatilho_check sem 'checkin'; drop constraint pesquisas_checkin_ck; drop columns checkin_max, checkin_dias, ciclo, aluno_id.
