-- v0.107 — Cenários: ciclo de vida, descarte com motivo e link da documentação do teste
-- 1. gm_cenarios.descarte (jsonb): motivo, perdeu_para (id de outro cenário), observação, quando e quem descartou.
--    Descartar = status 'arquivado' com descarte preenchido (só cenário que nunca foi aprovado). Reabrir = volta para 'rascunho'.
--    Nada se apaga: o cenário descartado fica no Histórico (tela Cenários).
-- 2. growth_experimentos.link_doc: link da documentação completa do teste (Notion, Drive...), ao lado do aprendizado escrito.
-- 3. A trava do cenário aprovado passa a barrar também o descarte (status dele segue o Kanban).
-- 4. Tela gro-cenarios no catálogo de acesso, liberada para quem já tem o Growth Model.
-- Ativo, Encerrado e Cancelado não são gravados no cenário: vêm do card do Kanban ligado a ele (growth_experimentos.cenario_id).
-- Rode DEPOIS de 20261012100000_revops_retencao.sql. Idempotente.

alter table gm_cenarios add column if not exists descarte jsonb;
alter table gm_cenarios drop constraint if exists gm_cenarios_descarte_check;
alter table gm_cenarios add constraint gm_cenarios_descarte_check check (descarte is null or jsonb_typeof(descarte) = 'object');

-- cenário aprovado continua congelado: o descarte (com motivo) é só para quem nunca foi aprovado
create or replace function public.gm_cenarios_guarda() returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'aprovado' or old.aprovado_em is not null then raise exception 'Cenário aprovado não pode ser excluído: arquive-o'; end if;
    return old;
  end if;
  if old.status = 'aprovado' or (old.aprovado_em is not null and old.status = 'arquivado') then
    if new.status = 'arquivado' and old.status = 'aprovado'
       and new.nome = old.nome and new.escopo = old.escopo and new.financeiro = old.financeiro and coalesce(new.ue, '{}') = coalesce(old.ue, '{}')
       and coalesce(new.resultados, '{}') = coalesce(old.resultados, '{}') and coalesce(new.baseline, '{}') = coalesce(old.baseline, '{}')
       and new.descarte is not distinct from old.descarte then
      new.atualizado_em := now(); return new;
    end if;
    raise exception 'Cenário aprovado está congelado: duplique para criar uma nova versão';
  end if;
  new.atualizado_em := now();
  return new;
end $$;

alter table growth_experimentos add column if not exists link_doc text;
alter table growth_experimentos drop constraint if exists growth_experimentos_link_doc_check;
alter table growth_experimentos add constraint growth_experimentos_link_doc_check check (link_doc is null or link_doc ~* '^https?://');

do $$
begin
  if to_regclass('public.acesso_telas') is not null then
    update acesso_telas set nome = 'Growth Model' where tela = 'gro-modelo';
    insert into acesso_telas (tela, modulo, nome, grupo, ordem)
    values ('gro-cenarios', 'gro', 'Cenários', 'Growth', coalesce((select ordem from acesso_telas where tela = 'gro-modelo'), 31))
    on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
    if to_regclass('public.pacotes_acesso') is not null then
      update pacotes_acesso set telas = telas || array['gro-cenarios'] where telas @> array['gro-modelo'] and not telas @> array['gro-cenarios'];
    end if;
  end if;
end $$;
