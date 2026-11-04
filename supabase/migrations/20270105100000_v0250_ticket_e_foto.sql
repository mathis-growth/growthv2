-- v0.250 — Dashboard de marketing: vendas no resumo (para o ticket médio) e foto do usuário.
-- 1. funil_analise devolve "vendas" por campanha e no total ("pos"). O ticket médio é receita ÷ vendas. Troca de texto, com erro se o trecho não for encontrado.
-- 2. Local "avatares" no Storage: até 2 MB, só imagem, leitura pública pelo endereço. Cada pessoa só grava, troca e apaga na própria pasta (id do usuário).
-- Rode depois de 20270104100000_atendimento_disparo_grupos_acesso.sql. Idempotente.

do $m$
declare def text; novo text;
begin
  select pg_get_functiondef('public.funil_analise(uuid,date,date,uuid,uuid)'::regprocedure) into def;
  def := replace(def, E'\r\n', E'\n');
  if position('count(*) as vendas' in def) = 0 then
    if position('rec as (select co.campanha_id, count(distinct v.pessoa_id) as clientes,' in def) = 0
       or position('''clientes'', coalesce(rec.clientes, 0), ''receita''' in def) = 0
       or position('select jsonb_build_object(''leads'', sum((x ->> ''leads'')::numeric), ''clientes''' in def) = 0 then
      raise exception 'v0.250: trecho esperado de funil_analise não encontrado; nada foi alterado.';
    end if;
    novo := replace(def, 'rec as (select co.campanha_id, count(distinct v.pessoa_id) as clientes,', 'rec as (select co.campanha_id, count(*) as vendas, count(distinct v.pessoa_id) as clientes,');
    novo := replace(novo, '''clientes'', coalesce(rec.clientes, 0), ''receita''', '''vendas'', coalesce(rec.vendas, 0), ''clientes'', coalesce(rec.clientes, 0), ''receita''');
    novo := replace(novo, 'select jsonb_build_object(''leads'', sum((x ->> ''leads'')::numeric), ''clientes''', 'select jsonb_build_object(''leads'', sum((x ->> ''leads'')::numeric), ''vendas'', sum((x ->> ''vendas'')::numeric), ''clientes''');
    execute novo;
  end if;
end $m$;

do $s$ begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('avatares', 'avatares', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
      on conflict (id) do update set public = true, file_size_limit = 2097152, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];
    execute 'drop policy if exists avatares_ler_propria on storage.objects';
    execute 'drop policy if exists avatares_gravar_propria on storage.objects';
    execute 'drop policy if exists avatares_trocar_propria on storage.objects';
    execute 'drop policy if exists avatares_apagar_propria on storage.objects';
    execute $p$create policy avatares_ler_propria on storage.objects for select to authenticated using (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute $p$create policy avatares_gravar_propria on storage.objects for insert to authenticated with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute $p$create policy avatares_trocar_propria on storage.objects for update to authenticated using (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute $p$create policy avatares_apagar_propria on storage.objects for delete to authenticated using (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
  end if;
end $s$;

-- Para desfazer: drop policy avatares_ler_propria, avatares_gravar_propria, avatares_trocar_propria e avatares_apagar_propria on storage.objects;
-- apagar o local "avatares" pelo painel do Storage; tirar "vendas" de funil_analise (reaplicar a definição anterior).
