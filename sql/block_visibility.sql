-- Block gating needs the BLOCKED user to know they're blocked, so the app can
-- (for that user only) show the blocker's profile as private and disable
-- messaging. blocked_users was previously visible/synced only to the blocker;
-- this also exposes a block row to the person who was blocked.

drop policy if exists "Blocked user can see they are blocked."
  on public.blocked_users;
create policy "Blocked user can see they are blocked."
  on public.blocked_users for select
  using (auth.uid() = blocked_id);

notify pgrst, 'reload schema';

-- ============================================================================
-- ⚠️ PowerSync sync rules — add a bucket so the blocked user downloads the row:
--
--   user_blocked_by:
--     parameters: select request.jwt() ->> 'oid' as user_id
--     data:
--       - select * from blocked_users where blocked_id = bucket.user_id
--
-- Then DEPLOY the sync rules. (See sync_rules.txt — already updated there.)
-- ============================================================================
