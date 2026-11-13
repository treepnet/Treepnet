-- The admin panel's invite page showed Bronze/Silver/Gold/Platinum ranks the
-- app doesn't have. What a user really gets is a premium month per 5 invites
-- (profiles.referral_tier_expires_at, refresh_referral_tier) and a badge
-- colour 1-5 from how densely they map (referral_tier). analytics.users had
-- the colour; the premium end is added here (last column, so the view is only
-- extended). Read by analytics-api as analytics_ro, whose grant stays.

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
    COALESCE(c.created_at, ( SELECT min(x.ts) AS min
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
    (c.created_at IS NULL) AS signup_estimated,
    p.onboarded_at,
    p.referral_tier_expires_at
   FROM ((profiles p
     LEFT JOIN auth_credentials c ON ((c.user_id = p.id)))
     LEFT JOIN profile_presence pp ON ((pp.user_id = p.id)));
