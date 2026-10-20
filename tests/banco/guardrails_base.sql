-- Complemento para testar a v0.100 (guardrails), depois de gm_base + v0.98 + decisao_base + v0.99.
create table if not exists acesso_telas (tela text primary key, modulo text not null, nome text not null, grupo text, ordem int not null default 0);
create table if not exists pacotes_acesso (id uuid primary key default gen_random_uuid(), nome text, telas text[]);
insert into acesso_telas values ('gro-ciclo', 'gro', 'Ciclo', 'Growth', 60) on conflict do nothing;
insert into pacotes_acesso (nome, telas) values ('Consultoria', array['gro-ciclo']);
insert into produtos (id, workspace_id, nome) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Curso'), ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1', 'Mentoria');
