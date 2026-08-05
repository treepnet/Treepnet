-- Read receipts (single vs double check). Unlike messages.is_read (which does
-- not round-trip through sync), this per-(conversation,user) "last read"
-- watermark is a synced upsert, so the SENDER can learn when the RECIPIENT read
-- up to. A message shows ✓✓ once the other party's last_read_at >= its time.
-- `id` = '{conversation_id}_{user_id}' so an upsert keeps one row per user.

create table if not exists public.conversation_reads (
  id text primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now()
);

create index if not exists conversation_reads_conversation_idx
  on public.conversation_reads (conversation_id);

alter table public.conversation_reads enable row level security;

drop policy if exists "Participants read receipts." on public.conversation_reads;
create policy "Participants read receipts."
  on public.conversation_reads for select
  using (
    exists (
      select 1 from public.participants p
      where p.conversation_id = conversation_reads.conversation_id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "Insert own receipt." on public.conversation_reads;
create policy "Insert own receipt."
  on public.conversation_reads for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Update own receipt." on public.conversation_reads;
create policy "Update own receipt."
  on public.conversation_reads for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Delete own receipt." on public.conversation_reads;
create policy "Delete own receipt."
  on public.conversation_reads for delete to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.conversation_reads to authenticated;
grant select on public.conversation_reads to powersync_role;

notify pgrst, 'reload schema';

-- ============================================================================
-- ⚠️ PowerSync sync rules — add to the user_conversations bucket:
--       - select * from conversation_reads where conversation_id = bucket.conversation_id
-- Then DEPLOY. (sync_rules.txt already updated.)
-- ============================================================================
