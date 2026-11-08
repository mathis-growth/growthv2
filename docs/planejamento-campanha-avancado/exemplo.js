/* Dados FICTÍCIOS para o protótipo: um seminário online que vende um curso. Nada aqui é dado real de cliente. */
(function (raiz) {
  const EXEMPLO = () => ({
    nome: 'Seminário Método X · setembro (exemplo)',
    estrategia: { id: 'est-cev', nome: 'Captação → Evento → Venda', versao: 3, objetivo: 'Aquisição de novos clientes', modelo: 'Captação → Evento → Venda',
      etapas: ['Impressões', 'Cliques', 'Visitas à página', 'Leads captados', 'Inscritos no evento (opcional)', 'Participantes', 'Cliques na oferta', 'Checkouts iniciados', 'Compras aprovadas', 'Novos clientes'] },
    produto: { nome: 'Curso Método X (exemplo)',
      preco: { v: 1997, origem: 'real_conc' }, desconto: { v: 0, origem: 'usuario' }, tributos: { v: 6, origem: 'real_conc' }, taxaPlataforma: { v: 9.9, origem: 'real_conc' }, taxaTransacao: { v: 1, origem: 'real_conc' },
      comissao: { v: 0, origem: 'usuario' }, reembolso: { v: 7, origem: 'historico' }, chargeback: { v: 0.5, origem: 'historico' }, inadimplencia: { v: 0, origem: 'usuario' },
      entrega: { v: 60, origem: 'usuario' }, suporte: { v: 25, origem: 'premissa' }, infra: { v: 8, origem: 'real_nconc' } },
    ofertas: { bump: { tem: true, nome: 'Planner do método', preco: 97, aceite: 25, recLiqUnit: 75, mcUnit: 70 }, upsell: { tem: true, nome: 'Mentoria em grupo', preco: 497, aceite: 8, recLiqUnit: 390, mcUnit: 300 } },
    funil: { cpm: 28, ctr: 1.2, cliqueVisita: 85, convPagina: 30, inscricao: null, comparecimento: 35, convPresentes: 5, convAusentes: 0.8, pctNovos: 85, elasticidade: 0.6, verbaRef: 15000 },
    canais: [{ nome: 'Meta Ads e Google Ads', tipo: 'pago' }, { nome: 'Orgânico', tipo: 'org', leads: 600 }, { nome: 'WhatsApp API', tipo: 'api', leads: 300, custoLead: 3.15 }],
    recursos: [
      { nome: 'Copywriting (equipe interna)', tipo: 'disp_aloc', valor: 2000 }, { nome: 'Design (equipe interna)', tipo: 'disp_aloc', valor: 1500 }, { nome: 'Página de captura (já existe)', tipo: 'disp_sem', valor: 0 },
      { nome: 'Criativos e vídeos (freelancer)', tipo: 'fixo', valor: 3000 }, { nome: 'Ferramentas extras do evento', tipo: 'fixo', valor: 500 }, { nome: 'Produção da live', tipo: 'fixo', valor: 2500 },
      { nome: 'Reforço no atendimento', tipo: 'fixo', valor: 2000 }, { nome: 'Closer comercial (por venda)', tipo: 'var_venda', valor: 50, capacidade: 200 } ],
    plano: { receitaAno: 1800000, contribuicaoProdutoAno: 600000, realizadoAteAgosto: 380000, campanhasComprometidas: 120000, pesoCampanha: 0.15, orcamentoAquisicaoAno: 220000, realizadoAquisicao: 128000, comprometidoAquisicao: 45000 },
    residualMinimo: 45000, metaVendas: 70, verbaPlanejada: 15000, capacidadeVendas: 300, orcamentoDisponivel: 47000, tetoBusca: 200000,
    caixa: { saldo: 120000, reserva: 20000, pctParcelado: 60, parcelas: 12, antecipar: false, taxaAntecipacao: 1.6, repasseDias: 30, programados: [{ dia: 10, valor: 25000, nome: 'Folha e fixos de setembro' }, { dia: 40, valor: 25000, nome: 'Folha e fixos de outubro' }] },
    datas: { capA: 0, capB: 20, live: 23, carA: 24, carB: 30, inicio: '2027-09-01' },
    ltv: { taxaSegunda: 12, mcIncremental: 800, custoRetencao: 60, clientesBase: 140, minClientes: 30, diasAteSegunda: 120 },
    historico: [ // FICTÍCIO. Mesmo produto e mesma estratégia. Canais somam o total de cada campanha.
      { nome: 'Seminário Método X · mar/27', periodo: 'mar/27', oferta: 'R$ 1.997 + bump', ticket: 2090, publico: 'Frio + base', midia: 13800, leads: 2300, inscritos: 2300, participantes: 830, vendasPresentes: 64, vendas: 88, novos: 76, receita: 183900,
        canais: { meta: { midia: 11000, leads: 1450, novos: 46 }, google: { midia: 2800, leads: 300, novos: 9 }, org: { leads: 400, novos: 15 }, api: { custo: 473, leads: 150, novos: 6 } },
        ofertas: { bump: { vendas: 20 }, upsell: { vendas: 6 }, downsell: null } },
      { nome: 'Seminário Método X · mai/27', periodo: 'mai/27', oferta: 'R$ 1.997 + bump + downsell', ticket: 2075, publico: 'Frio + base', midia: 16200, leads: 2650, inscritos: 2650, participantes: 905, vendasPresentes: 70, vendas: 95, novos: 80, receita: 197100,
        canais: { meta: { midia: 12600, leads: 1600, novos: 46 }, google: { midia: 3600, leads: 380, novos: 10 }, org: { leads: 480, novos: 17 }, api: { custo: 599, leads: 190, novos: 7 } },
        ofertas: { bump: { vendas: 26 }, upsell: { vendas: 8 }, downsell: { nome: 'Curso essencial R$ 497', ofertadoPara: 835, vendas: 9 } } },
      { nome: 'Seminário Método X · jul/27', periodo: 'jul/27', oferta: 'R$ 1.797 (promo) + bump', ticket: 1860, publico: 'Frio', midia: 12100, leads: 2050, inscritos: 2050, participantes: 640, vendasPresentes: 49, vendas: 66, novos: 60, receita: 122800, diferenca: 'preço promocional',
        canais: { meta: { midia: 9800, leads: 1350, novos: 38 }, google: { midia: 2300, leads: 280, novos: 8 }, org: { leads: 300, novos: 10 }, api: { custo: 378, leads: 120, novos: 4 } },
        ofertas: { bump: { vendas: 14 }, upsell: { vendas: 4 }, downsell: null } } ],
    canaisPlano: { meta: 0.8, google: 0.2 }, // divisão da verba de mídia entre Meta e Google (premissa)
  });
  if (typeof module !== 'undefined' && module.exports) module.exports = { EXEMPLO }; else raiz.EXEMPLO = EXEMPLO;
})(typeof window !== 'undefined' ? window : globalThis);
