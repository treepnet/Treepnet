-- Sign in with Google and Sign in with Apple.
--
-- The auth-service checks the token Google or Apple gave the phone, then
-- finds the account this table ties that Google/Apple account to (or one
-- with the same address, which Google/Apple say is the person's own, and
-- ties it), and signs in as it: the same custom token as a password sign-in,
-- so profiles.id stays the user id everywhere. A new account is made once a
-- username is picked.
--
-- One row per Google/Apple account: `subject` is its stable id (Apple's
-- address can be a private relay one, so the address can't be the key).
-- Only the auth-service (superuser) reads or writes it.

create table public.auth_identities (
  provider      text not null check (provider in ('google', 'apple')),
  subject       text not null check (length(subject) between 1 and 255),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  -- The address Google/Apple gave last (an Apple relay one maybe).
  email         text,
  created_at    timestamptz not null default now(),
  last_login_at timestamptz not null default now(),
  primary key (provider, subject)
);

create index auth_identities_user_id_idx on public.auth_identities (user_id);

-- New tables are granted to `authenticated` by default: this one is no one's
-- through the API.
alter table public.auth_identities enable row level security;
revoke all on table public.auth_identities from public, anon, authenticated;

-- The admin's sign-up date: an account made with Google/Apple has no
-- password row, so its date was guessed from its first activity. The view as
-- 030 left it, with the earlier of the password row's and the first
-- Google/Apple sign-in's dates (one made with Google can set a password
-- later: that date is not when it signed up).
create or replace view analytics.users as
 SELECT p.id,
    p.username,
    ((p.avatar_url IS NOT NULL) AND (p.avatar_url <> ''::text)) AS has_avatar,
    ((p.bio IS NOT NULL) AND (p.bio <> ''::text)) AS has_bio,
    p.is_private,
    p.referral_tier,
    (EXTRACT(year FROM p.birthday))::integer AS birth_year,
    ((p.push_token IS NOT NULL) AND (p.push_token <> ''::text)) AS has_push_token,
    COALESCE(pp.last_seen_at, p.last_seen_at) AS last_seen_at,
    COALESCE(LEAST(c.created_at,
      ( SELECT min(i.created_at) FROM auth_identities i WHERE i.user_id = p.id )),
      ( SELECT min(x.ts) AS min
           FROM ( SELECT min(posts.created_at) AS ts
                   FROM posts
                  WHERE (posts.user_id = p.id)
                UNION ALL
                 SELECT min(stories.created_at) AS min
                   FROM stories
                  WHERE (stories.user_id = p.id)
                UNION ALL
                 SELECT min(likes.created_at) AS min
                   FROM likes
                  WHERE (likes.user_id = p.id)
                UNION ALL
                 SELECT min(comments.created_at) AS min
                   FROM comments
                  WHERE (comments.user_id = p.id)
                UNION ALL
                 SELECT min(subscriptions.created_at) AS min
                   FROM subscriptions
                  WHERE (subscriptions.subscriber_id = p.id)
                UNION ALL
                 SELECT min(visited_regions.created_at) AS min
                   FROM visited_regions
                  WHERE (visited_regions.user_id = p.id)) x)) AS signup_at,
    (c.created_at IS NULL
      AND NOT EXISTS (SELECT 1 FROM auth_identities i WHERE i.user_id = p.id))
      AS signup_estimated,
    p.onboarded_at,
    p.referral_tier_expires_at
   FROM ((profiles p
     LEFT JOIN auth_credentials c ON ((c.user_id = p.id)))
     LEFT JOIN profile_presence pp ON ((pp.user_id = p.id)));
