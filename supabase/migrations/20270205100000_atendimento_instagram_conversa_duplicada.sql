-- Consolida a única duplicação Instagram conhecida sem excluir nenhum registro.
-- A conversa mais antiga, identificada pelo ID externo da DM, permanece ativa.
-- Mensagens da segunda conversa são movidas para ela; a segunda é arquivada.
-- O bloco só atua se houver exatamente um par sem referências ou IDs de mensagem conflitantes.
do $$
declare
  v_pares integer;
  v_principal uuid;
  v_duplicada uuid;
  v_mensagens integer;
  v_movidas integer;
begin
  with pares as (
    select distinct principal.id as principal_id, duplicada.id as duplicada_id
    from public.social_conversas social
    join public.atd_canais canal
      on canal.workspace_id = social.workspace_id
     and canal.canal = 'instagram'
     and canal.provedor = 'zernio'
    join public.atd_conversas principal
      on principal.canal_id = canal.id
     and principal.externo_id = social.id_externo
     and principal.arquivada = false
    join public.atd_conversas duplicada
      on duplicada.canal_id = canal.id
     and duplicada.id <> principal.id
     and duplicada.endereco = social.id_externo
     and duplicada.externo_id <> social.id_externo
     and duplicada.arquivada = false
    where principal.pessoa_id is not null
      and principal.pessoa_id = duplicada.pessoa_id
      and principal.criado_em < duplicada.criado_em
      and not exists (select 1 from public.atd_agendamentos x where x.conversa_id = duplicada.id)
      and not exists (select 1 from public.atd_automacao_execucoes x where x.conversa_id = duplicada.id)
      and not exists (select 1 from public.atd_disparos_grupos_itens x where x.conversa_id = duplicada.id)
      and not exists (select 1 from public.atd_grupo_campanha_acessos x where x.conversa_id = duplicada.id)
      and not exists (
        select 1
        from public.atd_mensagens origem
        join public.atd_mensagens destino
          on destino.conversa_id = principal.id
         and destino.externo_id = origem.externo_id
        where origem.conversa_id = duplicada.id
          and origem.externo_id is not null
      )
  )
  select count(*), (array_agg(principal_id))[1], (array_agg(duplicada_id))[1]
    into v_pares, v_principal, v_duplicada
  from pares;

  if v_pares = 0 then return; end if;
  if v_pares <> 1 then
    raise exception 'Consolidação Instagram exige um único par seguro; encontrados %', v_pares;
  end if;

  -- atd_receber bloqueia esta mesma linha do canal antes de gravar mensagens.
  perform 1 from public.atd_canais canal
    join public.atd_conversas conversa on conversa.canal_id = canal.id
    where conversa.id = v_principal
    for update of canal;

  select count(*) into v_mensagens
    from public.atd_mensagens where conversa_id = v_duplicada;

  update public.atd_mensagens
     set conversa_id = v_principal
   where conversa_id = v_duplicada;
  get diagnostics v_movidas = row_count;
  if v_movidas <> v_mensagens then
    raise exception 'Mensagens movidas (%) diferem da contagem inicial (%)', v_movidas, v_mensagens;
  end if;

  update public.atd_conversas
     set arquivada = true, status = 'resolvida', nao_lidas = 0
   where id = v_duplicada and arquivada = false;
  if not found then
    raise exception 'A conversa duplicada mudou durante a consolidação';
  end if;
end $$;
