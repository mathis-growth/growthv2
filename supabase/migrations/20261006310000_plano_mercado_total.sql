alter table planos add column if not exists mercado_total numeric(16,0) check (mercado_total is null or mercado_total > 0);
alter table planos add column if not exists mercado_rotulo text;
comment on column planos.mercado_total is 'Tamanho do mercado endereçável (nº de pessoas ou empresas) para calcular penetração de mercado';
