-- v0.146 — Growth's Content: biblioteca de estruturas de roteiro e copy (interna) e custos de IA (só para quem a Mathisa indicar).
-- 1) content_estruturas: a receita de cada estrutura (etapas e instruções para a IA). Só a equipe interna lê e edita.
--    O cliente vê apenas nome, para que serve e formatos (content_estruturas_opcoes) e escolhe quais usar por formato.
-- 2) ia_uso: cada chamada de IA (tokens, buscas na web, custo em dólar). Ninguém lê a tabela direto:
--    só ia_custos(), e só para os e-mails em sistema_config.custos_emails.
-- Pode ser rodado de novo sem erro.

create table if not exists public.content_estruturas (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  para_que text not null default '',
  formatos text[] not null default '{}',
  etapas jsonb not null default '[]'::jsonb,
  instrucoes text not null default '',
  ativo boolean not null default true,
  ordem int not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint content_estruturas_formatos_ck check (formatos <@ array['reels', 'carrossel', 'post', 'stories', 'video', 'email']::text[])
);
alter table public.content_estruturas enable row level security;
drop policy if exists content_estruturas_interno on public.content_estruturas;
create policy content_estruturas_interno on public.content_estruturas for all to authenticated using (sou_equipe_interna()) with check (sou_equipe_interna());
revoke all on public.content_estruturas from anon;
grant select, insert, update, delete on public.content_estruturas to authenticated;

create table if not exists public.content_estruturas_ws (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  estrutura_id uuid not null references public.content_estruturas(id) on delete cascade,
  formato text not null,
  escolhido_em timestamptz not null default now(),
  primary key (workspace_id, estrutura_id, formato)
);
alter table public.content_estruturas_ws enable row level security;
drop policy if exists content_estruturas_ws_ver on public.content_estruturas_ws;
create policy content_estruturas_ws_ver on public.content_estruturas_ws for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
revoke all on public.content_estruturas_ws from anon;
revoke insert, update, delete on public.content_estruturas_ws from authenticated;
grant select on public.content_estruturas_ws to authenticated;

-- o que o cliente vê: só o nome, para que serve e os formatos (nunca as etapas nem as instruções)
create or replace function public.content_estruturas_opcoes(p_ws uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'nome', e.nome, 'para_que', e.para_que, 'formatos', to_jsonb(e.formatos),
      'escolhidas', coalesce((select jsonb_agg(w.formato order by w.formato) from content_estruturas_ws w where w.workspace_id = p_ws and w.estrutura_id = e.id), '[]'::jsonb))
    order by e.ordem, e.nome) from content_estruturas e where e.ativo), '[]'::jsonb);
end $$;
revoke all on function public.content_estruturas_opcoes(uuid) from public, anon;
grant execute on function public.content_estruturas_opcoes(uuid) to authenticated;

-- o cliente escolhe (troca tudo de uma vez): [{"estrutura_id": "...", "formato": "reels"}, ...]
create or replace function public.content_estruturas_escolher(p_ws uuid, p_escolhas jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para configurar o Growth''s Content deste cliente'; end if;
  if jsonb_typeof(coalesce(p_escolhas, '[]'::jsonb)) <> 'array' then raise exception 'Escolhas inválidas'; end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p_escolhas, '[]'::jsonb)) x
             where not exists (select 1 from content_estruturas e where e.ativo and e.id::text = x->>'estrutura_id' and (x->>'formato') = any(e.formatos)))
    then raise exception 'Estrutura ou formato que não existe'; end if;
  delete from content_estruturas_ws where workspace_id = p_ws;
  insert into content_estruturas_ws (workspace_id, estrutura_id, formato)
    select distinct p_ws, (x->>'estrutura_id')::uuid, x->>'formato' from jsonb_array_elements(coalesce(p_escolhas, '[]'::jsonb)) x;
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.content_estruturas_escolher(uuid, jsonb) from public, anon;
grant execute on function public.content_estruturas_escolher(uuid, jsonb) to authenticated;

