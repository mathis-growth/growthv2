const FX = window.FIXTURE; FX.campanha_calculos = FX.campanha_calculos || []; window.GRAVADOS = [];
function B(t) { this.t = t; this.f = []; this.op = 'select'; }
B.prototype.select = function () { return this; }; B.prototype.order = function () { return this; }; B.prototype.limit = function () { return this; }; B.prototype.range = function (a, b) { this.rg = [a, b]; return this; }; B.prototype.single = function () { this.um = true; return this; };
B.prototype.eq = function (c, v) { this.f.push(r => c.includes('->>') ? (r[c.split('->>')[0]] || {})[c.split('->>')[1]] === v : String(r[c]) === String(v)); return this; };
B.prototype.ilike = function (c, v) { const re = new RegExp('^' + v.replace(/%/g, '.*') + '$', 'i'); this.f.push(r => re.test(r[c] || '')); return this; };
B.prototype.in = function (c, vs) { this.f.push(r => vs.includes(r[c])); return this; };
B.prototype.or = function () { return this; };
B.prototype.insert = function (v) { this.op = 'insert'; this.v = v; return this; }; B.prototype.update = function (v) { this.op = 'update'; this.v = v; return this; };
B.prototype.run = function () { if (this.op === 'insert') { const row = { id: 'calc-' + (GRAVADOS.length + 1), ...this.v }; FX.campanha_calculos.push(row); GRAVADOS.push(['insert', row]); return this.um ? row : [row]; }
  let rows = (FX[this.t] || []).filter(r => this.f.every(f => f(r))); if (this.op === 'update') { rows.forEach(r => Object.assign(r, this.v)); GRAVADOS.push(['update', this.v]); return rows; }
  if (this.rg) rows = rows.slice(this.rg[0], this.rg[1] + 1); return this.um ? rows[0] : rows; };
window.sb = { from: t => new B(t) }; window.q = async b => JSON.parse(JSON.stringify(b.run())); window.S = { ws: '0583533e-7818-49f2-b8ef-3cd4ecfc551a' }; window.VIEWS = {};
window.gcTodos = async mk => { let r = [], i = 0; for (;;) { const p = await q(mk().range(i, i + 999)); r = r.concat(p); if (p.length < 1000 || i > 200000) return r; i += 1000; } };
