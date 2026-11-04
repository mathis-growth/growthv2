-- v0.261: bruto dos anúncios por plataforma. Termina com "v0261: tudo OK".
do $t$
declare ws uuid; cx uuid; k1 uuid; n int; ok_ boolean;
begin
  ws := provisionar_workspace('Teste v0261');
  insert into conexoes (workspace_id, plataforma, status) values (ws, 'meta', 'conectado') returning id into cx;
  insert into conexao_contas (workspace_id, conexao_id, tipo, id_externo, nome) values (ws, cx, 'meta_ads', 'act_1', 'Conta') returning id into k1;
  n := conexao_gravar_bruto(k1, 'meta_ads', '[{"data":"2026-10-01","anuncio_ext":"a1","payload":{"spend":"10","campo_novo":"x"}},{"data":"2026-10-01","anuncio_ext":"a2","payload":{"spend":"5"}},{"data":"","anuncio_ext":"a3","payload":{}}]');
  if n <> 2 then raise exception 'X: gravou %', n; end if;
  if (select payload ->> 'campo_novo' from meta_ads_bruto where conta_id = k1 and anuncio_ext = 'a1') <> 'x' then raise exception 'X: payload'; end if;
  -- a plataforma ajustou o número: o mesmo dia é regravado, sem duplicar
  n := conexao_gravar_bruto(k1, 'meta_ads', '[{"data":"2026-10-01","anuncio_ext":"a1","payload":{"spend":"12"}}]');
  if (select count(*) from meta_ads_bruto where conta_id = k1) <> 2 or (select payload ->> 'spend' from meta_ads_bruto where anuncio_ext = 'a1' and conta_id = k1) <> '12' then raise exception 'X: regravar'; end if;
  n := conexao_gravar_bruto(k1, 'youtube_ads', '[{"data":"2026-10-01","anuncio_ext":"y1","payload":{"campaign":{"advertisingChannelType":"VIDEO"}}}]');
  if (select count(*) from youtube_ads_bruto where conta_id = k1) <> 1 or exists (select 1 from google_ads_bruto where conta_id = k1) then raise exception 'X: tabela por plataforma'; end if;
  ok_ := false; begin perform conexao_gravar_bruto(k1, 'tiktok', '[]'); exception when others then ok_ := true; end; if not ok_ then raise exception 'X: plataforma inválida'; end if;
  if has_table_privilege('authenticated', 'public.meta_ads_bruto', 'select') or has_function_privilege('anon', 'public.conexao_gravar_bruto(uuid,text,jsonb)', 'execute') then raise exception 'X: acesso'; end if;
end $t$;
select 'v0261: tudo OK' as resultado;
