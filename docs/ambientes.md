# Ambientes: Teste, Homologação e um banco por cliente (decisão de 20/10/2026)

**Decisão da Rebecka:** os dados de clientes diferentes não ficam no mesmo banco. Cada cliente tem o seu próprio projeto Supabase. Mapa visual: artefato "Ambientes do Growths", no Claude.

| Etapa | Galho | Banco (Supabase) | Endereço | Dados |
|---|---|---|---|---|
| Teste (interno) | `dev` | `growths-teste` | `dev.growthv2.pages.dev` | fictícios, recriáveis |
| Homologação (interno) | `homologacao` | `growths-homolog` | `homologacao.growthv2.pages.dev` | cópia anonimizada de um cliente |
| Produção | `main` (protegido, tag `vX.YYY`) | **um projeto por cliente** | **um endereço por cliente** | só daquele cliente |

**Como uma versão anda**
1. Ela nasce em `dev`.
2. Um pull request `dev → homologacao` só mescla se os testes passarem.
3. A versão é validada em Homologação.
4. Um pull request `homologacao → main` é aprovado.
5. A publicação automática percorre o `clientes.json`, em ondas: a onda 1 é a Mathisa/Demo, depois vêm os demais. Em cada cliente, aplica as migrações, publica as funções e publica a tela apontando para o banco dele.
6. Se um cliente falhar, a fila para. Esse cliente fica na versão anterior, com banco e tela juntos.

**`clientes.json`**: a lista de clientes, com o projeto, o endereço e a onda de cada um. As chaves ficam nos segredos do GitHub.

**O que fica melhor**
- Isolamento total dos dados.
- Backup e exclusão por cliente (LGPD).
- Um cliente não deixa os outros lentos.
- Dá para liberar em ondas.

**O que exige cuidado**
- Custo: um projeto pago por cliente, que entra no preço do contrato.
- Login: a equipe da Mathisa precisa de acesso em cada banco. Trocar de cliente vira trocar de endereço.
- A visão consolidada de todos os clientes vira um relatório que junta os bancos.
- O endereço de retorno do Meta e do Google muda por cliente.

Dentro do banco de um cliente, o workspace continua existindo, para um cliente com mais de um negócio.

**Para montar**
1. Preço e plano: decisão da Rebecka.
2. Criar Teste e Homologação: com o ok de custo.
3. Separar o banco atual: cada workspace de cliente vira o projeto dele.
4. Galhos, `clientes.json` e GitHub Actions por cliente.
5. Domínios no Cloudflare.
6. Script "cliente novo".
7. README com a versão de cada cliente.
