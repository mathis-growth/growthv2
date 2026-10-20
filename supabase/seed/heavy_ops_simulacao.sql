-- Simulação do RevOps: cria um workspace SEPARADO com dados fictícios (nomes e e-mails inventados).
-- Nada daqui toca nos dados do workspace de demonstração. Para remover tudo, apague o workspace
-- "RevOps — Simulação (dados fictícios)" no Supabase (o delete em cascata leva junto pessoas, vendas e lançamentos).
-- Os parâmetros abaixo (probabilidade de ascender, risco mensal de saída) definem o cenário simulado.
do $$
declare
  ws uuid; uid uuid := '981ecb82-d432-4ee5-a0c7-1b6ca85bdf33'; cc uuid;
  nomes text[] := array['Ana','Bruno','Carla','Diego','Elisa','Fábio','Gabriela','Henrique','Isabela','João','Karen','Lucas','Mariana','Nicolas','Olívia','Paulo','Queila','Rafael','Sabrina','Tiago','Úrsula','Vitor','Wanda','Xavier','Yasmin','Zeca','Amanda','Bianca','Caio','Daniela'];
  sobrenomes text[] := array['Almeida','Barbosa','Cardoso','Duarte','Esteves','Ferraz','Gomes','Haddad','Ibrahim','Junqueira','Klein','Lopes','Moreira','Nogueira','Oliveira','Pacheco','Queiroz','Ribeiro','Siqueira','Teixeira','Uchoa','Vasconcelos','Werner','Ximenes','Zanetti'];
  pr uuid[]; nome_p text[] := array['Mini Curso Start','Template Pack','Curso Método Completo','Mentoria em Grupo','Consultoria Elite'];
  tag_p text[] := array['mini-start','template-pack','curso-metodo','mentoria-grupo','consultoria-elite'];
  tipo_p text[] := array['digital','digital','curso','servico','servico'];
  preco_p numeric[] := array[197,67,1497,3997,9997]; niv_p int[] := array[1,1,2,3,4];
  n_clientes int := 320; hazard_mes numeric := 0.04;
  i int; pid uuid; idx int; dias int; dt timestamptz; fp text; ok boolean; bruto numeric; nivel int; prox numeric; k int;
begin
  perform setseed(0.37);
  ws := provisionar_workspace('RevOps — Simulação (dados fictícios)');
  insert into workspace_membros (workspace_id, user_id, papel) values (ws, uid, 'admin');
  select id into cc from centros_custo where workspace_id = ws and codigo = 'PRODUTO';
  for k in 1..5 loop
    pr[k] := gen_random_uuid();
    insert into produtos (id, workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id, nivel_escada)
    values (pr[k], ws, nome_p[k], tag_p[k], tipo_p[k], false, preco_p[k], cc, niv_p[k]);
  end loop;

  for i in 1..n_clientes loop
    insert into pessoas (workspace_id, nome, email)
    values (ws, nomes[1 + floor(random() * 30)::int] || ' ' || sobrenomes[1 + floor(random() * 25)::int], 'sim' || i || '@exemplo.invalid')
    returning id into pid;
    dias := floor(175 * (1 - power(random(), 0.65)))::int + 1;
    k := floor(random() * 100)::int;
    idx := case when k < 50 then 1 when k < 78 then 2 when k < 95 then 3 else 4 end;
    loop
      dt := now() - make_interval(days => dias) - make_interval(hours => floor(random() * 10)::int);
      ok := random() >= 0.03;
      fp := case when random() < 0.4 then 'pix' when random() < 0.92 then 'cartao_credito' else 'boleto' end;
      bruto := preco_p[idx];
      insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, parcelas, status, data_venda, valor_bruto, taxa_plataforma, impostos)
      values (ws, pid, pr[idx], fp, 1, case when ok then 'aprovada' else 'reembolsada' end, dt, bruto, round(bruto * 0.099 + 1, 2), round(bruto * 0.06, 2));
      exit when not ok;
      nivel := niv_p[idx];
      prox := case nivel when 1 then 0.34 when 2 then 0.26 when 3 then 0.14 else 0 end;
      exit when random() >= prox;
      dias := dias - (case nivel when 1 then 15 + floor(random() * 55)::int else 30 + floor(random() * 60)::int end);
      exit when dias < 1;
      idx := case nivel when 1 then 3 when 2 then 4 else 5 end;
    end loop;
  end loop;

  update pessoas p set convertido_em = x.d
  from (select pessoa_id, min(data_venda) as d from vendas where workspace_id = ws and status = 'aprovada' group by pessoa_id) x where p.id = x.pessoa_id;
  update alunos a set entrou_em = v.data_venda from vendas v where v.id = a.venda_id and a.workspace_id = ws;

  -- saídas: risco mensal de sair, menor nos produtos de ticket maior
  with t as (
    select a.id, a.entrou_em + (-ln(1 - random()) / ((hazard_mes / 30.0) * case p.nivel_escada when 1 then 1.3 when 2 then 0.8 when 3 then 0.4 else 0.2 end)) * interval '1 day' as sai, random() as r2
    from alunos a join produtos p on p.id = a.produto_id where a.workspace_id = ws)
  update alunos a set status = case when t.r2 < 0.75 then 'inativo' else 'cancelado' end, saiu_em = t.sai
  from t where t.id = a.id and t.sai < now();

  -- etapa do kanban conforme o tempo de casa
  with s as (
    select a.id, case when now() - a.entrou_em < interval '14 days' then 'Novo aluno' when now() - a.entrou_em < interval '45 days' then 'Onboarding'
         when now() - a.entrou_em < interval '120 days' then 'Em andamento' when random() < 0.5 then 'Concluído' else 'Em andamento' end as nome
    from alunos a where a.workspace_id = ws and a.saiu_em is null)
  update alunos a set etapa_kanban_id = e.id
  from s join etapas_kanban e on e.workspace_id = ws and e.quadro = 'alunos' and e.nome = s.nome
  where a.id = s.id;

  update pessoas p set status_cliente = 'inativo'
  where p.workspace_id = ws and p.status_funil = 'cliente' and not exists (select 1 from alunos a where a.pessoa_id = p.id and a.saiu_em is null);

  insert into heavyops_metas (workspace_id) values (ws);
  if current_setting('growths.dry', true) = '1' then raise exception 'RESULTADO %', heavyops_painel(ws, 30)::text; end if;
end $$;
