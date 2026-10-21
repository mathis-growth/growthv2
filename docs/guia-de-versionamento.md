# Guia de versionamento

Como registrar mudanças neste repositório sem precisar de linha de comando.

## Conceitos em uma linha

- **Repositório:** a pasta do projeto, com todo o histórico.
- **Commit:** uma "foto" salva do projeto, com uma mensagem dizendo o que mudou. É o que forma o histórico.
- **Release (versão):** um marco com número (por exemplo, v0.2.0) que você publica quando uma entrega está fechada.
- **Branch:** uma cópia paralela para mexer sem afetar a versão principal (`main`).
- **Pull request:** o pedido para juntar uma branch na `main`, onde outra pessoa revisa antes.

## Rotina do dia a dia (pelo site do GitHub)

1. Abra o arquivo, clique no **lápis** (Edit), altere e clique em **Commit changes**.
2. Escreva a mensagem no formato `tipo: o que mudou`. Exemplos:
   - `banco: adiciona tabela de metas mensais`
   - `docs: atualiza taxas de exemplo da Hotmart`
   - `correção: arruma cálculo do imposto sobre a taxa`
3. Se a mudança alterou comportamento, **atualize a documentação no mesmo commit** e anote no [CHANGELOG](../CHANGELOG.md), na seção "Não lançado".

Para adicionar arquivos novos: **Add file → Create new file** (ou **Upload files**).

## Regra de ouro do banco

Nunca edite uma migração antiga em `supabase/migrations/`. Cada mudança no banco é um **arquivo novo** com nome `AAAAMMDDHHMMSS_descricao.sql`. Assim o histórico mostra exatamente o que foi aplicado e em que ordem.

## Numeração das versões

`MAIOR.MENOR.CORREÇÃO`, começando em 0 enquanto o sistema está em construção.

| Quando | Exemplo |
| --- | --- |
| Entrega nova (módulo, tela, tabelas novas) | 0.1.0 → 0.2.0 |
| Correção de erro, sem funcionalidade nova | 0.2.0 → 0.2.1 |
| Sistema pronto para uso estável | 1.0.0 |

## Publicar uma versão

1. Mova o conteúdo de "Não lançado" do `CHANGELOG.md` para uma seção nova com o número e a data.
2. No GitHub, abra **Releases → Create a new release**.
3. Em **Choose a tag**, digite `v0.2.0` e escolha **Create new tag**.
4. Dê um título, cole o trecho do CHANGELOG na descrição e clique em **Publish release**.

## Trabalhando em dupla (Rebecka e Rogério)

- Convide o Rogério em **Settings → Collaborators → Add people**.
- Para mudanças maiores, trabalhem em uma **branch** (`feature/campanhas`, por exemplo) e abram um **pull request**; a outra pessoa revisa e aprova antes de juntar na `main`.
- Use a aba **Issues** para a lista de tarefas e perguntas em aberto, e a aba **Projects** para um quadro Kanban do trabalho.

## Cuidados

- O repositório deve ser **privado**.
- Nunca suba senhas, chaves de API, `.env` ou a chave `service_role` do Supabase. Se isso acontecer por engano, troque a chave no Supabase imediatamente: apagar o arquivo do repositório não remove o histórico.


## v0.76
Versão menor: nova funcionalidade no Growth Model, sem mudança de banco.


## v0.77
Versão menor: funcionalidade nova (estratégias e jornada) com migração de banco.


## v0.78
Versão menor: melhoria do Growth Model, sem banco.


## v0.79
Versão menor: melhoria do Growth Model, sem banco.


## v0.80
Versão menor: correções de segurança no banco (migração `20261008230000`) e dois ajustes no front.


## v0.81
Versão menor: dois módulos novos (Simulador de lucro e blocos de estratégia), migração `20261010200000`. Versão da fórmula do simulador: `gps-1.0` (gravada em cada cenário e foto; mudar a fórmula = nova versão).


## v0.82
Versão menor: reorganização do menu (Growth Model com abas), sem banco.


## v0.83
Versão menor: regra financeira nova no banco (migração 20261010220000) e texto da tela.


## v0.84
Correção: menu, sem banco.


