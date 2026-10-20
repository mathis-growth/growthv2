(function(){
const D = window.__SEED || {}; window.__D = D; window.__calls = [];
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : 'id' + Math.random().toString(36).slice(2));
const FK = { campanhas: 'campanha_id', produtos: 'produto_id', funis: 'funil_id', funil_etapas: 'etapa_id', motivos_resultado: 'negocio_motivo_id', fontes_video: 'fonte_id', fornecedores: 'fornecedor_id', plataformas_venda: 'plataforma_id', contrato_itens: null };
function from(t) {
  const st = { t, op: 'select', f: [], ord: null, lim: null, single: false, payload: null, onConflict: null, sel: '*' };
  const run = () => {
    if ((window.__SEM || []).includes(t)) return { data: null, error: { message: "relation \"public." + t + "\" does not exist" } };
    if (D[t] === undefined && !Array.isArray(D[t])) D[t] = [];
    const rows = D[t];
    if (!Array.isArray(rows)) return { data: rows, error: null };
    const match = r => st.f.every(([k, op, v]) => op === 'eq' ? r[k] === v : op === 'neq' ? r[k] !== v : op === 'in' ? v.includes(r[k]) : op === 'gte' ? r[k] >= v : op === 'lte' ? r[k] <= v : op === 'gt' ? r[k] > v : op === 'lt' ? r[k] < v : op === 'like' ? String(r[k] || '').startsWith(String(v).replace(/%$/, '')) : op === 'is' ? r[k] == v : op === 'not' ? true : true);
    if (st.op === 'insert') { const arr = [].concat(st.payload).map(x => ({ id: uid(), criado_em: new Date().toISOString(), ...x })); rows.push(...arr); return { data: st.single ? arr[0] : arr, error: null }; }
    if (st.op === 'upsert') { const keys = (st.onConflict || 'id').split(','); [].concat(st.payload).forEach(x => { const i = rows.findIndex(r => keys.every(k => r[k] === x[k])); if (i >= 0) Object.assign(rows[i], x); else rows.push({ id: uid(), ...x }); }); return { data: null, error: null }; }
    if (st.op === 'update') { rows.filter(match).forEach(r => Object.assign(r, st.payload)); return { data: null, error: null }; }
    if (st.op === 'delete') { D[t] = rows.filter(r => !match(r)); return { data: null, error: null }; }
    let out = rows.filter(match);
    if (st.ord) { const [k, asc] = st.ord; out = out.slice().sort((a, b) => (a[k] > b[k] ? 1 : a[k] < b[k] ? -1 : 0) * (asc ? 1 : -1)); }
    if (st.lim != null) out = out.slice(0, st.lim);
    out = out.map(r => { const o = { ...r }; String(st.sel || '').replace(/(\w+)\(([^)]*)\)/g, (m, tb) => { const fk = FK[tb] !== undefined ? FK[tb] : tb.replace(/s$/, '') + '_id'; if (fk) o[tb] = (D[tb] || []).find(x => x.id === r[fk]) || null; return m; }); return o; });
    if (st.single) return { data: out[0] || null, error: out[0] ? null : { message: 'não encontrado' } };
    return { data: out, error: null };
  };
  const p = new Proxy(function () {}, { get(_, k) {
    if (k === 'then') return (res, rej) => { try { res(run()); } catch (e) { rej(e); } };
    if (k === 'catch') return fn => Promise.resolve(run());
    return (...a) => { window.__calls.push([t, k, a[0]]);
      if (k === 'select') { if (st.op === 'select') st.sel = a[0]; }
      else if (['insert', 'update', 'delete', 'upsert'].includes(k)) { st.op = k; st.payload = a[0]; if (k === 'upsert' && a[1]) st.onConflict = a[1].onConflict; }
      else if (['eq', 'neq', 'in', 'gte', 'lte', 'gt', 'lt', 'like', 'is'].includes(k)) st.f.push([a[0], k, a[1]]);
      else if (k === 'order') { if (!st.ord) st.ord = [a[0], !(a[1] && a[1].ascending === false)]; }
      else if (k === 'limit') st.lim = a[0];
      else if (k === 'single' || k === 'maybeSingle') st.single = true;
      return p; };
  } });
  return p;
}
const rpc = (n, a) => { window.__calls.push(['rpc', n, a]); const f = window.__RPC && window.__RPC[n];
  const r = () => { if (f) { try { return { data: f(a, D), error: null }; } catch (e) { return { data: null, error: { message: e.message } }; } } const v = D['rpc:' + n]; return { data: v === undefined ? null : v, error: null }; };
  return { then: (res) => res(r()), catch: () => Promise.resolve(r()) }; };
window.supabase = { createClient: () => ({ from, rpc, auth: { getSession: async () => ({ data: { session: { user: { email: 't@t.com' } } } }), onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }), signOut: async () => {} }, storage: { from: () => ({}) }, channel: () => ({ on() { return this; }, subscribe() { return this; } }), removeChannel: () => {} }) };
})();
