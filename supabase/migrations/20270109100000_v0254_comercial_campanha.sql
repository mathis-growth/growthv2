-- v0.254 — Comercial da campanha: vendedor interno ou externo, comissão e meta por campanha, link de cada vendedor.
-- A venda que chega com o código do vendedor (sck ou utm_content) já fica ligada a ele, e a comissão sai pelas regras que já existem.
-- Idempotente. Para desfazer: drop das funções e do gatilho abaixo, drop table campanha_vendedores, alter table equipe drop column externo.

alter table public.equipe add column if not exists externo boolean not null default false;

create table if not exists public.campanha_vendedores (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  equipe_id uuid not null references equipe(id) on delete cascade,
  comissao_pct numeric(6,3) check (comissao_pct is null or (comissao_pct >= 0 and comissao_pct <= 100)),
  base text not null default 'liquido' check (base in ('liquido', 'bruto')),
  meta_vendas int check (meta_vendas is null or meta_vendas >= 0),
  codigo text not null check (char_length(codigo) between 3 and 60),
  regra_id uuid references comissao_regras(id) on delete set null,
  criado_em timestamptz not null default now(),
  unique (campanha_id, equipe_id),
  unique (workspace_id, codigo)
);
create index if not exists campanha_vendedores_ws on public.campanha_vendedores (workspace_id, campanha_id);
alter table public.campanha_vendedores enable row level security;
drop policy if exists campanha_vendedores_acesso on public.campanha_vendedores;
create policy campanha_vendedores_acesso on public.campanha_vendedores for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on public.campanha_vendedores;
create policy perm_ler on public.campanha_vendedores as restrictive for select to authenticated using (perm(workspace_id, 'ler', array['mkt','adm','gro','vendas','fin']));
drop policy if exists perm_inserir on public.campanha_vendedores;
create policy perm_inserir on public.campanha_vendedores as restrictive for insert to authenticated with check (perm(workspace_id, 'editar', array['mkt','adm','vendas']));
drop policy if exists perm_alterar on public.campanha_vendedores;
create policy perm_alterar on public.campanha_vendedores as restrictive for update to authenticated using (perm(workspace_id, 'editar', array['mkt','adm','vendas'])) with check (perm(workspace_id, 'editar', array['mkt','adm','vendas']));
drop policy if exists perm_apagar on public.campanha_vendedores;
create policy perm_apagar on public.campanha_vendedores as restrictive for delete to authenticated using (perm(workspace_id, 'editar', array['mkt','adm','vendas']));

-- a comissão definida para a campanha vale mais que a da oferta ou do produto
do $m$
declare def text;
begin
  select pg_get_functiondef('public._comissao_regras_aplicaveis(uuid,date,uuid,uuid[],uuid,uuid,boolean)'::regprocedure) into def;
  def := replace(def, E'\r\n', E'\n');
  if position('v0.254' in def) = 0 then
    if position($$case r.escopo when 'oferta' then 4 when 'produto' then 3 when 'campanha' then 2 else 1 end desc$$ in def) = 0 then raise exception 'v0.254: ordem das regras não encontrada'; end if;
    def := replace(def, $$case r.escopo when 'oferta' then 4 when 'produto' then 3 when 'campanha' then 2 else 1 end desc$$, $$case r.escopo when 'campanha' then 5 when 'oferta' then 4 when 'produto' then 3 else 1 end desc /* v0.254 */$$);
    execute def;
  end if;
end $m$;

-- venda com o código do vendedor: liga ao vendedor e à campanha. Roda antes do vendedor automático (responsável pela pessoa).
create or replace function public.venda_vendedor_codigo() returns trigger language plpgsql security definer set search_path = public as $$
declare cv campanha_vendedores; cod text := coalesce(nullif(new.extras ->> 'sck', ''), nullif(new.utm_content, ''));
begin
  if new.vendedor_id is not null or cod is null then return new; end if;
  select * into cv from campanha_vendedores where workspace_id = new.workspace_id and codigo = cod;
  if cv.id is null then return new; end if;
  new.vendedor_id := cv.equipe_id;
  if new.campanha_id is null then new.campanha_id := cv.campanha_id; end if;
  return new;
end $$;
drop trigger if exists vendas_a_codigo_t on public.vendas;
create trigger vendas_a_codigo_t before insert or update of utm_content, extras on public.vendas for each row execute function public.venda_vendedor_codigo();

