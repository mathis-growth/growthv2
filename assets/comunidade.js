(() => {
  'use strict';

  const TIPOS_COMUNIDADE = [
    ['publica', 'Pública'], ['gratuita', 'Gratuita'], ['privada', 'Privada'],
    ['premium', 'Premium'], ['alunos', 'Exclusiva para alunos'],
    ['assinantes', 'Exclusiva para assinantes'], ['convite', 'Por convite']
  ];
  const TIPOS_ESPACO = [
    ['feed', 'Feed'], ['perguntas', 'Perguntas e respostas'], ['cursos', 'Aprendizado'],
    ['eventos', 'Eventos'], ['biblioteca', 'Biblioteca']
  ];
  const ACESSOS_ESPACO = [
    ['todos', 'Público'], ['membros', 'Membros da comunidade'], ['alunos', 'Alunos'],
    ['assinantes', 'Assinantes'], ['privado', 'Acesso restrito']
  ];
  const tipoLabel = (lista, chave) => lista.find(([valor]) => valor === chave)?.[1] || chave;
  const slugify = valor => String(valor || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);
  const escHtml = valor => String(valor ?? '').replace(/[&<>"']/g, caractere => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[caractere]);
  const selectOptions = (lista, selecionado) => lista.map(([valor, rotulo]) =>
    `<option value="${valor}"${valor === selecionado ? ' selected' : ''}>${rotulo}</option>`).join('');
  const comunidadePodeEditar = () => nivelMod('revops') !== 'ler' || souAdmin();
  const webUrl = value => {
    const text = String(value || '').trim();
    if (!text) return null;
    try { const parsed = new URL(text); return ['https:', 'http:'].includes(parsed.protocol) ? parsed.href : null; }
    catch { return null; }
  };

  function estilos() {
    if (document.getElementById('comunidadeAdminCss')) return;
    const style = document.createElement('style');
    style.id = 'comunidadeAdminCss';
    style.textContent = `
      .com-admin{display:grid;gap:16px}.com-admin .com-head{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;flex-wrap:wrap}
      .com-admin .com-head h1{margin:0 0 4px}.com-admin .com-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}
      .com-admin .com-card{overflow:hidden;padding:0}.com-admin .com-cover{height:90px;background:linear-gradient(120deg,var(--com-cor,#2457d6),#172c69);position:relative}.com-admin .com-cover>img{width:100%;height:100%;object-fit:cover}
      .com-admin .com-logo{width:54px;height:54px;border-radius:14px;object-fit:cover;background:var(--surface);border:3px solid var(--surface);position:absolute;left:16px;bottom:-20px;display:grid;place-items:center;color:var(--accent);font-weight:700;font-size:20px}
      .com-admin .com-body{padding:28px 16px 16px}.com-admin .com-card-title{display:flex;align-items:flex-start;justify-content:space-between;gap:8px}
      .com-admin .com-card-title h2{font-size:16px;margin:0}.com-admin .com-meta{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0;color:var(--muted);font-size:12px}
      .com-admin .com-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}.com-admin .com-actions .btn{white-space:nowrap}
      .com-admin .com-tabs{display:flex;gap:8px;flex-wrap:wrap}.com-admin .com-tabs button.on{background:var(--accent);color:#fff;border-color:var(--accent)}
      .com-admin .com-space-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:center;padding:12px;border:1px solid var(--line);border-radius:10px;margin-top:8px}
      .com-admin .com-space-row h3{font-size:14px;margin:0 0 4px}.com-admin .com-empty{padding:30px;text-align:center}.com-admin .com-kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px}
      @media(max-width:640px){.com-admin .com-space-row{grid-template-columns:1fr}.com-admin .com-space-row .com-actions{margin-top:0}}
    `;
    document.head.appendChild(style);
  }

  const badge = (texto, ativo) => `<span class="pill ${ativo ? 'good' : 'neutral'}">${texto}</span>`;
  const activeText = value => value ? 'Ativo' : 'Arquivado';

  async function listaComunidades(workspaceId) {
    const rows = await q(sb.from('comunidades').select('*').eq('workspace_id', workspaceId).order('atualizado_em', { ascending: false }));
    if (!rows.length) return [];
    const ids = rows.map(row => row.id);
    const spaces = await q(sb.from('comunidade_espacos').select('id,comunidade_id,ativo').eq('workspace_id', workspaceId).in('comunidade_id', ids));
    const counts = new Map();
    for (const space of spaces) counts.set(space.comunidade_id, (counts.get(space.comunidade_id) || 0) + (space.ativo ? 1 : 0));
    return rows.map(row => ({ ...row, espacos_ativos: counts.get(row.id) || 0 }));
  }

  function comunidadeModal(comunidade = null) {
    const form = modal(comunidade ? 'Editar comunidade' : 'Criar comunidade', `
      <div class="grid2">
        <label>Nome da comunidade<input name="nome" required maxlength="120" value="${escHtml(comunidade?.nome || '')}" placeholder="Ex.: Mentoria Médico 2.0"></label>
        <label>Identificador da URL<input name="slug" required pattern="[a-z0-9]+(-[a-z0-9]+)*" maxlength="80" value="${escHtml(comunidade?.slug || '')}" placeholder="mentoria-medico-2"></label>
        <label>Modelo de acesso<select name="tipo">${selectOptions(TIPOS_COMUNIDADE, comunidade?.tipo || 'privada')}</select></label>
        <label>Status<select name="status">${selectOptions([['rascunho', 'Rascunho'], ['ativa', 'Ativa'], ['arquivada', 'Arquivada']], comunidade?.status || 'rascunho')}</select></label>
        <label>Cor principal<input name="cor_primaria" type="color" value="${escHtml(comunidade?.cor_primaria || '#2457d6')}"></label>
        <label>URL do logotipo<input name="logo_url" type="url" value="${escHtml(comunidade?.logo_url || '')}" placeholder="https://..."></label>
        <label style="grid-column:1/-1">URL da capa<input name="capa_url" type="url" value="${escHtml(comunidade?.capa_url || '')}" placeholder="https://..."></label>
        <label style="grid-column:1/-1">Descrição<textarea name="descricao" rows="3" maxlength="2000" placeholder="Para quem é esta comunidade e o que encontrará nela">${escHtml(comunidade?.descricao || '')}</textarea></label>
      </div>
      <p class="muted">O identificador será usado para montar o endereço do portal quando a experiência dos membros for criada.</p>`, async dados => {
      const slug = slugify(dados.slug);
      if (!slug) throw new Error('Informe um identificador com letras, números e hífens.');
      const registro = {
        workspace_id: S.ws, nome: dados.nome.trim(), slug, tipo: dados.tipo, status: dados.status,
        descricao: dados.descricao.trim(), logo_url: webUrl(dados.logo_url),
        capa_url: webUrl(dados.capa_url), cor_primaria: dados.cor_primaria,
        atualizado_em: new Date().toISOString()
      };
      if (dados.logo_url.trim() && !registro.logo_url) throw new Error('A URL do logotipo precisa começar com http:// ou https://.');
      if (dados.capa_url.trim() && !registro.capa_url) throw new Error('A URL da capa precisa começar com http:// ou https://.');
      const query = comunidade
        ? sb.from('comunidades').update(registro).eq('id', comunidade.id).eq('workspace_id', S.ws)
        : sb.from('comunidades').insert(registro);
      await q(query);
      toast(comunidade ? 'Comunidade atualizada.' : 'Comunidade criada.');
    }, comunidade ? 'Salvar alterações' : 'Criar comunidade', true);
    const nome = form?.querySelector('[name="nome"]');
    const slug = form?.querySelector('[name="slug"]');
    if (nome && slug && !comunidade) {
      let alteracaoManual = false;
      slug.addEventListener('input', () => { alteracaoManual = true; });
      nome.addEventListener('input', () => { if (!alteracaoManual) slug.value = slugify(nome.value); });
    }
  }

  function modalGrupo(comunidade, grupo = null) {
    modal(grupo ? 'Editar grupo de espaços' : 'Novo grupo de espaços', `
      <label>Nome do grupo<input name="nome" required maxlength="100" value="${escHtml(grupo?.nome || '')}" placeholder="Ex.: Comece aqui"></label>
      <label>Descrição<textarea name="descricao" rows="3" maxlength="1000">${escHtml(grupo?.descricao || '')}</textarea></label>
      <label>Ordem<input name="ordem" type="number" min="0" step="1" value="${Number(grupo?.ordem || 0)}"></label>
      ${grupo ? `<label class="chk"><input type="checkbox" name="ativo"${grupo.ativo ? ' checked' : ''}> Grupo ativo</label>` : ''}`,
    async dados => {
      const patch = { nome: dados.nome.trim(), descricao: dados.descricao.trim(), ordem: Number(dados.ordem || 0), atualizado_em: new Date().toISOString() };
      if (grupo) {
        patch.ativo = !!dados.ativo;
        await q(sb.from('comunidade_grupos').update(patch).eq('id', grupo.id).eq('workspace_id', S.ws));
      } else await q(sb.from('comunidade_grupos').insert({ ...patch, workspace_id: S.ws, comunidade_id: comunidade.id }));
      toast(grupo ? 'Grupo atualizado.' : 'Grupo criado.');
    }, grupo ? 'Salvar' : 'Criar grupo');
  }

  function modalEspaco(comunidade, grupos, espaco = null) {
    const grupoOptions = [['', 'Sem grupo'], ...grupos.map(grupo => [grupo.id, grupo.nome])];
    modal(espaco ? 'Editar espaço' : 'Novo espaço', `
      <div class="grid2">
        <label>Nome do espaço<input name="nome" required maxlength="100" value="${escHtml(espaco?.nome || '')}" placeholder="Ex.: Avisos importantes"></label>
        <label>Endereço do espaço<input name="slug" required pattern="[a-z0-9]+(-[a-z0-9]+)*" maxlength="80" value="${escHtml(espaco?.slug || '')}" placeholder="avisos-importantes"></label>
        <label>Grupo<select name="grupo_id">${selectOptions(grupoOptions, espaco?.grupo_id || '')}</select></label>
        <label>Tipo de espaço<select name="tipo">${selectOptions(TIPOS_ESPACO, espaco?.tipo || 'feed')}</select></label>
        <label>Quem pode acessar<select name="acesso">${selectOptions(ACESSOS_ESPACO, espaco?.acesso || 'membros')}</select></label>
        <label>Ordem<input name="ordem" type="number" min="0" step="1" value="${Number(espaco?.ordem || 0)}"></label>
        <label style="grid-column:1/-1">Descrição<textarea name="descricao" rows="3" maxlength="1000">${escHtml(espaco?.descricao || '')}</textarea></label>
        ${espaco ? `<label class="chk" style="grid-column:1/-1"><input type="checkbox" name="ativo"${espaco.ativo ? ' checked' : ''}> Espaço ativo</label>` : ''}
      </div>`, async dados => {
      const slug = slugify(dados.slug);
      if (!slug) throw new Error('Informe um identificador válido para o espaço.');
      const patch = {
        workspace_id: S.ws, comunidade_id: comunidade.id, grupo_id: dados.grupo_id || null,
        nome: dados.nome.trim(), slug, descricao: dados.descricao.trim(), tipo: dados.tipo,
        acesso: dados.acesso, ordem: Number(dados.ordem || 0), atualizado_em: new Date().toISOString()
      };
      if (espaco) {
        patch.ativo = !!dados.ativo;
        await q(sb.from('comunidade_espacos').update(patch).eq('id', espaco.id).eq('workspace_id', S.ws));
      } else await q(sb.from('comunidade_espacos').insert(patch));
      toast(espaco ? 'Espaço atualizado.' : 'Espaço criado.');
    }, espaco ? 'Salvar' : 'Criar espaço', true);
    const form = document.querySelector('#modalRoot form');
    const nome = form?.querySelector('[name="nome"]');
    const slug = form?.querySelector('[name="slug"]');
    if (nome && slug && !espaco) {
      let manual = false;
      slug.addEventListener('input', () => { manual = true; });
      nome.addEventListener('input', () => { if (!manual) slug.value = slugify(nome.value); });
    }
  }

  async function renderEspacos(root, comunidade) {
    const [grupos, espacos] = await Promise.all([
      q(sb.from('comunidade_grupos').select('*').eq('workspace_id', S.ws).eq('comunidade_id', comunidade.id).order('ordem').order('nome')),
      q(sb.from('comunidade_espacos').select('*').eq('workspace_id', S.ws).eq('comunidade_id', comunidade.id).order('ordem').order('nome'))
    ]);
    const editavel = comunidadePodeEditar();
    const porGrupo = new Map(grupos.map(grupo => [grupo.id, []]));
    const semGrupo = [];
    for (const espaco of espacos) (porGrupo.get(espaco.grupo_id) || semGrupo).push(espaco);
    const linha = espaco => `<div class="com-space-row"><div><h3>${escHtml(espaco.nome)} ${badge(activeText(espaco.ativo), espaco.ativo)}</h3>
      <div class="muted">${tipoLabel(TIPOS_ESPACO, espaco.tipo)} · ${tipoLabel(ACESSOS_ESPACO, espaco.acesso)} · /${escHtml(espaco.slug)}</div>
      ${espaco.descricao ? `<p class="muted">${escHtml(espaco.descricao)}</p>` : ''}</div>
      <div class="com-actions">${editavel ? `<button class="btn sm" data-space-edit="${espaco.id}">Editar</button>` : ''}</div></div>`;
    const grupoMarkup = grupos.map(grupo => `<section class="panel"><div class="com-head"><div><h2>${escHtml(grupo.nome)} ${badge(activeText(grupo.ativo), grupo.ativo)}</h2>${grupo.descricao ? `<p class="muted">${escHtml(grupo.descricao)}</p>` : ''}</div>
      ${editavel ? `<button class="btn sm" data-group-edit="${grupo.id}">Editar grupo</button>` : ''}</div>
      ${(porGrupo.get(grupo.id) || []).map(linha).join('') || '<p class="muted">Ainda não há espaços neste grupo.</p>'}</section>`).join('');
    root.innerHTML = `<div class="com-admin">
      <div class="com-head"><div><button class="btn sm" data-com-back>← Comunidades</button><h1 style="margin-top:12px">${escHtml(comunidade.nome)}</h1><p class="muted">Organize grupos e espaços desta comunidade.</p></div>
        ${editavel ? `<div class="com-actions"><button class="btn" data-group-new>Novo grupo</button><button class="btn pri" data-space-new>Novo espaço</button></div>` : ''}</div>
      <div class="com-kpis">${kpi('Grupos', num(grupos.length), 'Na comunidade')}${kpi('Espaços ativos', num(espacos.filter(e => e.ativo).length), 'Dentro dos grupos')}</div>
      ${grupoMarkup || '<section class="panel com-empty"><h2>Comece criando um grupo</h2><p class="muted">Use grupos para organizar os espaços por tema ou etapa.</p></section>'}
      ${semGrupo.length ? `<section class="panel"><h2>Sem grupo</h2>${semGrupo.map(linha).join('')}</section>` : ''}
    </div>`;
    root.querySelector('[data-com-back]').onclick = () => { S.comunidadeAdminId = null; render(); };
    if (editavel) {
      root.querySelector('[data-group-new]').onclick = () => modalGrupo(comunidade);
      root.querySelector('[data-space-new]').onclick = () => modalEspaco(comunidade, grupos);
      root.querySelectorAll('[data-group-edit]').forEach(button => button.onclick = () => {
        const grupo = grupos.find(item => item.id === button.dataset.groupEdit);
        modalGrupo(comunidade, grupo);
      });
      root.querySelectorAll('[data-space-edit]').forEach(button => button.onclick = () => {
        modalEspaco(comunidade, grupos, espacos.find(item => item.id === button.dataset.spaceEdit));
      });
    }
  }

  async function comunidadeAdmin(root) {
    estilos();
    const workspaceId = S.ws;
    if (S.comunidadeAdminId) {
      const comunidade = (await q(sb.from('comunidades').select('*').eq('workspace_id', workspaceId).eq('id', S.comunidadeAdminId).maybeSingle()));
      if (comunidade) return renderEspacos(root, comunidade);
      S.comunidadeAdminId = null;
    }
    const comunidades = await listaComunidades(workspaceId);
    const editavel = comunidadePodeEditar();
    const cards = comunidades.map(comunidade => `<article class="panel com-card" style="--com-cor:${escHtml(comunidade.cor_primaria || '#2457d6')}">
      <div class="com-cover">${webUrl(comunidade.capa_url) ? `<img src="${escHtml(webUrl(comunidade.capa_url))}" alt="">` : ''}
        ${webUrl(comunidade.logo_url) ? `<img class="com-logo" src="${escHtml(webUrl(comunidade.logo_url))}" alt="">` : `<div class="com-logo" aria-hidden="true">${escHtml(comunidade.nome.slice(0, 1).toUpperCase())}</div>`}</div>
      <div class="com-body"><div class="com-card-title"><h2>${escHtml(comunidade.nome)}</h2>${badge(tipoLabel([['rascunho','Rascunho'],['ativa','Ativa'],['arquivada','Arquivada']], comunidade.status), comunidade.status === 'ativa')}</div>
        <div class="com-meta"><span>${tipoLabel(TIPOS_COMUNIDADE, comunidade.tipo)}</span><span>/${escHtml(comunidade.slug)}</span><span>${num(comunidade.espacos_ativos)} espaços ativos</span></div>
        ${comunidade.descricao ? `<p class="muted">${escHtml(comunidade.descricao)}</p>` : '<p class="muted">Sem descrição cadastrada.</p>'}
        <div class="com-actions"><button class="btn pri" data-com-manage="${comunidade.id}">Gerenciar espaços</button>${editavel ? `<button class="btn" data-com-edit="${comunidade.id}">Editar</button><button class="btn" data-com-toggle="${comunidade.id}">${comunidade.status === 'arquivada' ? 'Reabrir' : 'Arquivar'}</button>` : ''}</div>
      </div></article>`).join('');
    root.innerHTML = `<div class="com-admin"><div class="com-head"><div><h1>Comunidades</h1><p class="muted">Crie comunidades e organize seus espaços. O portal dos membros será conectado na próxima etapa.</p></div>${editavel ? '<button class="btn pri" id="comNovo">＋ Nova comunidade</button>' : ''}</div>
      <div class="com-kpis">${kpi('Comunidades', num(comunidades.length), 'Neste workspace')}${kpi('Ativas', num(comunidades.filter(c => c.status === 'ativa').length), 'Disponíveis para configuração')}${kpi('Espaços ativos', num(comunidades.reduce((total, c) => total + c.espacos_ativos, 0)), 'Somando as comunidades')}</div>
      ${cards ? `<div class="com-grid">${cards}</div>` : `<section class="panel com-empty"><h2>Crie a primeira comunidade</h2><p class="muted">Cadastre uma comunidade para começar a organizar grupos e espaços.</p>${editavel ? '<button class="btn pri" id="comNovoVazio">Criar comunidade</button>' : ''}</section>`}</div>`;
    const novo = root.querySelector('#comNovo') || root.querySelector('#comNovoVazio');
    if (novo) novo.onclick = () => comunidadeModal();
    root.querySelectorAll('[data-com-manage]').forEach(button => button.onclick = () => { S.comunidadeAdminId = button.dataset.comManage; render(); });
    if (editavel) {
      root.querySelectorAll('[data-com-edit]').forEach(button => button.onclick = () => comunidadeModal(comunidades.find(item => item.id === button.dataset.comEdit)));
      root.querySelectorAll('[data-com-toggle]').forEach(button => button.onclick = () => {
        const comunidade = comunidades.find(item => item.id === button.dataset.comToggle);
        const arquivar = comunidade.status !== 'arquivada';
        modal(arquivar ? 'Arquivar comunidade' : 'Reabrir comunidade',
          `<p>${arquivar ? 'A comunidade deixará de aparecer como ativa. Seus dados e espaços serão mantidos.' : 'A comunidade voltará ao status de rascunho para continuar a configuração.'}</p>`,
          async () => {
            await q(sb.from('comunidades').update({ status: arquivar ? 'arquivada' : 'rascunho', atualizado_em: new Date().toISOString() }).eq('id', comunidade.id).eq('workspace_id', workspaceId));
            toast(arquivar ? 'Comunidade arquivada.' : 'Comunidade reaberta como rascunho.');
          }, arquivar ? 'Arquivar' : 'Reabrir');
      });
    }
  }

  window.comunidadeAdmin = comunidadeAdmin;
})();
