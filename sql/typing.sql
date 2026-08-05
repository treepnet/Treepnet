-- Typing indicator. One row per (conversation, user); the app upserts
-- updated_at while typing (throttled) and the other participant treats a fresh
-- updated_at as "typing…". `id` is '{conversation_id}_{user_id}' so an upsert
-- (INSERT OR REPLACE) keeps a single row. conversation_id is denormalized so
-- PowerSync sync rules can scope it without a JOIN.

create table if not exists public.typing_status (
  id text primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);

create index if not exists typing_status_conversation_idx
  on public.typing_status (conversation_id);

alter table public.typing_status enable row level security;

drop policy if exists "Participants read typing." on public.typing_status;
create policy "Participants read typing."
  on public.typing_status for select
  using (
    exists (
      select 1 from public.participants p
      where p.conversation_id = typing_status.conversation_id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "Insert own typing." on public.typing_status;
create policy "Insert own typing."
  on public.typing_status for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Update own typing." on public.typing_status;
create policy "Update own typing."
  on public.typing_status for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Delete own typing." on public.typing_status;
create policy "Delete own typing."
  on public.typing_status for delete to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.typing_status to authenticated;
grant select on public.typing_status to powersync_role;

notify pgrst, 'reload schema';

-- ============================================================================
-- ⚠️ PowerSync sync rules — add typing to the user_conversations bucket:
--       - select * from typing_status where conversation_id = bucket.conversation_id
-- Then DEPLOY from the PowerSync dashboard.
-- ============================================================================
