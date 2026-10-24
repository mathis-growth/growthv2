-- v0.132 (parte 2, depois do RODAR_v0.132_alertas.sql e de publicar a edge function "avisos"):
-- liga o agendador do banco. De hora em hora (no minuto 7) confere os alertas de cada cliente com alertas ligados,
-- manda o resumo de ontem na hora escolhida e pede à função "avisos" que envie os e-mails e WhatsApps da fila.
-- Troque <PROJETO> pelo id do projeto no Supabase (ex.: yngyghlyonybvfvjcmxl). Pode ser rodado de novo sem erro.

create extension if not exists pg_cron;
create extension if not exists pg_net;

insert into public.sistema_config (chave, valor) values ('avisos_url', 'https://<PROJETO>.supabase.co/functions/v1/avisos')
on conflict (chave) do update set valor = excluded.valor;

select cron.unschedule(jobid) from cron.job where jobname = 'growths-alertas';
select cron.schedule('growths-alertas', '7 * * * *', $$select public.growths_rodar_agendado()$$);