-- leitura: vendedores da campanha, os cadastrados nas ofertas ou produtos dela e os demais, com o realizado
create or replace function public.campanha_comercial(p_campanha uuid) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c campanhas; r jsonb;
begin
  select * into c from campanhas where id = p_campanha;
  if c.id is null or not pertence_ao_workspace(c.workspace_id) or not perm(c.workspace_id, 'ler', array['mkt','adm','gro','vendas','fin']) then raise exception 'Sem acesso a esta campanha'; end if;
  with ofs as (select oferta_id, produto_id from campanha_ofertas where campanha_id = p_campanha),
  vend as (select e.* from equipe e where e.workspace_id = c.workspace_id and e.ativo and (e.vinculo = 'vendedor' or e.equipe_comercial)),
  regra as (select distinct on (x.equipe_id) x.equipe_id, x.percentual, x.base from comissao_regras x
     where x.workspace_id = c.workspace_id and x.ativo and x.equipe_id in (select id from vend)
       and ((x.escopo = 'oferta' and x.oferta_id in (select oferta_id from ofs)) or (x.escopo = 'produto' and (x.produto_id in (select produto_id from ofs) or x.produto_id = c.produto_id)))
     order by x.equipe_id, case x.escopo when 'oferta' then 2 else 1 end desc, x.criado_em desc),
  res as (select v.vendedor_id, count(*) as vendas, sum(v.valor_bruto) as valor from vendas v where v.campanha_id = p_campanha and v.status = 'aprovada' and v.vendedor_id is not null group by 1),
  com as (select cm.equipe_id, sum(cm.valor) as valor from comissoes cm join vendas v on v.id = cm.venda_id where v.campanha_id = p_campanha and cm.status not in ('cancelada', 'estorno_pendente', 'estornada') group by 1)
  select jsonb_build_object(
    'vendedores', coalesce((select jsonb_agg(jsonb_build_object('equipe_id', cv.equipe_id, 'nome', e.nome, 'externo', e.externo, 'comissao_pct', cv.comissao_pct, 'base', cv.base, 'meta_vendas', cv.meta_vendas, 'codigo', cv.codigo, 'vendas', coalesce(res.vendas, 0), 'valor', coalesce(res.valor, 0), 'comissao', coalesce(com.valor, 0)) order by e.nome)
       from campanha_vendedores cv join equipe e on e.id = cv.equipe_id left join res on res.vendedor_id = cv.equipe_id left join com on com.equipe_id = cv.equipe_id where cv.campanha_id = p_campanha), '[]'::jsonb),
    'candidatos', coalesce((select jsonb_agg(jsonb_build_object('equipe_id', rg.equipe_id, 'nome', v.nome, 'externo', v.externo, 'comissao_pct', rg.percentual, 'base', rg.base) order by v.nome)
       from regra rg join vend v on v.id = rg.equipe_id where not exists (select 1 from campanha_vendedores cv where cv.campanha_id = p_campanha and cv.equipe_id = rg.equipe_id)), '[]'::jsonb),
    'outros', coalesce((select jsonb_agg(jsonb_build_object('equipe_id', v.id, 'nome', v.nome, 'externo', v.externo) order by v.nome)
       from vend v where not exists (select 1 from regra rg where rg.equipe_id = v.id) and not exists (select 1 from campanha_vendedores cv where cv.campanha_id = p_campanha and cv.equipe_id = v.id)), '[]'::jsonb)) into r;
  return r;
end $$;
revoke execute on function public.campanha_comercial(uuid) from public, anon;
grant execute on function public.campanha_comercial(uuid) to authenticated, service_role;

-- gravação: vendedores, metas e links, e a regra de comissão de cada um nesta campanha
create or replace function public.campanha_comercial_salvar(p_campanha uuid, p_itens jsonb) returns int language plpgsql security definer set search_path = public as $$
declare c campanhas; it jsonb; cv campanha_vendedores; pct numeric; b text; n int := 0; rid uuid; eq uuid; vd uuid;
begin
  select * into c from campanhas where id = p_campanha;
  if c.id is null or not pertence_ao_workspace(c.workspace_id) or not perm(c.workspace_id, 'editar', array['mkt','adm','vendas']) then raise exception 'Sem permissão para alterar o comercial desta campanha'; end if;
  if jsonb_typeof(p_itens) <> 'array' then raise exception 'Lista de vendedores inválida'; end if;
  -- quem saiu da lista: a regra deixa de valer
  for cv in select * from campanha_vendedores where campanha_id = p_campanha and equipe_id not in (select (e ->> 'equipe_id')::uuid from jsonb_array_elements(p_itens) e) loop
    if cv.regra_id is not null then update comissao_regras set ativo = false where id = cv.regra_id; end if;
    delete from campanha_vendedores where id = cv.id;
  end loop;
  for it in select * from jsonb_array_elements(p_itens) loop
    eq := (it ->> 'equipe_id')::uuid; pct := nullif(it ->> 'comissao_pct', '')::numeric; b := coalesce(nullif(it ->> 'base', ''), 'liquido');
    if not exists (select 1 from equipe where id = eq and workspace_id = c.workspace_id) then raise exception 'Vendedor não encontrado'; end if;
    if pct is not null and (pct < 0 or pct > 100) then raise exception 'A comissão vai de 0 a 100%%'; end if;
    insert into campanha_vendedores (workspace_id, campanha_id, equipe_id, comissao_pct, base, meta_vendas, codigo)
      values (c.workspace_id, p_campanha, eq, pct, b, nullif(it ->> 'meta_vendas', '')::int, it ->> 'codigo')
      on conflict (campanha_id, equipe_id) do update set comissao_pct = excluded.comissao_pct, base = excluded.base, meta_vendas = excluded.meta_vendas, codigo = excluded.codigo
      returning * into cv;
    rid := cv.regra_id;
    if coalesce(pct, 0) > 0 then
      if rid is null then
        insert into comissao_regras (workspace_id, equipe_id, escopo, campanha_id, percentual, base, sobre, observacao)
          values (c.workspace_id, eq, 'campanha', p_campanha, pct, b, 'proprias', 'Definida no Comercial da campanha') returning id into rid;
        update campanha_vendedores set regra_id = rid where id = cv.id;
      else update comissao_regras set percentual = pct, base = b, ativo = true where id = rid; end if;
    elsif rid is not null then update comissao_regras set ativo = false where id = rid; end if;
    n := n + 1;
  end loop;
  -- vendas que já estão ligadas aos vendedores desta campanha seguem a regra nova
  for vd in select id from vendas where campanha_id = p_campanha and vendedor_id is not null and status = 'aprovada' loop perform comissao_calcular_venda(vd); end loop;
  return n;
end $$;
revoke execute on function public.campanha_comercial_salvar(uuid, jsonb) from public, anon;
grant execute on function public.campanha_comercial_salvar(uuid, jsonb) to authenticated, service_role;

notify pgrst, 'reload schema';
