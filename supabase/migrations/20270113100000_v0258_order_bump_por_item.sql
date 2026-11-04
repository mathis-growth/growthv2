-- v0.258: fatura com order bump vira uma venda para cada item, na Eduzz e na Hubla. Cada bump tem produto, valor e status próprios.
-- Aditiva. Para desfazer: reaplicar _pv_tenta e _pv_bruto_tratar da v0.257 e drop de _pv_linhas e _pv_produto.

create or replace function public._pv_produto(p_ws uuid, p_plat uuid, p_ids jsonb) returns uuid language sql stable security definer set search_path = public as $$
  select coalesce(
    (select x.produto_id from plataforma_produto_vinculos x where x.workspace_id = p_ws and x.plataforma_id = p_plat and x.id_externo in (select jsonb_array_elements_text(p_ids)) limit 1),
    (select x.produto_id from produto_plataforma x where x.workspace_id = p_ws and x.plataforma_id = p_plat and x.id_externo in (select jsonb_array_elements_text(p_ids)) limit 1));
$$;

-- divide a fatura: a primeira linha é a venda principal, com o que sobra do valor; cada order bump é uma linha própria
create or replace function public._pv_linhas(p_prov text, p jsonb, n jsonb) returns jsonb language plpgsql stable set search_path = public as $$
declare d jsonb; it jsonb; o jsonb; pr jsonb; ls jsonb := '[]'::jsonb; soma numeric := 0; v numeric; tx text := n ->> 'transacao'; idp text;
begin
  if tx is null or n ->> 'alvo' is null then return jsonb_build_array(n); end if;
  if p_prov = 'eduzz' then
    d := coalesce(p -> 'data', '{}'::jsonb);
    if (d -> 'orderBump' ->> 'isMainSale')::boolean is false or jsonb_typeof(d -> 'items') <> 'array' then return jsonb_build_array(n); end if;
    for it in select x from jsonb_array_elements(d -> 'items') x where coalesce((x ->> 'isBump')::boolean, false) loop
      v := coalesce(nullif(it -> 'price' ->> 'value', '')::numeric, 0) - coalesce(nullif(it -> 'coupon' -> 'discount' ->> 'value', '')::numeric, 0);
      soma := soma + v; idp := coalesce(it ->> 'productId', '?');
      ls := ls || jsonb_build_array(n || jsonb_build_object('transacao', tx || ':' || idp, 'pai', tx, 'valor', v, 'produto_ids', jsonb_build_array(idp), 'produto_nome', it ->> 'name', 'bump', true, 'itens', null));
    end loop;
  elsif p_prov = 'hubla' then
    d := coalesce(p -> 'event', '{}'::jsonb);
    if nullif(d -> 'invoice' ->> 'parentInvoiceId', '') is not null or jsonb_typeof(d -> 'products') <> 'array' then return jsonb_build_array(n); end if;
    for pr in select x from jsonb_array_elements(d -> 'products') x loop
      for o in select x from jsonb_array_elements(case when jsonb_typeof(pr -> 'offers') = 'array' then pr -> 'offers' else '[]'::jsonb end) x where coalesce((x ->> 'isOrderBump')::boolean, false) loop
        v := coalesce(nullif(o ->> 'amountCents', '')::numeric, 0) / 100; soma := soma + v; idp := coalesce(pr ->> 'id', '?');
        ls := ls || jsonb_build_array(n || jsonb_build_object('transacao', tx || ':' || idp, 'pai', tx, 'valor', v, 'produto_ids', jsonb_build_array(idp), 'produto_nome', coalesce(o ->> 'name', pr ->> 'name'), 'bump', true));
      end loop;
    end loop;
  else
    return jsonb_build_array(n);
  end if;
  if jsonb_array_length(ls) = 0 then return jsonb_build_array(n); end if;
  return jsonb_build_array(n || jsonb_build_object('valor', greatest(coalesce(nullif(n ->> 'valor', '')::numeric, 0) - soma, 0))) || ls;
end $$;

-- aplica todas as linhas juntas: se um produto não estiver ligado, nada entra pela metade e a tela pede a ligação dele
create or replace function public._pv_tenta(p_ws uuid, p_plat uuid, p_prov text, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare n jsonb; l jsonb; r jsonb; res jsonb; algum boolean := false; pr uuid; ped text;
begin
  n := _pv_normaliza(p_prov, p);
  begin
    for l in select x from jsonb_array_elements(_pv_linhas(p_prov, p, n)) x loop
      -- o mesmo bump pode vir na fatura principal e numa fatura própria: conta uma vez
      ped := coalesce(nullif(l ->> 'pai', ''), l ->> 'transacao');
      if coalesce((l ->> 'bump')::boolean, false) and l ->> 'alvo' is not null and not exists (select 1 from vendas where workspace_id = p_ws and plataforma_id = p_plat and id_externo = l ->> 'transacao') then
        pr := _pv_produto(p_ws, p_plat, l -> 'produto_ids');
        if pr is not null and exists (select 1 from vendas where workspace_id = p_ws and plataforma_id = p_plat and pedido_ref = ped and produto_id = pr and id_externo <> l ->> 'transacao') then
          r := jsonb_build_object('situacao', 'ignorado', 'motivo', 'Este order bump já está registrado neste pedido.');
          res := coalesce(res, r); continue;
        end if;
      end if;
      r := _pv_aplicar(p_ws, p_plat, p_prov, l);
      if r ->> 'situacao' = 'revisar' then
        res := r || jsonb_build_object('produto_externo', l -> 'produto_ids' ->> 0, 'produto_nome', l ->> 'produto_nome');
        raise exception 'revisar' using errcode = 'GW001';
      end if;
      if r ->> 'situacao' = 'processado' then algum := true; end if;
      if res is null or (r ->> 'situacao' = 'processado' and res ->> 'situacao' <> 'processado') then res := r; end if;
    end loop;
  exception when sqlstate 'GW001' then
    return res;
  end;
  return res;
exception when others then
  return jsonb_build_object('situacao', 'erro', 'motivo', left(sqlerrm, 300));
end $$;

create or replace function public._pv_bruto_tratar(p_prov text, p_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare ws uuid; pl jsonb; cfg plataforma_webhooks; r jsonb; tb text := _pv_tabela(p_prov);
begin
  execute format('select workspace_id, payload from %I where id = $1', tb) into ws, pl using p_id;
  select * into cfg from plataforma_webhooks where workspace_id = ws and provedor = p_prov;
  if cfg.workspace_id is null then return jsonb_build_object('situacao', 'aguardando'); end if;
  r := _pv_tenta(ws, cfg.plataforma_id, p_prov, pl);
  execute format('update %I set tratamento = $1, motivo = $2, venda_id = coalesce($3, venda_id), tratado_em = now(), produto_externo = coalesce($4, produto_externo), produto_nome = coalesce($5, produto_nome) where id = $6', tb)
    using r ->> 'situacao', r ->> 'motivo', nullif(r ->> 'venda_id', '')::uuid, r ->> 'produto_externo', r ->> 'produto_nome', p_id;
  return r;
end $$;

revoke execute on function public._pv_produto(uuid, uuid, jsonb), public._pv_linhas(text, jsonb, jsonb), public._pv_tenta(uuid, uuid, text, jsonb), public._pv_bruto_tratar(text, uuid) from public, anon, authenticated;

notify pgrst, 'reload schema';
