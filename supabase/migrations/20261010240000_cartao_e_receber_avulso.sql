-- v0.86 — Cartão de crédito não é saldo em banco · pagamento de fatura · contas a receber avulsas · pacote "Casa"
-- Rode DEPOIS de 20261010230000_pacotes_acesso.sql (usa pode_editar da v0.80 e pacotes_acesso da v0.85). Idempotente.
--
-- 1. Cartão de crédito
--    Antes: o cartão era cadastrado como uma "conta bancária" e o saldo dele (negativo, porque só tem saídas) era somado
--    ao "Saldo em banco" dos painéis. Cada compra no cartão diminuía o caixa no dia da compra.
--    Agora: contas_bancarias.tipo = 'conta' | 'cartao'. Cartão fica fora do saldo em banco e do caixa projetado.
--    A compra no cartão continua baixando a conta a pagar (o passivo passa do fornecedor para o cartão).
--    O dinheiro só sai do banco quando a fatura é paga: pagar_fatura_cartao (D cartão / C banco).
-- 2. Contas a receber avulsas (sem venda nem contrato), para a casa e para receitas eventuais:
--    receber_avulso_criar / receber_avulso_cancelar; o recebimento lança D banco / C conta de receita escolhida.
-- 3. Pacote "Casa" (só telas do financeiro) e aplicação ao workspace "Casa".

-- ---------- 1. tipo da conta ----------
alter table contas_bancarias add column if not exists tipo text not null default 'conta';
alter table contas_bancarias add column if not exists dia_vencimento int;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'contas_bancarias_tipo_check') then
    alter table contas_bancarias add constraint contas_bancarias_tipo_check check (tipo in ('conta', 'cartao'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'contas_bancarias_dia_venc_check') then
    alter table contas_bancarias add constraint contas_bancarias_dia_venc_check check (dia_vencimento is null or dia_vencimento between 1 and 31);
  end if;
end $$;

-- cartão nunca é a conta padrão de recebimento/pagamento
create or replace function public.contas_bancarias_cartao_padrao() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.tipo = 'cartao' then new.padrao := false; end if;
  return new;
end $$;
revoke execute on function public.contas_bancarias_cartao_padrao() from public, anon;
drop trigger if exists contas_bancarias_cartao_padrao_t on contas_bancarias;
create trigger contas_bancarias_cartao_padrao_t before insert or update on contas_bancarias
  for each row execute function public.contas_bancarias_cartao_padrao();

-- contas já cadastradas cujo nome ou conta contábil indicam cartão
update contas_bancarias cb set tipo = 'cartao', padrao = false
 where cb.tipo = 'conta'
   and (cb.nome ilike '%cart%o%cr%dito%'
        or exists (select 1 from plano_contas pc where pc.id = cb.conta_contabil_id and pc.tipo = 'passivo' and pc.nome ilike '%cart%o%'));

-- saldo em banco: só contas (os painéis fin_dashboard, fin_dashboard_periodo e painel_gerencial leem esta view)
create or replace view v_saldo_contas_bancarias with (security_invoker = true) as
select cb.id as conta_bancaria_id, cb.workspace_id, cb.nome, cb.saldo_inicial,
       cb.saldo_inicial + coalesce(sum(case m.tipo when 'entrada' then m.valor else -m.valor end), 0) as saldo_atual
  from contas_bancarias cb left join movimentacoes_bancarias m on m.conta_bancaria_id = cb.id
 where cb.tipo = 'conta'
 group by cb.id;

-- fatura em aberto de cada cartão (compras − pagamentos de fatura; positivo = devendo)
create or replace view v_cartoes_fatura with (security_invoker = true) as
select cb.id as conta_bancaria_id, cb.workspace_id, cb.nome, cb.banco, cb.dia_vencimento, cb.ativa,
       -(cb.saldo_inicial + coalesce(sum(case m.tipo when 'entrada' then m.valor else -m.valor end), 0)) as fatura_aberta,
       coalesce(sum(m.valor) filter (where m.tipo = 'saida'), 0) as compras,
       coalesce(sum(m.valor) filter (where m.tipo = 'entrada'), 0) as pagamentos
  from contas_bancarias cb left join movimentacoes_bancarias m on m.conta_bancaria_id = cb.id
 where cb.tipo = 'cartao'
 group by cb.id;
grant select on v_cartoes_fatura to authenticated;
revoke all on v_cartoes_fatura from anon;

-- "entrou / saiu" do período no painel gerencial: compra no cartão não é saída de caixa
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.painel_gerencial(uuid, date, date, date)'::regprocedure);
  if position('tipo = ''cartao''' in d) = 0 then
    n := replace(d, 'from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim',
                    'from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and conta_bancaria_id not in (select id from contas_bancarias where tipo = ''cartao'')');
    if n = d then raise exception 'painel_gerencial: trecho de entrou/saiu não encontrado — revisar'; end if;
    execute n;
  end if;
end $$;

-- pagamento de fatura
alter table lancamentos drop constraint if exists lancamentos_origem_tipo_check;
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo = any (array[
  'venda', 'recebimento', 'estorno', 'manual', 'conta_pagar', 'pagamento', 'cancelamento_pagar',
  'contrato_parcela', 'cancelamento_contrato', 'desconto', 'fatura_cartao']));

