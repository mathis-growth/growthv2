-- v0.149 — Growth's Content: ficha de conteúdo de cada produto e ideias ligadas a um produto.
-- 1) content_produto_fichas: o que o conteúdo precisa saber do produto (para quem é, dor, transformação, método,
--    entregáveis, provas, objeções, oferta, momento de venda...). Uma ficha por produto.
-- 2) conteudos.produto_id: a ideia ou pauta pode ser sobre um produto.
-- Quem edita a ficha: quem configura o Growth's Content do cliente (Marketing com edição) ou a equipe interna.
-- Pode ser rodado de novo sem erro.

create table if not exists public.content_produto_fichas (
  produto_id uuid primary key references public.produtos(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  ficha jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
create index if not exists content_produto_fichas_ws on public.content_produto_fichas (workspace_id);
alter table public.content_produto_fichas enable row level security;
drop policy if exists content_produto_fichas_ver on public.content_produto_fichas;
create policy content_produto_fichas_ver on public.content_produto_fichas for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
revoke all on public.content_produto_fichas from anon;
revoke insert, update, delete on public.content_produto_fichas from authenticated;
grant select on public.content_produto_fichas to authenticated;

alter table public.conteudos add column if not exists produto_id uuid references public.produtos(id) on delete set null;
create index if not exists conteudos_produto on public.conteudos (produto_id) where produto_id is not null;

-- grava a ficha (só campos conhecidos, texto até 4000 caracteres cada)
create or replace function public.content_produto_ficha_salvar(p_produto uuid, p_ficha jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ws uuid; k text; v text; f jsonb := '{}'::jsonb;
  campos text[] := array['frase', 'para_quem', 'nao_e_para', 'dor', 'ja_tentou', 'transformacao', 'prazo_resultado', 'metodo', 'etapas',
    'entregaveis', 'bonus', 'formato_entrega', 'diferenciais', 'provas', 'garantia', 'objecoes', 'condicoes', 'pagina_vendas', 'checkout',
    'momento', 'proxima_abertura', 'cta', 'consciencia', 'papel_escada', 'pilares', 'palavras_publico', 'evitar', 'materiais'];
begin
  select workspace_id into ws from produtos where id = p_produto;
  if ws is null then raise exception 'Produto não encontrado'; end if;
  if not content_pode_configurar(ws) then raise exception 'Sem permissão para editar a ficha deste produto'; end if;
  if jsonb_typeof(coalesce(p_ficha, '{}'::jsonb)) <> 'object' then raise exception 'Ficha inválida'; end if;
  for k, v in select key, trim(coalesce(value #>> '{}', '')) from jsonb_each(coalesce(p_ficha, '{}'::jsonb)) loop
    if not (k = any(campos)) then raise exception 'Campo desconhecido na ficha: %', k; end if;
    if length(v) > 4000 then raise exception 'Texto longo demais em %', k; end if;
    if v <> '' then f := f || jsonb_build_object(k, v); end if;
  end loop;
  if f ? 'momento' and f->>'momento' not in ('perpetuo', 'lancamento', 'aberto', 'fechado', 'em_breve') then raise exception 'Momento de venda inválido'; end if;
  if f ? 'papel_escada' and f->>'papel_escada' not in ('entrada', 'principal', 'ascensao', 'recorrencia') then raise exception 'Papel na escada inválido'; end if;
  if f ? 'consciencia' and f->>'consciencia' not in ('inconsciente', 'problema', 'solucao', 'produto', 'total') then raise exception 'Nível de consciência inválido'; end if;
  insert into content_produto_fichas (produto_id, workspace_id, ficha, atualizado_em, atualizado_por) values (p_produto, ws, f, now(), auth.uid())
    on conflict (produto_id) do update set ficha = excluded.ficha, atualizado_em = now(), atualizado_por = auth.uid();
  return f;
end $$;
revoke all on function public.content_produto_ficha_salvar(uuid, jsonb) from public, anon;
grant execute on function public.content_produto_ficha_salvar(uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