## v0.85
Versão menor: pacotes de acesso (migração 20261010230000) e tela nova em Configurações.

## v0.86
Versão menor: cartão de crédito, extrato e listas no dashboard, a receber avulsa, projeto de campanha e atividades por bloco (migração 20261010240000).

## v0.87
Versão menor: módulo Casa dentro da operação e transferência empresa → Casa (migração 20261010250000).

## v0.88
Versão menor: Fase 1 de segurança e confiança do dado (migração 20261011000000), 4 telas novas em Configurações.

## v0.89
Versão menor: Fase 2 de captação e vendas (migração 20261011100000), aba nova na campanha e tela de abandono de checkout.

## v0.90
Versão menor: projetos com tags, filtros, painel e modelos; vínculo projeto × campanha; meta de CPL por canal (migração 20261011200000).

## v0.91
Versão de ajuste: projeto automático da campanha opcional (migração 20261011300000).

## v0.92
Versão de correção: cartões do Dashboard principal clicáveis e arquivo único com as migrações pendentes (sem migração nova).

## v0.93
Versão de funcionalidade: tela Custo operacional com ponto de equilíbrio por regime tributário e "Puxar do financeiro" no simulador (migração 20261011400000, só catálogo de acesso).

## v0.94
Versão de funcionalidade: margens por produto, lucro líquido e meta de margem (migração 20261011500000).

## v0.95
Versão de ajuste: cenários ruim/bom/ótimo na margem de lucro e nos índices do Planejamento (migração 20261011600000).

## v0.96
Versão de funcionalidade: aba Meta de retirada no Unit Economics (sem migração).

## v0.97
Versão de funcionalidade: Growth Now fase A — ofertas com versões e pacote, esteira ramificada, campanha híbrida, North Star (migração 20261011700000).

## v0.98
Versão de funcionalidade: Growth Now fase B — cenários nomeados, baseline travado, cabeçalho financeiro duplo, comparador (migração 20261011800000).

## v0.99
Versão de funcionalidade: Growth Now fase C — ICE, aprovação com documento de decisão, Kanban em 7 colunas (migração 20261011900000).

## v0.100
Versão de funcionalidade: Growth Now fase D — guardrails projetados e monitorados, alertas, acompanhamento contínuo, resultados e aprendizados (migração 20261012000000). Fecha as 4 fases da especificação.

## v0.101
Versão de correção: abas do Growth Model (as telas de cenários e mapa ficaram acessíveis pelo menu). Sem migração.

## v0.102
Versão menor: novo visual (azul em degradê, movimento ao passar o mouse) e escolha de modo claro ou escuro. Sem migração.

## v0.103
Versão menor: nova tela simples do Growth Model (a anterior continua em Mais opções). Sem migração.

## v0.104
Versão menor: ajustes do cenário valem em qualquer filtro de produto. Sem migração.

## v0.105
Versão menor: nova tela RevOps → Retenção & Expansão (coortes, recompra, RFM), com migração `20261012100000_revops_retencao.sql`.

## v0.106
Versão menor: Growth Model em formato de planilha e comparação de cenários com ICE. Sem migração.

## v0.107
Versão menor: tela Cenários (ciclo de vida e histórico), descarte com motivo e link da documentação do teste. Com migração (`RODAR_v0.107_cenarios.sql`).

## v0.108
Versão menor: reorganização do menu Growth (6 itens), Growth Model com as abas Planilha e Cenários, saída do Unit Economics e da Análise de funil. Sem migração.

## v0.109
Versão menor: ideias de conteúdo pelo ChatGPT (chaves, funções no banco, edge function `ideias` e tela de configuração). Com migração (`RODAR_v0.109_ideias_chatgpt.sql`).

## v0.110
Versão menor sem mudança de tela: auditoria de consistência e sincronização repositório × produção.

## v0.111
Versão menor: correção dos achados críticos e altos da auditoria (lucro, receita e imposto iguais em todas as telas; regime no Cadastro da empresa). Com migração (`RODAR_v0.111_consistencia.sql`). Para voltar: `index_v0.109_para_voltar.html`. As funções antigas continuam no repositório, nas migrações anteriores.

