-- v0.165 (Strategy Canvas S1 a S3): biblioteca, posições, conexões, versões e cópia para a campanha.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "canvas_s1_s3: tudo OK".
do $t$
declare ws uuid; ws2 uuid; f uuid; f2 uuid; b1 uuid; b2 uuid; b3 uuid; bl uuid; bo uuid; c uuid; c2 uuid; v int; n int; cb1 uuid; vid uuid;
begin
  insert into workspaces (nome) values ('CV') returning id into ws;
  insert into workspaces (nome) values ('CV2') returning id into ws2;
  -- S1: biblioteca
  insert into funis (workspace_id, nome, tipo, categoria, objetivo) values (ws, 'Lançamento com aulas', 'lancamento', 'Lançamento', 'Vender a mentoria') returning id into f;
  if (select status from funis where id = f) <> 'ativa' or (select versao_atual from funis where id = f) <> 0 then raise exception 'X: padrão da biblioteca'; end if;
  update funis set status = 'arquivada' where id = f;
  if (select ativo from funis where id = f) then raise exception 'X: arquivar não desligou'; end if;
  update funis set ativo = true where id = f;
  if (select status from funis where id = f) <> 'ativa' then raise exception 'X: religar não voltou para ativa'; end if;
  insert into funis (workspace_id, nome, tipo, ativo) values (ws, 'Antiga desligada', 'outro', false) returning id into f2;
  if (select status from funis where id = f2) <> 'arquivada' then raise exception 'X: criada desligada deveria ficar arquivada'; end if;

  -- S2: blocos com posição e propriedades, conexões com ramificação
  insert into estrategia_blocos (workspace_id, funil_id, ordem, fase, tipo, nome, x, y, props) values (ws, f, 10, 'aquisicao', 'trafego', 'Meta Ads', 40, 80, '{"canal": "Meta Ads", "objetivo": "Gerar cliques"}') returning id into b1;
  insert into estrategia_blocos (workspace_id, funil_id, ordem, fase, tipo, nome, x, y) values (ws, f, 20, 'aquisicao', 'captura', 'Página de captura', 300, 80) returning id into b2;
  insert into estrategia_blocos (workspace_id, funil_id, ordem, fase, tipo, nome, x, y) values (ws, f, 210, 'conversao', 'checkout', 'Checkout', 820, 80) returning id into b3;
  insert into estrategia_blocos (workspace_id, funil_id, ordem, fase, tipo, nome, x, y, props) values (ws, f, 120, 'aquecimento', 'condicao', 'Assistiu à aula?', 560, 80, '{"rotulo": "Condição"}') returning id into bl;
  insert into estrategia_etapas (workspace_id, funil_id, ordem, fase, chave, nome, origem, metrica, bloco_id, papel, conta_como) values
    (ws, f, 100, 'aquisicao', 'trafego1_cliques', 'Meta Ads · Cliques', 'anuncios', 'cliques', b1, 'principal', null),
    (ws, f, 101, 'aquisicao', 'trafego1_investimento', 'Meta Ads · Investimento', 'anuncios', 'investimento', b1, 'diagnostico', 'investimento'),
    (ws, f, 200, 'aquisicao', 'captura1_leads', 'Página · Leads', 'leads', null, b2, 'principal', null),
    (ws, f, 2100, 'conversao', 'checkout1_vendas', 'Checkout · Vendas', 'vendas', 'clientes', b3, 'principal', 'clientes_novos');
  insert into estrategia_conexoes (workspace_id, funil_id, de_bloco, para_bloco) values (ws, f, b1, b2), (ws, f, b2, bl);
  insert into estrategia_conexoes (workspace_id, funil_id, de_bloco, para_bloco, tipo, rotulo, condicao, peso) values (ws, f, bl, b3, 'sim', 'Assistiu', 'presença na aula', 50);
  if (select peso from estrategia_conexoes where de_bloco = bl) is not null then raise exception 'X: peso só vale na divisão'; end if;
  begin insert into estrategia_conexoes (workspace_id, funil_id, de_bloco, para_bloco) values (ws, f, b1, b1); raise exception 'X: conexão para o mesmo bloco';
  exception when check_violation then null; end;
  begin insert into estrategia_conexoes (workspace_id, funil_id, de_bloco, para_bloco) values (ws, f, b1, b2); raise exception 'X: conexão repetida';
  exception when unique_violation then null; end;
  insert into funis (workspace_id, nome, tipo) values (ws2, 'Outra', 'outro') returning id into f2;
  insert into estrategia_blocos (workspace_id, funil_id, ordem, fase, tipo, nome) values (ws2, f2, 10, 'aquisicao', 'trafego', 'X') returning id into bo;
  begin insert into estrategia_conexoes (workspace_id, funil_id, de_bloco, para_bloco) values (ws, f, b1, bo); raise exception 'X: conexão com bloco de outra estratégia';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;

  -- S3: versão 1, alteração, versão 2; versão imutável
  v := estrategia_publicar(f, 'Primeira');
  if v <> 1 or (select versao_atual from funis where id = f) <> 1 then raise exception 'X: publicar v1'; end if;
  if jsonb_array_length((select foto->'blocos' from estrategia_versoes where funil_id = f and versao = 1)) <> 4
     or jsonb_array_length((select foto->'conexoes' from estrategia_versoes where funil_id = f and versao = 1)) <> 3 then raise exception 'X: foto incompleta'; end if;
  begin update estrategia_versoes set nota = 'mudou' where funil_id = f and versao = 1; raise exception 'X: versão mudou';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  -- campanha 1 usa a v1
  insert into campanhas (workspace_id, nome, status) values (ws, 'Lançamento de março', 'planejada') returning id into c;
  n := campanha_aplicar_estrategia(c, f, false);
  if n <> 4 then raise exception 'X: copiou % métricas', n; end if;
  if (select count(*) from campanha_blocos where campanha_id = c) <> 4 then raise exception 'X: bloco de lógica (sem métricas) não foi copiado'; end if;
  if (select count(*) from campanha_conexoes where campanha_id = c) <> 3 then raise exception 'X: conexões não foram copiadas'; end if;
  select id into cb1 from campanha_blocos where campanha_id = c and bloco_origem_id = b1;
  if (select x from campanha_blocos where id = cb1) <> 40 or (select props->>'canal' from campanha_blocos where id = cb1) <> 'Meta Ads' or (select status from campanha_blocos where id = cb1) <> 'planejado' then raise exception 'X: posição/propriedades/status na campanha'; end if;
  if (select k.tipo || '/' || k.rotulo from campanha_conexoes k join campanha_blocos d on d.id = k.de_bloco where k.campanha_id = c and d.bloco_origem_id = bl) <> 'sim/Assistiu' then raise exception 'X: ramificação na campanha'; end if;
  select versao_id into vid from campanha_estrategias where campanha_id = c and funil_id = f;
  if (select versao from estrategia_versoes where id = vid) <> 1 then raise exception 'X: campanha sem a versão 1'; end if;
  -- muda a estratégia e publica v2: a campanha 1 continua igual e na v1
  update estrategia_blocos set nome = 'Meta Ads e Google Ads', x = 60 where id = b1;
  v := estrategia_publicar(f, null);
  if v <> 2 then raise exception 'X: v2'; end if;
  if (select nome from campanha_blocos where id = cb1) <> 'Meta Ads' or (select x from campanha_blocos where id = cb1) <> 40 then raise exception 'X: mudar a estratégia mexeu na campanha'; end if;
  if (select versao from estrategia_versoes where id = (select versao_id from campanha_estrategias where campanha_id = c)) <> 1 then raise exception 'X: campanha 1 mudou de versão'; end if;
  -- campanha 2 com a mesma estratégia pega a v2, sem misturar com a 1
  insert into campanhas (workspace_id, nome, status) values (ws, 'Lançamento de abril', 'planejada') returning id into c2;
  perform campanha_aplicar_estrategia(c2, f, false);
  if (select versao from estrategia_versoes where id = (select versao_id from campanha_estrategias where campanha_id = c2)) <> 2 then raise exception 'X: campanha 2 sem a v2'; end if;
  if (select nome from campanha_blocos where campanha_id = c2 and bloco_origem_id = b1) <> 'Meta Ads e Google Ads' then raise exception 'X: campanha 2 sem o nome novo'; end if;
  if exists (select 1 from campanha_conexoes k join campanha_blocos d on d.id = k.de_bloco where k.campanha_id = c2 and d.campanha_id <> c2) then raise exception 'X: conexões misturadas'; end if;
  -- aplicar de novo não duplica
  perform campanha_aplicar_estrategia(c2, f, false);
  if (select count(*) from campanha_blocos where campanha_id = c2) <> 4 or (select count(*) from campanha_conexoes where campanha_id = c2) <> 3 then raise exception 'X: aplicar de novo duplicou'; end if;
  -- substituir refaz tudo
  perform campanha_aplicar_estrategia(c2, f, true);
  if (select count(*) from campanha_conexoes where campanha_id = c2) <> 3 then raise exception 'X: substituir sem conexões'; end if;
  -- estratégia nunca publicada: a campanha grava a v1 sozinha
  insert into funis (workspace_id, nome, tipo) values (ws, 'Perpétuo simples', 'perpetuo') returning id into f2;
  insert into estrategia_blocos (workspace_id, funil_id, ordem, fase, tipo, nome) values (ws, f2, 10, 'conversao', 'checkout', 'Checkout');
  insert into campanhas (workspace_id, nome) values (ws, 'Perpétuo') returning id into c;
  perform campanha_aplicar_estrategia(c, f2, false);
  if (select versao_atual from funis where id = f2) <> 1 or (select versao_id from campanha_estrategias where campanha_id = c) is null then raise exception 'X: versão automática na primeira campanha'; end if;
  raise notice 'canvas_s1_s3: tudo OK';
end $t$;
select 'canvas_s1_s3: tudo OK' as resultado;
