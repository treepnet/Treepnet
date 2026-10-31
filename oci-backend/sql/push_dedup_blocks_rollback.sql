-- Undoes push_dedup_blocks.sql: every like/follow/comment pushes again,
-- blocks or not.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < push_dedup_blocks_rollback.sql

begin;

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
  insert into public.push_outbox (recipient_id, actor_id, type, title, body, data)
  values (p_recipient, p_actor, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
end;
$$;

drop index if exists public.push_outbox_dedup_idx;

commit;
