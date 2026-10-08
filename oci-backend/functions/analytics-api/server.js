'use strict';

// Treepnet admin analytics API — read-only.
//
// Connects to Postgres as the locked-down `analytics_ro` role (SELECT only, on
// the PII-safe `analytics.*` views — see oci-backend/sql/analytics.sql +
// analytics_v2.sql) and serves the JSON the custom admin panel renders
// (github.com/Hikmatbek-dev/Treepnet-admin-panel).
//
// Exposes aggregate numbers only — no emails, phones, password hashes, push
// tokens, message/comment text, or media URLs ever leave the DB (the views
// don't select them, and the role can't read the base tables).
//
// Behind Caddy at admin.treepnet.com/api/* (prefix stripped -> this sees
// /dashboard, /health). Caddy's basic_auth gates every request.

const http = require('http');
const { Pool } = require('pg');

const PORT = parseInt(process.env.PORT || '4300', 10);
const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  max: 4,
  idleTimeoutMillis: 30000,
  statement_timeout: 15000,
});

// Tiny in-process cache: the dashboard is heavy-ish and viewed by a handful of
// admins, so recompute at most once per CACHE_MS instead of on every request.
const CACHE_MS = 30000;
const cache = new Map(); // range -> { at, payload }

const q = async (sql, params) => (await pool.query(sql, params)).rows;
const n = (v) => (v == null ? 0 : Number(v));
const pct = (a, b) => (b > 0 ? Math.round((a / b) * 1000) / 10 : 0);
const round2 = (x) => Math.round(x * 100) / 100;

const RANGE_DAYS = { today: 1, '7d': 7, '30d': 30, '90d': 90, all: null };

// Invite count -> referral tier (profiles.referral_tier is the travel colour,
// not invites, so tiers are derived from the real invite graph here).
function tierOf(invited) {
  if (invited >= 50) return 'Platinum';
  if (invited >= 21) return 'Gold';
  if (invited >= 6) return 'Silver';
  return 'Bronze';
}

function userStatus(lastSeenAt) {
  if (!lastSeenAt) return 'dormant';
  const days = (Date.now() - new Date(lastSeenAt).getTime()) / 86400000;
  if (days <= 7) return 'active';
  if (days <= 30) return 'inactive';
  return 'dormant';
}

async function buildKpiOverview(days) {
  const [kpi] = await q('select * from analytics.kpis');
  const [act] = await q('select * from analytics.active_users');
  const [today] = await q(
    `select (select count(*) from analytics.signups
               where created_at >= date_trunc('day', now())) as new_today`
  );
  // Period-over-period change for the selected window (default 7d; 30d for all).
  const w = days || 30;
  const [chg] = await q(
    `with cur as (
       select
         (select count(*) from analytics.signups where created_at >= now() - ($1||' days')::interval) u,
         (select count(*) from analytics.posts   where created_at >= now() - ($1||' days')::interval) p,
         (select count(*) from analytics.stories where created_at >= now() - ($1||' days')::interval) s,
         (select count(*) from analytics.referrals where created_at >= now() - ($1||' days')::interval) r,
         (select count(*) from analytics.likes   where created_at >= now() - ($1||' days')::interval)
         + (select count(*) from analytics.comments where created_at >= now() - ($1||' days')::interval) e
     ), prev as (
       select
         (select count(*) from analytics.signups where created_at >= now() - ($2||' days')::interval and created_at < now() - ($1||' days')::interval) u,
         (select count(*) from analytics.posts   where created_at >= now() - ($2||' days')::interval and created_at < now() - ($1||' days')::interval) p,
         (select count(*) from analytics.stories where created_at >= now() - ($2||' days')::interval and created_at < now() - ($1||' days')::interval) s,
         (select count(*) from analytics.referrals where created_at >= now() - ($2||' days')::interval and created_at < now() - ($1||' days')::interval) r,
         (select count(*) from analytics.likes   where created_at >= now() - ($2||' days')::interval and created_at < now() - ($1||' days')::interval)
         + (select count(*) from analytics.comments where created_at >= now() - ($2||' days')::interval and created_at < now() - ($1||' days')::interval) e
     )
     select cur.u cu, prev.u pu, cur.p cp, prev.p pp, cur.s cs, prev.s ps,
            cur.r cr, prev.r pr, cur.e ce, prev.e pe from cur, prev`,
    [String(w), String(w * 2)]
  );
  const growth = (c, p) => (p > 0 ? round2(((c - p) / p) * 100) : c > 0 ? 100 : 0);
  // DAU change: today vs yesterday from the daily snapshot, if present.
  const da = await q(
    `select dau from analytics.daily_active order by day desc limit 2`
  );
  const dauChange =
    da.length === 2 ? growth(n(da[0].dau), n(da[1].dau)) : 0;

  return {
    totalUsers: n(kpi.total_users),
    dau: n(act.dau),
    wau: n(act.wau),
    mau: n(act.mau),
    stickiness: pct(n(act.dau), n(act.mau)),
    newUsersToday: n(today.new_today),
    totalPosts: n(kpi.total_posts),
    totalStories: n(kpi.total_stories),
    totalComments: n(kpi.total_comments),
    totalLikes: n(kpi.total_likes),
    totalReferrals: n(kpi.total_referrals),
    totalFollows: n(kpi.total_follows),
    // Chat moved to its own backend/DB; these legacy tables are not tracked here.
    totalConversations: 0,
    totalMessages: 0,
    changes: {
      users: growth(n(chg.cu), n(chg.pu)),
      dau: dauChange,
      posts: growth(n(chg.cp), n(chg.pp)),
      stories: growth(n(chg.cs), n(chg.ps)),
      engagement: growth(n(chg.ce), n(chg.pe)),
      referrals: growth(n(chg.cr), n(chg.pr)),
    },
  };
}

