// Edge function "conexoes": login com Meta e Google e sincronização dos dados. As rotas e os detalhes estão em rotas.ts.
// Publicar SEM verificação de JWT: supabase functions deploy conexoes --no-verify-jwt
import { atende } from './rotas.ts';
Deno.serve(atende);
