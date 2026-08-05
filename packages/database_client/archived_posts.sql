-- Archived posts list. Idempotent — safe to re-run.
-- Mirrors `saved_posts`: a per-user join table of the posts the signed-in user
-- has archived (hidden from their public profile grid but kept privately).
-- PowerSync syncs rows where user_id = the signed-in user (see sync_rules.txt
-- bucket `user_archived_posts`).
create table if not exists public.archived_posts (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  post_id uuid not null,
  created_at timestamptz not null default now(),
  constraint archived_posts_pkey primary key (id),
  constraint archived_posts_unique unique (user_id, post_id),
  constraint archived_posts_user_fkey foreign key (user_id)
    references public.profiles (id) on update cascade on delete cascade,
  constraint archived_posts_post_fkey foreign key (post_id)
    references public.posts (id) on update cascade on delete cascade
);

alter table public.archived_posts enable row level security;

drop policy if exists "Archived posts are visible to their owner." on public.archived_posts;
create policy "Archived posts are visible to their owner." on public.archived_posts
  for select using (auth.uid() = user_id);

drop policy if exists "Users can archive their own posts." on public.archived_posts;
create policy "Users can archive their own posts." on public.archived_posts
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can unarchive their own posts." on public.archived_posts;
create policy "Users can unarchive their own posts." on public.archived_posts
  for delete using (auth.uid() = user_id);
