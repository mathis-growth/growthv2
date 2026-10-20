-- v0.67: cadastro de fornecedor com endereço, descrição/observações e link do contrato.
alter table fornecedores add column if not exists endereco text, add column if not exists observacoes text, add column if not exists contrato_url text;
