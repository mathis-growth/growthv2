# Como testar a v0.294 — Uso do Growths pelos clientes

1. No Supabase, rode `supabase/RODAR_v0.294_uso_resumo_mathisa.sql` (SQL Editor). É aditivo — só cria/substitui uma função, nenhuma tabela é alterada.
2. Publique o `index.html` novo.
3. Entre com um login da equipe interna da Mathisa (`sou_equipe_interna` precisa dar `true`) e confira que **Administrativo** agora tem a tela **"Uso do Growths pelos clientes"**. Entrando como um cliente (login dele, não da equipe), essa tela não deve aparecer em nenhum pacote.
4. Abra a tela: deve mostrar os KPIs (clientes ativos, sessões, telas abertas, cliente mais ativo), o ranking "Clientes mais ativos", "Telas mais usadas" somando todos os clientes, e "Atividade por dia".
5. Troque o período no seletor (7/30/90 dias, 12 meses) e confirme que os números mudam.
6. Clique em "Ver uso desse cliente" numa linha do ranking: deve trocar para aquele workspace e abrir **Configurações → Dados e integrações → Uso da plataforma** já com o detalhe completo daquele cliente (essa tela já existia desde a v0.30; não muda nada nela).
7. Se os números vierem todos zerados: é porque ainda não há uso registrado no período (o rastreio só grava enquanto as pessoas navegam depois do SQL rodado) — não é erro.
8. Confira também que **Administrativo → Plano e resultados do ano** volta a abrir a tela certa (Plano do ano / Resultados do ano), e não mais a campanha — isso era um bug de uma reatribuição antiga, corrigido nesta versão, sem relação com a tela nova.

O que ainda não foi testado: contra dados reais de produção (depende de você rodar o SQL primeiro). Peço que confirme o ranking e o clique de drill-down ao vivo.
