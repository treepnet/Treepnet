-- Fewer, fairer pushes: no repeats, nothing across a block.
--
-- Before: every like, follow and comment queued a push unconditionally. A
-- like taken back and given again, or an unfollow and re-follow, pushed each
-- time; and pushes still went between people where one had blocked the other.
--
-- After (enqueue_push):
--   * nothing when either side blocked the other;
--   * a like (per post), follow or follow request from the same person is
--     pushed once in 6 hours — comments are each new text, so they still go.
-- (On the phone, pushes about one post are also merged into one — see
-- functions/push-worker, android tag / apns-collapse-id.)
--
-- Undo: push_dedup_blocks_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < push_dedup_blocks.sql

begin;

create index if not exists push_outbox_dedup_idx
  on public.push_outbox (recipient_id, actor_id, type, created_at);

create or replace function public.enqueue_push(
  p_recipient uuid,
  p_actor uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient is null or p_recipient = p_actor then
    return;
  end if;
  if p_actor is not null and exists (
    select 1 from blocked_users b
     where (b.blocker_id = p_recipient and b.blocked_id = p_actor)
        or (b.blocker_id = p_actor and b.blocked_id = p_recipient)
  ) then
    return;
  end if;
  if p_type in ('like', 'follow', 'follow_request') and exists (
    select 1 from push_outbox o
     where o.recipient_id = p_recipient
       and o.actor_id = p_actor
       and o.type = p_type
       and o.created_at > now() - interval '6 hours'
       and (o.data ->> 'post_id') is not distinct from (p_data ->> 'post_id')
  ) then
    return;
  end if;
  insert into push_outbox (recipient_id, actor_id, type, title, body, data)
  values (p_recipient, p_actor, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
end;
$$;

commit;
