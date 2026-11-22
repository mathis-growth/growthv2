-- Vincula ao CRM conversas Instagram já existentes no Atendimento.
-- A origem social só é usada quando existe uma única conversa correspondente
-- e a pessoa pertence ao mesmo workspace. Não copia mensagens nem sobrescreve
-- vínculos feitos manualmente.
with candidatos as (
  select
    a.id as conversa_id,
    (array_agg(distinct s.pessoa_id))[1] as pessoa_id
  from public.atd_conversas a
  join public.atd_canais ch
    on ch.id = a.canal_id
   and ch.workspace_id = a.workspace_id
   and ch.canal = 'instagram'
  join public.social_conversas s
    on s.workspace_id = a.workspace_id
   and s.id_externo is not null
   and (s.id_externo = a.externo_id or s.id_externo = a.endereco)
  join public.pessoas p
    on p.id = s.pessoa_id
   and p.workspace_id = a.workspace_id
  where a.pessoa_id is null
  group by a.id
  having count(distinct s.id) = 1
     and count(distinct s.pessoa_id) = 1
)
update public.atd_conversas a
set pessoa_id = c.pessoa_id
from candidatos c
where a.id = c.conversa_id
  and a.pessoa_id is null;
