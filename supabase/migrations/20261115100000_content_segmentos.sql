-- v0.160 — Linha editorial com subtemas e datas no Kanban (Growth's Content).
-- Subtema = tema com tema_pai_id (dois níveis: tema → subtema), herdando a linha do pai. O nome continua único por cliente.
-- Conteúdo ganha subtema_id. No método simples, aprovar a ideia exige tema e data de publicação (o conteúdo entra no calendário).
-- Pode ser rodado de novo sem erro.
alter table public.conteudo_temas add column if not exists tema_pai_id uuid references public.conteudo_temas(id) on delete cascade;
alter table public.conteudo_temas drop constraint if exists conteudo_temas_pai_check;
alter table public.conteudo_temas add constraint conteudo_temas_pai_check check (tema_pai_id is null or tema_pai_id <> id);
create index if not exists conteudo_temas_pai on public.conteudo_temas (tema_pai_id);
alter table public.conteudos add column if not exists subtema_id uuid references public.conteudo_temas(id) on delete set null;

create or replace function public.conteudo_tema_valida() returns trigger language plpgsql security definer set search_path = public as $$
declare pai record;
begin
  if new.tema_pai_id is not null then
    select * into pai from conteudo_temas where id = new.tema_pai_id;
    if pai.id is null or pai.workspace_id <> new.workspace_id then raise exception 'O tema do subtema precisa ser deste cliente'; end if;
    if pai.tema_pai_id is not null then raise exception 'Subtema de subtema não existe: escolha um tema'; end if;
    new.linha_id := pai.linha_id; new.transversal := false;
  elsif tg_op = 'UPDATE' and old.tema_pai_id is null and exists (select 1 from conteudo_temas s where s.tema_pai_id = new.id) then
    update conteudo_temas set linha_id = new.linha_id where tema_pai_id = new.id and linha_id is distinct from new.linha_id;
  end if;
  return new;
end $$;
drop trigger if exists conteudo_tema_valida_t on public.conteudo_temas;
create trigger conteudo_tema_valida_t before insert or update on public.conteudo_temas for each row execute function public.conteudo_tema_valida();

CREATE OR REPLACE FUNCTION public.conteudo_valida()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pos int; tem_ideia boolean; tem_pauta boolean; met text; dests text[]; tem_formatos boolean;
begin
  if new.tema_id is not null and not exists (select 1 from conteudo_temas where id = new.tema_id and workspace_id = new.workspace_id) then
    raise exception 'O tema precisa pertencer ao mesmo workspace'; end if;
  -- v0.160: subtema. Se o tema escolhido for um subtema (ex.: importação pelo nome), ele vira o subtema e o tema passa a ser o pai.
  if new.tema_id is not null and exists (select 1 from conteudo_temas where id = new.tema_id and tema_pai_id is not null) then
    new.subtema_id := new.tema_id; select tema_pai_id into new.tema_id from conteudo_temas where id = new.subtema_id; end if;
  if new.subtema_id is not null then
    if new.tema_id is null then select tema_pai_id into new.tema_id from conteudo_temas where id = new.subtema_id and workspace_id = new.workspace_id; end if;
    if not exists (select 1 from conteudo_temas where id = new.subtema_id and workspace_id = new.workspace_id and tema_pai_id = new.tema_id) then
      raise exception 'O subtema precisa ser um subtema do tema escolhido'; end if;
  end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
    raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  if new.formato_id is not null and not exists (select 1 from conteudo_formatos where id = new.formato_id and workspace_id = new.workspace_id and grupo = 'formato') then
    raise exception 'O formato precisa ser um formato deste workspace'; end if;
  if new.quadro_id is not null and not exists (select 1 from conteudo_formatos where id = new.quadro_id and workspace_id = new.workspace_id and grupo = 'quadro') then
    raise exception 'O quadro de autoridade precisa ser deste workspace'; end if;
  select coalesce(c.metodo, 'simples'), coalesce(c.destinos, '{}') into met, dests from conteudo_config c where c.workspace_id = new.workspace_id;
  met := coalesce(met, 'simples'); dests := coalesce(dests, '{}');
  new.destino := nullif(trim(coalesce(new.destino, '')), '');
  if new.destino is not null and cardinality(dests) > 0 and not (lower(new.destino) = any (select lower(x) from unnest(dests) x)) then
    raise exception 'Destino "%" não está entre os destinos cadastrados (%)', new.destino, array_to_string(dests, ', '); end if;
  if new.destino is not null and cardinality(dests) > 0 then select x into new.destino from unnest(dests) x where lower(x) = lower(new.destino) limit 1; end if;
  new.palavra_chave := nullif(trim(coalesce(new.palavra_chave, '')), '');
  new.tags := coalesce((select array_agg(distinct trim(x)) from unnest(new.tags) x where trim(x) <> ''), '{}');
  if new.validado and (tg_op = 'INSERT' or not old.validado) then new.validado_em := coalesce(new.validado_em, now()); end if;
  if not new.validado then new.validado_em := null; end if;
  pos := array_position(array['ideia', 'pauta', 'producao', 'pronto', 'agendado', 'publicado'], new.status);
  if pos is not null then
    if met = 'simples' then
      -- v0.159: o fluxo novo do Growth's Content (roteiro aprovado antes da peça; peça aprovada antes de ficar pronta)
      if pos >= 2 and new.tema_id is null then raise exception 'Escolha o tema antes de aprovar a ideia'; end if;
      if pos >= 2 and new.data_publicacao is null then raise exception 'Informe a data de publicação antes de aprovar a ideia: ela coloca o conteúdo no calendário'; end if;
      if pos >= 3 and new.roteiro_aprovado_em is null then raise exception 'Aprove o roteiro antes de produzir a peça'; end if;
      if pos >= 4 and new.peca_aprovada_em is null then raise exception 'Aprove a peça antes de marcar como pronta'; end if;
    elsif met = 'score6' then
      tem_formatos := exists (select 1 from conteudo_formatos where workspace_id = new.workspace_id and grupo = 'formato' and ativo);
      if pos >= 2 and num_nonnulls(new.s1, new.s2, new.s3, new.s4, new.s5, new.s6) < 6 then raise exception 'Dê as 6 notas (1 a 5) do score antes de aprovar a pauta'; end if;
      if pos >= 2 and new.tema_id is null then raise exception 'Escolha o território e a frente antes de aprovar a pauta'; end if;
      if pos >= 2 and cardinality(dests) > 0 and new.destino is null then raise exception 'Escolha o destino (%) antes de aprovar a pauta', array_to_string(dests, ', '); end if;
      if pos >= 2 and tem_formatos and new.formato_id is null then raise exception 'Escolha o formato antes de aprovar a pauta'; end if;
      if pos >= 3 and not new.validado then raise exception 'Marque VALIDAR antes de produzir: a escolha é sua, não do ranking'; end if;
    else
      tem_ideia := num_nonnulls(new.ideia_n1, new.ideia_n2, new.ideia_n3, new.ideia_n4, new.ideia_n5) = 5;
      tem_pauta := num_nonnulls(new.pauta_n1, new.pauta_n2, new.pauta_n3, new.pauta_n4, new.pauta_n5) = 5;
      if pos >= 2 and not tem_ideia then raise exception 'Dê as 5 notas da ideia antes de aprová-la como pauta'; end if;
      if pos >= 2 and new.tema_id is null then raise exception 'Escolha o tema antes de aprovar a pauta'; end if;
      if pos >= 3 and not tem_pauta then raise exception 'Dê as 5 notas da pauta antes de produzir'; end if;
    end if;
    if met <> 'simples' and pos >= 3 and cardinality(new.canais) = 0 then raise exception 'Marque pelo menos um canal antes de produzir'; end if;
    if met <> 'simples' and pos >= 4 and (new.copy_url is null or new.midia_url is null) then raise exception 'Informe o link da copy e o link da mídia para marcar como pronto'; end if;
    if pos >= 5 and new.data_publicacao is null then raise exception 'Informe a data de publicação para agendar'; end if;
  end if;
  if new.data_publicacao is not null and new.dia_semana is null then new.dia_semana := extract(isodow from new.data_publicacao)::smallint; end if;
  if new.status = 'publicado' then new.publicado_em := coalesce(new.publicado_em, now()); else new.publicado_em := null; end if;
  new.atualizado_em := now();
  return new;
end $function$;

notify pgrst, 'reload schema';