async function buildActivityTrends(days) {
  const limit = days || 90;
  const rows = await q(
    `select to_char(day, 'MM-DD') as date, dau, wau, mau, signups
       from analytics.daily_active
      where day >= current_date - ($1||' days')::interval
      order by day`,
    [String(limit)]
  );
  return rows.map((r) => ({
    date: r.date,
    dau: n(r.dau),
    wau: n(r.wau),
    mau: n(r.mau),
    signups: n(r.signups),
  }));
}

async function buildHourlyActivity() {
  const rows = await q(
    `select extract(hour from ts)::int as h, count(distinct uid) as active
       from (
         select user_id uid, created_at ts from analytics.posts    where created_at >= now() - interval '30 days'
         union all select user_id, created_at from analytics.comments where created_at >= now() - interval '30 days'
         union all select user_id, created_at from analytics.likes    where created_at >= now() - interval '30 days'
       ) e
      group by 1`
  );
  const byHour = new Map(rows.map((r) => [n(r.h), n(r.active)]));
  const out = [];
  for (let h = 0; h < 24; h += 2) {
    const label = String(h).padStart(2, '0') + ':00';
    out.push({ hour: label, active: byHour.get(h) || 0 });
  }
  return out;
}

async function buildUserSegments() {
  const [r] = await q(
    `select
       count(*) filter (where last_seen_at >= now() - interval '1 day') d,
       count(*) filter (where last_seen_at >= now() - interval '7 days'  and last_seen_at < now() - interval '1 day') w,
       count(*) filter (where last_seen_at >= now() - interval '30 days' and last_seen_at < now() - interval '7 days') m,
       count(*) filter (where last_seen_at < now() - interval '30 days' or last_seen_at is null) dormant,
       count(*) total
     from analytics.users`
  );
  const total = n(r.total);
  return [
    { key: 'today', count: n(r.d), percentage: pct(n(r.d), total), color: '#10b981' },
    { key: 'weekly', count: n(r.w), percentage: pct(n(r.w), total), color: '#06b6d4' },
    { key: 'monthly', count: n(r.m), percentage: pct(n(r.m), total), color: '#6366f1' },
    { key: 'dormant', count: n(r.dormant), percentage: pct(n(r.dormant), total), color: '#94a3b8' },
  ];
}

