alter function checa_lancamento_balanceado() set search_path = public;
revoke execute on function checa_lancamento_balanceado() from public, anon, authenticated;
