# Como testar o Planejamento de campanha avançado (v0.287)

1. Publique o `index.html` da v0.287. Não há nada para rodar no banco.
2. Entre num cliente com campanhas que tenham mídia e leads (ex.: Growths — Demo) e abra **Marketing → Planejamento de campanha avançado**.
3. **Passo 1:** escolha a estratégia e o produto. O produto mostra quantas campanhas tem.
4. **Passo 3, Histórico do produto:** confira as campanhas listadas, o CAC e o CPL médios e a variação. Marque e desmarque "Só campanhas desta estratégia".
5. **Passo 4:** os impostos, a taxa e o reembolso vêm das vendas. Preencha custo de entrega, suporte e infraestrutura (sem eles a margem fica incompleta).
6. **Passo 7:** informe a contribuição mínima e, se quiser o teto de caixa, o saldo de hoje.
7. **Passo 9:** escolha "Histórico do produto" e clique em **Copiar para pessimista, base e otimista**.
8. **Passo 10:** mude o % de Meta, o CPL e os leads orgânicos e veja vendas, CAC e contribuição mudarem.
9. **Passo 13:** mexa numa taxa do funil e veja as cores (vermelho abaixo da meta, azul na meta, verde acima).
10. Saia da tela e volte: o planejamento deve abrir como você deixou (o topo mostra "Salvo no Growths às …").
11. Em **Growth Model → Calculadora de campanha**, os planejamentos avançados não devem aparecer na lista.

O que ainda não faz: levar as metas para uma campanha, cockpit dentro do módulo e TikTok no plano por canal.

## Diagnóstico e baseline (v0.290)
1. Abra **Marketing → Planejamento de campanha avançado**. A tela abre na aba **Diagnóstico e baseline**.
2. Confira a situação sugerida e os números: receita, clientes novos e CAC devem bater com Vendas e com as campanhas.
3. Em "Apurar o custo de servir", preencha equipe, % do tempo, outros custos e alunos: aparece o custo por aluno e a margem muda para "Estimado".
4. Digite uma correção em qualquer indicador: ele fica "Informado por você". Apague: volta ao número do sistema.
5. Clique em **Aprovar baseline**. A aba mostra "aprovado v1" e o rodapé "✓ Baseline salvo".
6. Vá para **Planejar campanha**, passo 4: o suporte por aluno deve vir com o custo de servir.
7. Saia e volte: o baseline e a campanha abrem como você deixou.

## Plano do ano (v0.291)
1. Com o baseline preenchido (custos fixos e margem), abra a aba **Plano do ano**.
2. Confira a meta sugerida e digite o lucro desejado: os quatro cartões e os cenários mudam.
3. Suba a meta ou o lucro até aparecer o aviso de que o plano não fecha no CAC de hoje.
4. Mude o peso de um trimestre e veja a meta e o orçamento do trimestre mudarem.
5. Clique em **Aprovar plano do ano**.
6. Em **Planejar campanha**, o passo 2 deve trazer o orçamento de aquisição do ano e o passo 7 a contribuição mínima. Mude um deles lá: o valor digitado fica.

## Resultados do ano (v0.292)
1. Abra a aba **Resultados do ano**. O ano corrente mostra o realizado por trimestre e as campanhas com dados.
2. Em **Planejar campanha**, copie para os cenários (passo 9) e, no passo 2, escolha uma campanha já realizada em "Campanha do Growths ligada".
3. Volte a Resultados do ano: a campanha mostra planejado → realizado, com o desvio em cor.
4. Com uma campanha só, a seção 3 avisa que não há padrão. Com duas ou mais, mostra o desvio médio.
5. Troque o ano nos botões do topo.