async function buildProfileCompleteness() {
  const [r] = await q(
    `select count(*) total,
       count(*) filter (where has_avatar) avatar,
       count(*) filter (where has_bio) bio,
       count(*) filter (where not is_private) pub,
       count(*) filter (where is_private) priv,
       count(*) filter (where has_push_token) push
     from analytics.users`
  );
  const total = n(r.total);
  const row = (key, c) => ({ key, withFeature: n(c), total, pct: pct(n(c), total) });
  return [
    row('avatar', r.avatar),
    row('bio', r.bio),
    row('public', r.pub),
    row('private', r.priv),
    row('push', r.push),
  ];
}

async function buildBirthYearDistribution() {
  const [r] = await q(
    `select
       count(*) filter (where birth_year < 1990) b1,
       count(*) filter (where birth_year between 1990 and 1995) b2,
       count(*) filter (where birth_year between 1996 and 2000) b3,
       count(*) filter (where birth_year between 2001 and 2005) b4,
       count(*) filter (where birth_year >= 2006) b5,
       count(*) filter (where birth_year is not null) total
     from analytics.users`
  );
  const total = n(r.total);
  const row = (key, c) => ({ key, count: n(c), pct: pct(n(c), total) });
  return [
    row('lt1990', r.b1),
    row('1990_1995', r.b2),
    row('1996_2000', r.b3),
    row('2001_2005', r.b4),
    row('gte2006', r.b5),
  ];
}

async function buildContentStats() {
  const [kpi] = await q('select total_posts, total_stories, total_users from analytics.kpis');
  const [p] = await q(
    `select
       (select count(*) from analytics.posts where created_at >= date_trunc('day', now())) today,
       (select count(distinct user_id) from analytics.posts) creators,
       (select count(*) from analytics.posts where has_location) geo`
  );
  const [s] = await q(
    `select
       count(*) filter (where is_active) active,
       count(*) filter (where content_type in ('image', 'photo')) photo,
       count(*) filter (where content_type = 'video') video,
       count(*) total
     from analytics.stories`
  );
  const trend = await q(
    `select to_char(d, 'Dy') as weekday, to_char(d,'YYYY-MM-DD') iso,
       (select count(*) from analytics.posts   p where p.created_at::date = d) posts,
       (select count(*) from analytics.stories st where st.created_at::date = d) stories
     from generate_series(current_date - interval '6 days', current_date, interval '1 day') d
     order by d`
  );
  const totalPosts = n(kpi.total_posts);
  const totalUsers = n(kpi.total_users);
  const creators = n(p.creators);
  const storiesTotal = n(s.total);
  return {
    postsTotal: totalPosts,
    postsToday: n(p.today),
    creatorsCount: creators,
    creatorsPct: pct(creators, totalUsers),
    avgPostsPerCreator: creators > 0 ? round2(totalPosts / creators) : 0,
    geoTaggedPct: pct(n(p.geo), totalPosts),
    storiesTotal,
    storiesActive: n(s.active),
    storiesPhotoPct: pct(n(s.photo), storiesTotal),
    storiesVideoPct: pct(n(s.video), storiesTotal),
    // No story-highlights flag is tracked in the analytics layer.
    highlightsCount: 0,
    dailyPostTrends: trend.map((t) => ({
      day: t.weekday.trim(),
      iso: t.iso,
      posts: n(t.posts),
      stories: n(t.stories),
    })),
  };
}

async function buildEngagementStats() {
  const [kpi] = await q('select total_likes, total_comments, total_follows, total_posts, total_users from analytics.kpis');
  const [e] = await q(
    `select
       (select count(*) from analytics.likes    where created_at >= date_trunc('day', now())) today_likes,
       (select count(*) from analytics.comments where created_at >= date_trunc('day', now())) today_comments,
       (select count(*) from analytics.comments where is_reply) replies,
       (select count(*) from analytics.follows  where created_at >= date_trunc('day', now())) follows_today,
       (select count(distinct subscribed_to_id) from analytics.follows) users_with_followers,
       (select count(distinct user_id) from (
            select user_id from analytics.likes    where created_at >= now() - interval '7 days'
            union select user_id from analytics.comments where created_at >= now() - interval '7 days'
        ) x) engagers_7d`
  );
  const totalLikes = n(kpi.total_likes);
  const totalComments = n(kpi.total_comments);
  const totalPosts = n(kpi.total_posts);
  const totalUsers = n(kpi.total_users);
  return {
    totalLikes,
    todayLikes: n(e.today_likes),
    totalComments,
    todayComments: n(e.today_comments),
    replyCommentPct: pct(n(e.replies), totalComments),
    // Bookmarks/saved posts aren't exposed in the analytics layer.
    bookmarksCount: 0,
    avgLikesPerPost: totalPosts > 0 ? round2(totalLikes / totalPosts) : 0,
    // Share of users who liked or commented in the last 7 days.
    engagementRatePct: pct(n(e.engagers_7d), totalUsers),
    followsTotal: n(kpi.total_follows),
    followsToday: n(e.follows_today),
    zeroFollowerUsersPct: pct(totalUsers - n(e.users_with_followers), totalUsers),
  };
}

