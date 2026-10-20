alter role authenticator with login password 'audit' noinherit;
grant anon, authenticated, service_role to authenticator;
grant usage on schema public, extensions, auth to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant execute on all functions in schema public to authenticated, service_role;
grant execute on all functions in schema auth to anon, authenticated, service_role;
grant execute on all functions in schema extensions to anon, authenticated, service_role;
