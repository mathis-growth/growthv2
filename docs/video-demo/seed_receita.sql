-- Só no banco "video": mais vendas para o demo mostrar um negócio saudável.
do $$
declare
  w uuid := '5467097a-99b4-44eb-a981-8c9e1e7a41e5';
  plat uuid := '2902c08f-2de3-4dba-9074-0075b288da2e';
  perp uuid := '78bfa7aa-7100-4d9b-b8b6-43fefb0534df';
  curso uuid := 'fbac648c-40be-486d-89ef-7e04a2a87740';
  ment uuid := '4990be40-ecc6-4cdc-baf9-4176255c52de';
  bruno uuid := '1d4669f6-a839-46bb-9c42-72981421dc62';
  nomes text[] := array['Ana','Beatriz','Camila','Daniela','Eduardo','Fernanda','Gabriel','Helena','Igor','Juliana','Lucas','Mariana','Natália','Otávio','Paula','Rafael','Sofia','Tiago','Vanessa','Yuri'];
  sobren text[] := array['Souza','Lima','Pereira','Rocha','Martins','Araújo','Ribeiro','Gomes','Barbosa','Teixeira','Moura','Cardoso'];
  m record; i int; pid uuid; dv timestamptz; nm text; n int := 5000; prod uuid; fp text;
begin
  for m in select * from (values ('2026-07-01'::date, 12, 35, 30), ('2026-08-01', 12, 38, 30), ('2026-09-01', 14, 45, 30), ('2026-10-01', 9, 26, 18)) t(ini, qm, qc, dias) loop
    for i in 1..(m.qm + m.qc) loop
      n := n + 1;
      nm := nomes[1 + (n*7) % 20] || ' ' || sobren[1 + (n*5) % 12];
      dv := (m.ini + ((n*13) % m.dias))::timestamp + make_interval(hours => 9 + (n % 11));
      prod := case when i <= m.qm then ment else curso end;
      fp := case when n % 3 = 0 then 'pix' else 'cartao_credito' end;
      insert into pessoas (workspace_id, nome, email, status_funil, status_cliente, negocio_status, utm_source, utm_medium, utm_campaign, utm_content, campanha_id, canal_origem, qualificacao, criado_em, captada)
      values (w, nm, lower(replace(nm,' ','.')) || n || '@email.test', 'cliente', 'ativo', 'ganho',
              case when prod = ment then 'instagram' else 'facebook' end, case when prod = ment then 'organico' else 'cpc' end,
              'perpetuo-meta', 'criativo-' || (1 + n % 3), perp, case when prod = ment then 'instagram' else 'meta_ads' end,
              'qualificado', dv - interval '6 days', true)
      returning id into pid;
      insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, campanha_id, forma_pagamento, parcelas, status, data_venda, valor_bruto, vendedor_id, utm_source, utm_campaign, utm_content, comprador_email, aprovada_em, pedido_ref)
      values (w, pid, prod, plat, perp, fp, 1, 'aprovada', dv, case when prod = ment then 3000 else 997 end,
              case when prod = ment then bruno end, case when prod = ment then 'instagram' else 'facebook' end, 'perpetuo-meta', 'criativo-' || (1 + n % 3),
              lower(replace(nm,' ','.')) || n || '@email.test', dv, 'PED-' || n);
    end loop;
  end loop;
end $$;
