/**
 * Growths — pastas do Growth's Content no Google Drive.
 * Roda na conta da Rebecka (as pastas ficam no nome dela). O Growths chama este endereço com a senha abaixo.
 * Implantar: Implantar → Gerenciar implantações → editar (lápis) → Versão: Nova versão → Implantar.
 *   (Primeira vez: Nova implantação → App da Web → Executar como: Eu → Quem pode acessar: Qualquer pessoa.)
 * Ações:
 *   teste          → confere a senha e a pasta raiz
 *   criar_cliente  → cria (ou completa) a pasta do cliente e a árvore de subpastas
 *   ler            → lê os arquivos das pastas pedidas: texto de Docs, Planilhas, Apresentações, Word, Excel, PowerPoint
 *                    (convertidos na hora), .txt/.md/.csv; PDF em base64 (até 4 MB); fontes e .zip são ignorados.
 *                    Pastas da Mathisa primeiro; cada pasta tem limite próprio de arquivos e de texto.
 * Depois de colar uma versão nova: rode a função "autorizar" uma vez (Executar) e reimplante como Nova versão.
 */
const SENHA = '<SENHA — a mesma de sistema_config.drive_script_senha>';

const EMAIL_MATHISA = 'rebecka@rebeckacappello.com.br'; // só para a mensagem de pasta sem acesso
const LER_MAX_ARQUIVOS = 120;         // por pedido (cada pasta tem o próprio limite, abaixo)
const LER_MAX_TEXTO = 60000;          // caracteres por arquivo
const LER_MAX_TOTAL = 600000;         // caracteres somando tudo
const LER_MAX_PDF = 4 * 1024 * 1024;  // bytes por PDF

