-- Growths — Escola Aurora (empresa fictícia para testar as telas) + Lançamento "Semana da Fluência" em captação.
-- PARTE 1 de 4 (dados). Depois rode as partes 2, 3 e 4 (imagens dos criativos).
-- Como usar: Supabase → SQL Editor → New query → cole este arquivo inteiro → Run. Leva alguns segundos.
-- Cria um workspace NOVO chamado "Escola Aurora" (não mexe na Mathisa nem nos outros). Se ele já existir, o arquivo para sem mudar nada.
-- O que entra:
--   • Histórico jul–out/2026: perpétuo do Curso Inglês Base (Meta Ads), lançamento de setembro (Google), mentoria em contratos,
--     despesas pagas, recebimentos, reembolsos — tudo pelos fluxos reais do banco (DRE, caixa e contas a receber batem).
--   • Lançamento "Formação Fluência · Semana da Fluência": captação de 01 a 26/10, aulas 27, 29 e 31/10, carrinho de 03 a 09/11.
--     R$ 20.000 de tráfego só na aquisição, 7 campanhas de anúncio (Meta, Google, TikTok) + Instagram orgânico e e-mail,
--     31 anúncios com imagem, métricas diárias de 01 a 16/10, leads, grupo VIP, pesquisa de qualificação, metas por canal.
-- Requer a v0.111 rodada? Não. Funciona com o banco até a v0.109; com a v0.111 também preenche o anexo do Simples.
begin;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $$ begin
  if exists (select 1 from workspaces where nome = 'Escola Aurora') then raise exception 'O workspace "Escola Aurora" já existe. Nada foi alterado.'; end if;
  if not exists (select 1 from auth.users where email = 'rebecka@rebeckacappello.com.br') then raise exception 'Usuária rebecka@rebeckacappello.com.br não encontrada.'; end if;
end $$;

