-- Expõe a nova tela de Disparos para membros com Atendimento no workspace.
insert into public.acesso_telas(tela,modulo,nome,grupo,ordem)
values ('atd-grupos-disparo','vendas','Disparos','Atendimento',124)
on conflict(tela) do update set modulo=excluded.modulo,nome=excluded.nome,grupo=excluded.grupo,ordem=excluded.ordem;

-- Mantém o acesso coerente com os pacotes que já liberam as telas de Atendimento.
update public.pacotes_acesso
set telas=telas||array['atd-grupos-disparo']
where (telas @> array['atd-conversas'] or telas @> array['atd-canais'] or telas @> array['atd-templates'] or telas @> array['atd-automacoes'])
  and not telas @> array['atd-grupos-disparo'];
