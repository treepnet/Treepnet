-- Blocked users list. Idempotent — safe to re-run.
-- PowerSync syncs rows where blocker_id = the signed-in user (see
-- sync_rules.txt bucket `user_blocked_users`).
create table if not exists public.blocked_users (
  id uuid not null default gen_random_uuid(),
  blocker_id uuid not null,
  blocked_id uuid not null,
  created_at timestamptz not null default now(),
  constraint blocked_users_pkey primary key (id),
  constraint blocked_users_unique unique (blocker_id, blocked_id),
  constraint blocked_users_blocker_fkey foreign key (blocker_id)
    references public.profiles (id) on update cascade on delete cascade,
  constraint blocked_users_blocked_fkey foreign key (blocked_id)
    references public.profiles (id) on update cascade on delete cascade
);

alter table public.blocked_users enable row level security;

drop policy if exists "Blocks are visible to their owner." on public.blocked_users;
create policy "Blocks are visible to their owner." on public.blocked_users
  for select using (auth.uid() = blocker_id);

drop policy if exists "Users can create their own blocks." on public.blocked_users;
create policy "Users can create their own blocks." on public.blocked_users
  for insert with check (auth.uid() = blocker_id);

drop policy if exists "Users can remove their own blocks." on public.blocked_users;
create policy "Users can remove their own blocks." on public.blocked_users
  for delete using (auth.uid() = blocker_id);

grant select on public.blocked_users to anon, authenticated;
grant insert, delete on public.blocked_users to authenticated;

-- PowerSync replicates with its own role; BYPASSRLS does not grant privileges.
grant select on public.blocked_users to powersync_role;

-- PostgREST caches the schema. Without this reload the app's writes fail with
-- PGRST205 "Could not find the table" — and because PowerSync uploads in order,
-- that one failure blocks the WHOLE upload queue behind it, so nothing else
-- reaches the server either.
notify pgrst, 'reload schema';
