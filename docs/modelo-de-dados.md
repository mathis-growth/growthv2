

## v0.130
- `pesquisas.visual jsonb`: `{marca, titulo, logo_url, fonte_titulo, fonte_texto, cor_primaria, cor_fundo, cor_cartao, cor_texto, raio, botao, enviar}`.
- `pesquisas.captacao jsonb`: `{ativa, campos: {telefone: {mostrar, obrig, rotulo}, instagram: {...}}, etapa_id, tags, responsavel_id, passo_contato, passo_final, aviso_titulo, aviso_texto, consentimentos: [{texto, obrig}], nota_final, sucesso_titulo, sucesso_texto}`.
- `pesquisa_perguntas.secao text`: passo do formulário.
- `pesquisa_respostas.contato jsonb`, `consentimentos jsonb` (`[{texto, aceito}]`), `utm jsonb`, `novo_contato boolean`.
- Funções: `pesquisa_captar(token, respostas, contato, extra)` (anon e autenticado), `pesquisa_registrar(...)` (interna); `pesquisa_responder` e `pesquisa_publica` reescritas (a pública devolve `visual`, `captacao` sem etapa/tags/responsável e a `secao` de cada pergunta).
- Grava em `pessoas` (colunas que já existiam): nome, email, telefone, utm_*, pagina_origem, referrer, canal_origem, etapa_kanban_id, tags, responsavel_comercial_id, `extras.instagram/formulario/consentimentos/consentimento_em`; e uma linha em `pessoa_historico` (campo "formulario"). **Pendente em produção.**

## v0.129
- `pesquisas.qualif jsonb`: `{ativa, modo: "soma"|"media", corte, faixas: [{min, tag}]}`.
- `pesquisa_perguntas.pontos jsonb`: `{opcoes: {"<opção>": {p, tag}}}` ou `{peso}`.
- Funções `pesquisa_qualificar(uuid)`, `pesquisa_requalificar(uuid)`; `pesquisa_responder` chama a primeira.
- Grava em `pessoas.pontuacao_qualificacao`, `pessoas.qualificacao` e `pessoas.tags` (colunas que já existiam). Aplicado em produção em 21/10/2026.

## v0.128
- Sem mudança no banco. Leituras: `v_trafego_anuncio_dia` da campanha, `vendas` da campanha com `produtos` e `ofertas`, `campanha_meta_leads`.

## v0.127
- Nova coluna (pendente em produção): `empresa.saldo_minimo numeric` (≥ 0 ou vazio). Migração `20261025100000_saldo_minimo.sql`.
- Leituras novas: `ofertas` (papel) com `vendas.oferta_id`; `planos` + `planejamento_mensal` + `vendas`/`pessoas` (plano no tempo); `gm_cenarios` aprovados (`resultados`).

## v0.126
- Sem mudança no banco. Leituras novas: `checkout_abandonos` (abandono no tempo); `growth_experimentos` (impacto, confiança, facilidade, valor_base, valor_resultado); `vendas` por campanha (burn-up) e de todo o workspace com `contratos.ativado_em` (novos × existentes); `arvore_serie` dos nós `mkt.ads`, `mkt.cpl` e `mkt.cac`.

## v0.125
- Sem mudança no banco. Leituras novas: `movimentacoes_bancarias` + `contas_bancarias.tipo` (resultado × banco); `contas_receber`/`contas_pagar` em aberto (vencimentos); `contratos` + `contrato_itens` (MRR mês a mês); `painel_gerencial` do período anterior (observações); `funil_cohorts` por campanha e `campanhas.meta_cac` (dispersão).

## v0.124
- Sem mudança no banco. Leituras novas: `planejamento_mensal` (metas do mês) no Dashboard; `arvore_no` com `ven.soma` (quebras por produto e campanha) e `fin.lucro` (fórmula) para os gráficos.

## v0.123
- `arvore_serie(p_ws uuid, p_no text, p_par jsonb, p_gran text)` → lista de pontos `{ini, fim, valor, un, parcial}`. Usa `arvore_no` para cada ponto (mesmas permissões; segurança do chamador).
