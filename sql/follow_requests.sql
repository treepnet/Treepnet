-- ============================================================================
-- follow_requests.sql — Private-account follow-request approval flow
-- ----------------------------------------------------------------------------
-- Adds a `status` column to `subscriptions`:
--   'accepted' — a normal follow (public accounts, and approved requests)
--   'pending'  — a follow REQUEST awaiting the owner's Accept/Decline
--
-- Content visibility (private profile gating) unlocks only on 'accepted'.
-- Default is 'accepted' so every EXISTING follow keeps working untouched.
-- ============================================================================

alter table public.subscriptions
  add column if not exists status text not null default 'accepted';

-- Optional integrity guard (safe to skip if you prefer):
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'subscriptions_status_check'
  ) then
    alter table public.subscriptions
      add constraint subscriptions_status_check
      check (status in ('pending', 'accepted'));
  end if;
end $$;

-- The owner of the account (subscribed_to) must be able to UPDATE a request
-- row to 'accepted'. INSERT (send request) and DELETE (cancel / decline) are
-- already covered by the existing policies in tables.sql:
--   * insert: authenticated  (the requester creates the pending row)
--   * delete: auth.uid() = subscribed_to_id OR auth.uid() = subscriber_id
--             (subscriber cancels, or owner declines)
drop policy if exists "Owner can accept a follow request." on public.subscriptions;
create policy "Owner can accept a follow request."
  on public.subscriptions for update to authenticated
  using (auth.uid() = subscribed_to_id)
  with check (auth.uid() = subscribed_to_id);

grant update on public.subscriptions to authenticated;

-- PostgREST schema cache refresh:
notify pgrst, 'reload schema';

-- ============================================================================
-- ⚠️ PowerSync sync rules — MUST include the new column
-- ----------------------------------------------------------------------------
-- The app reads `subscriptions.status` from the local mirror. If your
-- PowerSync sync rules select explicit columns for `subscriptions`, add
-- `status` to that list (or use `select *`). Otherwise the column syncs as
-- NULL locally — which the app treats as 'accepted', so pending requests would
-- wrongly unlock content. After editing sync rules, deploy them.
--
-- Also make sure `subscriptions` is granted to your PowerSync replication role
-- (e.g. `grant select on public.subscriptions to powersync_role;`) — it should
-- already be, since follows synced before this change.
-- ============================================================================
