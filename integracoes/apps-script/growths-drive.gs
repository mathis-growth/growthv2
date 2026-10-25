/**
 * Growths — pastas do Growth's Content no Google Drive.
 * Roda na conta da Rebecka (as pastas ficam no nome dela). O Growths chama este endereço com a senha abaixo.
 * Implantar: Implantar → Nova implantação → App da Web → Executar como: Eu → Quem pode acessar: Qualquer pessoa.
 */
const SENHA = '<SENHA — a mesma de sistema_config.drive_script_senha>';

function doPost(e) {
  const responde = o => ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
  const trava = LockService.getScriptLock();
  try {
    const b = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (b.senha !== SENHA) return responde({ ok: false, erro: 'Senha inválida' });
    const raiz = DriveApp.getFolderById(b.raiz);
    if (b.acao === 'teste') return responde({ ok: true, raiz: raiz.getName() });
    if (b.acao !== 'criar_cliente') return responde({ ok: false, erro: 'Ação desconhecida' });
    const nome = String(b.nome || '').replace(/[\\/]/g, '-').trim();
    if (!nome) return responde({ ok: false, erro: 'Cliente sem nome' });
    trava.waitLock(30000);
    // a mesma pasta nunca é criada duas vezes: se já existe uma com o nome do cliente, usa ela
    const pega = (pai, n) => { const it = pai.getFoldersByName(n); return it.hasNext() ? it.next() : pai.createFolder(n); };
    const pasta = b.pasta_id ? DriveApp.getFolderById(b.pasta_id) : pega(raiz, nome);
    // árvore: lista de caminhos, ex. ["01 Briefing", "02 Conteúdos/Roteiros"]
    (b.arvore || []).forEach(caminho => {
      let p = pasta;
      String(caminho).split('/').map(x => x.trim()).filter(Boolean).forEach(n => { p = pega(p, n); });
    });
    return responde({ ok: true, id: pasta.getId(), url: pasta.getUrl(), nome: pasta.getName() });
  } catch (err) {
    return responde({ ok: false, erro: String(err && err.message || err) });
  } finally {
    try { trava.releaseLock(); } catch (x) {}
  }
}