create temp table _lfa_camp (k text primary key, canal text, nome text, utm text, orc numeric, meta int, temp text, vendas int) on commit drop;
insert into _lfa_camp values
('int','meta_ads','[CAP] Frio · Interesses','lfa26-meta-frio-interesses',5500,1200,'frio',17),
('lal','meta_ads','[CAP] Frio · Lookalike de alunos','lfa26-meta-frio-lookalike',4500,1000,'frio',15),
('adv','meta_ads','[CAP] Frio · Aberto (Advantage+)','lfa26-meta-frio-advantage',3000,600,'frio',9),
('rmk','meta_ads','[CAP] Quente · Remarketing','lfa26-meta-quente-remarketing',2000,500,'quente',10),
('yt','google_ads','[CAP] YouTube · In-stream','lfa26-google-youtube',2000,260,'frio',4),
('src','google_ads','[CAP] Pesquisa · Inglês para adultos','lfa26-google-pesquisa',1000,170,'quente',3),
('tt','tiktok_ads','[CAP] TikTok · Spark Ads','lfa26-tiktok-spark',2000,400,'frio',5);
create temp table _lfa_ad (cod text primary key, camp text, nome text, angulo text, formato text, ini date, fim date, utm_content text, img text) on commit drop;
insert into _lfa_ad values
('AD01','int','AD01 · Trava na hora de falar · Estático','dor','estatico','2026-10-01',null,'ad01-trava-na-hora-de-falar',null),
('AD02','int','AD02 · Entende mas não fala · Reels','dor','reels','2026-10-01',null,'ad02-entende-mas-nao-fala',null),
('AD03','int','AD03 · Depoimento Carla · 6 meses · Reels','prova','reels','2026-10-01',null,'ad03-depoimento-carla-6-meses',null),
('AD04','int','AD04 · 3 erros de quem estuda sozinho · Carrossel','autoridade','carrossel','2026-10-01',null,'ad04-3-erros-de-quem-estuda-sozinho',null),
('AD05','int','AD05 · Semana da Fluência · aulas grátis · Estático','evento','estatico','2026-10-01',null,'ad05-semana-da-fluencia-aulas-gratis',null),
('AD06','int','AD06 · Inglês em 20 min por dia · Estático','desejo','estatico','2026-10-01','2026-10-05','ad06-ingles-em-20-min-por-dia',null),
('AD07','int','AD07 · Viajar sem medo · Reels','desejo','reels','2026-10-01',null,'ad07-viajar-sem-medo',null),
('AD08','int','AD08 · Antes e depois · áudio real · Reels','prova','reels','2026-10-08',null,'ad08-antes-e-depois-audio-real',null),
('AD09','int','AD09 · Quiz · qual é o seu nível? · Carrossel','curiosidade','carrossel','2026-10-08',null,'ad09-quiz-qual-e-o-seu-nivel',null),
('AD10','lal','AD10 · Trava na hora de falar · Estático','dor','estatico','2026-10-01',null,'ad10-trava-na-hora-de-falar',null),
('AD11','lal','AD11 · Depoimento Carla · 6 meses · Reels','prova','reels','2026-10-01',null,'ad11-depoimento-carla-6-meses',null),
('AD12','lal','AD12 · 3 erros de quem estuda sozinho · Carrossel','autoridade','carrossel','2026-10-01',null,'ad12-3-erros-de-quem-estuda-sozinho',null),
('AD13','lal','AD13 · Promoção no trabalho · Estático','desejo','estatico','2026-10-01',null,'ad13-promocao-no-trabalho',null),
('AD14','lal','AD14 · Aula ao vivo 27/10 · Stories','evento','stories','2026-10-08',null,'ad14-aula-ao-vivo-27-10',null),
('AD15','lal','AD15 · Método em 4 passos · Carrossel','autoridade','carrossel','2026-10-01','2026-10-09','ad15-metodo-em-4-passos',null),
('AD16','adv','AD16 · Trava na hora de falar · Estático','dor','estatico','2026-10-01',null,'ad16-trava-na-hora-de-falar',null),
('AD17','adv','AD17 · Depoimento Carla · 6 meses · Reels','prova','reels','2026-10-01',null,'ad17-depoimento-carla-6-meses',null),
('AD18','adv','AD18 · Antes e depois · áudio real · Reels','prova','reels','2026-10-08',null,'ad18-antes-e-depois-audio-real',null),
('AD19','adv','AD19 · Você fala “I am agree”? · Estático','curiosidade','estatico','2026-10-01',null,'ad19-voce-fala-i-am-agree',null),
('AD20','rmk','AD20 · Faltam poucos dias · Stories','evento','stories','2026-10-01',null,'ad20-faltam-poucos-dias',null),
('AD21','rmk','AD21 · Depoimentos em sequência · Carrossel','prova','carrossel','2026-10-01',null,'ad21-depoimentos-em-sequencia',null),
('AD22','rmk','AD22 · Garanta sua vaga · Estático','evento','estatico','2026-10-01',null,'ad22-garanta-sua-vaga',null),
('AD23','rmk','AD23 · Bastidores da aula · Reels','autoridade','reels','2026-10-08',null,'ad23-bastidores-da-aula',null),
('AD24','yt','AD24 · Vídeo 45s · Trava na hora de falar · Vídeo','dor','video','2026-10-01',null,'ad24-video-45s-trava-na-hora-de-falar',null),
('AD25','yt','AD25 · Vídeo 30s · Depoimento Carla · Vídeo','prova','video','2026-10-01',null,'ad25-video-30s-depoimento-carla',null),
('AD26','yt','AD26 · Bumper 6s · Semana da Fluência · Vídeo','evento','video','2026-10-08',null,'ad26-bumper-6s-semana-da-fluencia',null),
('AD27','src','AD27 · Busca · curso de inglês online · Texto','oferta','texto','2026-10-01',null,'ad27-busca-curso-de-ingles-online',null),
('AD28','src','AD28 · Busca · inglês rápido · Texto','oferta','texto','2026-10-01','2026-10-12','ad28-busca-ingles-rapido',null),
('AD29','tt','AD29 · POV: você trava no inglês · Vertical','dor','vertical','2026-10-01',null,'ad29-pov-voce-trava-no-ingles',null),
('AD30','tt','AD30 · Professora reage a erros · Vertical','autoridade','vertical','2026-10-01',null,'ad30-professora-reage-a-erros',null),
('AD31','tt','AD31 · Fala comigo em inglês · Vertical','curiosidade','vertical','2026-10-08',null,'ad31-fala-comigo-em-ingles',null);
create temp table _lfa_img (nome text primary key, img text) on commit drop;
create temp table _lfa_dia (cod text, data date, imp int, cli int, custo numeric, vis int, alc int, leads int) on commit drop;
insert into _lfa_dia values
('AD01','2026-10-01',1345,27,33.99,21,1268,4),
('AD02','2026-10-01',687,9,15.71,7,618,2),
('AD03','2026-10-01',1075,17,25.6,14,1027,8),
('AD04','2026-10-01',547,7,13.84,5,538,1),
('AD05','2026-10-01',681,9,17.35,7,645,2),
('AD06','2026-10-01',591,4,13.84,3,561,0),
('AD07','2026-10-01',591,8,13.84,6,558,1),
('AD10','2026-10-01',1261,26,35.45,21,1236,9),
('AD11','2026-10-01',1161,19,30.14,15,1078,5),
('AD12','2026-10-01',620,8,17.51,7,595,5),
('AD13','2026-10-01',705,10,18.68,8,696,4),
('AD15','2026-10-01',682,6,17.51,5,637,1),
('AD16','2026-10-01',1251,18,25.05,14,1215,5),
('AD17','2026-10-01',1342,17,25.05,13,1276,1),
('AD19','2026-10-01',2170,40,41.77,31,2076,16),
('AD20','2026-10-01',297,7,13.27,6,275,4),
('AD21','2026-10-01',289,7,12.84,6,273,2),
('AD22','2026-10-01',233,4,10.12,3,221,1),
('AD24','2026-10-01',1412,11,22.3,8,1283,5),
('AD25','2026-10-01',1852,15,29.37,10,1734,6),
('AD27','2026-10-01',141,9,13.91,8,129,1),
('AD28','2026-10-01',76,4,7.16,4,69,0),
('AD29','2026-10-01',1945,19,22.76,12,1852,3),
('AD30','2026-10-01',2370,23,27.4,15,2144,4),
('AD01','2026-10-02',833,15,20.21,11,728,7),
('AD02','2026-10-02',823,10,20.21,8,718,2),
('AD03','2026-10-02',835,14,20.21,12,768,8),
('AD04','2026-10-02',851,10,20.21,8,751,2),
('AD05','2026-10-02',809,10,20.21,8,722,3),
('AD06','2026-10-02',853,6,20.21,5,781,1),
('AD07','2026-10-02',801,9,20.21,7,739,3),
('AD10','2026-10-02',862,16,22.02,13,758,4),
('AD11','2026-10-02',837,14,22.02,11,774,8),
('AD12','2026-10-02',833,11,22.02,9,756,5),
('AD13','2026-10-02',787,11,22.02,9,708,4),
('AD15','2026-10-02',798,7,22.02,6,716,3),
('AD16','2026-10-02',1534,20,30.63,15,1418,7),
('AD17','2026-10-02',1530,21,30.63,16,1425,5),
('AD19','2026-10-02',1637,33,30.63,27,1473,12),
('AD20','2026-10-02',289,6,12.24,5,233,4),
('AD21','2026-10-02',276,6,12.24,5,223,4),
('AD22','2026-10-02',297,5,12.24,5,231,3),
('AD24','2026-10-02',1696,13,27.17,9,1491,5),
('AD25','2026-10-02',1593,12,27.17,9,1442,3),
('AD27','2026-10-02',108,7,11.33,6,99,0),
('AD28','2026-10-02',113,5,11.33,4,103,1),
('AD29','2026-10-02',1914,16,22.38,10,1710,4),
('AD30','2026-10-02',1958,20,22.38,12,1803,3),
('AD01','2026-10-03',828,16,19.95,13,691,8),
('AD02','2026-10-03',822,11,19.95,9,725,6),
('AD03','2026-10-03',850,13,19.95,11,751,4),
('AD04','2026-10-03',801,10,19.95,8,653,2),
('AD05','2026-10-03',878,11,19.95,9,734,2),
('AD06','2026-10-03',827,6,19.95,5,709,3),
('AD07','2026-10-03',840,10,19.95,8,708,4),
('AD10','2026-10-03',842,16,23.58,13,691,6),
('AD11','2026-10-03',886,14,23.58,12,745,5),
('AD12','2026-10-03',909,12,23.58,9,757,7),
('AD13','2026-10-03',871,13,23.58,10,751,6),
('AD15','2026-10-03',896,7,23.58,6,739,2),
('AD16','2026-10-03',1542,21,29.19,16,1313,5),
('AD17','2026-10-03',1622,20,29.19,16,1466,5),
('AD19','2026-10-03',1446,28,29.19,22,1265,10),
('AD20','2026-10-03',306,5,12.41,4,206,2),
('AD21','2026-10-03',290,6,12.41,5,203,4),
('AD22','2026-10-03',291,5,12.41,5,195,3),
('AD24','2026-10-03',1654,13,26.38,9,1444,3),
('AD25','2026-10-03',1593,14,26.38,10,1385,3),
('AD27','2026-10-03',102,6,10.4,5,93,1),
('AD28','2026-10-03',103,5,10.4,5,94,0),
('AD29','2026-10-03',2047,18,23.25,12,1702,1),
('AD30','2026-10-03',2100,19,23.25,12,1833,5),
('AD01','2026-10-04',1275,23,31.81,19,1040,8),
('AD02','2026-10-04',799,11,18.87,9,670,4),
('AD03','2026-10-04',1892,29,46.36,24,1583,14),
('AD04','2026-10-04',321,3,7.84,2,262,0),
('AD05','2026-10-04',518,7,12.01,5,422,3),
('AD06','2026-10-04',279,2,6.77,2,220,1),
('AD07','2026-10-04',475,6,12.32,5,368,1),
('AD10','2026-10-04',938,18,26.47,14,699,5),
('AD11','2026-10-04',872,15,22.92,12,714,3),
('AD12','2026-10-04',1198,16,34.33,13,976,3),
('AD13','2026-10-04',923,12,24.08,10,706,6),
('AD15','2026-10-04',172,1,4.65,1,135,0),
('AD16','2026-10-04',1184,15,22.55,12,990,6),
('AD17','2026-10-04',263,3,5.3,2,215,2),
('AD19','2026-10-04',3213,58,63.39,44,2786,17),
('AD20','2026-10-04',354,6,15.45,5,215,3),
('AD21','2026-10-04',399,7,16.17,6,262,4),
('AD22','2026-10-04',212,4,8.79,3,133,1),
('AD24','2026-10-04',1660,13,28.02,9,1453,6),
('AD25','2026-10-04',1434,11,22.11,7,1303,4),
('AD27','2026-10-04',88,6,8.4,5,80,1),
('AD28','2026-10-04',119,6,12.11,5,109,1),
('AD29','2026-10-04',1046,9,11.06,6,830,1),
('AD30','2026-10-04',3397,33,38.68,21,2699,6),
('AD01','2026-10-05',1227,23,30.89,18,934,10),
('AD02','2026-10-05',798,11,19.95,9,592,5),
('AD03','2026-10-05',1905,31,43.67,24,1509,12),
('AD04','2026-10-05',352,4,8.46,3,277,2),
('AD05','2026-10-05',645,8,15.48,6,510,2),
('AD06','2026-10-05',319,2,8.16,2,254,0),
('AD07','2026-10-05',359,4,8.32,3,276,2),
('AD10','2026-10-05',1077,19,29.83,15,786,11),
('AD11','2026-10-05',744,11,20.84,9,553,5),
('AD12','2026-10-05',588,8,16.63,7,447,3),
('AD13','2026-10-05',1235,17,33.81,14,894,7),
('AD15','2026-10-05',351,3,9.64,2,254,1),
('AD16','2026-10-05',1544,20,28.73,15,1179,9),
('AD17','2026-10-05',564,7,10.32,5,453,3),
('AD19','2026-10-05',2916,53,53.69,40,2441,15),
('AD20','2026-10-05',323,6,14.92,5,176,4),
('AD21','2026-10-05',426,8,17.97,7,244,6),
('AD22','2026-10-05',171,3,7.42,3,94,2),
('AD24','2026-10-05',1937,14,31.12,10,1606,8),
('AD25','2026-10-05',1519,12,24.29,8,1294,4),
('AD27','2026-10-05',101,6,10.86,5,92,3),
('AD28','2026-10-05',106,5,10.81,4,97,0),
('AD29','2026-10-05',1140,10,12.33,6,890,3),
('AD30','2026-10-05',3276,29,37.15,18,2614,5),
('AD01','2026-10-06',2061,35,52.66,29,1425,12),
('AD02','2026-10-06',1347,17,34.3,14,986,8),
('AD03','2026-10-06',2456,35,59.8,27,1748,15),
('AD04','2026-10-06',717,8,17.82,6,540,3),
('AD05','2026-10-06',833,9,19.74,7,625,2),
('AD07','2026-10-06',765,9,17.68,7,550,1),
('AD10','2026-10-06',1935,35,51.19,29,1348,17),
('AD11','2026-10-06',1185,19,32.42,15,825,9),
('AD12','2026-10-06',864,10,23.94,8,593,2),
('AD13','2026-10-06',1392,17,40.24,14,998,9),
('AD15','2026-10-06',471,4,12.2,3,327,0),
('AD16','2026-10-06',2401,31,43.84,23,1848,10),
('AD17','2026-10-06',1092,13,19.91,11,836,5),
('AD19','2026-10-06',3002,54,60.59,40,2345,13),
('AD20','2026-10-06',423,6,19.57,5,208,4),
('AD21','2026-10-06',536,9,24.91,8,284,6),
('AD22','2026-10-06',270,4,12.02,3,137,1),
('AD24','2026-10-06',2670,19,45.1,13,2266,8),
('AD25','2026-10-06',1804,15,30.0,10,1510,6),
('AD27','2026-10-06',178,12,18.87,11,163,1),
('AD28','2026-10-06',110,5,11.36,4,101,0),
('AD29','2026-10-06',2302,20,24.23,13,1758,3),
('AD30','2026-10-06',3427,31,39.44,20,2578,13),
('AD01','2026-10-07',2296,42,53.36,33,1593,16),
('AD02','2026-10-07',1755,21,41.75,17,1196,5),
('AD03','2026-10-07',2370,36,61.29,28,1676,17),
('AD04','2026-10-07',964,10,22.73,8,688,1),
('AD05','2026-10-07',686,8,17.34,6,497,1),
('AD07','2026-10-07',409,4,9.95,3,284,1),
('AD10','2026-10-07',2038,31,55.64,25,1307,11),
('AD11','2026-10-07',1372,20,37.25,17,903,6),
('AD12','2026-10-07',464,5,13.61,4,305,0),
('AD13','2026-10-07',1445,18,37.87,15,981,2),
('AD15','2026-10-07',364,3,9.63,2,252,0),
('AD16','2026-10-07',2411,31,45.49,25,1710,12),
('AD17','2026-10-07',1511,19,28.76,15,1127,9),
('AD19','2026-10-07',2532,49,51.97,39,1888,19),
('AD20','2026-10-07',481,6,20.16,5,215,3),
('AD21','2026-10-07',603,10,25.89,9,301,6),
('AD22','2026-10-07',163,2,7.66,2,74,2),
('AD24','2026-10-07',2522,17,42.03,12,2025,4),
('AD25','2026-10-07',2148,17,35.21,12,1687,5),
('AD27','2026-10-07',139,10,14.09,9,127,1),
('AD28','2026-10-07',170,8,16.8,7,156,1),
('AD29','2026-10-07',1839,15,20.32,9,1392,1),
('AD30','2026-10-07',4015,35,45.63,23,2999,10),
('AD01','2026-10-08',319,6,8.21,5,213,2),
('AD02','2026-10-08',161,2,3.73,2,109,2),
('AD03','2026-10-08',353,5,8.55,4,246,3),
('AD04','2026-10-08',45,0,1.1,0,30,0),
('AD05','2026-10-08',56,1,1.32,1,38,1),
('AD07','2026-10-08',57,1,1.49,1,37,0),
('AD08','2026-10-08',4912,84,110.85,70,4857,36),
('AD09','2026-10-08',2783,37,70.52,29,2696,12),
('AD10','2026-10-08',406,6,10.77,5,252,3),
('AD11','2026-10-08',256,4,7.47,3,166,3),
('AD12','2026-10-08',92,1,2.41,1,60,0),
('AD13','2026-10-08',89,1,2.52,1,57,1),
('AD14','2026-10-08',4895,71,131.4,57,4782,29),
('AD15','2026-10-08',93,1,2.55,1,58,1),
('AD16','2026-10-08',414,5,7.74,4,296,0),
('AD17','2026-10-08',325,4,6.21,3,234,2),
('AD18','2026-10-08',5261,70,101.62,56,5046,24),
('AD19','2026-10-08',556,10,10.13,8,392,4),
('AD20','2026-10-08',51,1,2.42,1,21,0),
('AD21','2026-10-08',86,1,3.85,1,38,0),
('AD22','2026-10-08',41,0,1.8,0,17,0),
('AD23','2026-10-08',1141,27,45.56,23,1097,17),
('AD24','2026-10-08',221,2,3.58,1,180,1),
('AD25','2026-10-08',274,2,4.54,1,214,1),
('AD26','2026-10-08',4635,29,69.98,19,4401,8),
('AD27','2026-10-08',152,10,14.99,9,139,2),
('AD28','2026-10-08',148,7,14.41,7,136,1),
('AD29','2026-10-08',97,1,1.12,1,67,0),
('AD30','2026-10-08',484,4,5.43,3,343,1),
('AD31','2026-10-08',5634,42,59.46,26,5315,6),
('AD01','2026-10-09',348,5,8.7,4,211,3),
('AD02','2026-10-09',269,3,7.04,2,172,2),
('AD03','2026-10-09',466,7,11.13,6,304,3),
('AD04','2026-10-09',110,1,2.56,1,73,1),
('AD05','2026-10-09',124,2,2.97,2,82,0),
('AD07','2026-10-09',134,1,3.29,1,85,0),
('AD08','2026-10-09',3148,54,78.71,42,2762,23),
('AD09','2026-10-09',3424,49,78.71,39,3002,15),
('AD10','2026-10-09',496,7,13.36,6,290,3),
('AD11','2026-10-09',431,6,12.34,5,258,4),
('AD12','2026-10-09',169,2,4.94,2,104,1),
('AD13','2026-10-09',172,2,5.09,2,107,2),
('AD14','2026-10-09',4251,62,111.14,49,3761,29),
('AD15','2026-10-09',175,1,5.12,1,111,0),
('AD16','2026-10-09',258,3,5.31,2,176,0),
('AD17','2026-10-09',440,5,8.81,4,310,1),
('AD18','2026-10-09',5808,85,106.08,66,5466,30),
('AD19','2026-10-09',681,13,13.64,10,485,5),
('AD20','2026-10-09',93,1,4.2,1,35,0),
('AD21','2026-10-09',106,2,4.62,2,44,1),
('AD22','2026-10-09',77,1,3.61,1,29,0),
('AD23','2026-10-09',879,20,39.21,17,691,8),
('AD24','2026-10-09',296,2,4.64,1,222,0),
('AD25','2026-10-09',297,2,4.94,1,228,0),
('AD26','2026-10-09',3697,22,62.82,16,3444,7),
('AD27','2026-10-09',172,11,18.15,10,158,1),
('AD28','2026-10-09',125,5,12.31,4,115,1),
('AD29','2026-10-09',217,2,2.41,1,148,0),
('AD30','2026-10-09',468,4,5.32,3,319,0),
('AD31','2026-10-09',5811,46,61.67,30,5207,14),
('AD01','2026-10-10',397,6,10.22,5,235,1),
('AD02','2026-10-10',340,4,8.0,3,218,0),
('AD03','2026-10-10',414,6,10.27,5,263,3),
('AD04','2026-10-10',179,2,4.25,2,115,0),
('AD05','2026-10-10',180,2,4.59,2,115,0),
('AD07','2026-10-10',187,2,4.79,2,117,2),
('AD08','2026-10-10',3211,55,77.6,42,2721,20),
('AD09','2026-10-10',3022,44,77.6,34,2657,8),
('AD10','2026-10-10',421,6,11.53,5,240,1),
('AD11','2026-10-10',509,8,13.73,7,304,5),
('AD12','2026-10-10',209,2,5.79,2,122,1),
('AD13','2026-10-10',277,3,7.7,2,162,1),
('AD14','2026-10-10',4666,70,121.59,59,3866,28),
('AD16','2026-10-10',280,3,5.16,2,181,1),
('AD17','2026-10-10',242,3,4.48,2,164,1),
('AD18','2026-10-10',5360,68,100.68,51,4625,25),
('AD19','2026-10-10',716,13,13.88,10,488,4),
('AD20','2026-10-10',106,1,4.56,1,38,1),
('AD21','2026-10-10',101,2,4.52,2,39,1),
('AD22','2026-10-10',100,1,4.53,1,36,0),
('AD23','2026-10-10',1041,22,42.43,19,752,11),
('AD24','2026-10-10',316,2,5.24,1,238,0),
('AD25','2026-10-10',337,3,5.26,2,257,2),
('AD26','2026-10-10',3830,23,61.84,17,3464,9),
('AD27','2026-10-10',140,10,14.72,9,128,4),
('AD28','2026-10-10',165,7,15.74,6,151,0),
('AD29','2026-10-10',354,3,3.91,2,230,1),
('AD30','2026-10-10',445,4,4.93,2,285,0),
('AD31','2026-10-10',5079,39,58.33,25,4338,9),
('AD01','2026-10-11',695,9,16.82,7,389,4),
('AD02','2026-10-11',836,10,19.46,8,495,5),
('AD03','2026-10-11',1771,26,42.53,20,1054,9),
('AD04','2026-10-11',914,9,21.31,7,537,4),
('AD05','2026-10-11',838,10,21.53,8,516,3),
('AD07','2026-10-11',1280,13,29.73,10,759,6),
('AD08','2026-10-11',1708,25,42.27,19,1373,7),
('AD09','2026-10-11',517,7,13.06,6,414,1),
('AD10','2026-10-11',637,9,18.19,7,337,6),
('AD11','2026-10-11',2233,35,61.17,28,1278,11),
('AD12','2026-10-11',836,10,22.96,8,469,6),
('AD13','2026-10-11',804,9,22.14,7,448,4),
('AD14','2026-10-11',1489,21,40.72,17,1167,10),
('AD16','2026-10-11',1307,15,26.0,12,818,6),
('AD17','2026-10-11',1298,16,25.77,12,837,6),
('AD18','2026-10-11',2111,27,41.32,21,1775,5),
('AD19','2026-10-11',3107,58,60.4,44,2118,18),
('AD20','2026-10-11',297,3,12.77,3,100,2),
('AD21','2026-10-11',283,4,12.78,4,104,3),
('AD22','2026-10-11',292,3,12.79,3,97,2),
('AD23','2026-10-11',410,9,16.66,8,271,7),
('AD24','2026-10-11',1604,12,25.37,8,1153,3),
('AD25','2026-10-11',2332,18,36.13,13,1688,8),
('AD26','2026-10-11',766,5,13.05,4,666,2),
('AD27','2026-10-11',211,15,20.03,13,194,4),
('AD28','2026-10-11',114,5,10.9,4,104,0),
('AD29','2026-10-11',2197,19,24.84,12,1402,5),
('AD30','2026-10-11',2202,20,25.48,13,1405,4),
('AD31','2026-10-11',1404,11,14.64,7,1162,5),
('AD01','2026-10-12',846,11,22.37,9,463,5),
('AD02','2026-10-12',1068,13,25.7,10,638,6),
('AD03','2026-10-12',1546,21,36.55,17,891,8),
('AD04','2026-10-12',985,10,22.79,8,586,3),
('AD05','2026-10-12',747,9,18.61,7,444,4),
('AD07','2026-10-12',1202,13,29.04,11,697,5),
('AD08','2026-10-12',1175,17,29.88,13,890,5),
('AD09','2026-10-12',365,5,8.94,4,283,1),
('AD10','2026-10-12',954,13,27.72,10,498,6),
('AD11','2026-10-12',1515,22,41.98,18,840,11),
('AD12','2026-10-12',1110,14,29.95,11,617,5),
('AD13','2026-10-12',884,11,24.04,9,486,5),
('AD14','2026-10-12',1489,21,42.27,17,1133,6),
('AD16','2026-10-12',1698,18,35.21,14,1022,4),
('AD17','2026-10-12',1897,23,35.18,18,1242,7),
('AD18','2026-10-12',1488,21,27.91,17,1241,4),
('AD19','2026-10-12',3705,69,69.26,52,2399,16),
('AD20','2026-10-12',226,2,9.99,2,72,1),
('AD21','2026-10-12',281,4,13.33,3,97,3),
('AD22','2026-10-12',213,2,9.98,2,68,1),
('AD23','2026-10-12',530,11,21.89,9,307,7),
('AD24','2026-10-12',1280,9,20.3,6,896,2),
('AD25','2026-10-12',2518,21,39.1,15,1788,7),
('AD26','2026-10-12',1068,6,16.64,4,930,2),
('AD27','2026-10-12',224,14,21.67,13,206,3),
('AD28','2026-10-12',99,4,9.77,3,91,1),
('AD29','2026-10-12',2131,17,24.43,11,1284,4),
('AD30','2026-10-12',1795,15,20.96,9,1136,4),
('AD31','2026-10-12',1947,16,21.63,11,1585,3),
('AD01','2026-10-13',1248,16,30.67,13,656,5),
('AD02','2026-10-13',1358,16,34.37,13,743,3),
('AD03','2026-10-13',1744,26,40.75,22,988,14),
('AD04','2026-10-13',838,9,21.71,7,465,4),
('AD05','2026-10-13',1113,12,26.61,10,639,6),
('AD07','2026-10-13',1192,12,30.23,10,680,3),
('AD08','2026-10-13',1308,21,30.05,17,939,7),
('AD09','2026-10-13',481,7,11.42,6,350,2),
('AD10','2026-10-13',1393,16,36.96,14,679,9),
('AD11','2026-10-13',1986,29,53.78,24,1047,15),
('AD12','2026-10-13',1133,13,32.85,11,594,8),
('AD13','2026-10-13',1192,14,32.96,11,642,3),
('AD14','2026-10-13',1289,17,34.67,14,931,8),
('AD16','2026-10-13',1589,17,30.42,13,958,3),
('AD17','2026-10-13',2514,31,46.52,23,1612,10),
('AD18','2026-10-13',1610,20,32.56,16,1210,8),
('AD19','2026-10-13',3691,69,75.57,52,2367,19),
('AD20','2026-10-13',175,2,7.96,2,52,1),
('AD21','2026-10-13',371,5,17.31,4,121,2),
('AD22','2026-10-13',177,2,7.96,2,53,0),
('AD23','2026-10-13',646,14,29.2,13,338,9),
('AD24','2026-10-13',1142,9,19.71,6,816,3),
('AD25','2026-10-13',2595,19,43.88,13,1817,5),
('AD26','2026-10-13',1312,8,20.56,6,1116,2),
('AD27','2026-10-13',312,22,32.9,19,287,7),
('AD29','2026-10-13',2290,18,27.37,12,1392,2),
('AD30','2026-10-13',2593,23,27.69,15,1594,8),
('AD31','2026-10-13',2038,14,22.7,9,1519,4),
('AD01','2026-10-14',1246,14,29.57,12,628,6),
('AD02','2026-10-14',766,9,18.27,7,413,4),
('AD03','2026-10-14',2156,29,55.51,23,1165,10),
('AD04','2026-10-14',985,10,26.1,8,525,4),
('AD05','2026-10-14',1350,14,33.39,11,748,5),
('AD07','2026-10-14',815,9,19.59,7,445,2),
('AD08','2026-10-14',1478,22,36.78,18,1062,7),
('AD09','2026-10-14',714,10,16.5,8,486,4),
('AD10','2026-10-14',1405,18,40.25,14,677,8),
('AD11','2026-10-14',1934,26,55.33,22,995,16),
('AD12','2026-10-14',1357,15,37.23,12,675,7),
('AD13','2026-10-14',628,7,18.39,6,322,3),
('AD14','2026-10-14',1361,19,37.46,15,926,5),
('AD16','2026-10-14',1084,13,22.29,10,642,7),
('AD17','2026-10-14',2635,29,49.22,23,1582,6),
('AD18','2026-10-14',2204,31,41.91,23,1716,11),
('AD19','2026-10-14',3650,68,72.77,54,2268,16),
('AD20','2026-10-14',184,2,8.73,2,51,1),
('AD21','2026-10-14',256,3,12.06,3,78,2),
('AD22','2026-10-14',185,1,8.74,1,52,0),
('AD23','2026-10-14',801,17,33.92,15,384,12),
('AD24','2026-10-14',1664,12,28.63,9,1182,6),
('AD25','2026-10-14',2078,16,36.15,11,1425,7),
('AD26','2026-10-14',1338,8,21.89,6,1101,4),
('AD27','2026-10-14',376,24,36.72,22,345,7),
('AD29','2026-10-14',1220,9,14.45,6,724,2),
('AD30','2026-10-14',3602,32,39.77,21,2090,8),
('AD31','2026-10-14',2421,19,26.69,13,1818,5),
('AD01','2026-10-15',1234,14,32.23,11,596,5),
('AD02','2026-10-15',999,10,24.34,8,513,4),
('AD03','2026-10-15',1743,23,42.27,19,940,9),
('AD04','2026-10-15',1023,10,24.99,8,549,1),
('AD05','2026-10-15',1118,12,28.18,10,602,5),
('AD07','2026-10-15',681,7,15.92,6,363,4),
('AD08','2026-10-15',1447,24,35.28,18,967,12),
('AD09','2026-10-15',905,11,23.64,9,598,5),
('AD10','2026-10-15',1397,15,38.28,12,639,4),
('AD11','2026-10-15',2177,29,58.8,25,1077,14),
('AD12','2026-10-15',1323,15,35.25,12,651,4),
('AD13','2026-10-15',723,8,20.9,6,358,3),
('AD14','2026-10-15',973,12,27.49,10,641,6),
('AD16','2026-10-15',1757,19,33.21,15,972,4),
('AD17','2026-10-15',1541,18,31.95,14,913,5),
('AD18','2026-10-15',2698,35,49.0,28,1909,8),
('AD19','2026-10-15',3343,60,61.85,45,2034,12),
('AD20','2026-10-15',169,2,7.48,2,45,2),
('AD21','2026-10-15',255,3,11.56,3,76,1),
('AD22','2026-10-15',162,1,7.47,1,43,0),
('AD23','2026-10-15',834,16,34.81,14,383,9),
('AD24','2026-10-15',1793,13,29.82,9,1243,5),
('AD25','2026-10-15',2016,15,33.51,10,1322,4),
('AD26','2026-10-15',1395,9,23.13,6,1074,1),
('AD27','2026-10-15',360,23,37.13,21,331,6),
('AD29','2026-10-15',1399,11,15.49,7,793,3),
('AD30','2026-10-15',3347,25,36.34,16,1895,3),
('AD31','2026-10-15',2466,19,27.29,12,1766,5),
('AD01','2026-10-16',1141,14,28.13,11,555,4),
('AD02','2026-10-16',952,11,24.86,8,495,3),
('AD03','2026-10-16',1642,23,40.84,18,834,9),
('AD04','2026-10-16',270,3,6.98,2,138,1),
('AD05','2026-10-16',1090,12,28.51,9,553,5),
('AD07','2026-10-16',878,9,23.05,7,439,3),
('AD08','2026-10-16',1942,31,47.05,25,1225,14),
('AD09','2026-10-16',1140,15,28.24,12,725,4),
('AD10','2026-10-16',876,8,25.76,7,382,6),
('AD11','2026-10-16',2326,31,61.66,26,1079,12),
('AD12','2026-10-16',900,10,26.7,8,417,5),
('AD13','2026-10-16',852,9,24.05,8,402,2),
('AD14','2026-10-16',1279,15,36.59,12,796,8),
('AD16','2026-10-16',1790,19,33.14,15,999,4),
('AD17','2026-10-16',2125,24,39.05,18,1232,9),
('AD18','2026-10-16',2596,32,51.19,25,1856,8),
('AD19','2026-10-16',3562,57,65.92,46,2011,20),
('AD20','2026-10-16',264,3,11.67,3,66,0),
('AD21','2026-10-16',168,2,7.51,2,46,0),
('AD22','2026-10-16',185,2,8.29,2,47,1),
('AD23','2026-10-16',674,12,31.47,10,285,7),
('AD24','2026-10-16',2398,18,37.93,13,1598,9),
('AD25','2026-10-16',2007,15,31.99,10,1288,2),
('AD26','2026-10-16',681,4,10.65,3,525,1),
('AD27','2026-10-16',385,26,36.49,23,354,6),
('AD29','2026-10-16',1905,14,22.74,9,1055,2),
('AD30','2026-10-16',1613,13,19.27,8,869,4),
('AD31','2026-10-16',2956,22,32.03,14,2061,3);
create temp table _lfa_org (data date, ig int, email int) on commit drop;
insert into _lfa_org values
('2026-10-01',15,118),
('2026-10-02',15,41),
('2026-10-03',15,4),
('2026-10-04',21,3),
('2026-10-05',19,2),
('2026-10-06',55,6),
('2026-10-07',18,5),
('2026-10-08',28,86),
('2026-10-09',20,27),
('2026-10-10',27,3),
('2026-10-11',24,4),
('2026-10-12',29,5),
('2026-10-13',60,5),
('2026-10-14',31,3),
('2026-10-15',36,64),
('2026-10-16',36,22);
-- ===== Parte 1: a escola (histórico de julho a 16/10/2026) =====
do $$
declare
  ws uuid; uid uuid; banco uuid; hot uuid; cc_prod uuid; cc_meta uuid; cc_goo uuid; cc_ger uuid;
  p_curso uuid; p_ment uuid; p_ebook uuid; c_perp uuid; c_lanc uuid; cn_meta uuid; cn_goo uuid; a uuid[] := '{}'; ag uuid;
  pe uuid; v uuid; ct uuid; d date; i int; k int; n int; dia date; custo numeric; fp text; forma text[] := array['pix','pix','cartao_credito','cartao_credito','cartao_credito','boleto'];
  nomes text[] := array['Ana','Bruno','Carla','Diego','Elisa','Fábio','Gabi','Heitor','Iara','João','Karen','Lucas','Marina','Nina','Otávio','Paula','Rafa','Sofia','Téo','Vera'];
  sob text[] := array['Silva','Souza','Lima','Costa','Rocha','Alves','Melo','Dias','Pires','Reis'];
  pc_meta uuid; pc_goo uuid; pc_pl uuid; pc_eq uuid; pc_fe uuid; seed float := 0.42;
