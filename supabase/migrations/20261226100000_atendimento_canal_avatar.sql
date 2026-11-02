-- Foto configurável do canal, armazenada no bucket privado de Atendimento.
ALTER TABLE public.atd_canais
  ADD COLUMN IF NOT EXISTS avatar_path text;

COMMENT ON COLUMN public.atd_canais.avatar_path IS
  'Caminho da foto do canal no bucket privado atendimento; nunca armazena URL pública.';
