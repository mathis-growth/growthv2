

## v0.126
- Sem mudança no banco. Leituras novas: `checkout_abandonos` (abandono no tempo); `growth_experimentos` (impacto, confiança, facilidade, valor_base, valor_resultado); `vendas` por campanha (burn-up) e de todo o workspace com `contratos.ativado_em` (novos × existentes); `arvore_serie` dos nós `mkt.ads`, `mkt.cpl` e `mkt.cac`.

## v0.125
- Sem mudança no banco. Leituras novas: `movimentacoes_bancarias` + `contas_bancarias.tipo` (resultado × banco); `contas_receber`/`contas_pagar` em aberto (vencimentos); `contratos` + `contrato_itens` (MRR mês a mês); `painel_gerencial` do período anterior (observações); `funil_cohorts` por campanha e `campanhas.meta_cac` (dispersão).

## v0.124
- Sem mudança no banco. Leituras novas: `planejamento_mensal` (metas do mês) no Dashboard; `arvore_no` com `ven.soma` (quebras por produto e campanha) e `fin.lucro` (fórmula) para os gráficos.

## v0.123
- `arvore_serie(p_ws uuid, p_no text, p_par jsonb, p_gran text)` → lista de pontos `{ini, fim, valor, un, parcial}`. Usa `arvore_no` para cada ponto (mesmas permissões; segurança do chamador).
