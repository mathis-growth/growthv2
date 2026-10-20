-- v0.50: todo workspace novo já nasce com Pró-labore (6.2.04) ligado a "Pró-labore e retiradas a pagar" (2.1.03)
-- e com "Distribuição de lucros" (3.1.02). Antes, só a Mathisa tinha essas contas (criadas na v0.47).
create or replace function _provisionar_prolabore(p_ws uuid) returns void language plpgsql security definer set search_path = public as $$
declare p21 uuid; p31 uuid; p62 uuid; c203 uuid;
begin
  select id into p21 from plano_contas where workspace_id = p_ws and codigo = '2.1';
  select id into p31 from plano_contas where workspace_id = p_ws and codigo = '3.1';
  select id into p62 from plano_contas where workspace_id = p_ws and codigo = '6.2';
  if p21 is not null and not exists (select 1 from plano_contas where workspace_id = p_ws and codigo = '2.1.03') then
    insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento) values (p_ws, '2.1.03', 'Pró-labore e retiradas a pagar', 'passivo', 'credora', p21, true);
  end if;
  if p31 is not null and not exists (select 1 from plano_contas where workspace_id = p_ws and codigo = '3.1.02') then
    insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento) values (p_ws, '3.1.02', 'Distribuição de lucros', 'patrimonio', 'devedora', p31, true);
  end if;
  select id into c203 from plano_contas where workspace_id = p_ws and codigo = '2.1.03';
  if p62 is not null and not exists (select 1 from plano_contas where workspace_id = p_ws and codigo = '6.2.04') then
    insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento, conta_passivo_id) values (p_ws, '6.2.04', 'Pró-labore', 'despesa', 'devedora', p62, true, c203);
  end if;
end $$;
create or replace function provisionar_workspace(p_nome text) returns uuid language plpgsql security definer set search_path = public as $$
declare ws uuid;
begin
  ws := _provisionar_pre_motivos(p_nome);
  perform _provisionar_motivos(ws);
  perform _provisionar_prolabore(ws);
  return ws;
end $$;
