-- At most 2000 follows (requests waiting for approval included).
--
-- The phone syncs one bucket per person the user follows (the `authors`
-- stream), plus open profiles and posts, and PowerSync stops ALL sync for a
-- connection past max_buckets_per_connection (3000, powersync/service.yaml):
-- at about 2990 follows the app would simply stop updating, saying nothing.
-- Nothing capped follows. The 2001st is refused (check_violation, which the
-- app treats as final: "Couldn't save your change"); following again someone
-- already followed is not counted (migration 013 drops the repeat). The
-- monitor warns when any connection passes 1500 buckets.
--
-- Same function as before, with the limit after the block check.

create or replace function public.subscriptions_enforce()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if exists (
      select 1 from public.blocked_users b
       where (b.blocker_id = new.subscriber_id and b.blocked_id = new.subscribed_to_id)
          or (b.blocker_id = new.subscribed_to_id and b.blocked_id = new.subscriber_id)
    ) then
      raise exception 'cannot follow: blocked' using errcode = '42501';
    end if;
    if not exists (
         select 1 from public.subscriptions s
          where s.subscriber_id = new.subscriber_id
            and s.subscribed_to_id = new.subscribed_to_id)
       and (select count(*) from public.subscriptions s
             where s.subscriber_id = new.subscriber_id) >= 2000 then
      raise exception 'follow limit reached (2000)' using errcode = '23514';
    end if;
    new.status := case
      when coalesce((select p.is_private from public.profiles p
                      where p.id = new.subscribed_to_id), false)
        then 'pending'
      else 'accepted'
    end;
  else
    if new.subscriber_id is distinct from old.subscriber_id
       or new.subscribed_to_id is distinct from old.subscribed_to_id then
      raise exception 'cannot change who follows whom' using errcode = '42501';
    end if;
    if new.status is null or new.status not in ('pending', 'accepted') then
      raise exception 'invalid follow status' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
