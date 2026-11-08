-- v0.282 — Conteúdo: aprovar a ideia não pede data nem tema.
-- Pedido da Rebecka (07/11): "quando eu mudo para ideia aprovada, ele não tem que me obrigar a colocar a data. De nada. Só quando for a produção."
-- · Método simples: tema e data de publicação passam a ser exigidos a partir de Em produção (antes: a partir de Pautas aprovadas).
-- · Os outros métodos (notas e score) não mudam. O resto da função é igual à versão em produção.
-- Aditivo e idempotente (create or replace). Rode depois de 20270125100000_atendimento_automacoes_email_canvas.sql.

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
      -- v0.282: aprovar a ideia (Pautas aprovadas) não pede nada; tema e data de publicação só na produção
      if pos >= 3 and new.tema_id is null then raise exception 'Escolha o tema antes de mandar para a produção'; end if;
      if pos >= 3 and new.data_publicacao is null then raise exception 'Informe a data de publicação antes de mandar para a produção: ela coloca o conteúdo no calendário'; end if;
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
