# Front-end de teste do Growths

Uma única página (`index.html`) que conversa com o Supabase. Serve para testar o banco enquanto a interface definitiva não existe.

## Como abrir

1. Dê dois cliques em `index.html` (abre no navegador). Precisa de internet.
2. Clique em **Criar conta** com seu e-mail e uma senha. Se o Supabase pedir confirmação, confirme o e-mail e volte para **Entrar**.
3. Peça o vínculo do seu login ao workspace de demonstração (ou rode no SQL Editor, trocando o e-mail):

   ```sql
   select vincular_usuario(
     (select id from workspaces where nome = 'Growths — Demo'), 'seu@email.com');
   ```

## Menu

- **Marketing:** dashboard (investimento, CPL, CAC, ROAS, leads por dia) e campanhas com planejamento anual (metas por mês e gráficos de meta x realizado).
- **CRM:** funil de leads e alunos, em Kanban com arrastar e soltar.
- **Financeiro:** vendas e contas a receber; contas a pagar.
- **Administrativo:** painel gerencial (DRE, fluxo de caixa) e cadastros: clientes, fornecedores, produtos, plataformas, canais, funis, impostos e contas bancárias.

## Segurança

A chave no arquivo é a chave **publicável**, feita para ficar no navegador. Cada pessoa só enxerga os workspaces aos quais está vinculada. Nunca coloque a chave `service_role` aqui.

## Novidades da versão 0.3
Menu com grupos recolhíveis (Cadastros no fim). Novas telas: Dashboard de campanhas por canal, Tráfego pago (resumo diário e cartões por criativo, com importação de CSV), Leads por origem, Jornada do funil (Kanban com grupo e API), Lançamentos contábeis (somente estorno), Regras contábeis, Plano de contas, Centros de custo, Anúncios e Funis com etapas e listas.

## Se a tela ficar em branco
Abra o `index.html` direto no navegador (Chrome, Edge ou Safari), não pela pré-visualização do aplicativo. Se aparecer o aviso de "sem resposta do servidor", confira a internet e se o projeto do Supabase não está pausado (projetos gratuitos pausam por inatividade).
