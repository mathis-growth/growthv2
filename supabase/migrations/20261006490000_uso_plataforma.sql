-- v0.30: rastreio de uso das telas (quem usa o quê, com que frequência e onde trava)
-- Guarda só: tela, tipo de evento, tempo, título do formulário e mensagem de erro curta. Nenhum dado de cliente/lead/valor.
create table if not exists uso_eventos (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  usuario_email text,
  sessao text not null,
  tipo text not null check (tipo in ('tela','tempo','modal_abre','modal_salva','modal_cancela','erro')),
  tela text not null,
  detalhe text,
  segundos integer check (segundos is null or segundos between 0 and 14400),
  criado_em timestamptz not null default now()
);
create index if not exists uso_eventos_ws_data on uso_eventos (workspace_id, criado_em desc);
create index if not exists uso_eventos_ws_tela on uso_eventos (workspace_id, tela, tipo);
alter table uso_eventos enable row level security;
drop policy if exists uso_eventos_insercao on uso_eventos;
create policy uso_eventos_insercao on uso_eventos for insert to authenticated
  with check (pertence_ao_workspace(workspace_id) and user_id = auth.uid());
drop policy if exists uso_eventos_leitura on uso_eventos;
create policy uso_eventos_leitura on uso_eventos for select to authenticated
  using (eh_admin(workspace_id));

-- Resumo calculado no banco (só administrador do workspace)
create or replace function uso_resumo(p_ws uuid, p_ini date, p_fim date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not eh_admin(p_ws) then raise exception 'Só administrador vê o uso da plataforma'; end if;
  if p_fim - p_ini > 400 then raise exception 'O período máximo é de 400 dias'; end if;
  with e as (
    select * from uso_eventos
    where workspace_id = p_ws
      and criado_em >= p_ini::timestamp at time zone 'America/Sao_Paulo'
      and criado_em <  (p_fim + 1)::timestamp at time zone 'America/Sao_Paulo'),
  t as (
    select tela,
      count(*) filter (where tipo='tela') aberturas,
      count(distinct user_id) filter (where tipo='tela') usuarios,
      count(distinct sessao) filter (where tipo='tela') sessoes,
      coalesce(sum(segundos) filter (where tipo='tempo'),0) tempo_total,
      count(*) filter (where tipo='tempo') n_tempo,
      count(*) filter (where tipo='erro') erros,
      count(*) filter (where tipo='modal_abre') modais_abertos,
      count(*) filter (where tipo='modal_salva') modais_salvos,
      count(*) filter (where tipo='modal_cancela') modais_cancelados,
      max(criado_em) ultimo
    from e group by tela)
  select jsonb_build_object(
    'total_eventos', (select count(*) from e),
    'usuarios', (select count(distinct user_id) from e),
    'sessoes', (select count(distinct sessao) from e),
    'por_tela', coalesce((select jsonb_agg(jsonb_build_object('tela',tela,'aberturas',aberturas,'usuarios',usuarios,'sessoes',sessoes,
        'tempo_total',tempo_total,'tempo_medio', case when n_tempo>0 then round(tempo_total::numeric/n_tempo,0) end,
        'erros',erros,'modais_abertos',modais_abertos,'modais_salvos',modais_salvos,'modais_cancelados',modais_cancelados,
        'taxa_abandono', case when modais_abertos>0 then round(modais_cancelados::numeric/modais_abertos,4) end,
        'taxa_erro', case when aberturas>0 then round(erros::numeric/aberturas,4) end,'ultimo',ultimo) order by aberturas desc) from t),'[]'::jsonb),
    'por_usuario', coalesce((select jsonb_agg(x order by (x->>'aberturas')::int desc) from (
        select jsonb_build_object('email',coalesce(max(usuario_email),'?'),'aberturas',count(*) filter (where tipo='tela'),
          'telas',count(distinct tela) filter (where tipo='tela'),'sessoes',count(distinct sessao),
          'tempo_total',coalesce(sum(segundos) filter (where tipo='tempo'),0),'erros',count(*) filter (where tipo='erro'),'ultimo',max(criado_em)) x
        from e group by user_id) u),'[]'::jsonb),
    'por_dia', coalesce((select jsonb_agg(jsonb_build_object('dia',d,'aberturas',a,'usuarios',u) order by d) from (
        select (criado_em at time zone 'America/Sao_Paulo')::date d, count(*) filter (where tipo='tela') a, count(distinct user_id) u from e group by 1) q),'[]'::jsonb),
    'formularios', coalesce((select jsonb_agg(x order by (x->>'abertos')::int desc) from (
        select jsonb_build_object('tela',tela,'form',detalhe,'abertos',count(*) filter (where tipo='modal_abre'),
          'salvos',count(*) filter (where tipo='modal_salva'),'cancelados',count(*) filter (where tipo='modal_cancela')) x
        from e where tipo in ('modal_abre','modal_salva','modal_cancela') and detalhe is not null group by tela, detalhe) f),'[]'::jsonb),
    'erros_top', coalesce((select jsonb_agg(x order by (x->>'n')::int desc) from (
        select jsonb_build_object('tela',tela,'erro',detalhe,'n',count(*),'ultimo',max(criado_em)) x
        from e where tipo='erro' group by tela, detalhe order by count(*) desc limit 20) z),'[]'::jsonb)
  ) into r;
  return r;
end $$;
revoke all on function uso_resumo(uuid,date,date) from public, anon;
grant execute on function uso_resumo(uuid,date,date) to authenticated;
