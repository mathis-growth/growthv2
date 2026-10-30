-- v0.173 — E1 da integração comercial: CPF ou CNPJ no cadastro da pessoa (uma pessoa só, sem cadastro paralelo de empresa).
-- 1. documento_normaliza(texto): só os dígitos; vazio vira nulo.
-- 2. documento_valido(digitos): CPF (11) ou CNPJ (14) com dígitos verificadores; recusa sequências repetidas (111.111.111-11).
-- 3. pessoas.documento: guardado só com dígitos (o gatilho normaliza o que foi digitado), válido e único por workspace quando houver.
--    O tipo (CPF ou CNPJ) sai do tamanho; não há coluna própria.
-- 4. Mesclar cadastros: documentos diferentes impedem a mesclagem; o documento da removida passa para a mantida se ela não tiver.
-- Não preenche nada sozinho: hoje nenhuma pessoa tem CPF/CNPJ em extras (conferido em 30/10/2026).
-- Rode depois de 20261125100000_estrategia_publicar_definer.sql. Idempotente.

create or replace function public.documento_normaliza(p text) returns text language sql immutable as $$
  select nullif(regexp_replace(coalesce(p, ''), '\D', '', 'g'), '')
$$;

create or replace function public.documento_valido(p text) returns boolean language plpgsql immutable as $$
declare d text := regexp_replace(coalesce(p, ''), '\D', '', 'g'); s int; r int; i int; pesos int[];
begin
  if length(d) = 11 then
    if d ~ '^(\d)\1{10}$' then return false; end if;
    s := 0; for i in 1..9 loop s := s + substr(d, i, 1)::int * (11 - i); end loop;
    r := (s * 10) % 11; if r = 10 then r := 0; end if; if r <> substr(d, 10, 1)::int then return false; end if;
    s := 0; for i in 1..10 loop s := s + substr(d, i, 1)::int * (12 - i); end loop;
    r := (s * 10) % 11; if r = 10 then r := 0; end if; return r = substr(d, 11, 1)::int;
  elsif length(d) = 14 then
    if d ~ '^(\d)\1{13}$' then return false; end if;
    pesos := array[5,4,3,2,9,8,7,6,5,4,3,2];
    s := 0; for i in 1..12 loop s := s + substr(d, i, 1)::int * pesos[i]; end loop;
    r := s % 11; r := case when r < 2 then 0 else 11 - r end; if r <> substr(d, 13, 1)::int then return false; end if;
    pesos := array[6,5,4,3,2,9,8,7,6,5,4,3,2];
    s := 0; for i in 1..13 loop s := s + substr(d, i, 1)::int * pesos[i]; end loop;
    r := s % 11; r := case when r < 2 then 0 else 11 - r end; return r = substr(d, 14, 1)::int;
  end if;
  return false;
end $$;

alter table pessoas add column if not exists documento text;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'pessoas_documento_ck') then
    alter table pessoas add constraint pessoas_documento_ck check (documento is null or (documento ~ '^\d{11}$|^\d{14}$' and documento_valido(documento)));
  end if;
end $c$;
create unique index if not exists pessoas_documento_uq on pessoas (workspace_id, documento) where documento is not null;

-- o que vier digitado (com pontos, traço, barra) é guardado só com os dígitos; inválido dá um erro claro
create or replace function public.pessoas_documento_t() returns trigger language plpgsql set search_path = public as $$
begin
  new.documento := documento_normaliza(new.documento);
  if new.documento is not null and not (new.documento ~ '^\d{11}$|^\d{14}$' and documento_valido(new.documento)) then
    raise exception 'CPF ou CNPJ inválido: confira os números.' using errcode = '23514';
  end if;
  if new.documento is not null and exists (select 1 from pessoas x where x.workspace_id = new.workspace_id and x.documento = new.documento and x.id <> new.id) then
    raise exception 'Este CPF/CNPJ já está no cadastro de outra pessoa. Abra o cadastro dela ou junte os dois.' using errcode = '23505';
  end if;
  return new;
end $$;
revoke execute on function public.pessoas_documento_t() from public, anon, authenticated;
drop trigger if exists pessoas_documento_t on pessoas;
create trigger pessoas_documento_t before insert or update of documento on pessoas for each row execute function pessoas_documento_t();

-- mesclar: documento diferente impede; o da removida vai para a mantida
do $m$
declare def text; novo text;
begin
  select pg_get_functiondef('public._pessoas_mesclar_v088(uuid,uuid,text)'::regprocedure) into def;
  def := replace(def, E'\r\n', E'\n');
  if position('documento = coalesce(a.documento, b.documento)' in def) > 0 then return; end if;
  if position('update pessoas set email = null, telefone = null where id = b.id;' in def) = 0
     or position('email = coalesce(a.email, b.email),' in def) = 0 then
    raise exception 'v0.173: trecho esperado de _pessoas_mesclar_v088 não encontrado; nada foi alterado.';
  end if;
  novo := replace(def, 'update pessoas set email = null, telefone = null where id = b.id;',
    'if a.documento is not null and b.documento is not null and a.documento <> b.documento then raise exception ''Os dois cadastros têm CPF/CNPJ diferentes: não são a mesma pessoa.''; end if;
  update pessoas set email = null, telefone = null, documento = null where id = b.id;');
  novo := replace(novo, 'email = coalesce(a.email, b.email),', 'email = coalesce(a.email, b.email), documento = coalesce(a.documento, b.documento),');
  -- correção que já faltava: sem tags nos dois cadastros, array_agg devolve nulo e pessoas.tags não aceita nulo (a mesclagem falhava)
  novo := replace(novo, 'tags = (select array_agg(distinct t) from unnest(coalesce(a.tags, ''{}'') || coalesce(b.tags, ''{}'')) t),',
    'tags = coalesce((select array_agg(distinct t) from unnest(coalesce(a.tags, ''{}'') || coalesce(b.tags, ''{}'')) t), ''{}''),');
  if position('tags = coalesce((select array_agg' in novo) = 0 then raise exception 'v0.173: trecho das tags em _pessoas_mesclar_v088 não encontrado; nada foi alterado.'; end if;
  execute novo;
end $m$;

-- Para desfazer: drop trigger pessoas_documento_t on pessoas; drop function pessoas_documento_t(); drop index pessoas_documento_uq;
-- alter table pessoas drop constraint pessoas_documento_ck, drop column documento; drop function documento_valido(text), documento_normaliza(text);
-- e reaplicar _pessoas_mesclar_v088 de 20261011000000_fase1_confianca_dado.sql.
