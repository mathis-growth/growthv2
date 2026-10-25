

## v0.134
- `social_posts`: `conta_id` passa a aceitar vazio (post importado); novas colunas `origem` ('api' | 'importado'), `rede` (padrão 'instagram'), `conteudo_id` (ligação com a Máquina), `vinculo` ('manual' | 'automatico'), `seguidores_ganhos`. Índice único (cliente, rede, id_externo) para os importados. Pela tela só se altera `conteudo_id` e `vinculo` (quem edita Marketing); gatilho confere que o conteúdo é do mesmo cliente.
- Funções: `social_importar_posts(ws, itens jsonb)` (tudo ou nada, até 2.000), `social_vincular_auto(ws)`, `instagram_dashboard(ws, ini, fim)` → `periodo`, `fontes`, `totais`, `anterior`, `seguidores` (fim, início, antes, alcance e visitas da conta), `serie` por dia e `posts` (métricas, engajamento, conteúdo ligado com território, frente, formato, quadro, destino, etiquetas e score).
- Dados da conta por dia: `social_perfis_dia` (Meta) e, sem ela, `conteudo_conta_dia` canal instagram (importado na tela).

## v0.133
- `conteudo_config` +: `metodo` ('notas5' | 'score6'), `criterios_score text[6]`, `destinos text[]`, `meta_semanal`, `dia_fechamento` (1 = segunda … 7 = domingo; padrão 6, sábado), `tags text[]` (sugestões), `linha jsonb` (núcleo da marca: papel, tese, síntese, visão, inimigo, frase-guia, estruturas, lentes, frases), `modelo`.
- `conteudo_linhas` (= territórios) +: `pergunta_central`, `funcao`, `papel_funil`, `entra`, `nao_entra`, `cor`. `conteudo_temas` (= frentes) +: `descricao`, `transversal` (camada transversal).
- `conteudo_formatos` (nova): `grupo` ('formato' | 'quadro'), `nome`, `funcao`, `execucao`, `melhor_uso`, `estrutura`, `tipo_midia`, `vezes_semana`, `dias_semana`, `cor`, `ordem`, `ativo`. Único por cliente, grupo e nome.
- `conteudos` +: `formato_id`, `quadro_id`, `destino`, `palavra_chave`, `palavras_relacionadas[]`, `perguntas_busca[]`, `intencao`, `entidade`, `problema`, `achado`, `classificacao` (evidência/tendência/discussão/hype), `fundamento`, `evidencia`, `s1`…`s6` (1 a 5), `score_total` (gerada, 6 a 30), `score_notas`, `tags[]`, `dia_semana`, `validado`, `validado_em`, `hook`, `tese`, `cta`, `objetivo`, `estrutura`, `estrutura_notas jsonb`, `obs_producao`, `decisao` (manter/aprofundar/testar/descartar), `aprendizado`.
- `conteudo_fechamentos` (nova, 1 por cliente e semana): `semana_ini` (segunda), `resumo jsonb` (foto de `conteudo_semana`), `retro jsonb`, `objetivo_proxima`, `pre_pauta`, `fechado_por`.
- `conteudo_personas` (nova): `respostas jsonb` do questionário. `conteudo_linha_propostas` (nova): `origem` (ia/colada/modelo), `modelo_ia`, `proposta jsonb` (mesmo formato do modelo V18), `status` (proposta/aplicada/descartada).
- Funções: `conteudo_valida` (gatilho, agora por método), `conteudo_modelo_v18()`, `conteudo_aplicar_linha(ws, jsonb, modelo)`, `conteudo_instalar_v18(ws)`, `conteudo_aplicar_proposta(id)`, `conteudo_semana(ws, segunda)`, `conteudo_fechar_semana(ws, segunda, retro, objetivo, pre_pauta)`. Tabelas novas com RLS do cliente + regra de módulo (Marketing edita; Marketing e Administrativo leem).

## v0.132
- `alertas_config` (1 por cliente): `ligado`, `resumo_diario`, `resumo_hora`, `regras jsonb` (`variacao_pct`, `desvios`, `dias_seguidos`, `gasto_sem_lead`, `desligadas[]`), `destinatarios uuid[]` (vazio = equipe com acesso).
- `alertas`: `chave` única por cliente (não repete), `tipo` (brusco/repetido/operacional), `regra`, `severidade` (alta/media/info), `titulo`, `mensagem`, `dados`, `dia`, `visto_em`, `resolvido_em`.
- `resumos_diarios` (cliente + dia): `fatos jsonb`, `texto`, `avisado_em`.
- `sistema_config` (sem acesso pelo sistema): `avisos_token`, `avisos_url` para o agendador chamar a função `avisos`.
- `notificacoes`: novos tipos `alerta`, `resumo`, `teste` (mesma fila e canais).
- Funções: `growths_serie(ws, ini, fim)`, `growths_fatos_dia(ws, dia)`, `growths_verificar_alertas(ws, ref, avisar)`, `growths_resumo_gerar(ws, dia, avisar)`, `growths_resumo_texto(fatos)`, `growths_ia_extra(ws, ini, fim)`, `growths_aviso_teste(ws)`, `growths_avisar` (interna), `growths_rodar_agendado(ref)` (só o banco). **Pendente em produção.**

## v0.131
- Sem mudança no banco. Leituras novas: `pesquisa_respostas` (com `contato`) + `pesquisa_resposta_itens` + `pessoas` (qualificação, pontuação, tags) na aba Quem respondeu.

## v0.130
- `pesquisas.visual jsonb`: `{marca, titulo, logo_url, fonte_titulo, fonte_texto, cor_primaria, cor_fundo, cor_cartao, cor_texto, raio, botao, enviar}`.
- `pesquisas.captacao jsonb`: `{ativa, campos: {telefone: {mostrar, obrig, rotulo}, instagram: {...}}, etapa_id, tags, responsavel_id, passo_contato, passo_final, aviso_titulo, aviso_texto, consentimentos: [{texto, obrig}], nota_final, sucesso_titulo, sucesso_texto}`.
- `pesquisa_perguntas.secao text`: passo do formulário.
- `pesquisa_respostas.contato jsonb`, `consentimentos jsonb` (`[{texto, aceito}]`), `utm jsonb`, `novo_contato boolean`.
- Funções: `pesquisa_captar(token, respostas, contato, extra)` (anon e autenticado), `pesquisa_registrar(...)` (interna); `pesquisa_responder` e `pesquisa_publica` reescritas (a pública devolve `visual`, `captacao` sem etapa/tags/responsável e a `secao` de cada pergunta).
- Grava em `pessoas` (colunas que já existiam): nome, email, telefone, utm_*, pagina_origem, referrer, canal_origem, etapa_kanban_id, tags, responsavel_comercial_id, `extras.instagram/formulario/consentimentos/consentimento_em`; e uma linha em `pessoa_historico` (campo "formulario"). Aplicado em produção em 21/10/2026.

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
