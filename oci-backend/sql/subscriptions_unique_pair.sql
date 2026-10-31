-- One follow (or follow request) per pair. The app checked "already
-- following?" and inserted in two steps, so two quick taps could both insert:
-- with no unique pair on the server, the second row stayed and the follower
-- count went up by two. The pair index from missing_indexes.sql becomes this
-- unique one (it serves the same lookups). Prod had no duplicates
-- (2026-10-31); with any, this fails and leaves an INVALID index — remove the
-- extra rows, drop it, run again.
--
-- CONCURRENTLY: built without blocking writes, so no begin/commit.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < subscriptions_unique_pair.sql
-- Undo: subscriptions_unique_pair_rollback.sql

create unique index concurrently if not exists subscriptions_pair_unique
  on public.subscriptions (subscriber_id, subscribed_to_id);
drop index concurrently if exists public.subscriptions_pair_idx;