async function buildReferralStats() {
  const [kpi] = await q('select total_referrals, total_users from analytics.kpis');
  const [t] = await q(
    `select
       (select count(*) from analytics.referrals where created_at >= date_trunc('day', now())) today,
       (select count(distinct invited_id) from analytics.referrals) invited_users`
  );
  const [tiers] = await q(
    `select
       count(*) filter (where invited_count between 1 and 5)   bronze,
       count(*) filter (where invited_count between 6 and 20)  silver,
       count(*) filter (where invited_count between 21 and 50) gold,
       count(*) filter (where invited_count > 50)              platinum,
       count(*) total
     from analytics.referral_counts`
  );
  const lb = await q(
    `select rc.user_id, rc.username, rc.invited_count,
       (select count(*) from analytics.referrals r
          join analytics.users u on u.id = r.invited_id
         where r.referrer_id = rc.user_id
           and u.last_seen_at >= now() - interval '30 days') active
     from analytics.referral_counts rc
     order by rc.invited_count desc
     limit 10`
  );
  const totalReferrers = n(tiers.total);
  const totalUsers = n(kpi.total_users);
  return {
    totalReferrals: n(kpi.total_referrals),
    referralsToday: n(t.today),
    referralUserSharePct: pct(n(t.invited_users), totalUsers),
    tiers: [
      { key: 'Bronze', count: n(tiers.bronze), pct: pct(n(tiers.bronze), totalReferrers), color: '#b45309' },
      { key: 'Silver', count: n(tiers.silver), pct: pct(n(tiers.silver), totalReferrers), color: '#94a3b8' },
      { key: 'Gold', count: n(tiers.gold), pct: pct(n(tiers.gold), totalReferrers), color: '#eab308' },
      { key: 'Platinum', count: n(tiers.platinum), pct: pct(n(tiers.platinum), totalReferrers), color: '#06b6d4' },
    ],
    leaderboard: lb.map((r) => {
      const invited = n(r.invited_count);
      const active = n(r.active);
      return {
        userId: r.user_id,
        username: r.username,
        tier: tierOf(invited),
        invitedCount: invited,
        activeReferralsCount: active,
        conversionRate: pct(active, invited),
        rewardEarned: '—',
      };
    }),
  };
}

async function buildGeography() {
  const [tot] = await q('select count(*) c from analytics.posts where has_location');
  const totalGeo = n(tot.c);
  const rows = await q(
    `select coalesce(location_country, '—') country,
            coalesce(location_region, '') region,
            count(distinct user_id) visitors,
            count(*) posts
     from analytics.posts
     where has_location
     group by 1, 2
     order by posts desc
     limit 12`
  );
  const geographyStats = rows.map((r) => ({
    country: r.region ? `${r.country} (${r.region})` : r.country,
    code: '',
    visitorsCount: n(r.visitors),
    postsCount: n(r.posts),
    percentage: pct(n(r.posts), totalGeo),
  }));
  const travelers = await q(
    `select u.username,
            count(distinct v.region_iso) regions,
            (select count(*) from analytics.posts p where p.user_id = v.user_id) posts
     from analytics.visited_regions v
     join analytics.users u on u.id = v.user_id
     group by v.user_id, u.username
     order by regions desc
     limit 5`
  );
  const topTravelers = travelers.map((r) => ({
    username: r.username,
    visitedRegionsCount: n(r.regions),
    totalPosts: n(r.posts),
    points: n(r.regions) * 100 + n(r.posts),
  }));
  return { geographyStats, topTravelers };
}

