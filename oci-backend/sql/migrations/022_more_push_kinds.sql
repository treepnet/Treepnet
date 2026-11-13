-- Three more pushes: a reply to your comment, your follow request accepted,
-- and a like on your comment.
--
-- Only the post's owner heard about a comment, so whoever was replied to
-- never knew and conversations under posts died; a requester never learned
-- they were let in; a like on a comment told no one.
--
-- Pushes only. The notifications list in the app (the notifications table)
-- gets these kinds later, once every phone runs a build that knows them: the
-- released 1.0.8 shows any kind it doesn't know as "liked your post". A
-- push's text is written here (and put in Russian by the push worker), so
-- 1.0.8 shows it right; a tap on it just opens the app.

-- Repeats within 6 hours are dropped for the new kinds too, per comment for
-- a comment's likes.
create or replace function public.enqueue_push(
  p_recipient uuid, p_actor uuid, p_type text, p_title text, p_body text, p_data jsonb)
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
  if p_type in ('like', 'follow', 'follow_request', 'comment_like', 'follow_accepted') and exists (
    select 1 from push_outbox o
     where o.recipient_id = p_recipient
       and o.actor_id = p_actor
       and o.type = p_type
       and o.created_at > now() - interval '6 hours'
       and (o.data ->> 'post_id') is not distinct from (p_data ->> 'post_id')
       and (o.data ->> 'comment_id') is not distinct from (p_data ->> 'comment_id')
  ) then
    return;
  end if;
  insert into push_outbox (recipient_id, actor_id, type, title, body, data)
  values (p_recipient, p_actor, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
end;
$$;

-- A comment tells the post's owner, as before, and a reply also tells the
-- author of the comment replied to (unless that is the owner, already told,
-- or the replier).
create or replace function public.trg_push_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_parent uuid;
  v_actor text;
begin
  if new.post_id is null then return new; end if;
  select user_id into v_owner from public.posts where id = new.post_id;
  if v_owner is null then return new; end if;
  v_actor := public.push_actor_name(new.user_id);
  perform public.enqueue_push(
    v_owner, new.user_id, 'comment',
    v_actor, 'commented: ' || left(coalesce(new.content, ''), 120),
    jsonb_build_object('type', 'comment', 'actor_id', new.user_id, 'post_id', new.post_id)
  );
  if new.replied_to_comment_id is not null then
    select user_id into v_parent from public.comments where id = new.replied_to_comment_id;
    if v_parent is not null and v_parent <> v_owner then
      perform public.enqueue_push(
        v_parent, new.user_id, 'reply',
        v_actor, 'replied: ' || left(coalesce(new.content, ''), 120),
        jsonb_build_object('type', 'reply', 'actor_id', new.user_id,
                           'post_id', new.post_id, 'comment_id', new.id)
      );
    end if;
  end if;
  return new;
end;
$$;

-- A like on a post tells its owner, as before; a like on a comment tells the
-- comment's author.
create or replace function public.trg_push_on_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_post uuid;
  v_actor text;
begin
  if new.post_id is not null then
    select user_id into v_owner from public.posts where id = new.post_id;
    if v_owner is null then return new; end if;
    v_actor := public.push_actor_name(new.user_id);
    perform public.enqueue_push(
      v_owner, new.user_id, 'like',
      v_actor, 'liked your post',
      jsonb_build_object('type', 'like', 'actor_id', new.user_id, 'post_id', new.post_id)
    );
  elsif new.comment_id is not null then
    select user_id, post_id into v_owner, v_post from public.comments where id = new.comment_id;
    if v_owner is null then return new; end if;
    v_actor := public.push_actor_name(new.user_id);
    perform public.enqueue_push(
      v_owner, new.user_id, 'comment_like',
      v_actor, 'liked your comment',
      jsonb_build_object('type', 'comment_like', 'actor_id', new.user_id,
                         'post_id', v_post, 'comment_id', new.comment_id)
    );
  end if;
  return new;
end;
$$;

-- A follow request accepted tells the one who asked.
create or replace function public.trg_push_on_follow_accepted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.enqueue_push(
    new.subscriber_id, new.subscribed_to_id, 'follow_accepted',
    public.push_actor_name(new.subscribed_to_id), 'accepted your follow request',
    jsonb_build_object('type', 'follow_accepted', 'actor_id', new.subscribed_to_id)
  );
  return new;
end;
$$;

revoke all on function public.trg_push_on_follow_accepted() from public, anon, authenticated;

drop trigger if exists push_on_follow_accepted on public.subscriptions;
create trigger push_on_follow_accepted
  after update of status on public.subscriptions
  for each row
  when (old.status = 'pending' and new.status = 'accepted')
  execute function public.trg_push_on_follow_accepted();
