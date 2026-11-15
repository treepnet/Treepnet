-- A private account made public accepts the follow requests waiting for it.
--
-- Switching to public left them pending: the people who asked stayed on
-- "Requested" for good, though anyone may now follow the account outright.
-- Each row going pending -> accepted runs the triggers that are already
-- there: sync_scoping_on_subscription adds the follower to both counts and
-- turns the owner's "requested to follow" notification into "followed you",
-- and push_on_follow_accepted tells the requester (P3 #182).

create or replace function public.accept_pending_on_public()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  update public.subscriptions
     set status = 'accepted'
   where subscribed_to_id = new.id
     and status = 'pending';
  return null;
end;
$function$;

revoke all on function public.accept_pending_on_public() from public, anon, authenticated;

create trigger accept_pending_on_public
  after update of is_private on public.profiles
  for each row
  when (old.is_private is true and new.is_private is not true)
  execute function public.accept_pending_on_public();
