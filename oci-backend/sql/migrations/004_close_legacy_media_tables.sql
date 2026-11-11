-- The legacy images and videos tables are closed to the API.
--
-- Nothing in the app reads or writes them (no code, not synced) and they are
-- empty, yet authenticated held every right on them and their INSERT
-- policies were WITH CHECK (true). PostgREST runs a request without a token
-- as authenticated too, so anyone on the internet could fill the disk and the
-- nightly backups through them.
--
-- delete_account_by_id() still reads and clears them; it runs as its owner,
-- so it is unaffected. The tables themselves can go with the other legacy
-- objects later.

revoke all on table public.images, public.videos from public, anon, authenticated;
