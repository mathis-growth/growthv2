-- v0.275: colunas livres por etapa no Kanban de conteúdo. Termina com "v0275: tudo OK".
-- Rodar no PGlite: node pglite_run.mjs <repo> tests/banco/v0275_conteudo_colunas.sql
-- no PGlite as migrações da Produção (pg_net) não sobem; as colunas que os gatilhos de conteúdo leem entram aqui
alter table conteudos add column if not exists roteiro text, add column if not exists roteiro_aprovado_em timestamptz, add column if not exists roteiro_aprovado_por text,
  add column if not exists peca_aprovada_em timestamptz, add column if not exists peca_aprovada_por text;
do $t$
declare ws uuid; ws2 uuid; ap uuid; gr uuid; outra uuid; c uuid; tm uuid;
begin
  ws := provisionar_workspace('Teste v0275'); ws2 := provisionar_workspace('Outro v0275');
  insert into conteudo_colunas (workspace_id, etapa, nome, ordem) values (ws, 'ideia', 'Ideias aprovadas', 1) returning id into ap;
  insert into conteudo_colunas (workspace_id, etapa, nome, ordem) values (ws, 'producao', 'Para gravar sexta', 1) returning id into gr;
  insert into conteudo_colunas (workspace_id, etapa, nome, ordem) values (ws2, 'ideia', 'Aprovadas', 1) returning id into outra;
  insert into conteudo_temas (workspace_id, nome, prioridade) values (ws, 'Negócios', 1) returning id into tm;
  insert into conteudos (workspace_id, titulo, status, formato, coluna_id, tema_id) values (ws, 'Ideia boa', 'ideia', 'reels', ap, tm) returning id into c;
  if (select coluna_id from conteudos where id = c) is distinct from ap then raise exception 'A: coluna da mesma etapa fica'; end if;
  -- mudou de etapa: a coluna da etapa antiga sai
  update conteudos set status = 'pauta', data_publicacao = current_date + 7 where id = c;
  if (select coluna_id from conteudos where id = c) is not null then raise exception 'B: coluna de outra etapa sai'; end if;
  -- coluna de outra etapa não entra
  update conteudos set coluna_id = ap where id = c;
  if (select coluna_id from conteudos where id = c) is not null then raise exception 'C: coluna de outra etapa não entra'; end if;
  -- mudar de etapa já escolhendo a coluna da etapa nova
  update conteudos set roteiro = 'texto', roteiro_aprovado_em = now() where id = c;
  update conteudos set status = 'producao', coluna_id = gr where id = c;
  if (select coluna_id from conteudos where id = c) is distinct from gr then raise exception 'D: etapa e coluna juntas'; end if;
  -- coluna de outro workspace não entra
  update conteudos set status = 'ideia', coluna_id = outra where id = c;
  if (select coluna_id from conteudos where id = c) is not null then raise exception 'E: coluna de outro workspace'; end if;
  -- apagar a coluna devolve o conteúdo para a etapa (sem coluna)
  update conteudos set coluna_id = ap where id = c; delete from conteudo_colunas where id = ap;
  if (select coluna_id from conteudos where id = c) is not null or (select status from conteudos where id = c) <> 'ideia' then raise exception 'F: apagar a coluna'; end if;
  begin insert into conteudo_colunas (workspace_id, etapa, nome) values (ws, 'producao', 'Para gravar sexta'); raise exception 'G: nome repetido na etapa';
  exception when unique_violation then null; end;
end $t$;
select 'v0275: tudo OK' as resultado;