create or replace function public.pagar_fatura_cartao(p_cartao uuid, p_valor numeric, p_data date default null, p_banco uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c contas_bancarias; b contas_bancarias; d date; l uuid;
begin
  select * into c from contas_bancarias where id = p_cartao;
  if not found or c.tipo <> 'cartao' then raise exception 'Escolha um cartão de crédito'; end if;
  if not pode_editar(c.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor pago da fatura'; end if;
  select * into b from contas_bancarias where id = coalesce(p_banco,
    (select id from contas_bancarias where workspace_id = c.workspace_id and tipo = 'conta' and padrao and ativa limit 1));
  if not found or b.workspace_id <> c.workspace_id or b.tipo <> 'conta' then raise exception 'Escolha a conta bancária que pagou a fatura'; end if;
  if c.conta_contabil_id is null or b.conta_contabil_id is null then raise exception 'Cartão ou conta sem conta contábil no cadastro'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (c.workspace_id, d, 'Pagamento de fatura: ' || c.nome, 'fatura_cartao', c.id) returning id into l;
  perform _partida(l, c.workspace_id, c.conta_contabil_id, null, 'D', round(p_valor, 2));
  perform _partida(l, c.workspace_id, b.conta_contabil_id, null, 'C', round(p_valor, 2));
  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id) values
    (c.workspace_id, b.id, d, 'saida', round(p_valor, 2), 'Pagamento de fatura: ' || c.nome, 'fatura_cartao', c.id, l),
    (c.workspace_id, c.id, d, 'entrada', round(p_valor, 2), 'Pagamento de fatura (de ' || b.nome || ')', 'fatura_cartao', c.id, l);
  return l;
end $$;

create or replace function public.desfazer_fatura_cartao(p_lancamento uuid, p_data date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare l0 lancamentos; l1 uuid; d date;
begin
  select * into l0 from lancamentos where id = p_lancamento;
  if not found or l0.origem_tipo <> 'fatura_cartao' or l0.estorno_de is not null then raise exception 'Pagamento de fatura não encontrado'; end if;
  if not pode_editar(l0.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if exists (select 1 from lancamentos e where e.estorno_de = l0.id) then raise exception 'Este pagamento de fatura já foi desfeito'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (l0.workspace_id, d, 'Desfeito: ' || l0.descricao, 'fatura_cartao', l0.origem_id, l0.id) returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = l0.id;
  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
  select workspace_id, conta_bancaria_id, d, case tipo when 'entrada' then 'saida' else 'entrada' end, valor, 'Desfeito: ' || descricao, 'fatura_cartao', origem_id, l1
    from movimentacoes_bancarias where lancamento_id = l0.id;
  return l1;
end $$;

-- ---------- 2. contas a receber avulsas ----------
alter table contas_receber add column if not exists conta_receita_id uuid references plano_contas(id);

create or replace function public.receber_avulso_criar(p_ws uuid, p_descricao text, p_valor numeric, p_vencimento date,
                                                      p_conta_receita uuid, p_conta_bancaria uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if not pode_editar(p_ws, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if coalesce(trim(p_descricao), '') = '' then raise exception 'Descreva a conta a receber'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor'; end if;
  if p_vencimento is null then raise exception 'Informe a data prevista'; end if;
  if not exists (select 1 from plano_contas where id = p_conta_receita and workspace_id = p_ws and aceita_lancamento and tipo in ('receita', 'ativo', 'passivo', 'patrimonio')) then
    raise exception 'Escolha a conta de receita (plano de contas)';
  end if;
  if p_conta_bancaria is not null and not exists (select 1 from contas_bancarias where id = p_conta_bancaria and workspace_id = p_ws and tipo = 'conta') then
    raise exception 'Conta bancária inválida';
  end if;
  insert into contas_receber (workspace_id, descricao, valor, vencimento, status, conta_bancaria_id, conta_receita_id)
  values (p_ws, trim(p_descricao), round(p_valor, 2), p_vencimento, 'previsto', p_conta_bancaria, p_conta_receita) returning id into v;
  return v;
end $$;

-- avulsa ainda não recebida não tem lançamento (a receita entra no recebimento): cancelar é só marcar
create or replace function public.receber_avulso_cancelar(p_conta_receber uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cr contas_receber;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found or cr.conta_receita_id is null then raise exception 'Conta a receber avulsa não encontrada'; end if;
  if not pode_editar(cr.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cr.status <> 'previsto' then raise exception 'Só dá para cancelar conta ainda não recebida (esta está %)', cr.status; end if;
  update contas_receber set status = 'cancelado' where id = cr.id;
end $$;

-- recebimento de avulsa: D banco / C conta de receita escolhida
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.registrar_recebimento(uuid, date, uuid)'::regprocedure);
  if position('conta_receita_id' in d) = 0 then
    -- busca tolerante a espaços e quebras de linha (o SQL Editor pode trocar \n por \r\n ao colar)
    n := regexp_replace(d, 'if\s+cr\.contrato_id\s+is\s+not\s+null\s+then\s+r\s*:=\s*_regra\(\s*cr\.workspace_id\s*,\s*''contrato_recebimento''\s*\)\s*;',
      'if cr.conta_receita_id is not null then r.conta_debito_id := null; r.conta_credito_id := cr.conta_receita_id; v_desc := ''Recebimento: '' || coalesce(cr.descricao, ''avulso''); '
      || 'elsif cr.contrato_id is not null then r := _regra(cr.workspace_id, ''contrato_recebimento'');');
    if n = d then raise exception 'registrar_recebimento: trecho não encontrado — revisar'; end if;
    -- recebimento não pode cair em cartão
    n := replace(n, 'if v_banco_contabil is null then raise exception ''Conta bancária inválida para este workspace''; end if;',
                    'if v_banco_contabil is null then raise exception ''Conta bancária inválida para este workspace''; end if;
  if (select tipo from contas_bancarias where id = v_banco) = ''cartao'' then raise exception ''Recebimento não pode entrar no cartão de crédito: escolha uma conta bancária''; end if;');
    execute n;
  end if;
end $$;

-- recebimento parcial: avulsa recebe o valor inteiro (mensagem clara)
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.registrar_recebimento_parcial(uuid, numeric, date, uuid)'::regprocedure);
  if position('conta_receita_id' in d) = 0 then
    n := replace(d, '  if cr.contrato_id is null then raise exception',
                    '  if cr.conta_receita_id is not null then raise exception ''Conta avulsa recebe o valor inteiro. Para dividir, cancele e crie duas.''; end if;
  if cr.contrato_id is null then raise exception');
    if n <> d then execute n; end if;
  end if;
end $$;

revoke execute on function public.pagar_fatura_cartao(uuid, numeric, date, uuid), public.desfazer_fatura_cartao(uuid, date),
  public.receber_avulso_criar(uuid, text, numeric, date, uuid, uuid), public.receber_avulso_cancelar(uuid) from public, anon;
grant execute on function public.pagar_fatura_cartao(uuid, numeric, date, uuid), public.desfazer_fatura_cartao(uuid, date),
  public.receber_avulso_criar(uuid, text, numeric, date, uuid, uuid), public.receber_avulso_cancelar(uuid) to authenticated, service_role;

-- ---------- 3. pacote Casa ----------
insert into pacotes_acesso (nome, descricao, telas) values
('Casa', 'Finanças pessoais: só o financeiro (dashboard, contas a receber e a pagar, lançamentos) e os cadastros financeiros.',
  array['fin-dash', 'fin-receber', 'fin-pagar', 'fin-lanc', 'cad-equipe', 'cad-planocontas', 'cad-bancos', 'cad-formaspag', 'cad-fornecedores', 'cad-centros'])
on conflict (nome) do nothing;
update workspaces w set pacote_id = (select id from pacotes_acesso where nome = 'Casa')
 where w.nome = 'Casa' and w.pacote_id is null and not w.agencia;

-- ---------- 4. campanha → projeto: atividades a partir dos blocos da estratégia ----------
-- Cada bloco ativo da campanha vira uma atividade principal no projeto da campanha, com subatividades do tipo do bloco
-- (ex.: Tráfego pago → definir públicos, criativos, configurar campanhas, acompanhar). Idempotente por bloco.
alter table projeto_atividades add column if not exists campanha_bloco_id uuid references campanha_blocos(id) on delete set null;
create index if not exists projeto_atividades_bloco on projeto_atividades (campanha_bloco_id);

create or replace function public._bloco_tarefas(p_tipo text, p_nome text) returns table (ordem int, titulo text, funcao text)
language sql immutable set search_path = public as $$
  select t.ordem, t.titulo, t.funcao from (values
    ('conteudo', 1, 'Planejar o calendário de conteúdo', 'Social media'), ('conteudo', 2, 'Produzir posts, reels e stories', 'Designer'), ('conteudo', 3, 'Colocar o link com UTM na bio e nos stories', 'Social media'),
    ('trafego', 1, 'Definir públicos e orçamento', 'Tráfego'), ('trafego', 2, 'Produzir os criativos dos anúncios', 'Designer'), ('trafego', 3, 'Configurar campanhas, pixel e UTMs', 'Tráfego'), ('trafego', 4, 'Acompanhar métricas e otimizar', 'Tráfego'),
    ('captura', 1, 'Escrever a copy da página', 'Copywriter'), ('captura', 2, 'Montar a página de captura', 'Desenvolvedor'), ('captura', 3, 'Ligar o formulário aos leads do Growths', 'Desenvolvedor'), ('captura', 4, 'Testar a página no celular e no computador', 'Desenvolvedor'),
    ('indicacao', 1, 'Definir regra e recompensa da indicação', 'Gestor'), ('indicacao', 2, 'Criar link de indicação com UTM', 'Tráfego'), ('indicacao', 3, 'Convidar parceiros e indicadores', 'Comercial'),
    ('grupo', 1, 'Criar o grupo e os links de entrada', 'Social media'), ('grupo', 2, 'Escrever as mensagens do grupo', 'Copywriter'), ('grupo', 3, 'Programar o cronograma de mensagens', 'Social media'),
    ('api', 1, 'Montar a lista de contatos', 'Comercial'), ('api', 2, 'Escrever as mensagens do disparo', 'Copywriter'), ('api', 3, 'Configurar e agendar o disparo', 'Social media'),
    ('email', 1, 'Escrever a sequência de e-mails', 'Copywriter'), ('email', 2, 'Configurar a automação de envio', 'Desenvolvedor'), ('email', 3, 'Testar os envios', 'Desenvolvedor'),
    ('pesquisa', 1, 'Montar as perguntas da pesquisa', 'Gestor'), ('pesquisa', 2, 'Publicar a pesquisa e o link', 'Social media'), ('pesquisa', 3, 'Definir o critério de qualificação', 'Comercial'),
    ('aula', 1, 'Definir o roteiro da aula', 'Especialista'), ('aula', 2, 'Preparar a apresentação', 'Designer'), ('aula', 3, 'Configurar a sala ou transmissão', 'Social media'), ('aula', 4, 'Ensaiar e testar áudio e vídeo', 'Especialista'), ('aula', 5, 'Enviar os lembretes', 'Social media'),
    ('vsl', 1, 'Roteirizar o vídeo', 'Copywriter'), ('vsl', 2, 'Gravar', 'Especialista'), ('vsl', 3, 'Editar', 'Editor de vídeo'), ('vsl', 4, 'Publicar a página do vídeo', 'Desenvolvedor'),
    ('checkout', 1, 'Cadastrar produto e oferta na plataforma', 'Gestor'), ('checkout', 2, 'Configurar o checkout e os meios de pagamento', 'Desenvolvedor'), ('checkout', 3, 'Fazer uma compra de teste', 'Gestor'),
    ('comercial', 1, 'Definir o script de abordagem', 'Comercial'), ('comercial', 2, 'Distribuir os leads para SDR e closer', 'Comercial'), ('comercial', 3, 'Acompanhar o funil comercial', 'Comercial'),
    ('recompra', 1, 'Definir a oferta de recompra ou ascensão', 'Gestor'), ('recompra', 2, 'Escrever a comunicação para clientes', 'Copywriter'), ('recompra', 3, 'Disparar e acompanhar', 'Comercial'),
    ('assinatura', 1, 'Configurar a régua de renovação', 'Desenvolvedor'), ('assinatura', 2, 'Escrever as mensagens de renovação', 'Copywriter'), ('assinatura', 3, 'Acompanhar cancelamentos', 'Comercial')
  ) t(tipo, ordem, titulo, funcao)
  where t.tipo = p_tipo
  union all
  select 1, 'Preparar: ' || p_nome, null::text where not exists (select 1 where p_tipo in ('conteudo','trafego','captura','indicacao','grupo','api','email','pesquisa','aula','vsl','checkout','comercial','recompra','assinatura'))
  order by 1;
$$;

create or replace function public._campanha_gerar_atividades(p_campanha uuid) returns int
language plpgsql security definer set search_path = public as $$
declare pj projetos; b record; t record; pai uuid; n int := 0; o int; prev text;
begin
  select * into pj from projetos where campanha_id = p_campanha order by criado_em limit 1;
  if not found then return 0; end if;
  prev := coalesce(current_setting('growths.recalc', true), '');
  perform set_config('growths.recalc', '1', true);
  select coalesce(max(ordem), 0) into o from projeto_atividades where projeto_id = pj.id and pai_id is null;
  for b in select cb.* from campanha_blocos cb
            where cb.campanha_id = p_campanha and cb.ativo
              and not exists (select 1 from projeto_atividades a where a.projeto_id = pj.id and a.campanha_bloco_id = cb.id)
            order by array_position(array['aquisicao','aquecimento','conversao','retencao'], cb.fase), cb.ordem, cb.criado_em loop
    o := o + 10;
    insert into projeto_atividades (workspace_id, projeto_id, titulo, descricao, ordem, depende_de, campanha_bloco_id, status)
    values (pj.workspace_id, pj.id, b.nome, 'Bloco da estratégia (' || b.fase || '). Criada junto com a campanha.', o, '{}', b.id, 'bloqueada')
    returning id into pai;
    n := n + 1;
    for t in select x.ordem as k, x.titulo, x.funcao from _bloco_tarefas(b.tipo, b.nome) x loop
      insert into projeto_atividades (workspace_id, projeto_id, pai_id, titulo, funcao, responsavel_id, ordem, depende_de, status)
      values (pj.workspace_id, pj.id, pai, t.titulo, t.funcao, case when t.funcao is not null then equipe_resolve(pj.workspace_id, t.funcao) end, t.k, '{}', 'bloqueada');
      n := n + 1;
    end loop;
  end loop;
  perform set_config('growths.recalc', prev, true);
  if n > 0 then perform projeto_recalcula(pj.id); end if;
  return n;
end $$;
revoke execute on function public._campanha_gerar_atividades(uuid), public._bloco_tarefas(text, text) from public, anon, authenticated;

create or replace function public.campanha_gerar_atividades(p_campanha uuid) returns int
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  select workspace_id into w from campanhas where id = p_campanha;
  if w is null or not pode_editar(w, '{prj,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  return _campanha_gerar_atividades(p_campanha);
end $$;
revoke execute on function public.campanha_gerar_atividades(uuid) from public, anon;
grant execute on function public.campanha_gerar_atividades(uuid) to authenticated, service_role;

create or replace function public.campanha_blocos_atividades() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform _campanha_gerar_atividades(new.campanha_id);
  return null;
end $$;
revoke execute on function public.campanha_blocos_atividades() from public, anon, authenticated;
drop trigger if exists campanha_blocos_atividades_t on campanha_blocos;
create trigger campanha_blocos_atividades_t after insert on campanha_blocos
  for each row execute function public.campanha_blocos_atividades();
