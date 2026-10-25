-- v0.141 — O acesso do cliente decide o Growth's Content.
-- 1) Catálogo de telas dos pacotes: Growth's Content vira um subgrupo de Marketing (Estratégia de conteúdo e Instagram)
--    e as DMs do Instagram entram em Vendas. Sem isso, cliente com acesso restrito não via o Instagram nem as DMs.
-- 2) Cliente com acesso restrito que inclui o Growth's Content fica marcado como usuário do módulo (e ganha a pasta
--    no Drive pela v0.140); sem ele, desmarcado (a pasta fica). Cliente sem restrição (acesso a tudo) não muda sozinho.
-- Pode ser rodado de novo sem erro.

insert into public.acesso_telas (tela, modulo, nome, grupo, ordem) values
  ('mkt-cont', 'mkt', 'Estratégia de conteúdo', 'Marketing / Growth''s Content', 11),
  ('mkt-insta', 'mkt', 'Instagram', 'Marketing / Growth''s Content', 11),
  ('crm-dms', 'vendas', 'DMs do Instagram', 'Vendas', 17)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo, ordem = excluded.ordem;

-- o acesso (pacote + ligadas − desligadas) inclui o Growth's Content? null = acesso a tudo (sem restrição)
create or replace function public.content_no_acesso(p_pacote uuid, p_liga text[], p_desliga text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select case when p_pacote is null and coalesce(cardinality(p_liga), 0) = 0 and coalesce(cardinality(p_desliga), 0) = 0 then null
    else 'mkt-cont' = any (coalesce((select telas from pacotes_acesso where id = p_pacote), case when p_pacote is null then (select array_agg(tela) from acesso_telas) else '{}'::text[] end) || coalesce(p_liga, '{}'))
         and not ('mkt-cont' = any (coalesce(p_desliga, '{}'))) end;
$$;
revoke all on function public.content_no_acesso(uuid, text[], text[]) from public, anon, authenticated;

create or replace function public.content_acesso_gatilho() returns trigger
language plpgsql security definer set search_path = public as $$
declare tem boolean;
begin
  if coalesce(new.agencia, false) then return new; end if;
  if tg_op = 'UPDATE' and new.pacote_id is not distinct from old.pacote_id and new.acesso_liga is not distinct from old.acesso_liga and new.acesso_desliga is not distinct from old.acesso_desliga then return new; end if;
  tem := content_no_acesso(new.pacote_id, new.acesso_liga, new.acesso_desliga);
  if tem is not null then new.content_ativo := tem; end if;
  return new;
end $$;
revoke all on function public.content_acesso_gatilho() from public, anon, authenticated;
drop trigger if exists content_acesso_t on public.workspaces;
create trigger content_acesso_t before insert or update on public.workspaces for each row execute function public.content_acesso_gatilho();

-- a pasta é pedida quando content_ativo liga, venha de onde vier (antes só quando a coluna era citada no update)
drop trigger if exists content_ws_t on public.workspaces;
create trigger content_ws_t after insert or update on public.workspaces for each row execute function public.content_ws_gatilho();

notify pgrst, 'reload schema';
