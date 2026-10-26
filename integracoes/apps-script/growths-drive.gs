/**
 * Growths — pastas do Growth's Content no Google Drive.
 * Roda na conta da Rebecka (as pastas ficam no nome dela). O Growths chama este endereço com a senha abaixo.
 * Implantar: Implantar → Gerenciar implantações → editar (lápis) → Versão: Nova versão → Implantar.
 *   (Primeira vez: Nova implantação → App da Web → Executar como: Eu → Quem pode acessar: Qualquer pessoa.)
 * Ações:
 *   teste          → confere a senha e a pasta raiz
 *   criar_cliente  → cria (ou completa) a pasta do cliente e a árvore de subpastas
 *   ler            → lê os arquivos das pastas pedidas (v0.151): texto de Docs, Planilhas, Apresentações, .txt/.md/.csv;
 *                    PDF em base64 (até 4 MB); o resto é listado com o motivo de não ter sido lido.
 */
const SENHA = '<SENHA — a mesma de sistema_config.drive_script_senha>';

const LER_MAX_ARQUIVOS = 80;          // por pedido
const LER_MAX_TEXTO = 60000;          // caracteres por arquivo
const LER_MAX_TOTAL = 600000;         // caracteres somando tudo
const LER_MAX_PDF = 4 * 1024 * 1024;  // bytes por PDF
const LER_MAX_PDFS = 6;

function doPost(e) {
  const responde = o => ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
  const trava = LockService.getScriptLock();
  try {
    const b = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (b.senha !== SENHA) return responde({ ok: false, erro: 'Senha inválida' });
    if (b.acao === 'ler') return responde(ler_(b));
    const raiz = DriveApp.getFolderById(b.raiz);
    if (b.acao === 'teste') return responde({ ok: true, raiz: raiz.getName(), versao: 2 });
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

/* ---------- leitura das pastas ---------- */
// b.pastas = [{ id, rotulo }], b.desde = ISO (opcional: só arquivos alterados depois)
function ler_(b) {
  const desde = b.desde ? new Date(b.desde) : null;
  const saida = [], pastasErro = [];
  let total = 0, pdfs = 0;
  const textoDe = (arq, tipo) => {
    if (tipo === MimeType.GOOGLE_DOCS) return DocumentApp.openById(arq.getId()).getBody().getText();
    if (tipo === MimeType.GOOGLE_SHEETS) {
      return SpreadsheetApp.openById(arq.getId()).getSheets().slice(0, 5).map(sh => {
        const v = sh.getDataRange().getDisplayValues().slice(0, 400);
        return '## ' + sh.getName() + '\n' + v.map(l => l.join(' | ')).join('\n');
      }).join('\n\n');
    }
    if (tipo === MimeType.GOOGLE_SLIDES) {
      return SlidesApp.openById(arq.getId()).getSlides().map((sl, i) => '## Lâmina ' + (i + 1) + '\n' + sl.getShapes().map(s => { try { return s.getText().asString(); } catch (x) { return ''; } }).filter(t => t.trim()).join('\n')).join('\n\n');
    }
    if (/^text\//.test(tipo) || /\.(md|txt|csv|srt|vtt)$/i.test(arq.getName())) return arq.getBlob().getDataAsString('UTF-8');
    return null;
  };
  const visita = (pasta, caminho, rotulo) => {
    const arqs = pasta.getFiles();
    while (arqs.hasNext() && saida.length < LER_MAX_ARQUIVOS) {
      const a = arqs.next(), tipo = a.getMimeType(), mod = a.getLastUpdated();
      if (desde && mod <= desde) continue;
      const item = { id: a.getId(), nome: a.getName(), caminho: caminho, rotulo: rotulo, tipo: tipo, modificado: mod.toISOString(), tamanho: a.getSize(), url: a.getUrl(), lido: false };
      try {
        if (tipo === MimeType.PDF) {
          if (a.getSize() > LER_MAX_PDF) item.motivo = 'PDF grande demais (acima de 4 MB)';
          else if (pdfs >= LER_MAX_PDFS) item.motivo = 'Limite de PDFs por leitura atingido';
          else { item.pdf_base64 = Utilities.base64Encode(a.getBlob().getBytes()); item.lido = true; pdfs++; }
        } else {
          let t = textoDe(a, tipo);
          if (t == null) item.motivo = /^(video|audio)\//.test(tipo) ? 'Vídeo ou áudio: precisa da transcrição em texto' : /^image\//.test(tipo) ? 'Imagem (não lida por enquanto)' : 'Formato não lido: converta para Google Docs ou PDF';
          else if (total >= LER_MAX_TOTAL) item.motivo = 'Limite de texto da leitura atingido';
          else { t = t.slice(0, Math.min(LER_MAX_TEXTO, LER_MAX_TOTAL - total)); total += t.length; item.texto = t; item.lido = true; }
        }
      } catch (err) { item.motivo = 'Não deu para abrir: ' + String(err && err.message || err); }
      saida.push(item);
    }
    const subs = pasta.getFolders();
    while (subs.hasNext() && saida.length < LER_MAX_ARQUIVOS) { const s = subs.next(); visita(s, caminho + ' › ' + s.getName(), rotulo); }
  };
  (b.pastas || []).forEach(p => {
    try { const f = DriveApp.getFolderById(p.id); visita(f, f.getName(), p.rotulo || ''); }
    catch (err) { pastasErro.push({ id: p.id, rotulo: p.rotulo || '', erro: 'Sem acesso a esta pasta (confira se foi compartilhada com ' + Session.getEffectiveUser().getEmail() + ')' }); }
  });
  return { ok: true, versao: 2, arquivos: saida, pastas_com_erro: pastasErro, limite_arquivos: saida.length >= LER_MAX_ARQUIVOS };
}
