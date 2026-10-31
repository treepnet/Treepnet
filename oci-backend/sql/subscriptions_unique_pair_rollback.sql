-- Undoes subscriptions_unique_pair.sql: back to the plain pair index.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < subscriptions_unique_pair_rollback.sql

create index concurrently if not exists subscriptions_pair_idx
  on public.subscriptions (subscriber_id, subscribed_to_id);
drop index concurrently if exists public.subscriptions_pair_unique;
