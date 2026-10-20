import json, sys
from playwright.sync_api import sync_playwright
import os, tempfile
HTML = os.path.join(tempfile.gettempdir(), 't81_growths.html')
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
# Teste de tela da v0.81 (blocos + simulador) com banco simulado. Rodar: python3 tests/tela/t81_blocos_simulador.py (precisa de playwright + chromium)
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Cliente Alfa', 'modo_produto': 'completo'}],
  'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', preco=1997, ativo=True, recorrente=False, tipo='servico'), dict(id='p2', nome='Clube', preco=97, ativo=True, recorrente=True, tipo='assinatura')]),
  'funis': [], 'funil_etapas': [], 'funil_listas': ws([dict(id='L1', funil_id=None, nome='Grupo VIP', tipo='grupo')]),
  'fontes_video': ws([dict(id='V1', nome='Aula 1 ao vivo', tipo='aula', campanha_id=None, funil_id=None, ativo=True), dict(id='V2', nome='Aula 2 ao vivo', tipo='aula', campanha_id=None, funil_id=None, ativo=True)]),
  'estrategia_etapas': [], 'estrategia_blocos': [], 'campanha_etapas': [], 'campanha_blocos': [], 'campanha_etapa_valores': [], 'etapas_catalogo': [],
  'campanhas': ws([dict(id='c1', nome='Lançamento Outubro', status='ativa', modelo='lancamento', data_inicio='2026-10-01', data_fim='2026-10-31', funil_id=None, produto_id='p1', fases={})]),
  'plano_metas': [], 'canais': ws([dict(id='cn1', codigo='001', nome='Meta Ads', ativo=True)]), 'pessoas': [], 'pessoa_toques': [],
  'simulador_cenarios': [], 'simulador_snapshots': [], 'gm_cenarios': [],
  'acesso_telas': [{'tela': 'adm-painel', 'modulo': 'adm', 'nome': 'Dashboard', 'grupo': 'Administrativo', 'ordem': 1}, {'tela': 'adm-dash', 'modulo': 'adm', 'nome': 'Dashboard Growth', 'grupo': 'Administrativo', 'ordem': 2}, {'tela': 'ia-perguntar', 'modulo': 'adm', 'nome': 'Pergunte aos dados', 'grupo': 'Administrativo', 'ordem': 3}, {'tela': 'adm-plano', 'modulo': 'adm', 'nome': 'Planejamento da empresa', 'grupo': 'Administrativo', 'ordem': 4}, {'tela': 'adm-empresa', 'modulo': 'adm', 'nome': 'Cadastro da empresa', 'grupo': 'Administrativo', 'ordem': 5}, {'tela': 'mkt-dash', 'modulo': 'mkt', 'nome': 'Dashboard', 'grupo': 'Marketing', 'ordem': 6}, {'tela': 'mkt-midia', 'modulo': 'mkt', 'nome': 'Dashboard de mídia', 'grupo': 'Marketing', 'ordem': 7}, {'tela': 'mkt-camp', 'modulo': 'mkt', 'nome': 'Campanhas e planejamento', 'grupo': 'Marketing', 'ordem': 8}, {'tela': 'mkt-trafego', 'modulo': 'mkt', 'nome': 'Mídia paga', 'grupo': 'Marketing', 'ordem': 9}, {'tela': 'mkt-video', 'modulo': 'mkt', 'nome': 'Vídeos e webinários', 'grupo': 'Marketing', 'ordem': 10}, {'tela': 'mkt-cont', 'modulo': 'mkt', 'nome': 'Planejamento de conteúdo', 'grupo': 'Marketing', 'ordem': 11}, {'tela': 'crm-dash', 'modulo': 'vendas', 'nome': 'Dashboard', 'grupo': 'Vendas', 'ordem': 12}, {'tela': 'crm-leads', 'modulo': 'vendas', 'nome': 'Funil comercial', 'grupo': 'Vendas', 'ordem': 13}, {'tela': 'crm-oport', 'modulo': 'vendas', 'nome': 'Oportunidades', 'grupo': 'Vendas', 'ordem': 14}, {'tela': 'crm-vendas', 'modulo': 'vendas', 'nome': 'Vendas', 'grupo': 'Vendas', 'ordem': 15}, {'tela': 'crm-contratos', 'modulo': 'vendas', 'nome': 'Contratos', 'grupo': 'Vendas', 'ordem': 16}, {'tela': 'mkt-origem', 'modulo': 'vendas', 'nome': 'Leads por origem', 'grupo': 'Vendas', 'ordem': 17}, {'tela': 'ho-dash', 'modulo': 'revops', 'nome': 'Dashboard', 'grupo': 'RevOps', 'ordem': 18}, {'tela': 'ho-ascensao', 'modulo': 'revops', 'nome': 'Ascensão da escada', 'grupo': 'RevOps', 'ordem': 19}, {'tela': 'ho-cohort', 'modulo': 'revops', 'nome': 'Cohorts', 'grupo': 'RevOps', 'ordem': 20}, {'tela': 'crm-alunos', 'modulo': 'revops', 'nome': 'Alunos', 'grupo': 'RevOps', 'ordem': 21}, {'tela': 'fin-dash', 'modulo': 'fin', 'nome': 'Dashboard', 'grupo': 'Financeiro', 'ordem': 22}, {'tela': 'fin-receber', 'modulo': 'fin', 'nome': 'Contas a receber', 'grupo': 'Financeiro', 'ordem': 23}, {'tela': 'fin-pagar', 'modulo': 'fin', 'nome': 'Contas a pagar', 'grupo': 'Financeiro', 'ordem': 24}, {'tela': 'fin-lanc', 'modulo': 'fin', 'nome': 'Lançamentos contábeis', 'grupo': 'Financeiro', 'ordem': 25}, {'tela': 'prj-lista', 'modulo': 'prj', 'nome': 'Projetos', 'grupo': 'Projetos', 'ordem': 26}, {'tela': 'prj-minhas', 'modulo': 'prj', 'nome': 'Minhas atividades', 'grupo': 'Projetos', 'ordem': 27}, {'tela': 'prj-modelos', 'modulo': 'prj', 'nome': 'Modelos de projeto', 'grupo': 'Projetos', 'ordem': 28}, {'tela': 'prj-avisos', 'modulo': 'prj', 'nome': 'Avisos', 'grupo': 'Projetos', 'ordem': 29}, {'tela': 'gro-diag', 'modulo': 'gro', 'nome': 'Diagnóstico Growth', 'grupo': 'Growth', 'ordem': 30}, {'tela': 'gro-modelo', 'modulo': 'gro', 'nome': 'Growth Loops', 'grupo': 'Growth', 'ordem': 31}, {'tela': 'gro-lucro', 'modulo': 'gro', 'nome': 'Unit Economics', 'grupo': 'Growth', 'ordem': 32}, {'tela': 'gro-analise', 'modulo': 'gro', 'nome': 'Análise de funil', 'grupo': 'Growth', 'ordem': 33}, {'tela': 'gro-pesq', 'modulo': 'gro', 'nome': 'Pesquisas', 'grupo': 'Growth', 'ordem': 34}, {'tela': 'gro-ciclo', 'modulo': 'gro', 'nome': 'Ciclo de Growth (Kanban)', 'grupo': 'Growth', 'ordem': 35}, {'tela': 'cfg-importar', 'modulo': 'cfg', 'nome': 'Importar e validar dados', 'grupo': 'Configurações / Dados e integrações', 'ordem': 36}, {'tela': 'cfg-integracoes', 'modulo': 'cfg', 'nome': 'Integrações', 'grupo': 'Configurações / Dados e integrações', 'ordem': 37}, {'tela': 'cfg-uso', 'modulo': 'cfg', 'nome': 'Uso da plataforma', 'grupo': 'Configurações / Dados e integrações', 'ordem': 38}, {'tela': 'cad-equipe', 'modulo': 'cad', 'nome': 'Equipe e acessos', 'grupo': 'Configurações / Pessoas e acessos', 'ordem': 39}, {'tela': 'cad-funcoes', 'modulo': 'cad', 'nome': 'Funções e permissões', 'grupo': 'Configurações / Pessoas e acessos', 'ordem': 40}, {'tela': 'cad-clientes', 'modulo': 'cad', 'nome': 'Clientes', 'grupo': 'Configurações / Comercial e produtos', 'ordem': 41}, {'tela': 'cad-produtos', 'modulo': 'cad', 'nome': 'Produtos', 'grupo': 'Configurações / Comercial e produtos', 'ordem': 42}, {'tela': 'cad-plataformas', 'modulo': 'cad', 'nome': 'Plataformas', 'grupo': 'Configurações / Comercial e produtos', 'ordem': 43}, {'tela': 'cad-canais', 'modulo': 'cad', 'nome': 'Canais', 'grupo': 'Configurações / Comercial e produtos', 'ordem': 44}, {'tela': 'cad-funis', 'modulo': 'cad', 'nome': 'Estratégias e funis', 'grupo': 'Configurações / Comercial e produtos', 'ordem': 45}, {'tela': 'cad-motivos', 'modulo': 'cad', 'nome': 'Motivos de ganho e perda', 'grupo': 'Configurações / Comercial e produtos', 'ordem': 46}, {'tela': 'cad-planocontas', 'modulo': 'cad', 'nome': 'Plano de contas', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 47}, {'tela': 'cad-regras', 'modulo': 'cad', 'nome': 'Regras contábeis', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 48}, {'tela': 'cad-impostos', 'modulo': 'cad', 'nome': 'Impostos', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 49}, {'tela': 'cad-bancos', 'modulo': 'cad', 'nome': 'Contas bancárias', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 50}, {'tela': 'cad-formaspag', 'modulo': 'cad', 'nome': 'Formas de pagamento', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 51}, {'tela': 'cad-fornecedores', 'modulo': 'cad', 'nome': 'Fornecedores', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 52}, {'tela': 'cad-centros', 'modulo': 'cad', 'nome': 'Centros de custo', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 53}, {'tela': 'cad-rateio', 'modulo': 'cad', 'nome': 'Rateio de custos', 'grupo': 'Configurações / Financeiro e contabilidade', 'ordem': 54}, {'tela': 'st-dash', 'modulo': 'adm', 'nome': 'Dashboard', 'grupo': 'Growth Starter', 'ordem': 55}, {'tela': 'st-relatorios', 'modulo': 'adm', 'nome': 'Relatórios', 'grupo': 'Growth Starter', 'ordem': 56}],
  'pacotes_acesso': [dict(id='pkD', nome='Disparo', descricao='Disparos', telas=['adm-painel', 'ia-perguntar', 'mkt-dash', 'mkt-midia', 'mkt-camp', 'mkt-trafego', 'crm-dash', 'crm-leads', 'crm-vendas', 'mkt-origem', 'gro-analise', 'cfg-importar', 'cfg-integracoes', 'cad-equipe', 'cad-funcoes', 'cad-clientes', 'cad-produtos', 'cad-canais', 'cad-funis'], ativo=True), dict(id='pkC', nome='Consultoria', descricao='Tudo', telas=[], ativo=True)],
}
RPC = r"""
window.__RPC = {
  acesso_workspace: (a, D) => { const w = D.workspaces.find(x => x.id === a.p_ws) || {}; const p = (D.pacotes_acesso || []).find(x => x.id === w.pacote_id); const liga = w.acesso_liga || [], des = w.acesso_desliga || [];
    if (!w.pacote_id && !liga.length && !des.length) return { pacote_id: null, telas: null };
    const base = p ? p.telas : D.acesso_telas.map(t => t.tela); const s = new Set(base.concat(liga).filter(t => !des.includes(t) || ['cad-equipe','cad-funcoes'].includes(t))); s.add('cad-equipe'); s.add('cad-funcoes');
    return { pacote_id: w.pacote_id, pacote: p && p.nome, liga, desliga: des, telas: [...s] }; },
  clientes_acesso: (a, D) => D.workspaces.filter(w => !w.agencia).map(w => ({ id: w.id, nome: w.nome, modo_produto: w.modo_produto, pacote_id: w.pacote_id || null, liga: w.acesso_liga || [], desliga: w.acesso_desliga || [] })),
  pacote_salvar: (a, D) => { if (!a.p_nome) throw new Error('Dê um nome ao pacote'); if (a.p_id) { Object.assign(D.pacotes_acesso.find(p => p.id === a.p_id), { nome: a.p_nome, descricao: a.p_descricao, telas: a.p_telas, ativo: a.p_ativo }); return a.p_id; }
    const id = 'pk' + Math.random().toString(36).slice(2, 7); D.pacotes_acesso.push({ id, nome: a.p_nome, descricao: a.p_descricao, telas: a.p_telas, ativo: a.p_ativo }); return id; },
  pacote_excluir: (a, D) => { if (D.workspaces.some(w => w.pacote_id === a.p_id)) throw new Error('Este pacote está em uso'); D.pacotes_acesso = D.pacotes_acesso.filter(p => p.id !== a.p_id); return null; },
  workspace_definir_acesso: (a, D) => { const w = D.workspaces.find(x => x.id === a.p_ws); Object.assign(w, { pacote_id: a.p_pacote, acesso_liga: a.p_liga, acesso_desliga: a.p_desliga }); return null; },
  campanha_aplicar_estrategia: (a, D) => { const c = D.campanhas.find(x => x.id === a.p_campanha); if (!c) throw new Error('Campanha não encontrada.'); c.funil_id = a.p_funil;
    if (a.p_substituir) { D.campanha_etapas = D.campanha_etapas.filter(e => e.campanha_id !== c.id); D.campanha_blocos = D.campanha_blocos.filter(e => e.campanha_id !== c.id); }
    D.estrategia_blocos.filter(b => b.funil_id === a.p_funil).sort((x, y) => x.ordem - y.ordem).forEach(b => { if (D.campanha_blocos.some(x => x.campanha_id === c.id && x.bloco_origem_id === b.id)) return;
      if (!D.estrategia_etapas.some(e => e.bloco_id === b.id && !D.campanha_etapas.some(x => x.campanha_id === c.id && x.chave === e.chave))) return;
      D.campanha_blocos.push({ id: 'cb' + Math.random().toString(36).slice(2, 8), workspace_id: c.workspace_id, campanha_id: c.id, bloco_origem_id: b.id, ordem: b.ordem, fase: b.fase, tipo: b.tipo, nome: b.nome, origem_ref: b.origem_ref, ativo: true }); });
    let n = 0; D.estrategia_etapas.filter(e => e.funil_id === a.p_funil).forEach(e => { if (D.campanha_etapas.some(x => x.campanha_id === c.id && x.chave === e.chave)) return;
      const cb = D.campanha_blocos.find(x => x.campanha_id === c.id && x.bloco_origem_id === e.bloco_id);
      D.campanha_etapas.push({ id: 'ce' + Math.random().toString(36).slice(2, 8), workspace_id: c.workspace_id, campanha_id: c.id, ordem: e.ordem, fase: e.fase, chave: e.chave, nome: e.nome, unidade: e.unidade, origem: e.origem, metrica: e.metrica, origem_ref: e.origem_ref, conta_como: e.conta_como, taxa_esperada: e.taxa_esperada, ativa: true, bloco_id: cb ? cb.id : null, papel: e.papel, fonte: e.fonte }); n++; });
    return n; },
  campanha_funil_etapas: (a, D) => D.campanha_etapas.filter(e => e.campanha_id === a.p_campanha && e.ativa !== false).sort((x, y) => x.ordem - y.ordem).map(e => {
    let v = null;
    if (e.origem === 'anuncios') v = e.metrica === 'investimento' ? 5000 : e.metrica === 'impressoes' ? 200000 : e.metrica === 'cliques' ? 3000 : 1800;
    if (e.origem === 'leads') v = 600;
    if (e.origem === 'vendas') v = e.metrica === 'receita' ? 39940 : 20;
    if (e.origem === 'manual' || e.origem === 'disparo' || v == null) { const xs = D.campanha_etapa_valores.filter(x => x.campanha_etapa_id === e.id && x.data >= a.p_ini && x.data <= a.p_fim); v = xs.length ? xs.reduce((s, x) => s + Number(x.valor), 0) : null; }
    return { id: e.id, chave: e.chave, nome: e.nome, fase: e.fase, unidade: e.unidade, origem: e.origem, metrica: e.metrica, conta_como: e.conta_como, taxa_esperada: e.taxa_esperada, valor: v || 0, tem: v != null, bloco_id: e.bloco_id, papel: e.papel, fonte: e.fonte }; })
};"""
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';' + RPC + '</script><script>' + MOCK + '</script>' + s[j:])