async function buildRecentUsers() {
  const rows = await q(
    `select u.id, u.username, u.has_avatar, u.has_bio, u.is_private, u.birth_year,
            u.last_seen_at, u.signup_at,
            coalesce(rc.invited_count, 0) invited,
            (select count(*) from analytics.posts p   where p.user_id = u.id) posts,
            (select count(*) from analytics.follows f where f.subscribed_to_id = u.id) followers
     from analytics.users u
     left join analytics.referral_counts rc on rc.user_id = u.id
     order by u.signup_at desc nulls last
     limit 12`
  );
  return rows.map((r) => ({
    id: r.id,
    username: r.username,
    hasAvatar: !!r.has_avatar,
    hasBio: !!r.has_bio,
    isPrivate: !!r.is_private,
    referralTier: tierOf(n(r.invited)),
    birthYear: n(r.birth_year),
    lastSeenAt: r.last_seen_at ? new Date(r.last_seen_at).toISOString() : null,
    signupAt: r.signup_at ? new Date(r.signup_at).toISOString() : null,
    status: userStatus(r.last_seen_at),
    postsCount: n(r.posts),
    followersCount: n(r.followers),
  }));
}

async function buildTopPosts() {
  const rows = await q(
    `select p.id, p.user_id, u.username, p.created_at, p.has_location,
            p.location_country, p.location_region, p.location_name,
            (select count(*) from analytics.likes l    where l.post_id = p.id) likes,
            (select count(*) from analytics.comments c where c.post_id = p.id) comments
     from analytics.posts p
     join analytics.users u on u.id = p.user_id
     order by likes desc, p.created_at desc
     limit 5`
  );
  return rows.map((r) => ({
    id: r.id,
    userId: r.user_id,
    username: r.username,
    createdAt: r.created_at ? new Date(r.created_at).toISOString() : null,
    hasLocation: !!r.has_location,
    country: r.location_country || undefined,
    region: r.location_region || undefined,
    placeName: r.location_name || undefined,
    likesCount: n(r.likes),
    commentsCount: n(r.comments),
    sharesCount: 0,
    contentType: 'image',
  }));
}

async function buildDashboard(range) {
  const days = RANGE_DAYS[range] ?? 7;
  const [
    kpiOverview,
    activityTrends,
    hourlyActivity,
    userSegments,
    profileCompleteness,
    birthYearDistribution,
    contentStats,
    engagementStats,
    referralStats,
    geo,
    recentUsers,
    topPosts,
  ] = await Promise.all([
    buildKpiOverview(days),
    buildActivityTrends(days),
    buildHourlyActivity(),
    buildUserSegments(),
    buildProfileCompleteness(),
    buildBirthYearDistribution(),
    buildContentStats(),
    buildEngagementStats(),
    buildReferralStats(),
    buildGeography(),
    buildRecentUsers(),
    buildTopPosts(),
  ]);
  return {
    generatedAt: new Date().toISOString(),
    range,
    kpiOverview,
    activityTrends,
    hourlyActivity,
    userSegments,
    profileCompleteness,
    birthYearDistribution,
    contentStats,
    engagementStats,
    referralStats,
    geographyStats: geo.geographyStats,
    topTravelers: geo.topTravelers,
    recentUsers,
    topPosts,
  };
}

function sendJson(res, status, body) {
  const s = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(s);
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/health') {
      await q('select 1');
      return sendJson(res, 200, { ok: true });
    }
    if (url.pathname === '/dashboard' && req.method === 'GET') {
      const range = RANGE_DAYS.hasOwnProperty(url.searchParams.get('range'))
        ? url.searchParams.get('range')
        : '7d';
      const hit = cache.get(range);
      if (hit && Date.now() - hit.at < CACHE_MS) {
        return sendJson(res, 200, hit.payload);
      }
      const payload = await buildDashboard(range);
      cache.set(range, { at: Date.now(), payload });
      return sendJson(res, 200, payload);
    }
    sendJson(res, 404, { error: 'not_found' });
  } catch (err) {
    console.error('analytics-api error:', err.message);
    sendJson(res, 500, { error: 'internal_error' });
  }
});

server.listen(PORT, () => console.log(`analytics-api listening on :${PORT}`));