begin
  perform setseed(seed);
  select id into uid from auth.users where email = 'rebecka@rebeckacappello.com.br';
  ws := provisionar_workspace('Escola Aurora');
  insert into workspace_membros (workspace_id, user_id, papel) values (ws, uid, 'admin') on conflict do nothing;
  -- o lançamento usa estes ids
  create temp table _lfa_ids (k text primary key, id uuid) on commit drop;
  insert into empresa (workspace_id, nome, regime_tributario) values (ws, 'Escola Aurora', 'simples_nacional') on conflict (workspace_id) do update set regime_tributario = 'simples_nacional';
  if exists (select 1 from information_schema.columns where table_name = 'empresa' and column_name = 'anexo_simples') then
    execute 'update empresa set anexo_simples = ''III'' where workspace_id = $1' using ws;
  end if;
  update empresa set razao_social = 'Escola Aurora de Idiomas Ltda (fictícia)', email_contato = 'contato@escolaaurora.test', regime_apuracao = 'competencia' where workspace_id = ws;
  select id into cc_prod from centros_custo where workspace_id = ws and codigo = 'PRODUTO';
  select id into cc_meta from centros_custo where workspace_id = ws and codigo = 'META';
  select id into cc_goo from centros_custo where workspace_id = ws and codigo = 'GOOGLE';
  select id into cc_ger from centros_custo where workspace_id = ws and codigo = 'GERAL';
  select id into pc_meta from plano_contas where workspace_id = ws and codigo = '6.1.02';
  select id into pc_goo from plano_contas where workspace_id = ws and codigo = '6.1.01';
  select id into pc_pl from plano_contas where workspace_id = ws and codigo = '6.2.04';
  select id into pc_eq from plano_contas where workspace_id = ws and codigo = '6.2.02';
  select id into pc_fe from plano_contas where workspace_id = ws and codigo = '6.2.01';
  insert into impostos_config (workspace_id, nome, aliquota_percentual, base) values (ws, 'Simples Nacional (estimado)', 8, 'valor_bruto');
  insert into contas_bancarias (workspace_id, nome, banco, saldo_inicial, conta_contabil_id, padrao)
  values (ws, 'Conta principal', 'Banco Aurora', 140000, (select id from plano_contas where workspace_id = ws and codigo = '1.1.01'), true) returning id into banco;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hotmart', 9.9, 1.00) returning id into hot;
  insert into plataforma_formas_pagamento (workspace_id, plataforma_id, forma_pagamento, prazo_recebimento_dias) values (ws, hot, 'pix', 0), (ws, hot, 'cartao_credito', 30), (ws, hot, 'boleto', 3);
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id, extras) values (ws, 'Curso Inglês Base', 'curso-ingles-base', 'curso', false, 997, cc_prod, '{"mc_custo_pct": 10}') returning id into p_curso;
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id, extras) values (ws, 'Mentoria de Conversação', 'mentoria-conversacao', 'servico', false, 3000, cc_prod, '{"mc_custo_pct": 25, "mc_custo_cliente": 150}') returning id into p_ment;
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id) values (ws, 'E-book 500 frases', 'ebook-500-frases', 'digital', false, 47, cc_prod) returning id into p_ebook;
  insert into produto_plataforma (workspace_id, produto_id, plataforma_id, id_externo) values (ws, p_curso, hot, 'AUR-CURSO'), (ws, p_ebook, hot, 'AUR-EBOOK');
  insert into campanhas (workspace_id, nome, status, modelo, data_inicio, produto_id, meta_leads_mes, meta_cac)
  values (ws, 'Perpétuo Curso Inglês Base', 'ativa', 'perpetuo', '2026-07-01', p_curso, 400, 220) returning id into c_perp;
  insert into campanhas (workspace_id, nome, status, modelo, data_inicio, data_fim, produto_id, orcamento_total, meta_leads, meta_vendas, meta_receita, meta_cac)
  values (ws, 'Lançamento Inglês Base · Set/26', 'finalizada', 'lancamento', '2026-09-01', '2026-09-30', p_curso, 21000, 700, 45, 44865, 300) returning id into c_lanc;
  update campanhas set data_carrinho_abre = '2026-09-21', data_carrinho_fecha = '2026-09-27' where id = c_lanc;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento) values (ws, c_perp, 'meta_ads', 'perpetuo-meta', 36000) returning id into cn_meta;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento) values (ws, c_lanc, 'google_ads', 'lanc-set-google', 21000) returning id into cn_goo;
  for k in 1..3 loop
    insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, ativo, angulo) values (ws, cn_meta, (array['Perpétuo · Dor da trava','Perpétuo · Prova social','Perpétuo · Oferta do curso'])[k], 'criativo-' || k, true, (array['dor','prova','oferta'])[k]) returning id into ag; a := a || ag;
  end loop;
  insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, ativo, angulo) values (ws, cn_goo, 'Pesquisa · curso de inglês', 'busca-1', true, 'oferta') returning id into ag;

  -- anúncios: custo e métricas por dia (perpétuo jul–out; lançamento só em setembro)
  for dia in select generate_series('2026-07-01'::date, '2026-10-16'::date, '1 day')::date loop
    for k in 1..3 loop
      custo := round((90 + k * 15 + random() * 30)::numeric, 2);
      insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina, alcance, origem)
      values (ws, a[k], dia, (custo * 95)::int, (custo * 95 * (0.012 - k * 0.0015 - (dia - '2026-07-01'::date) * 0.00002))::int, custo, ((custo * 95 * (0.012 - k * 0.0015 - (dia - '2026-07-01'::date) * 0.00002)) * 0.82)::int, (custo * 95 / (1.2 + (dia - '2026-07-01'::date) * 0.012))::int, 'integracao');
    end loop;
    if dia between '2026-09-01' and '2026-09-30' then
      custo := round((620 + random() * 160)::numeric, 2);
      insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina, alcance, origem)
      values (ws, ag, dia, (custo * 40)::int, (custo * 40 * 0.05)::int, custo, (custo * 40 * 0.05 * 0.86)::int, (custo * 32)::int, 'integracao');
    end if;
  end loop;

  -- leads e vendas do perpétuo (Meta): ~12 leads por dia, 4,5% compram em até 7 dias; 30% levam o e-book
  n := 0;
  for dia in select generate_series('2026-07-01'::date, '2026-10-16'::date, '1 day')::date loop
    for i in 1..(9 + (random() * 6)::int) loop
      n := n + 1;
      insert into pessoas (workspace_id, nome, email, utm_source, utm_medium, utm_campaign, utm_content, criado_em)
      values (ws, nomes[1 + n % 20] || ' ' || sob[1 + (n / 20) % 10], lower(nomes[1 + n % 20]) || '.' || lower(sob[1 + (n / 20) % 10]) || n || '@email.test', 'facebook', 'cpc', 'perpetuo-meta', 'criativo-' || (1 + n % 3), dia + time '09:00' + (i * interval '37 minutes'))
      returning id into pe;
      if random() < 0.045 and dia <= '2026-10-13' then
        fp := forma[1 + (random() * 5)::int];
        insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, campanha_id, forma_pagamento, valor_bruto, data_venda, id_externo, pedido_ref, utm_campaign, utm_content)
        values (ws, pe, p_curso, hot, c_perp, fp, 997, dia + (1 + (random() * 3)::int) + time '20:00', 'P-' || n, 'PED-' || n, 'perpetuo-meta', 'criativo-' || (1 + n % 3));
        if random() < 0.3 then
          insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, campanha_id, forma_pagamento, valor_bruto, data_venda, id_externo, pedido_ref)
          values (ws, pe, p_ebook, hot, c_perp, fp, 47, dia + (1 + (random() * 3)::int) + time '20:01', 'E-' || n, 'PED-' || n);
        end if;
      end if;
    end loop;
  end loop;
  -- lançamento de setembro (Google): 700 leads de 1 a 20/09, carrinho de 21 a 27/09, 6% compram
  for i in 1..700 loop
    n := n + 1; d := '2026-09-01'::date + (i % 20);
    insert into pessoas (workspace_id, nome, email, utm_source, utm_medium, utm_campaign, utm_content, criado_em)
    values (ws, nomes[1 + n % 20] || ' ' || sob[1 + (n / 20) % 10], lower(nomes[1 + n % 20]) || '.' || lower(sob[1 + (n / 20) % 10]) || n || '@email.test', 'google', 'cpc', 'lanc-set-google', 'busca-1', d + time '10:00' + (i % 9) * interval '1 hour')
    returning id into pe;
    if random() < 0.06 then
      insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, campanha_id, forma_pagamento, valor_bruto, data_venda, id_externo, pedido_ref, utm_campaign)
      values (ws, pe, p_curso, hot, c_lanc, forma[1 + (random() * 5)::int], 997, '2026-09-21'::date + (i % 7) + time '19:00', 'L-' || n, 'PEDL-' || n, 'lanc-set-google');
    end if;
  end loop;

  -- recebe o que já venceu; 4 reembolsos de vendas do curso
  perform registrar_recebimentos_ate(ws, '2026-10-16');
  for v in select id from vendas where workspace_id = ws and produto_id = p_curso and data_venda < '2026-10-01' order by data_venda limit 4 loop
    perform registrar_estorno(v, 'reembolso', 'Pediu reembolso na garantia de 7 dias', (select (data_venda + interval '5 days')::date from vendas where id = v));
  end loop;

  -- mentoria: 14 alunos do curso fecham contrato de 3 parcelas de R$ 1.000 (ago a out); parcelas vencidas são recebidas
  k := 0;
  for pe, d in select distinct on (v2.pessoa_id) v2.pessoa_id, (v2.data_venda + interval '20 days')::date from vendas v2
               where v2.workspace_id = ws and v2.produto_id = p_curso and v2.status = 'aprovada' and v2.data_venda between '2026-07-05' and '2026-09-20' order by v2.pessoa_id, v2.data_venda limit 14 loop
    k := k + 1;
    insert into contratos (workspace_id, pessoa_id, campanha_id, status, data_inicio, num_parcelas, primeiro_vencimento, conta_bancaria_id, forma_pagamento)
    values (ws, pe, null, 'rascunho', d, 3, d, banco, 'pix') returning id into ct;
    insert into contrato_itens (workspace_id, contrato_id, produto_id, quantidade, valor) values (ws, ct, p_ment, 1, 3000);
    perform ativar_contrato(ct);
  end loop;
  for v in select id from contas_receber where workspace_id = ws and contrato_id is not null and status = 'previsto' and vencimento <= '2026-10-16' loop
    perform registrar_recebimento(v, (select vencimento from contas_receber where id = v), banco);
  end loop;

  -- despesas: pró-labore, equipe, ferramentas (recorrentes) e as faturas de mídia (= soma do custo dos anúncios no mês)
  for d in select generate_series('2026-07-01'::date, '2026-10-01'::date, '1 month')::date loop
    insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id) values
      (ws, 'Pró-labore — ' || to_char(d, 'MM/YYYY'), 18000, d, d + 4, pc_pl, cc_ger),
      (ws, 'Equipe (editor e social media) — ' || to_char(d, 'MM/YYYY'), 9500, d, d + 9, pc_eq, cc_ger),
      (ws, 'Ferramentas — ' || to_char(d, 'MM/YYYY'), 2200, d, d + 14, pc_fe, cc_ger);
    insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id)
    select ws, 'Meta Ads — ' || to_char(d, 'MM/YYYY'), sum(m.custo), d, (d + interval '1 month')::date + 9, pc_meta, cc_meta, c_perp
      from metricas_anuncio_dia m where m.workspace_id = ws and m.anuncio_id = any(a) and date_trunc('month', m.data) = d having sum(m.custo) > 0;
    insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id)
    select ws, 'Google Ads — ' || to_char(d, 'MM/YYYY'), sum(m.custo), d, (d + interval '1 month')::date + 9, pc_goo, cc_goo, c_lanc
      from metricas_anuncio_dia m where m.workspace_id = ws and m.anuncio_id = ag and date_trunc('month', m.data) = d having sum(m.custo) > 0;
  end loop;
  for v in select id from contas_pagar where workspace_id = ws and vencimento <= '2026-10-16' and status = 'previsto' loop
    perform registrar_pagamento(v, (select vencimento from contas_pagar where id = v), banco);
  end loop;
  insert into _lfa_ids values ('ws', ws), ('uid', uid), ('banco', banco), ('hot', hot), ('cc_prod', cc_prod), ('cc_meta', cc_meta), ('cc_goo', cc_goo), ('p_curso', p_curso), ('p_ment', p_ment), ('p_ebook', p_ebook);