def go(pg, view, extra=''):
    pg.evaluate("([v,e])=>{S.ws='w1'; S.view=v; eval(e); render();}", [view, extra]); pg.wait_for_timeout(700)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace('\u00a0', ' ')
def toast(pg): return pg.evaluate("(()=>{const t=document.querySelector('#toast'); return t ? t.textContent : ''})()")
def D(pg, t): return pg.evaluate("t=>window.__D[t]", t)
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:300]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def submit(pg): pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(700)

with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1400, 'height': 1800}, accept_downloads=True); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')

    # ---------- BLOCOS ----------
    go(pg, 'cad-funis', "S.estSel=null")
    pg.click('#estNova'); pg.select_option('#modalRoot select[name=modelo]', 'lancamento'); submit(pg)
    bl = D(pg, 'estrategia_blocos'); et = D(pg, 'estrategia_etapas')
    chk(len(bl) == 7 and [x['nome'] for x in sorted(bl, key=lambda x: x['ordem'])] == ['Tráfego pago', 'Página de captura', 'Grupo de WhatsApp', 'Aula 1', 'Aula 2', 'Aula 3', 'Checkout'], 'modelo Lançamento cria 7 blocos na ordem certa', [x['nome'] for x in bl])
    chk(len(et) == 4 + 2 + 3 + 5 * 3 + 4 and all(e['bloco_id'] for e in et), 'cada bloco traz as métricas dele, todas ligadas ao bloco', len(et))
    chk(len(set(e['chave'] for e in et)) == len(et), 'chaves das etapas são únicas (3 aulas sem colisão)')
    chk(sum(1 for e in et if e['papel'] == 'principal') == 7, 'uma métrica principal por bloco')
    t = tx(pg); chk('Aquisição' in t and 'Retenção' in t and 'Aula 3' in t and 'Presentes' in t and 'Etapas avulsas' not in t, 'quadro em 4 colunas com os blocos e a principal', t[:300])
    pg.click('[data-badd=aquisicao]'); pg.select_option('#modalRoot select[name=tipo]', 'conteudo')
    chk(pg.input_value('#modalRoot input[name=nome]') == 'Conteúdo Instagram', 'nome sugerido do bloco de conteúdo')
    submit(pg); bl = D(pg, 'estrategia_blocos')
    chk(any(x['tipo'] == 'conteudo' for x in bl) and sum(1 for e in D(pg, 'estrategia_etapas') if e['chave'].startswith('conteudo1_')) == 7, 'bloco Conteúdo adicionado com 7 métricas')
    # duplicar a Aula 3
    a3 = next(x for x in bl if x['nome'] == 'Aula 3'); pg.click(f'[data-blk="{a3["id"]}"]'); pg.wait_for_timeout(300)
    chk('Pico simultâneo' in tx(pg, '#modalRoot') and 'principal' in tx(pg, '#modalRoot'), 'bloco aberto mostra métricas com papel e fonte')
    pg.click('#bDup'); pg.wait_for_timeout(700); bl = D(pg, 'estrategia_blocos')
    chk(any(x['nome'] == 'Aula 4' for x in bl) and len(set(e['chave'] for e in D(pg, 'estrategia_etapas'))) == len(D(pg, 'estrategia_etapas')), 'duplicar cria Aula 4 sem chave repetida')
    # ligar vídeo na Aula 1
    a1 = next(x for x in bl if x['nome'] == 'Aula 1'); pg.click(f'[data-blk="{a1["id"]}"]'); pg.wait_for_timeout(300)
    pg.select_option('#modalRoot select[name=ref]', 'V1'); submit(pg)
    a1e = [e for e in D(pg, 'estrategia_etapas') if e['bloco_id'] == a1['id']]
    chk(next(x for x in D(pg, 'estrategia_blocos') if x['id'] == a1['id'])['origem_ref'] == 'V1' and next(e for e in a1e if e['origem'] == 'video')['origem_ref'] == 'V1', 'ligar o vídeo no bloco liga a métrica de presença')
    # renomear bloco renomeia as etapas
    pg.click(f'[data-blk="{a1["id"]}"]'); pg.wait_for_timeout(300); pg.fill('#modalRoot input[name=nome]', 'Aula de abertura'); submit(pg)
    chk(all(e['nome'].startswith('Aula de abertura · ') for e in D(pg, 'estrategia_etapas') if e['bloco_id'] == a1['id']), 'renomear o bloco renomeia as métricas')
    # nome repetido
    pg.click(f'[data-blk="{a1["id"]}"]'); pg.wait_for_timeout(300); pg.fill('#modalRoot input[name=nome]', 'Aula 2'); submit(pg)
    chk('Já existe' in toast(pg), 'não deixa dois blocos com o mesmo nome', toast(pg)); pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    # tornar principal outra métrica
    pg.click(f'[data-blk="{a1["id"]}"]'); pg.wait_for_timeout(300); pg.click('#modalRoot [data-bpr]'); pg.wait_for_timeout(600)
    chk(sum(1 for e in D(pg, 'estrategia_etapas') if e['bloco_id'] == a1['id'] and e['papel'] == 'principal') == 1, 'trocar a principal mantém uma só principal')
    # remover a principal de um bloco com outras métricas é barrado
    pg.click(f'[data-blk="{a1["id"]}"]'); pg.wait_for_timeout(300)
    prin = next(e for e in D(pg, 'estrategia_etapas') if e['bloco_id'] == a1['id'] and e['papel'] == 'principal')
    pg.click(f'#modalRoot [data-brm="{prin["id"]}"]'); pg.wait_for_timeout(500)
    chk('principal antes' in toast(pg), 'não remove a principal sem escolher outra', toast(pg)); pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    # mover: subir a Aula 2 acima da Aula de abertura
    a2 = next(x for x in D(pg, 'estrategia_blocos') if x['nome'] == 'Aula 2'); go(pg, 'cad-funis')
    pg.click(f'[data-bup="{a2["id"]}"]'); pg.wait_for_timeout(800)
    aq = sorted([x for x in D(pg, 'estrategia_blocos') if x['fase'] == 'aquecimento'], key=lambda x: x['ordem'])
    chk([x['nome'] for x in aq][:3] == ['Grupo de WhatsApp', 'Aula 2', 'Aula de abertura'], 'subir bloco troca a ordem', [x['nome'] for x in aq])
    et2 = [e for e in D(pg, 'estrategia_etapas') if e['bloco_id'] == a2['id']]; eta = [e for e in D(pg, 'estrategia_etapas') if e['bloco_id'] == a1['id']]
    chk(max(e['ordem'] for e in et2) < min(e['ordem'] for e in eta), 'as métricas acompanham a nova ordem do bloco')
    # remover bloco
    a4 = next(x for x in D(pg, 'estrategia_blocos') if x['nome'] == 'Aula 4'); pg.click(f'[data-blk="{a4["id"]}"]'); pg.wait_for_timeout(300); pg.click('#bRm'); pg.wait_for_timeout(300); submit(pg)
    chk(not any(x['nome'] == 'Aula 4' for x in D(pg, 'estrategia_blocos')) and not any(e['bloco_id'] == a4['id'] for e in D(pg, 'estrategia_etapas')), 'remover bloco remove as métricas dele')
    # aplicar na campanha
    fid = D(pg, 'funis')[0]['id']
    pg.evaluate("f=>sb.rpc('campanha_aplicar_estrategia',{p_campanha:'c1',p_funil:f,p_substituir:false})", fid); pg.wait_for_timeout(300)
    chk(len(D(pg, 'campanha_blocos')) == len(D(pg, 'estrategia_blocos')) and all(e['bloco_id'] for e in D(pg, 'campanha_etapas')), 'campanha recebe os blocos e as etapas ligadas a eles')
    go(pg, 'mkt-camp', "S.campSel='c1'; S.campTab='etapas'; S.cePer={c:'c1',ini:'2026-10-01',fim:'2026-10-31'}")
    t = tx(pg)
    chk('TRÁFEGO PAGO' in t.upper() and 'Cliques no link' in t and 'Etapas avulsas' not in t, 'aba da campanha agrupa o funil por bloco', t[:400])
    # taxa só entre principais: Cliques (3000) → Leads (600) = 20%; Investimento/Impressões sem taxa
    rows = pg.evaluate("""[...document.querySelectorAll('#main table')[0].querySelectorAll('tr')].map(r=>[...r.cells].map(c=>c.innerText.trim()))""")
    def linha(nome): return next((r for r in rows if r and r[0].strip().startswith(nome)), None)
    chk(linha('Leads') and linha('Leads')[3] == '20,0%', 'taxa de Leads compara com a principal anterior (Cliques 3.000 → 600 = 20%)', linha('Leads'))
    chk(linha('Impressões') and linha('Impressões')[3] == '—', 'métrica de diagnóstico não tem taxa', linha('Impressões'))
    chk(linha('Investimento') is not None and linha('Visitas à página') is not None, 'diagnósticos continuam com volume')
    chk('ceQuadro' in pg.content() and pg.locator('#ceQuadro .blk').count() == len(D(pg, 'campanha_blocos')), 'quadro de blocos na campanha')
    # desligar bloco na campanha
    cb = next(x for x in D(pg, 'campanha_blocos') if x['nome'] == 'Aula 2'); pg.click(f'#ceQuadro [data-blk="{cb["id"]}"]'); pg.wait_for_timeout(300); pg.click('#bOn'); pg.wait_for_timeout(700)
    chk(next(x for x in D(pg, 'campanha_blocos') if x['id'] == cb['id'])['ativo'] is False and all(e['ativa'] is False for e in D(pg, 'campanha_etapas') if e['bloco_id'] == cb['id']), 'desligar bloco na campanha desliga as métricas')
    # duplicar estratégia
    go(pg, 'cad-funis', f"S.estSel='{fid}'"); pg.click('#estDup'); submit(pg)
    fs = D(pg, 'funis'); novo = next(f for f in fs if f['id'] != fid)
    chk(len([x for x in D(pg, 'estrategia_blocos') if x['funil_id'] == novo['id']]) == len([x for x in D(pg, 'estrategia_blocos') if x['funil_id'] == fid]), 'duplicar estratégia copia os blocos')
    chk(all(e['bloco_id'] in [x['id'] for x in D(pg, 'estrategia_blocos') if x['funil_id'] == novo['id']] for e in D(pg, 'estrategia_etapas') if e['funil_id'] == novo['id']), 'cópia liga as etapas aos blocos novos (não aos antigos)')
    nb = len(D(pg, 'campanha_blocos'))
    pg.evaluate("f=>sb.rpc('campanha_aplicar_estrategia',{p_campanha:'c1',p_funil:f,p_substituir:false})", novo['id']); pg.wait_for_timeout(300)
    vazios = [b2 for b2 in D(pg, 'campanha_blocos') if not any(e['bloco_id'] == b2['id'] for e in D(pg, 'campanha_etapas'))]
    chk(len(vazios) == 0, 'reaplicar estratégia com as mesmas chaves não cria blocos vazios', [b2['nome'] for b2 in vazios])
    # numeração: tirar uma métrica de diagnóstico e adicionar outra aula não colide
        # sem a migração
    pg.evaluate("window.__SEM=['estrategia_blocos','campanha_blocos']"); go(pg, 'cad-funis', f"S.estSel='{fid}'")
    chk('Os blocos ainda não estão no banco' in tx(pg) and 'Funil da estratégia' in tx(pg), 'sem a migração: aviso e tabela antiga')
    go(pg, 'mkt-camp', "S.campSel='c1'; S.campTab='etapas'"); chk('Funil etapa por etapa' in tx(pg), 'sem a migração a campanha continua abrindo')
    pg.evaluate("window.__SEM=[]")

    # ---------- PACOTES DE ACESSO ----------
    pg.evaluate("()=>{S.interno=true}"); go(pg, 'cfg-pacotes')
    t = tx(pg); chk('Pacotes de acesso dos clientes' in t and 'Disparo' in t and 'Cliente Alfa' in t, 'tela de pacotes lista pacotes e clientes', t[:300])
    pg.click('#pacNovo'); pg.fill('#modalRoot input[name=nome]', 'Mentoria Teste')
    pg.check('#modalRoot input[data-pg="Growth"]'); pg.check('#modalRoot input[name=t][value="mkt-dash"]'); submit(pg)
    nv = next((p for p in D(pg, 'pacotes_acesso') if p['nome'] == 'Mentoria Teste'), None)
    chk(nv and 'gro-lucro' not in nv['telas'] and 'gro-modelo' in nv['telas'] and 'mkt-dash' in nv['telas'] and 'fin-dash' not in nv['telas'], 'novo pacote com o grupo Growth inteiro + uma tela', nv)
    pg.select_option('[data-cp="w1"]', 'pkD'); pg.wait_for_timeout(900)
    chk(next(w for w in D(pg, 'workspaces') if w['id'] == 'w1')['pacote_id'] == 'pkD', 'pacote Disparo aplicado ao cliente')
    nav = pg.evaluate("[...document.querySelectorAll('#nav [data-v], #nav [data-g]')].map(b=>b.dataset.v||b.dataset.g)")
    chk('RevOps' not in nav and 'Projetos' not in nav and 'Financeiro' not in nav and 'Marketing' in nav, 'menu esconde módulos fora do pacote', nav)
    go(pg, 'fin-pagar'); chk('fin-pagar' != pg.evaluate("S.view") or 'Sem acesso' in tx(pg), 'tela fora do pacote não abre direto', [pg.evaluate("S.view"), tx(pg)[:120]])
    go(pg, 'cfg-pacotes'); pg.click('[data-ca="w1"]'); pg.wait_for_timeout(300)
    pg.select_option('#modalRoot select[name="a_ho-dash"]', 'liga'); pg.select_option('#modalRoot select[name="a_crm-vendas"]', 'desliga'); submit(pg)
    w1 = next(w for w in D(pg, 'workspaces') if w['id'] == 'w1')
    chk(w1['acesso_liga'] == ['ho-dash'] and w1['acesso_desliga'] == ['crm-vendas'], 'ajuste por cliente liga RevOps Dashboard e desliga Vendas', w1)
    pg.evaluate("()=>{ desenhaNav(); }"); pg.wait_for_timeout(200)
    chk(pg.evaluate("telaLiberada('ho-dash') && !telaLiberada('crm-vendas') && telaLiberada('cad-equipe')"), 'telas liberadas seguem pacote + ajustes; Equipe sempre liberada')
    pg.click('[data-px="pkD"]'); pg.wait_for_timeout(200); submit(pg); chk('em uso' in toast(pg) and any(p['id']=='pkD' for p in D(pg,'pacotes_acesso')), 'não exclui pacote em uso', toast(pg)); pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    pg.evaluate("()=>{S.interno=false}"); go(pg, 'cfg-pacotes'); chk('cfg-pacotes' != pg.evaluate("S.view") or 'Só a equipe interna' in tx(pg) or 'Sem acesso' in tx(pg), 'quem não é da equipe interna não abre os pacotes')
    chk(not pg.evaluate("[...document.querySelectorAll('#nav [data-v]')].some(b=>b.dataset.v==='cfg-pacotes')"), 'item Pacotes some do menu para o cliente')
    pg.evaluate("window.__SEM=['pacotes_acesso','acesso_telas']; S.interno=true"); go(pg, 'cfg-pacotes'); chk('ainda não estão no banco' in tx(pg), 'sem a migração: aviso')
    pg.evaluate("window.__SEM=[]; (()=>{const w=window.__D.workspaces.find(x=>x.id==='w1'); w.pacote_id=null; w.acesso_liga=[]; w.acesso_desliga=[];})(); S.permWs=null"); go(pg, 'adm-painel')
    chk(pg.evaluate("S.acesso === null"), 'cliente sem pacote volta a ver tudo')

    # ---------- v0.108: Unit Economics saiu do menu e das abas ----------
    chk(pg.evaluate("NAV.find(g=>g.g==='Growth').items.some(i=>i[0]==='gro-lucro'||i[0]==='gro-analise')") is False, 'menu Growth sem Unit Economics e sem Análise de funil')
    go(pg, 'gro-lucro'); chk(pg.evaluate("S.view") == 'gro-modelo' and pg.locator('[data-gm=gro-lucro]').count() == 0, 'rota antiga do Unit Economics abre o Growth Model, sem a aba')
    # tela estreita
    pg.set_viewport_size({'width': 420, 'height': 1200}); go(pg, 'gro-modelo'); pg.wait_for_timeout(300)
    chk(pg.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 2"), 'Growth Model sem rolagem lateral no celular', pg.evaluate("[document.documentElement.scrollWidth, window.innerWidth]"))
    go(pg, 'cad-funis', f"S.estSel='{fid}'"); chk(pg.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 2"), 'quadro de blocos sem rolagem lateral no celular', pg.evaluate("[document.documentElement.scrollWidth, window.innerWidth]"))
    pg.set_viewport_size({'width': 1400, 'height': 1800}); go(pg, 'cad-funis', f"S.estSel='{fid}'"); pass

    print('ERROS JS', errs)
    b.close()
print('RESULTADO', 'TUDO OK' if ok and not errs else 'COM FALHAS: ' + '; '.join(falhas))
