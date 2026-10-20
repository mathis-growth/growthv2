-- Novas categorias do catálogo de integrações: redes sociais/conteúdo e inteligência artificial.
alter table integracoes drop constraint integracoes_categoria_check;
alter table integracoes add constraint integracoes_categoria_check
  check (categoria in ('anuncios', 'video', 'vendas', 'mensageria', 'social', 'ia', 'outro'));
