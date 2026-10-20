alter table projetos add column if not exists concluido_em timestamptz;
update projetos p set concluido_em = coalesce((select max(a.concluida_em) from projeto_atividades a where a.projeto_id = p.id), p.criado_em)
 where p.status = 'concluido' and p.concluido_em is null;
create or replace function projetos_marca_conclusao() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.status = 'concluido' then
    if tg_op = 'INSERT' or old.status is distinct from 'concluido' or new.concluido_em is null then new.concluido_em := coalesce(new.concluido_em, now()); end if;
  else
    new.concluido_em := null;
  end if;
  return new;
end $$;
create trigger projetos_conclusao before insert or update of status on projetos
  for each row execute function projetos_marca_conclusao();