-- ---------- custos de IA ----------
create table if not exists public.ia_uso (
  id bigint generated always as identity primary key,
  workspace_id uuid references public.workspaces(id) on delete set null,
  funcao text not null,
  modelo text,
  tokens_entrada int not null default 0,
  tokens_saida int not null default 0,
  tokens_cache int not null default 0,
  buscas int not null default 0,
  custo_usd numeric(12, 6),
  detalhe jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index if not exists ia_uso_ws_em on public.ia_uso (workspace_id, criado_em);
alter table public.ia_uso enable row level security;
revoke all on public.ia_uso from public, anon, authenticated;

insert into public.sistema_config (chave, valor) values ('custos_emails', 'rebecka@rebeckacappello.com.br') on conflict (chave) do nothing;
insert into public.sistema_config (chave, valor) values ('cambio_usd_brl', '') on conflict (chave) do nothing;

create or replace function public.posso_ver_custos() returns boolean
language sql stable security definer set search_path = public as $$
  select sou_equipe_interna() and lower(coalesce(auth.email(), '')) <> '' and lower(auth.email()) = any (
    select lower(trim(e)) from sistema_config, unnest(string_to_array(valor, ',')) e where chave = 'custos_emails');
$$;
revoke all on function public.posso_ver_custos() from public, anon;
grant execute on function public.posso_ver_custos() to authenticated;

-- custos por cliente e por mês, no período
create or replace function public.ia_custos(p_ini date, p_fim date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not posso_ver_custos() then raise exception 'Só quem a Mathisa indicou vê os custos'; end if;
  return jsonb_build_object(
    'cambio', nullif((select valor from sistema_config where chave = 'cambio_usd_brl'), ''),
    'linhas', coalesce((select jsonb_agg(jsonb_build_object('workspace_id', x.workspace_id, 'cliente', coalesce(w.nome, '(sem cliente)'), 'mes', x.mes, 'chamadas', x.chamadas,
        'tokens_entrada', x.te, 'tokens_saida', x.ts, 'tokens_cache', x.tc, 'buscas', x.bu, 'custo_usd', x.usd, 'sem_custo', x.sem) order by x.mes desc, coalesce(w.nome, ''))
      from (select workspace_id, to_char(criado_em at time zone 'America/Sao_Paulo', 'YYYY-MM') mes, count(*) chamadas, sum(tokens_entrada) te, sum(tokens_saida) ts, sum(tokens_cache) tc,
                   sum(buscas) bu, sum(custo_usd) usd, count(*) filter (where custo_usd is null) sem
            from ia_uso where (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1, 2) x
      left join workspaces w on w.id = x.workspace_id), '[]'::jsonb),
    'por_funcao', coalesce((select jsonb_agg(jsonb_build_object('funcao', funcao, 'chamadas', n, 'custo_usd', usd) order by usd desc nulls last)
      from (select funcao, count(*) n, sum(custo_usd) usd from ia_uso where (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1) f), '[]'::jsonb));
end $$;
revoke all on function public.ia_custos(date, date) from public, anon;
grant execute on function public.ia_custos(date, date) to authenticated;

create or replace function public.ia_cambio_salvar(p_valor numeric) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not posso_ver_custos() then raise exception 'Só quem a Mathisa indicou altera o câmbio'; end if;
  if p_valor is not null and (p_valor <= 0 or p_valor > 100) then raise exception 'Câmbio inválido'; end if;
  update sistema_config set valor = coalesce(p_valor::text, '') where chave = 'cambio_usd_brl';
end $$;
revoke all on function public.ia_cambio_salvar(numeric) from public, anon;
grant execute on function public.ia_cambio_salvar(numeric) to authenticated;

-- ---------- estruturas iniciais (a equipe pode editar, desativar ou criar outras) ----------
insert into public.content_estruturas (nome, para_que, formatos, etapas, instrucoes, ordem) values
('AIDA', 'Clássica de vendas: chama a atenção, desperta interesse e desejo e leva à ação.', array['reels', 'carrossel', 'post', 'email'],
 '[{"nome": "Atenção", "instrucao": "Abra com uma frase que interrompa a rolagem: uma afirmação forte, um número ou uma pergunta que o público faria."},
   {"nome": "Interesse", "instrucao": "Mostre por que isso importa para esta pessoa agora, com um fato ou situação do dia a dia dela."},
   {"nome": "Desejo", "instrucao": "Descreva o resultado ou a transformação concreta; use prova (caso, número, depoimento) quando houver."},
   {"nome": "Ação", "instrucao": "Uma única chamada clara e coerente com o objetivo do conteúdo (salvar, comentar, chamar no direct, clicar)."}]',
 'Use a voz do cliente. Nada de promessa que o material do cliente não sustente.', 10),
('PAS (problema, agitação, solução)', 'Parte de uma dor que o público reconhece, aprofunda e apresenta a saída.', array['reels', 'carrossel', 'post', 'email'],
 '[{"nome": "Problema", "instrucao": "Nomeie a dor com as palavras que o público usa (veja a persona)."},
   {"nome": "Agitação", "instrucao": "Mostre o custo de continuar assim: o que piora, o que se perde. Sem exagero nem medo artificial."},
   {"nome": "Solução", "instrucao": "Apresente o caminho (o método ou a ideia central do cliente) e um primeiro passo possível."}]',
 'A agitação deve ser honesta e específica. A solução conecta com o mecanismo do cliente quando ele existir.', 20),
('Antes, depois e a ponte', 'Mostra onde a pessoa está, onde poderia estar e o que leva de um ponto ao outro.', array['reels', 'carrossel', 'post', 'stories', 'email'],
 '[{"nome": "Antes", "instrucao": "Retrate a situação atual do público com detalhes reconhecíveis."},
   {"nome": "Depois", "instrucao": "Retrate a situação desejada, concreta e crível."},
   {"nome": "Ponte", "instrucao": "Explique o que faz a travessia: o método, a virada de chave ou o primeiro passo."}]',
 'Bom para prova social: use casos reais do material do cliente quando houver.', 30),
('Gancho, conteúdo e chamada (Reels)', 'Roteiro curto de vídeo: segura nos primeiros segundos, entrega uma ideia e fecha com uma ação.', array['reels', 'stories'],
 '[{"nome": "Gancho (até 3 segundos)", "instrucao": "Uma frase falada e um texto na tela que façam a pessoa parar. Indique também o que aparece na imagem."},
   {"nome": "Contexto", "instrucao": "Uma ou duas frases dizendo por que isso importa."},
   {"nome": "Entrega", "instrucao": "De 1 a 3 pontos, um por cena, com o texto de tela de cada um."},
   {"nome": "Chamada", "instrucao": "Uma ação só, falada e escrita na tela."},
   {"nome": "Legenda", "instrucao": "Legenda curta que reforça o gancho, com a chamada no fim."}]',
 'Escreva o roteiro em falas curtas, como a pessoa fala. Indique a duração estimada.', 40),
