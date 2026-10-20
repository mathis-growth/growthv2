-- Projeto ligado a cliente e criado sozinho a partir do produto vendido
alter table projetos add column if not exists pessoa_id uuid references pessoas(id) on delete set null;
alter table projetos add column if not exists contrato_id uuid references contratos(id) on delete set null;
alter table projetos add column if not exists venda_id uuid references vendas(id) on delete set null;
alter table projetos add column if not exists produto_id uuid references produtos(id) on delete set null;
alter table produtos add column if not exists modelo_projeto_id uuid references projeto_modelos(id) on delete set null;
create index if not exists projetos_pessoa_ix on projetos (pessoa_id);
create unique index if not exists projetos_contrato_produto_uq on projetos (contrato_id, produto_id) where contrato_id is not null;
create unique index if not exists projetos_venda_uq on projetos (venda_id) where venda_id is not null;

create or replace function projeto_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.modelo_id is not null and not exists (select 1 from projeto_modelos where id = new.modelo_id and workspace_id = new.workspace_id) then
    raise exception 'O modelo precisa pertencer ao mesmo workspace'; end if;
  if new.campanha_id is not null and not exists (select 1 from campanhas where id = new.campanha_id and workspace_id = new.workspace_id) then
    raise exception 'A campanha precisa pertencer ao mesmo workspace'; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
    raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  if new.pessoa_id is not null and not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id) then
    raise exception 'O cliente precisa ser deste workspace'; end if;
  return new;
end $$;

create or replace function projeto_do_produto(p_ws uuid, p_pessoa uuid, p_produto uuid, p_contrato uuid, p_venda uuid, p_inicio date)
returns uuid language plpgsql security definer set search_path = public as $$
declare pr produtos; pe pessoas; novo uuid;
begin
  select * into pr from produtos where id = p_produto and workspace_id = p_ws;
  if not found or pr.modelo_projeto_id is null then return null; end if;
  select * into pe from pessoas where id = p_pessoa;
  if p_contrato is not null and exists (select 1 from projetos where contrato_id = p_contrato and produto_id = p_produto) then return null; end if;
  if p_venda is not null and exists (select 1 from projetos where venda_id = p_venda) then return null; end if;
  insert into projetos (workspace_id, nome, descricao, pessoa_id, contrato_id, venda_id, produto_id, modelo_id, data_inicio)
  values (p_ws, pr.nome || ' — ' || coalesce(pe.nome, 'cliente'),
          'Projeto criado automaticamente ao fechar ' || case when p_contrato is not null then 'o contrato' else 'a venda' end || ' de ' || pr.nome || '.',
          p_pessoa, p_contrato, p_venda, p_produto, pr.modelo_projeto_id,
          coalesce(p_inicio, (now() at time zone 'America/Sao_Paulo')::date))
  returning id into novo;
  return novo;
end $$;

create or replace function contratos_cria_projetos() returns trigger
language plpgsql security definer set search_path = public as $$
declare it record;
begin
  if new.status = 'ativo' and old.status is distinct from 'ativo' then
    for it in select distinct produto_id from contrato_itens where contrato_id = new.id loop
      perform projeto_do_produto(new.workspace_id, new.pessoa_id, it.produto_id, new.id, null, new.data_inicio);
    end loop;
  end if;
  return null;
end $$;
create trigger contratos_projetos_t after update of status on contratos
  for each row execute function contratos_cria_projetos();

create or replace function vendas_cria_projeto() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
    perform projeto_do_produto(new.workspace_id, new.pessoa_id, new.produto_id, null, new.id, (new.data_venda at time zone 'America/Sao_Paulo')::date);
  end if;
  return null;
end $$;
create trigger vendas_projeto_t after insert or update of status on vendas
  for each row execute function vendas_cria_projeto();

-- Novos canais de mídia e contato, para todos os workspaces atuais e futuros
insert into canais (workspace_id, codigo, nome)
select w.id, c.codigo, c.nome from workspaces w
cross join (values ('whatsapp_api', 'WhatsApp API oficial'), ('linkedin_ads', 'LinkedIn Ads'), ('tiktok_ads', 'TikTok Ads'), ('gpt_ads', 'GPT Ads (ChatGPT)')) as c(codigo, nome)
on conflict (workspace_id, codigo) do nothing;

create or replace function canais_novos_workspace() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into canais (workspace_id, codigo, nome) values
    (new.id, 'whatsapp_api', 'WhatsApp API oficial'), (new.id, 'linkedin_ads', 'LinkedIn Ads'),
    (new.id, 'tiktok_ads', 'TikTok Ads'), (new.id, 'gpt_ads', 'GPT Ads (ChatGPT)')
  on conflict (workspace_id, codigo) do nothing;
  return null;
end $$;
create trigger canais_novos_t after insert on workspaces for each row execute function canais_novos_workspace();