end $$;

-- ===== Parte 2: Lançamento "Formação Fluência · Semana da Fluência" (captação em andamento) =====
create function pg_temp._blk(p_ws uuid, p_funil uuid, p_tipo text, p_nome text, p_ordem int, p_n int) returns void language plpgsql as $f$
declare bid uuid := gen_random_uuid(); fase_ text; m record; j int := 0;
begin
  fase_ := case p_tipo when 'grupo' then 'aquecimento' when 'aula' then 'aquecimento' when 'checkout' then 'conversao' else 'aquisicao' end;
  insert into estrategia_blocos (id, workspace_id, funil_id, ordem, fase, tipo, nome, origem_ref) values (bid, p_ws, p_funil, p_ordem, fase_, p_tipo, p_nome, null);
  -- mesmas métricas do catálogo de blocos do Growths (EST_BLOCOS)
  for m in select * from (values
    ('trafego', 'cliques', 'Cliques no link', 'principal', 'anuncios', 'cliques', 'numero', null, 'Anúncios (importação)'),
    ('trafego', 'investimento', 'Investimento', 'diagnostico', 'anuncios', 'investimento', 'brl', 'investimento', 'Anúncios (importação)'),
    ('trafego', 'impressoes', 'Impressões', 'diagnostico', 'anuncios', 'impressoes', 'numero', null, 'Anúncios (importação)'),
    ('trafego', 'visitas', 'Visitas à página', 'diagnostico', 'anuncios', 'visitas', 'numero', null, 'Anúncios (importação)'),
    ('captura', 'leads', 'Leads', 'principal', 'leads', null, 'numero', null, 'Growths (leads da campanha)'),
    ('captura', 'visitas_pagina', 'Visitas à página', 'diagnostico', 'manual', null, 'numero', null, 'Analytics'),
    ('grupo', 'entradas', 'Entradas no grupo', 'principal', 'lista', null, 'numero', null, 'Growths (lista) / Sendflow'),
    ('grupo', 'saidas', 'Saídas do grupo', 'diagnostico', 'manual', null, 'numero', null, 'Sendflow'),
    ('grupo', 'cliques_links', 'Cliques nos links enviados', 'diagnostico', 'manual', null, 'numero', null, 'Sendflow'),
    ('aula', 'presentes', 'Presentes', 'principal', 'video', 'presentes', 'numero', null, 'Growths (presenças)'),
    ('aula', 'pico', 'Pico simultâneo', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma da transmissão'),
    ('aula', 'tempo_medio', 'Tempo médio assistido (min)', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma da transmissão'),
    ('aula', 'ate_oferta', 'Ficaram até a oferta', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma da transmissão'),
    ('aula', 'cliques_oferta', 'Cliques no link da oferta', 'diagnostico', 'manual', null, 'numero', null, 'Growths (UTM)'),
    ('checkout', 'vendas', 'Vendas aprovadas', 'principal', 'vendas', 'clientes', 'numero', 'clientes_novos', 'Growths (vendas)'),
    ('checkout', 'receita', 'Receita', 'diagnostico', 'vendas', 'receita', 'brl', 'receita', 'Growths (vendas)'),
    ('checkout', 'checkouts', 'Checkouts iniciados', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma de venda'),
    ('checkout', 'abandonos', 'Abandonos', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma de venda')
  ) x(tipo, k, nome, papel, origem, metrica, un, conta, fonte) where x.tipo = p_tipo loop
    insert into estrategia_etapas (workspace_id, funil_id, bloco_id, papel, fonte, ordem, fase, chave, nome, unidade, origem, metrica, origem_ref, conta_como, taxa_esperada)
    values (p_ws, p_funil, bid, m.papel, m.fonte, p_ordem * 10 + j, fase_, p_tipo || p_n || '_' || m.k, p_nome || ' · ' || m.nome, m.un, m.origem, m.metrica, null, m.conta, null);
    j := j + 1;
  end loop;
end $f$;

do $$
declare
  ws uuid := (select id from _lfa_ids where k = 'ws'); hot uuid := (select id from _lfa_ids where k = 'hot');
  cc_prod uuid := (select id from _lfa_ids where k = 'cc_prod'); cc_meta uuid := (select id from _lfa_ids where k = 'cc_meta'); cc_goo uuid := (select id from _lfa_ids where k = 'cc_goo');
  p_ment uuid := (select id from _lfa_ids where k = 'p_ment');
  p_form uuid; p_kit uuid; fn uuid; lista uuid; c uuid; cc_tt uuid; pc_tt uuid; r record; x record; a record; i int; n int := 0; pid uuid; em timestamptz;
  nomes text[] := array['Ana','Beatriz','Camila','Daniela','Eduarda','Fernanda','Gabriela','Helena','Isabela','Juliana','Larissa','Mariana','Natália','Patrícia','Renata','Sabrina','Tatiane','Vanessa','Aline','Bianca',
                        'André','Bruno','Caio','Diego','Eduardo','Felipe','Gustavo','Henrique','Igor','João','Leonardo','Marcelo','Matheus','Pedro','Rafael','Rodrigo','Thiago','Vinícius','Lucas','Gabriel'];
  sob text[] := array['Silva','Santos','Oliveira','Souza','Rodrigues','Ferreira','Alves','Pereira','Lima','Gomes','Costa','Ribeiro','Martins','Carvalho','Almeida','Lopes','Soares','Fernandes','Vieira','Barbosa',
                      'Rocha','Dias','Nascimento','Andrade','Moreira','Nunes','Marques','Machado','Mendes','Freitas'];
  ddd int[] := array[11,11,11,21,21,31,35,41,47,51,61,62,71,81,85,19,27,48];
begin
  perform setseed(0.7);
  -- produtos e plataforma
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id, extras) values (ws, 'Formação Fluência Aurora', 'formacao-fluencia', 'curso', false, 1997, cc_prod, '{"mc_custo_pct": 12}') returning id into p_form;
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id) values (ws, 'Kit de Conversação (order bump)', 'kit-conversacao', 'digital', false, 67, cc_prod) returning id into p_kit;
  insert into produto_plataforma (workspace_id, produto_id, plataforma_id, id_externo) values (ws, p_form, hot, 'AUR-FLUENCIA'), (ws, p_kit, hot, 'AUR-KIT');
  -- TikTok Ads: conta de mídia (6.1.03) e centro de custo, como os de Meta e Google
  insert into plano_contas select (jsonb_populate_record(null::plano_contas, to_jsonb(pc) || jsonb_build_object('id', gen_random_uuid(), 'codigo', '6.1.03', 'nome', 'Mídia paga – TikTok Ads'))).*
    from plano_contas pc where pc.workspace_id = ws and pc.codigo = '6.1.02' returning id into pc_tt;
  insert into centros_custo select (jsonb_populate_record(null::centros_custo, to_jsonb(cc) || jsonb_build_object('id', gen_random_uuid(), 'codigo', 'TIKTOK', 'nome', 'Aquisição – TikTok Ads'))).*
    from centros_custo cc where cc.id = cc_meta returning id into cc_tt;

  -- estratégia "Lançamento clássico" com os blocos do modelo pronto (tráfego, captura, grupo, 3 aulas, checkout)
  insert into funis (workspace_id, nome, tipo, produto_id, descricao, modelo_pronto, ativo)
  values (ws, 'Lançamento clássico · Semana da Fluência', 'lancamento', p_form, 'Captação paga e orgânica para o grupo VIP, 3 aulas ao vivo e carrinho de 7 dias.', 'lancamento', true) returning id into fn;
  perform pg_temp._blk(ws, fn, 'trafego', 'Tráfego pago', 10, 1);
  perform pg_temp._blk(ws, fn, 'captura', 'Página de captura', 20, 1);
  perform pg_temp._blk(ws, fn, 'grupo', 'Grupo de WhatsApp', 130, 1);
  perform pg_temp._blk(ws, fn, 'aula', 'Aula 1', 140, 1);
  perform pg_temp._blk(ws, fn, 'aula', 'Aula 2', 150, 2);
  perform pg_temp._blk(ws, fn, 'aula', 'Aula 3', 160, 3);
  perform pg_temp._blk(ws, fn, 'checkout', 'Checkout', 270, 1);
  insert into funil_listas (workspace_id, funil_id, nome, tipo) values (ws, fn, 'Grupo VIP · Semana da Fluência', 'grupo') returning id into lista;

  -- campanha
  insert into campanhas (workspace_id, nome, status, modelo, tipo_midia, data_inicio, data_fim, data_carrinho_abre, data_carrinho_fecha, produto_id, orcamento_total,
                         meta_leads, meta_vendas, meta_receita, meta_cac, meta_cpl, meta_taxa_lead_venda, projeto_auto, fases, observacoes)
  values (ws, 'Lançamento Formação Fluência · Nov/26', 'ativa', 'lancamento', 'hibrida', '2026-10-01', '2026-11-15', '2026-11-03', '2026-11-09', p_form, 20000,
          5000, 75, 150000, 270, 4.00, 1.5, false,
          '{"aquisicao": {"ini": "2026-10-01", "fim": "2026-10-26"}, "aquecimento": {"ini": "2026-10-27", "fim": "2026-11-02"}, "conversao": {"ini": "2026-11-03", "fim": "2026-11-09"}}',
          'Lançamento clássico. Captação de 01 a 26/10 com R$ 20 mil em tráfego (Meta 75%, Google 15%, TikTok 10%) + Instagram orgânico e e-mail para a base. '
          || 'Semana da Fluência: aulas ao vivo em 27, 29 e 31/10, às 20h, no YouTube. Carrinho de 03 a 09/11: Formação Fluência a R$ 1.997 (12x), order bump Kit de Conversação (R$ 67) e upsell da Mentoria. '
          || 'Meta: 5.000 leads (CPL pago de R$ 4,84), 75 vendas (1,5% dos leads), R$ 150 mil, CAC de mídia até R$ 270.')
  returning id into c;
  perform campanha_aplicar_estrategia(c, fn, false);
  insert into campanha_estrategias (workspace_id, campanha_id, funil_id, principal) values (ws, c, fn, true) on conflict do nothing;
  update campanha_blocos set origem_ref = lista where campanha_id = c and tipo = 'grupo';
  update campanha_etapas set origem_ref = lista where campanha_id = c and chave = 'grupo1_entradas';
  -- taxas esperadas entre as etapas principais (sobre a etapa anterior)
  update campanha_etapas e set taxa_esperada = t.v from (values ('captura1_leads', 0.33), ('grupo1_entradas', 0.66), ('aula1_presentes', 0.40), ('aula2_presentes', 0.72), ('aula3_presentes', 0.85), ('checkout1_vendas', 0.08)) t(k, v)
   where e.campanha_id = c and e.chave = t.k;
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco, ordem, taxa_exposicao, taxa_aceite) values
    (ws, c, p_form, 'Formação Fluência Aurora (12x de R$ 199,70)', 'principal', 1997, 1, null, null),
    (ws, c, p_kit, 'Kit de Conversação', 'order_bump', 67, 2, 1, 0.30),
    (ws, c, p_ment, 'Mentoria de Conversação (upsell)', 'upsell', 3000, 3, 1, 0.06);

  -- campanhas de anúncio (canal) com metas; orgânicos sem verba
  for r in select * from _lfa_camp loop
    insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento, meta_leads, meta_vendas, meta_cac, meta_cpl, temperatura, tipo, funil_id, observacoes)
    values (ws, c, r.canal, r.utm, r.orc, r.meta, r.vendas, round(r.orc / r.vendas, 2), round(r.orc / r.meta, 2), r.temp, 'pago', fn,
            r.nome || case r.k when 'int' then ' · público: interesse em inglês, intercâmbio, carreira (25–45)' when 'lal' then ' · público: semelhante 1–3% de alunos e compradores'
              when 'adv' then ' · público aberto, otimização por lead' when 'rmk' then ' · público: visitantes da página, engajados no Instagram e vídeo 50% (30 dias)'
              when 'yt' then ' · in-stream pulável, palavras-chave e afinidade' when 'src' then ' · termos: curso de inglês online, inglês para adultos' else ' · Spark Ads com vídeos da professora' end);
  end loop;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento, meta_leads, meta_vendas, temperatura, tipo, funil_id, observacoes) values
    (ws, c, 'organico', 'lfa26-instagram-organico', null, 450, 6, 'quente', 'organico', fn, 'Instagram orgânico · link da bio, stories e 2 lives por semana'),
    (ws, c, 'email', 'lfa26-email-base', null, 420, 6, 'quente', 'organico', fn, 'E-mail para a base de alunos e leads · 1 envio por semana');
  -- nome do canal: o utm_campaign identifica; o nome legível fica nas observações. Anúncios:
  for a in select d.*, cc.id ccid, k.temp, k.canal from _lfa_ad d join _lfa_camp k on k.k = d.camp join campanha_canais cc on cc.utm_campaign = k.utm and cc.workspace_id = ws order by d.cod loop
    insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, imagem_url, id_externo, ativo, angulo, temperatura)
    values (ws, a.ccid, a.nome, a.utm_content, a.img, case a.canal when 'meta_ads' then '1202' when 'google_ads' then '7001' else '7389' end || lpad((random() * 1e8)::bigint::text, 9, '0'),
            a.fim is null, a.angulo, a.temp);
    insert into campanha_links (workspace_id, campanha_canal_id, nome, url_destino, utm_source, utm_medium, utm_content, angulo, anuncio_id)
    values (ws, a.ccid, a.nome, 'https://escolaaurora.test/semana-da-fluencia', case a.canal when 'meta_ads' then 'facebook' when 'google_ads' then 'google' else 'tiktok' end,
            case a.canal when 'google_ads' then 'cpc' else 'paid_social' end, a.utm_content, a.angulo, (select id from anuncios where campanha_canal_id = a.ccid and utm_content = a.utm_content));
  end loop;

  -- métricas diárias dos anúncios (como vindas da integração com Meta, Google e TikTok, 01 a 16/10)
  insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina, alcance, origem)
  select ws, an.id, m.data, m.imp, m.cli, m.custo, m.vis, m.alc, 'integracao'
    from _lfa_dia m join _lfa_ad d on d.cod = m.cod join _lfa_camp k on k.k = d.camp join campanha_canais cc on cc.utm_campaign = k.utm and cc.workspace_id = ws
    join anuncios an on an.campanha_canal_id = cc.id and an.utm_content = d.utm_content;

  -- leads dos anúncios: pessoa nova entra pelo cadastro; 5% já estavam na base e entram por um toque de captura (como registrar_captura faz)
  for x in select m.data, m.leads, d.utm_content, k.utm, k.canal from _lfa_dia m join _lfa_ad d on d.cod = m.cod join _lfa_camp k on k.k = d.camp where m.leads > 0 order by m.data, d.cod loop
    for i in 1..x.leads loop
      em := x.data + time '07:00' + (power(random(), 0.75) * interval '16 hours 50 minutes');
      if random() < 0.05 then
        select p.id into pid from pessoas p where p.workspace_id = ws and p.criado_em < '2026-10-01' and not exists (select 1 from campanha_participacoes cp where cp.campanha_id = c and cp.pessoa_id = p.id) order by random() limit 1;
        insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
        values (ws, pid, em, 'captura', x.canal, c, 'Cadastro na campanha', case x.canal when 'meta_ads' then 'facebook' when 'google_ads' then 'google' else 'tiktok' end,
                case x.canal when 'google_ads' then 'cpc' else 'paid_social' end, x.utm, x.utm_content, 'captura', 'captura', gen_random_uuid());
      else
        n := n + 1;
        insert into pessoas (workspace_id, nome, email, telefone, status_funil, utm_source, utm_medium, utm_campaign, utm_content, canal_origem, campanha_id, criado_em)
        values (ws, nomes[1 + (random() * 39)::int] || ' ' || sob[1 + (random() * 29)::int], 'fluencia' || n || '@email.test',
                '(' || ddd[1 + (random() * 17)::int] || ') 9' || lpad((70000000 + n * 7)::text, 8, '0'), 'lead',
                case x.canal when 'meta_ads' then (array['facebook','instagram'])[1 + (random() < 0.62)::int] when 'google_ads' then 'google' else 'tiktok' end,
                case x.canal when 'google_ads' then 'cpc' else 'paid_social' end, x.utm, x.utm_content, x.canal, c, em);
      end if;
    end loop;
  end loop;
  -- orgânicos: Instagram (85% pessoas novas) e e-mail para a base (80% já estavam na base)
  for x in select * from _lfa_org order by data loop
    for i in 1..(x.ig + x.email) loop
      em := x.data + time '08:00' + (random() * interval '15 hours');
      if (i <= x.ig and random() < 0.15) or (i > x.ig and random() < 0.80) then
        select p.id into pid from pessoas p where p.workspace_id = ws and p.criado_em < '2026-10-01' and not exists (select 1 from campanha_participacoes cp where cp.campanha_id = c and cp.pessoa_id = p.id) order by random() limit 1;
        insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
        values (ws, pid, em, 'captura', case when i <= x.ig then 'organico' else 'email' end, c, 'Cadastro na campanha', case when i <= x.ig then 'instagram' else 'email' end,
                case when i <= x.ig then 'organic' else 'email' end, case when i <= x.ig then 'lfa26-instagram-organico' else 'lfa26-email-base' end,
                case when i > x.ig then 'email-' || to_char(x.data - ((extract(isodow from x.data)::int + 3) % 7), 'DDMM') when x.data in ('2026-10-06', '2026-10-13') and random() < 0.6 then 'live' when random() < 0.55 then 'bio' else 'stories' end,
                'captura', 'captura', gen_random_uuid());
      else
        n := n + 1;
        insert into pessoas (workspace_id, nome, email, telefone, status_funil, utm_source, utm_medium, utm_campaign, utm_content, canal_origem, campanha_id, criado_em)
        values (ws, nomes[1 + (random() * 39)::int] || ' ' || sob[1 + (random() * 29)::int], 'fluencia' || n || '@email.test',
                '(' || ddd[1 + (random() * 17)::int] || ') 9' || lpad((70000000 + n * 7)::text, 8, '0'), 'lead',
                case when i <= x.ig then 'instagram' else 'email' end, case when i <= x.ig then 'organic' else 'email' end,
                case when i <= x.ig then 'lfa26-instagram-organico' else 'lfa26-email-base' end,
                case when i > x.ig then 'email-' || to_char(x.data - ((extract(isodow from x.data)::int + 3) % 7), 'DDMM') when x.data in ('2026-10-06', '2026-10-13') and random() < 0.6 then 'live' when random() < 0.55 then 'bio' else 'stories' end,
                case when i <= x.ig then 'organico' else 'email' end, c, em);
      end if;
    end loop;
  end loop;
  -- cadastros repetidos: 4% tentam de novo nos dias seguintes
  for x in select cp.pessoa_id, cp.entrou_em, cp.canal, cp.utm_campaign, cp.utm_content from campanha_participacoes cp where cp.campanha_id = c and random() < 0.04 loop
    em := x.entrou_em + (1 + random() * 4) * interval '1 day';
    if em < '2026-10-17 00:00-03' then
      insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_campaign, utm_content, origem, ref_tabela, ref_id)
      values (ws, x.pessoa_id, em, 'captura', x.canal, c, 'Nova tentativa de cadastro (repetida)', x.utm_campaign, x.utm_content, 'captura', 'captura', gen_random_uuid());
    end if;
  end loop;
  -- grupo VIP: 66% entram minutos depois do cadastro; 3% saem
  insert into pessoa_lista (workspace_id, pessoa_id, lista_id, ativo, entrou_em, saiu_em)
  select ws, cp.pessoa_id, lista, s.sai is null, cp.entrou_em + (2 + random() * 90) * interval '1 minute', s.sai
    from campanha_participacoes cp cross join lateral (select case when random() < 0.045 then least(cp.entrou_em + (1 + random() * 6) * interval '1 day', timestamptz '2026-10-16 22:00-03') end sai) s
   where cp.campanha_id = c and random() < 0.66;
  -- pesquisa de qualificação (respondida por 70%): 38% qualificados, 32% não qualificados
  update pessoas p set pesquisa_respondida_em = cp.entrou_em + interval '3 minutes', pontuacao_qualificacao = (random() * 100)::int,
         respostas_pesquisa = jsonb_build_object('nivel', (array['iniciante','básico','intermediário','avançado'])[1 + (random() * 3)::int],
                                                  'objetivo', (array['trabalho','viagem','intercâmbio','concurso','conversar com estrangeiros'])[1 + (random() * 4)::int],
                                                  'investe', (array['até R$ 100/mês','R$ 100 a 200/mês','mais de R$ 200/mês'])[1 + (random() * 2)::int])
    from campanha_participacoes cp where cp.campanha_id = c and cp.pessoa_id = p.id and p.criado_em >= '2026-10-01' and random() < 0.70;
  update pessoas p set qualificacao = case when p.pontuacao_qualificacao >= 46 then 'qualificado' else 'nao_qualificado' end
   where p.workspace_id = ws and p.campanha_id = c and p.pesquisa_respondida_em is not null;
  update pessoas p set qualificacao = 'pendente' where p.workspace_id = ws and p.campanha_id = c and p.pesquisa_respondida_em is null;

  -- valores digitados por dia (Analytics e Sendflow): visitas da página de captura, saídas e cliques no grupo
  insert into campanha_etapa_valores (workspace_id, campanha_etapa_id, data, valor, origem)
  select ws, e.id, v.data, v.valor, case when e.chave like 'grupo%' then 'sendflow' else 'importacao' end
    from campanha_etapas e join (
      select 'captura1_visitas_pagina' k, d.data, (coalesce(sum(m.vis), 0) + round(o.ig * 2.7 + o.email * 1.9))::numeric valor from _lfa_org o join (select distinct data from _lfa_dia) d on d.data = o.data left join _lfa_dia m on m.data = o.data group by d.data, o.ig, o.email
      union all select 'grupo1_saidas', (pl.saiu_em at time zone 'America/Sao_Paulo')::date, count(*) from pessoa_lista pl where pl.lista_id = lista and pl.saiu_em is not null group by 2
      union all select 'grupo1_cliques_links', g.d, round(g.n * (0.12 + random() * 0.08)) from (select (pl.entrou_em at time zone 'America/Sao_Paulo')::date d, count(*) over (order by (pl.entrou_em at time zone 'America/Sao_Paulo')::date) n from pessoa_lista pl where pl.lista_id = lista) g group by g.d, g.n
    ) v on v.k = e.chave where e.campanha_id = c
  on conflict (campanha_etapa_id, data) do nothing;

  -- metas por tipo (aba Captação e metas): campanha, canais, público e ritmo por semana
  insert into campanha_metas (workspace_id, campanha_id, tipo, valor, fase, canal, temperatura, data_ini, data_fim, observacao) values
    (ws, c, 'investimento', 20000, 'aquisicao', null, null, '2026-10-01', '2026-10-26', 'Só tráfego pago da captação'),
    (ws, c, 'leads', 5000, 'aquisicao', null, null, '2026-10-01', '2026-10-26', 'Pagos 4.130 + orgânicos 870'),
    (ws, c, 'cpl', 4.00, 'aquisicao', null, null, '2026-10-01', '2026-10-26', 'Investimento ÷ todos os leads (com orgânicos)'),
    (ws, c, 'leads_qualificados', 1900, 'aquisicao', null, null, '2026-10-01', '2026-10-26', '38% dos leads com pesquisa qualificada'),
    (ws, c, 'investimento', 15000, 'aquisicao', 'meta_ads', null, null, null, '75% da verba'),
    (ws, c, 'leads', 3300, 'aquisicao', 'meta_ads', null, null, null, null),
    (ws, c, 'cpl', 4.55, 'aquisicao', 'meta_ads', null, null, null, null),
    (ws, c, 'investimento', 3000, 'aquisicao', 'google_ads', null, null, null, 'YouTube R$ 2.000 + Pesquisa R$ 1.000'),
    (ws, c, 'leads', 430, 'aquisicao', 'google_ads', null, null, null, null),
    (ws, c, 'cpl', 6.98, 'aquisicao', 'google_ads', null, null, null, null),
    (ws, c, 'investimento', 2000, 'aquisicao', 'tiktok_ads', null, null, null, 'Teste de canal: 10% da verba'),
    (ws, c, 'leads', 400, 'aquisicao', 'tiktok_ads', null, null, null, null),
    (ws, c, 'cpl', 5.00, 'aquisicao', 'tiktok_ads', null, null, null, null),
    (ws, c, 'leads', 450, 'aquisicao', 'organico', null, null, null, 'Instagram: bio, stories e lives'),
    (ws, c, 'leads', 420, 'aquisicao', 'email', null, null, null, 'Base de alunos e leads'),
    (ws, c, 'leads', 3460, 'aquisicao', null, 'frio', null, null, 'Interesses, lookalike, Advantage+, YouTube e TikTok'),
    (ws, c, 'leads', 1540, 'aquisicao', null, 'quente', null, null, 'Remarketing, pesquisa, Instagram e e-mail'),
    (ws, c, 'leads', 1000, 'aquisicao', null, null, '2026-10-01', '2026-10-07', 'Semana 1 (verba em 70%, aprendizado)'),
    (ws, c, 'leads', 1350, 'aquisicao', null, null, '2026-10-08', '2026-10-14', 'Semana 2 (verba cheia, criativos novos)'),
    (ws, c, 'leads', 1450, 'aquisicao', null, null, '2026-10-15', '2026-10-21', 'Semana 3 (escala dos vencedores)'),
    (ws, c, 'leads', 1200, 'aquisicao', null, null, '2026-10-22', '2026-10-26', 'Semana 4 (últimos 5 dias, remarketing forte)'),
    (ws, c, 'vendas', 75, 'conversao', null, null, '2026-11-03', '2026-11-09', null),
    (ws, c, 'conversao', 1.5, 'conversao', null, null, null, null, 'Vendas ÷ leads'),
    (ws, c, 'receita', 150000, 'conversao', null, null, '2026-11-03', '2026-11-09', 'Formação + order bump + upsell'),
    (ws, c, 'ticket_medio', 2000, 'conversao', null, null, null, null, null),
    (ws, c, 'cac', 270, null, null, null, null, null, 'CAC de mídia'),
    (ws, c, 'roas', 7.5, null, null, null, null, null, null);

  -- faturas de mídia do lançamento (gasto de 01 a 16/10, a pagar no cartão em 10/11)
  insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id)
  select ws, f.nome || ' — Lançamento Fluência (01 a 16/10)', sum(m.custo), '2026-10-01', '2026-11-10', f.pc, f.cc, c
    from _lfa_dia m join _lfa_ad d on d.cod = m.cod join _lfa_camp k on k.k = d.camp
    join (values ('meta_ads', 'Meta Ads', (select id from plano_contas where workspace_id = ws and codigo = '6.1.02'), cc_meta),
                 ('google_ads', 'Google Ads', (select id from plano_contas where workspace_id = ws and codigo = '6.1.01'), cc_goo),
                 ('tiktok_ads', 'TikTok Ads', pc_tt, cc_tt)) f(canal, nome, pc, cc) on f.canal = k.canal
   group by f.nome, f.pc, f.cc;
end $$;

commit;

-- Conferência (deve mostrar o workspace, 31 anúncios, ~R$ 11 mil investidos e ~3 mil leads na campanha)
select 'workspace' item, nome valor from workspaces where nome = 'Escola Aurora'
union all select 'anúncios do lançamento', count(*)::text from anuncios a join campanha_canais cc on cc.id = a.campanha_canal_id join campanhas c on c.id = cc.campanha_id where c.nome like 'Lançamento Formação Fluência%' and cc.tipo = 'pago'
union all select 'investido no lançamento (R$)', sum(m.custo)::text from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id join campanhas c on c.id = cc.campanha_id where c.nome like 'Lançamento Formação Fluência%'
union all select 'leads do lançamento', count(*)::text from campanha_participacoes p join campanhas c on c.id = p.campanha_id where c.nome like 'Lançamento Formação Fluência%'
union all select 'partidas D − C (deve ser 0)', sum(case tipo when 'D' then valor else -valor end)::text from partidas p join workspaces w on w.id = p.workspace_id where w.nome = 'Escola Aurora';