('Carrossel educativo', 'Ensina uma ideia em lâminas: capa que promete, passos claros e fechamento que gera salvamento.', array['carrossel'],
 '[{"nome": "Capa", "instrucao": "Título com a promessa ou a pergunta central, em poucas palavras."},
   {"nome": "Lâmina 2: por que importa", "instrucao": "O problema ou o erro comum que o carrossel resolve."},
   {"nome": "Lâminas do miolo", "instrucao": "Um ponto por lâmina, com título curto e uma ou duas frases de explicação ou exemplo."},
   {"nome": "Resumo", "instrucao": "Uma lâmina que junta os pontos (bom para salvar)."},
   {"nome": "Chamada", "instrucao": "Pedir para salvar, compartilhar ou comentar, ligada ao tema."}]',
 'Entre 6 e 10 lâminas. Texto de cada lâmina curto o bastante para ler sem esforço no celular.', 50),
('Storytelling (jornada curta)', 'Conta uma história real com virada, para gerar conexão e mostrar o método na prática.', array['reels', 'carrossel', 'post', 'video', 'email'],
 '[{"nome": "Situação", "instrucao": "Quem, onde e quando, em poucas linhas. Uma história real do cliente ou de um aluno."},
   {"nome": "Conflito", "instrucao": "O obstáculo ou o momento difícil."},
   {"nome": "Virada", "instrucao": "O que mudou: a decisão, a descoberta, o método."},
   {"nome": "Resultado", "instrucao": "Como ficou depois, com detalhe concreto."},
   {"nome": "Lição", "instrucao": "O que o público leva para a vida dele, e a chamada."}]',
 'Use somente histórias que estejam no material do cliente ou que ele tenha contado na call. Nunca invente.', 60),
('Pelos 5 níveis de consciência', 'Ajusta a mensagem ao quanto o público já sabe do problema e da solução.', array['reels', 'carrossel', 'post', 'email'],
 '[{"nome": "Diagnóstico do nível", "instrucao": "Escolha o nível do público deste conteúdo: inconsciente, consciente do problema, da solução, do produto ou totalmente consciente."},
   {"nome": "Abertura pelo nível", "instrucao": "Inconsciente: história ou curiosidade. Problema: nomeie a dor. Solução: compare caminhos. Produto: diferencial e prova. Totalmente consciente: oferta e urgência real."},
   {"nome": "Desenvolvimento", "instrucao": "Leve a pessoa um nível acima, sem pular etapas."},
   {"nome": "Chamada pelo nível", "instrucao": "Uma ação coerente com o nível (seguir, salvar, comentar, chamar no direct, comprar)."}]',
 'Indique na ideia qual nível foi escolhido e por quê.', 70)
on conflict (nome) do nothing;

notify pgrst, 'reload schema';
