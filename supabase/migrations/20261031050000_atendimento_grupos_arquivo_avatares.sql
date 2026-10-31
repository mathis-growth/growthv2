-- v0.189 — Identidade dos grupos, arquivamento local e miniaturas privadas.
-- Adiciona metadados sem excluir ou alterar histórico de conversas.
ALTER TABLE public.atd_canais
  ADD COLUMN IF NOT EXISTS exibir_grupos_arquivados boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS metadados_atualizados_em timestamptz;

ALTER TABLE public.atd_conversas
  ADD COLUMN IF NOT EXISTS arquivada boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS avatar_path text,
  ADD COLUMN IF NOT EXISTS avatar_atualizado_em timestamptz;

CREATE INDEX IF NOT EXISTS atd_conversas_grupos_arquivados_idx
  ON public.atd_conversas (workspace_id, canal_id, arquivada)
  WHERE grupo = true;

COMMENT ON COLUMN public.atd_conversas.arquivada IS
  'Arquivo operacional do Growth V2: Evolution 2.3.7 não garante disponibilizar o estado arquivado do celular.';
COMMENT ON COLUMN public.atd_canais.exibir_grupos_arquivados IS
  'Preferência por instância para mostrar grupos marcados como arquivados no Growth V2.';
COMMENT ON COLUMN public.atd_conversas.avatar_path IS
  'Caminho no bucket privado atendimento. Nunca uma URL pública ou token da Evolution.';
