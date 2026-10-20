-- Entrar numa lista filha (API) também aplica a etapa da lista pai (grupo).
create or replace function entrar_na_lista(p_pessoa uuid, p_lista uuid) returns void
language plpgsql security definer set search_path = public as $$
declare l funil_listas; pf pessoa_funil; cur uuid; n int := 0; was boolean; nome_l text; alvo uuid; o_atual int; o_alvo int;
begin
  select * into l from funil_listas where id = p_lista;
  if not found then raise exception 'Lista não encontrada'; end if;
  if not pode_operar(l.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  select * into pf from pessoa_funil where pessoa_id = p_pessoa and funil_id = l.funil_id;
  if not found then raise exception 'A pessoa não está neste funil'; end if;

  cur := p_lista;
  while cur is not null and n < 10 loop
    select nome, etapa_ao_entrar_id into nome_l, alvo from funil_listas where id = cur;
    select ativo into was from pessoa_lista where pessoa_id = p_pessoa and lista_id = cur;
    insert into pessoa_lista (workspace_id, pessoa_id, lista_id, ativo, entrou_em, saiu_em)
    values (l.workspace_id, p_pessoa, cur, true, now(), null)
    on conflict (pessoa_id, lista_id) do update
      set ativo = true, saiu_em = null,
          entrou_em = case when pessoa_lista.ativo then pessoa_lista.entrou_em else now() end;
    if not coalesce(was, false) then
      insert into pessoa_funil_historico (workspace_id, pessoa_id, funil_id, tipo, ref, de, para)
      values (l.workspace_id, p_pessoa, l.funil_id, 'lista', nome_l, 'fora', 'dentro');
    end if;
    if alvo is not null then
      select ordem into o_alvo from funil_etapas where id = alvo;
      select e.ordem into o_atual from pessoa_funil x join funil_etapas e on e.id = x.etapa_id where x.id = pf.id;
      if o_alvo > o_atual then update pessoa_funil set etapa_id = alvo where id = pf.id; end if;
    end if;
    select lista_pai_id into cur from funil_listas where id = cur;
    n := n + 1;
  end loop;
end $$;