## v0.112
Sem mudança de tela (o index.html continua na v0.111): só dados de teste, no arquivo `RODAR_escola_aurora.sql`, e os geradores em `supabase/seed/escola_aurora/`.

## v0.113
- index.html: 0.111 → 0.113. A 0.112 só teve dados.
- Novo: `supabase/functions/leads/` (`index.ts` e `campos.ts`), `supabase/RODAR_v0.113_leads.sql`, `tests/edge/leads_teste.ts` e `tests/auditoria/t113_leads.py`.
- `tests/edge/stub_supabase.ts` agora roda como anon, lê o banco de `PGDB` e passa jsonb.
- Script de montagem: `integra113.py`, que roda o `integra111.py` e aplica `leads113.js`.

## v0.114
- index.html: 0.113 → 0.114.
- Script de montagem: `integra114.py`, que roda o `integra113.py` e aplica `meta114.js`.
- Novo:
  - `supabase/migrations/20261019100000_meta_leads_ritmo.sql` e `supabase/RODAR_v0.114_meta_leads.sql`;
  - `tests/auditoria/t114_meta_leads.py`, `front_escola.py` e `pgrst_escola.conf`.

## v0.115
- index.html: 0.114 → 0.115.
- Script de montagem: `integra115.py`, que roda o `integra114.py` e aplica `det115.js`.
- Novo: migração `20261019200000_campanha_detalhe.sql`, `RODAR_v0.115_detalhe_campanha.sql` e `tests/auditoria/t115_detalhe.py`.

## v0.116
- index.html: 0.115 → 0.116.
- Script de montagem: `integra116.py`, que roda o `integra115.py` e aplica `arv116.js`. O gancho fica em `render()`, depois de `depoisDaTela88`.
- Novo: migração `20261020100000_arvore_numeros.sql`, `RODAR_v0.116_arvore_numeros.sql` e `tests/auditoria/t116_arvore.py`.
- O `t115_detalhe.py` foi ajustado: os cards da campanha agora abrem a árvore, e o detalhe da v0.115 abre por dentro dela.

## v0.120
- index.html: 0.119 → 0.120.
- Script de montagem: `integra120.py`, que roda o `integra119.py` e junta `com120.js` (Comissões) e `con120.js` (Conexões).
- Novo:
  - migrações `20261022100000_comissoes.sql` e `20261022200000_conexoes.sql`, e `RODAR_v0.120_comissoes_conexoes.sql`;
  - edge function `supabase/functions/conexoes/` (index.ts, rotas.ts, util.ts, meta.ts, google.ts);
  - `docs/conectar-meta-e-google.md`;
  - testes `t120_comissoes_conexoes.py`, `t120_comissoes_banco.sql`, `tests/edge/conexoes_teste.ts` e `stub_supabase_papeis.ts` + `import_map_papeis.json`.

## v0.119
- index.html: 0.118 → 0.119.
- Script de montagem: `integra119.py`, que roda o `integra118.py` e aplica as trocas direto no index.
- Novo: migração `20261021100000_arvore_numeros_4.sql`, `RODAR_v0.119_arvore_numeros_4.sql` e `tests/auditoria/t119_arvore4.py`.

## v0.118
- index.html: 0.117 → 0.118.
- Script de montagem: `integra118.py`, que roda o `integra117.py` e aplica as trocas direto no index.
- Novo: migração `20261020300000_arvore_numeros_3.sql`, `RODAR_v0.118_arvore_numeros_3.sql` e `tests/auditoria/t118_arvore3.py`.

## v0.117
- index.html: 0.116 → 0.117.
- Script de montagem: `integra117.py`, que roda o `integra116.py` e aplica as trocas direto no index.
- Novo: migração `20261020200000_arvore_numeros_2.sql`, `RODAR_v0.117_arvore_numeros_2.sql` e `tests/auditoria/t117_arvore2.py`.

## v0.121
- index.html: 0.120 → 0.121.
- Script de montagem: `integra121.py` (roda o `integra120.py`) com `v121.css` e `v121.js`.
- Novo: migração `20261023100000_arvore_vendedor.sql` e `RODAR_v0.121_arvore_vendedor.sql`; teste `t121_visual_campanha.py`.