function doPost(e) {
  const responde = o => ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
  const trava = LockService.getScriptLock();
  try {
    const b = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (b.senha !== SENHA) return responde({ ok: false, erro: 'Senha inválida' });
    if (b.acao === 'ler') return responde(ler_(b));
    const raiz = DriveApp.getFolderById(b.raiz);
    if (b.acao === 'teste') return responde({ ok: true, raiz: raiz.getName(), versao: 4 });
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
// Rode esta função UMA VEZ no editor (botão Executar) para o Google pedir as permissões de ler Documentos, Planilhas,
// Apresentações e converter Word/Excel/PowerPoint. Reimplantar sozinho não pede essas permissões.
function autorizar() {
  DriveApp.getRootFolder().getName();
  try { DocumentApp.getActiveDocument(); } catch (x) {}
  try { SpreadsheetApp.getActiveSpreadsheet(); } catch (x) {}
  try { SlidesApp.getActivePresentation(); } catch (x) {}
  UrlFetchApp.getRequest('https://www.googleapis.com/drive/v3/about?fields=user');
  return 'Permissões ok';
}

const ORDEM_ROTULO = { mathisa: 0, cliente: 1, 'cliente-extra': 2 };
const POR_PASTA_ARQ = 30, POR_PASTA_TEXTO = 150000, POR_PASTA_PDF = 3;
const LER_MAX_PDF_BYTES = 12 * 1024 * 1024;    // somando todos os PDFs (o pedido para a IA tem limite de tamanho)
const IGNORAR = /(font|zip|x-rar|octet-stream|x-7z|executable|x-msdownload|epub)/i;
const CONVERTE = {
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': MimeType.GOOGLE_DOCS,
  'application/msword': MimeType.GOOGLE_DOCS,
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': MimeType.GOOGLE_SHEETS,
  'application/vnd.ms-excel': MimeType.GOOGLE_SHEETS,
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': MimeType.GOOGLE_SLIDES,
  'application/vnd.ms-powerpoint': MimeType.GOOGLE_SLIDES };

// b.pastas = [{ id, rotulo }], b.desde = ISO (opcional: só arquivos alterados depois)
function ler_(b) {
  const desde = b.desde ? new Date(b.desde) : null;
  const saida = [], pastasErro = [];
  let total = 0, pdfBytes = 0, ignorados = 0;
  const textoGoogle = (id, tipo) => {
    if (tipo === MimeType.GOOGLE_DOCS) return DocumentApp.openById(id).getBody().getText();
    if (tipo === MimeType.GOOGLE_SHEETS) {
      return SpreadsheetApp.openById(id).getSheets().slice(0, 5).map(sh => {
        const v = sh.getDataRange().getDisplayValues().slice(0, 400);
        return '## ' + sh.getName() + '\n' + v.map(l => l.join(' | ')).join('\n');
      }).join('\n\n');
    }
    if (tipo === MimeType.GOOGLE_SLIDES) {
      return SlidesApp.openById(id).getSlides().map((sl, i) => '## Lâmina ' + (i + 1) + '\n' + sl.getShapes().map(s => { try { return s.getText().asString(); } catch (x) { return ''; } }).filter(t => t.trim()).join('\n')).join('\n\n');
    }
    return null;
  };
  // Word, Excel e PowerPoint: cria uma cópia convertida, lê e manda a cópia para a lixeira
  const converteELe = (arq, alvo) => {
    const r = UrlFetchApp.fetch('https://www.googleapis.com/drive/v3/files/' + arq.getId() + '/copy?fields=id', {
      method: 'post', contentType: 'application/json', muteHttpExceptions: true,
      headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() }, payload: JSON.stringify({ name: '[Growths leitura] ' + arq.getName(), mimeType: alvo }) });
    if (r.getResponseCode() !== 200) throw new Error('não deu para converter (' + r.getResponseCode() + ')');
    const id = JSON.parse(r.getContentText()).id;
    try { return textoGoogle(id, alvo); } finally { try { DriveApp.getFileById(id).setTrashed(true); } catch (x) {} }
  };
  const textoDe = (arq, tipo) => {
    const g = textoGoogle(arq.getId(), tipo);
    if (g != null) return g;
    if (CONVERTE[tipo]) return converteELe(arq, CONVERTE[tipo]);
    if (/^text\//.test(tipo) || /\.(md|txt|csv|srt|vtt)$/i.test(arq.getName())) return arq.getBlob().getDataAsString('UTF-8');
    return null;
  };
  const lePasta = (raiz, rotulo) => {
    const orc = { arq: 0, texto: 0, pdf: 0 };
    const visita = (pasta, caminho) => {
      const arqs = pasta.getFiles();
      while (arqs.hasNext() && orc.arq < POR_PASTA_ARQ && saida.length < LER_MAX_ARQUIVOS) {
        const a = arqs.next(), tipo = a.getMimeType(), mod = a.getLastUpdated();
        if (desde && mod <= desde) continue;
        if (IGNORAR.test(tipo) || /\.(otf|ttf|woff2?|zip|rar)$/i.test(a.getName())) { ignorados++; continue; }
        orc.arq++;
        const item = { id: a.getId(), nome: a.getName(), caminho: caminho, rotulo: rotulo, tipo: tipo, modificado: mod.toISOString(), tamanho: a.getSize(), url: a.getUrl(), lido: false };
        try {
          if (tipo === MimeType.PDF) {
            if (a.getSize() > LER_MAX_PDF) item.motivo = 'PDF grande demais (acima de 4 MB)';
            else if (orc.pdf >= POR_PASTA_PDF || pdfBytes + a.getSize() > LER_MAX_PDF_BYTES) item.motivo = 'Limite de PDFs desta leitura atingido';
            else { item.pdf_base64 = Utilities.base64Encode(a.getBlob().getBytes()); item.lido = true; orc.pdf++; pdfBytes += a.getSize(); }
          } else if (/^(video|audio)\//.test(tipo)) item.motivo = 'Vídeo ou áudio: precisa da transcrição em texto';
          else if (/^image\//.test(tipo)) item.motivo = 'Imagem (não lida por enquanto)';
          else {
            let t = textoDe(a, tipo);
            const resta = Math.min(LER_MAX_TEXTO, POR_PASTA_TEXTO - orc.texto, LER_MAX_TOTAL - total);
            if (t == null) item.motivo = 'Formato não lido: converta para Google Docs ou PDF';
            else if (resta <= 0) item.motivo = 'Limite de texto desta pasta atingido';
            else { t = t.slice(0, resta); total += t.length; orc.texto += t.length; item.texto = t; item.lido = true; }
          }
        } catch (err) { item.motivo = 'Não deu para abrir: ' + String(err && err.message || err); }
        saida.push(item);
      }
      const subs = pasta.getFolders();
      while (subs.hasNext() && orc.arq < POR_PASTA_ARQ && saida.length < LER_MAX_ARQUIVOS) { const s = subs.next(); visita(s, caminho + ' › ' + s.getName()); }
    };
    visita(raiz, raiz.getName());
  };
  (b.pastas || []).slice().sort((x, y) => (ORDEM_ROTULO[x.rotulo] ?? 9) - (ORDEM_ROTULO[y.rotulo] ?? 9)).forEach(p => {
    let f = null;
    try { f = DriveApp.getFolderById(p.id); f.getName(); }
    catch (err) { pastasErro.push({ id: p.id, rotulo: p.rotulo || '', erro: 'Sem acesso a esta pasta (confira se foi compartilhada com ' + (b.email || EMAIL_MATHISA) + ')' }); return; }
    lePasta(f, p.rotulo || '');
  });
  return { ok: true, versao: 4, arquivos: saida, pastas_com_erro: pastasErro, ignorados: ignorados, limite_arquivos: saida.length >= LER_MAX_ARQUIVOS };
}
