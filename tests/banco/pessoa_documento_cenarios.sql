-- v0.173 (E1): CPF/CNPJ na pessoa. Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "pessoa_documento: tudo OK".
do $t$
declare ws uuid; ws2 uuid; a uuid; b uuid; c uuid; d uuid; n int;
begin
  -- validação (CPF e CNPJ de teste, com dígitos certos)
  if not documento_valido('529.982.247-25') or not documento_valido('11.222.333/0001-81') then raise exception 'X: válidos recusados'; end if;
  if documento_valido('529.982.247-24') or documento_valido('11.222.333/0001-80') or documento_valido('111.111.111-11') or documento_valido('123') then raise exception 'X: inválido aceito'; end if;
  if documento_normaliza(' 529.982.247-25 ') <> '52998224725' or documento_normaliza('') is not null then raise exception 'X: normaliza'; end if;

  insert into workspaces (nome) values ('DOC') returning id into ws;
  insert into workspaces (nome) values ('DOC2') returning id into ws2;
  insert into pessoas (workspace_id, nome, email, documento) values (ws, 'Ana', 'ana@x.com', '529.982.247-25') returning id into a;
  if (select documento from pessoas where id = a) <> '52998224725' then raise exception 'X: não guardou só os dígitos'; end if;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Empresa Beta', 'beta@x.com') returning id into b;
  update pessoas set documento = '11222333000181' where id = b;
  if (select documento from pessoas where id = b) <> '11222333000181' then raise exception 'X: CNPJ'; end if;
  -- inválido
  begin update pessoas set documento = '52998224724' where id = b; raise exception 'X: aceitou CPF inválido';
  exception when check_violation then null; end;
  -- repetido no mesmo workspace
  begin insert into pessoas (workspace_id, nome, email, documento) values (ws, 'Ana 2', 'ana2@x.com', '52998224725'); raise exception 'X: aceitou CPF repetido';
  exception when unique_violation then null; end;
  -- mesmo documento em outro workspace pode (empresas diferentes)
  insert into pessoas (workspace_id, nome, email, documento) values (ws2, 'Ana', 'ana@x.com', '52998224725');
  -- apagar o documento
  update pessoas set documento = '' where id = b;
  if (select documento from pessoas where id = b) is not null then raise exception 'X: vazio não virou nulo'; end if;
  -- mesclar: documento passa para a mantida
  insert into pessoas (workspace_id, nome, email) values (ws, 'Carla', 'carla@x.com') returning id into c;
  insert into pessoas (workspace_id, nome, telefone, documento) values (ws, 'Carla (zap)', '35999990000', '11222333000181') returning id into d;
  perform set_config('growths.mesclar_interno', '1', true);
  perform _pessoas_mesclar_v088(c, d, 'teste');
  if (select documento from pessoas where id = c) <> '11222333000181' or exists (select 1 from pessoas where id = d) then raise exception 'X: mesclar não levou o documento'; end if;
  -- mesclar: documentos diferentes impedem
  begin perform _pessoas_mesclar_v088(a, c, 'teste'); raise exception 'X: mesclou documentos diferentes';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; if sqlerrm not like '%CPF/CNPJ diferentes%' then raise exception 'X: mensagem errada: %', sqlerrm; end if; end;
  select count(*) into n from pessoas where id in (a, c); if n <> 2 then raise exception 'X: mesclagem recusada apagou alguém'; end if;
  raise notice 'pessoa_documento: tudo OK';
end $t$;
select 'pessoa_documento: tudo OK' as resultado;
