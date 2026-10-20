-- Exemplo: duas contas de mídia paga no workspace Demo (uma paga, uma em aberto).
do $$
declare ws uuid; f1 uuid; f2 uuid; cg uuid; cm uuid; cp1 uuid; d1 uuid; d2 uuid; cc uuid;
begin
  select id into ws from workspaces where nome = 'Growths — Demo';
  select id into cc from centros_custo where workspace_id = ws and codigo = 'GOOGLE';
  insert into fornecedores (workspace_id, nome, categoria) values (ws, 'Google Ads (exemplo)', 'Mídia paga') returning id into f1;
  insert into fornecedores (workspace_id, nome, categoria) values (ws, 'Meta Ads (exemplo)', 'Mídia paga') returning id into f2;
  select id into cg from campanha_canais where workspace_id = ws and canal = 'google_ads';
  select id into cm from campanha_canais where workspace_id = ws and canal = 'meta_ads';
  select id into d1 from plano_contas where workspace_id = ws and codigo = '6.1.01';
  select id into d2 from plano_contas where workspace_id = ws and codigo = '6.1.02';
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, vencimento, conta_despesa_id, centro_custo_id, campanha_canal_id)
    values (ws, f1, 'Mídia Google – 1ª quinzena Out/26', 3200, '2026-10-03', d1, cc, cg) returning id into cp1;
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, vencimento, conta_despesa_id, campanha_canal_id)
    values (ws, f2, 'Mídia Meta – Out/26', 1500, '2026-10-20', d2, cm);
  perform registrar_pagamento(cp1, '2026-10-03');
end $$;
