-- O vídeo dos disparos é enviado diretamente ao Storage, sem passar pelo corpo da Edge.
-- Mantém o bucket privado e preserva um limite maior se já estiver configurado.
update storage.buckets
set file_size_limit = greatest(coalesce(file_size_limit, 0), 31457280)
where id = 'atendimento';
