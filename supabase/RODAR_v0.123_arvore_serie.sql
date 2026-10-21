-- JÁ APLICADO em produção em 21/10/2026 (via Supabase). Pode rodar de novo sem problema.
-- v0.123 — Série de um número da árvore no tempo (para o gráfico de linha do painel "De onde vem este número").
-- Calcula o mesmo nó (arvore_no) para cada dia, semana, mês ou ano do período. Uma chamada só, no máximo 62 pontos.
-- Números de período (ini/fim): cada ponto é o período daquele dia/semana/mês/ano, cortado no início e no fim escolhidos.
-- Números "na data" (hoje: saldo, MRR, a receber…): cada ponto é o valor no último dia daquele dia/semana/mês/ano.
create or replace function public.arvore_serie(p_ws uuid, p_no text, p_par jsonb default '{}'::jsonb, p_gran text default 'mes')
returns jsonb language plpgsql stable security invoker set search_path = public as $$
declare ini date; fim date; d date; e date; r jsonb; saida jsonb := '[]'::jsonb; modo text; n int := 0; passo interval;
begin
  if p_gran not in ('dia', 'semana', 'mes', 'ano') then raise exception 'Agrupamento inválido: %', p_gran; end if;
  if p_par ? 'ini' and p_par ? 'fim' then
    ini := (p_par ->> 'ini')::date; fim := (p_par ->> 'fim')::date; modo := 'periodo';
  elsif p_par ? 'hoje' then
    fim := (p_par ->> 'hoje')::date; modo := 'data';
    ini := case p_gran when 'dia' then fim - 29 when 'semana' then fim - 7 * 11 when 'mes' then (date_trunc('month', fim) - interval '11 months')::date
           else (date_trunc('year', fim) - interval '4 years')::date end;
  else return null; end if;
  if fim < ini then return '[]'::jsonb; end if;
  passo := case p_gran when 'dia' then interval '1 day' when 'semana' then interval '7 days' when 'mes' then interval '1 month' else interval '1 year' end;
  d := case p_gran when 'dia' then ini when 'semana' then date_trunc('week', ini)::date when 'mes' then date_trunc('month', ini)::date else date_trunc('year', ini)::date end;
  -- muitos pontos: começa mais tarde (mantém os mais recentes)
  while (fim - d) / greatest(1, extract(epoch from passo) / 86400)::int > 61 loop d := (d + passo)::date; end loop;
  while d <= fim and n < 62 loop
    e := ((d + passo)::date) - 1;
    if modo = 'periodo' then r := arvore_no(p_ws, p_no, p_par || jsonb_build_object('ini', greatest(d, ini), 'fim', least(e, fim)));
    else r := arvore_no(p_ws, p_no, p_par || jsonb_build_object('hoje', least(e, fim))); end if;
    saida := saida || jsonb_build_object('ini', greatest(d, ini), 'fim', least(e, fim), 'valor', r -> 'valor', 'un', r ->> 'un',
      'parcial', modo = 'periodo' and (d < ini or e > fim));
    d := (d + passo)::date; n := n + 1;
  end loop;
  return saida;
end $$;
revoke execute on function public.arvore_serie(uuid, text, jsonb, text) from public, anon;
grant execute on function public.arvore_serie(uuid, text, jsonb, text) to authenticated;
