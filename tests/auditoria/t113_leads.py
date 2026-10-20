"""v0.113: Receber leads. Na campanha → Captação e metas: gera chave de leads (escopo leads, não aparece em Ideias pelo ChatGPT),
o endereço e o código já levam a chave e o utm_campaign do canal; um lead gravado pela chave entra na campanha; um lead que chegou
antes do canal existir é ligado por "Religar leads". Precisa do banco fa + PostgREST (LEIA.md) e da migração 20261018100000."""
import sys, subprocess, json; sys.path.insert(0, '.')
from front import abre, vai
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'; CAMP = '54011ef1-34b7-44f1-978e-3d733d244899'
def psql(sql, role=None):
    pre = ('set role %s; ' % role) if role else ''
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-c', pre + sql], capture_output=True, text=True)
    return (r.stdout.strip() or r.stderr.strip())
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
try:
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx, pg = abre(b)
        t = vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'captacao'" % CAMP, 5000)
        chk('Receber leads de formulários' in t and 'Religar leads' in t, 'Captação e metas: botões Receber leads e Religar leads')
        pg.click('#ldReceber'); pg.wait_for_timeout(2500)
        u = pg.eval_on_selector('#ldUrl', 'e => e.value')
        chk(u.endswith('/functions/v1/leads?chave=SUA_CHAVE&utm_campaign=lanc-set-google'), 'endereço com o utm_campaign do canal antes da chave: ' + u)
        pg.click('#ldGerar'); pg.wait_for_timeout(2500)
        u = pg.eval_on_selector('#ldUrl', 'e => e.value'); k = u.split('chave=')[1].split('&')[0]
        chk(k.startswith('gw_') and len(k) == 67, 'chave gerada entra no endereço')
        chk(k in pg.eval_on_selector('#ldHtml', 'e => e.value') and 'name="redirect"' in pg.eval_on_selector('#ldHtml', 'e => e.value'), 'código do formulário leva a chave e a página de obrigado')
        chk(psql("select escopo from chaves_api where hash = chave_api_hash('%s')" % k) == 'leads', 'chave salva com escopo leads')
        # gravar um lead como a edge function faz (papel anon)
        r = json.loads(psql("select lead_por_chave('%s', '{\"nome\":\"Lead Teste 113\",\"email\":\"lead113@x.com\",\"utm_campaign\":\"lanc-set-google\"}')" % k, 'anon'))
        chk(r.get('nova') and r.get('campanha') == 'Lançamento Setembro', 'lead pela chave entra na campanha ' + str(r))
        chk('permission denied' in psql("select chave_api_ws_escopo('%s','leads')" % k, 'anon'), 'anon não chama a validação de chave direto')
        chk('inválida' in psql("select ideia_por_chave('%s', 'x', null, null, null, null)" % k, 'anon'), 'chave de leads não grava ideias')
        # lead que chegou antes do canal
        psql("select lead_por_chave('%s', '{\"email\":\"lead113b@x.com\",\"utm_campaign\":\"lanc-set-novo113\"}')" % k, 'anon')
        psql("insert into campanha_canais(workspace_id,campanha_id,canal,utm_campaign) values ('%s','%s','meta_ads','lanc-set-novo113')" % (WS, CAMP))
        pg.evaluate("() => { document.querySelector('#modalRoot').innerHTML = ''; }")
        vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'captacao'" % CAMP, 5000)
        pg.once('dialog', lambda d: d.accept()); pg.click('#ldReligar'); pg.wait_for_timeout(3000)
        chk(psql("select count(*) from campanha_participacoes cp join pessoas p on p.id = cp.pessoa_id where p.email = 'lead113b@x.com' and cp.campanha_id = '%s'" % CAMP) == '1', 'Religar leads liga o lead que chegou antes do canal')
        chk(psql("select campanha_id from pessoas where email = 'lead113b@x.com'") == CAMP, 'Religar leads preenche a campanha da pessoa')
        vai(pg, 'mkt-conteudo', "", 3000)
        pg.evaluate("() => modalIdeiasIA()"); pg.wait_for_timeout(2500)
        chk('Formulários de captura' not in pg.inner_text('#modalRoot'), 'Ideias pelo ChatGPT não lista a chave de leads')
        chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
        ctx.close(); b.close()
finally:
    psql("delete from pessoas where email in ('lead113@x.com','lead113b@x.com'); delete from campanha_canais where utm_campaign = 'lanc-set-novo113'; delete from chaves_api where escopo = 'leads' and workspace_id = '%s'" % WS)
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
