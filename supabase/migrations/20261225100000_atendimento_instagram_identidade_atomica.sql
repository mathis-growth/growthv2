-- Resolve a conversa do Instagram pelo participante na mesma transação que
-- grava a mensagem. atd_receber já bloqueia a linha do canal; com a busca
-- dentro deste lock, webhooks simultâneos não criam conversas duplicadas.
create or replace function public.atd_receber(p_canal uuid,p_conversa jsonb,p_mensagem jsonb default null) returns uuid
language plpgsql security definer set search_path=public as $$
declare c atd_canais; cv uuid; mid uuid; nova boolean;
begin
 select * into strict c from atd_canais where id=p_canal for update;

 if c.provedor='zernio' and c.canal='instagram'
    and nullif(p_conversa->>'endereco','') is not null then
  select id into cv from atd_conversas
   where canal_id=c.id and endereco=p_conversa->>'endereco'
   order by criado_em,id limit 1;
 end if;

 if cv is null then
  insert into atd_conversas(workspace_id,canal_id,externo_id,nome,endereco,grupo)
  values(c.workspace_id,c.id,p_conversa->>'id',
    coalesce(nullif(p_conversa->>'nome',''),p_conversa->>'id'),
    p_conversa->>'endereco',coalesce((p_conversa->>'grupo')::boolean,false))
  on conflict(canal_id,externo_id) do update
   set nome=case when nullif(p_conversa->>'nome','') is not null
     then excluded.nome else atd_conversas.nome end
  returning id into cv;
 else
  update atd_conversas set nome=case
    when nullif(p_conversa->>'nome','') is not null then p_conversa->>'nome'
    else nome end
   where id=cv;
 end if;

 if p_mensagem is null then return cv; end if;
 insert into atd_mensagens(workspace_id,conversa_id,externo_id,direcao,texto,participante,autor_nome,status,em,anexos)
 values(c.workspace_id,cv,p_mensagem->>'id',p_mensagem->>'direcao',
   coalesce(p_mensagem->>'texto',''),p_mensagem->>'participante',
   p_mensagem->>'autor_nome',coalesce(p_mensagem->>'status','recebida'),
   coalesce((p_mensagem->>'em')::timestamptz,now()),
   coalesce(p_mensagem->'anexos','[]'))
 on conflict(conversa_id,externo_id) do nothing returning id into mid;
 nova := mid is not null;
 if nova then
  update atd_conversas set
   nao_lidas=nao_lidas+case when p_mensagem->>'direcao'='recebida'
     and not coalesce((p_mensagem->>'historica')::boolean,false) then 1 else 0 end,
   status=case when p_mensagem->>'direcao'='recebida'
     and not coalesce((p_mensagem->>'historica')::boolean,false) then 'aberta' else status end,
   ultima_mensagem=case when ultima_em is null
     or ultima_em<=coalesce((p_mensagem->>'em')::timestamptz,now())
     then p_mensagem->>'texto' else ultima_mensagem end,
   ultima_em=greatest(ultima_em,coalesce((p_mensagem->>'em')::timestamptz,now()))
   where id=cv;
 end if;
 return cv;
end $$;
revoke all on function public.atd_receber(uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.atd_receber(uuid,jsonb,jsonb) to service_role;
