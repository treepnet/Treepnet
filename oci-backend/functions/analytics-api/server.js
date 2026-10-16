'use strict';

// Treepnet admin analytics API — read-only.
//
// Connects to Postgres as the locked-down `analytics_ro` role (SELECT only on
// the PII-safe `analytics.*` views — oci-backend/sql/analytics*.sql) and serves
// the JSON the admin panel (admin-panel/) renders. No emails, phones, password
// hashes, push tokens, message/comment text or media URLs ever leave the DB.
//
// Behind Caddy at admin.treepnet.com/api/* (prefix stripped), basic_auth gated.
//
//   GET /dashboard?preset=today|yesterday|7d|30d|90d|all
//   GET /dashboard?from=YYYY-MM-DD&to=YYYY-MM-DD      (inclusive, Tashkent days)
//   GET /users      every account with per-user counts (no PII)
//   GET /online     live presence counters
//   GET /health
//
// Every "period" number is computed for the selected window and compared with
// the window of the same length right before it. "Snapshot" numbers describe
// the state right now and do not depend on the window; the panel labels both.

const http = require('http');
const { Pool } = require('pg');

const PORT = parseInt(process.env.PORT || '4300', 10);
const TZ = 'Asia/Tashkent';
const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  max: 6,
  idleTimeoutMillis: 30000,
  statement_timeout: 20000,
});

const q = async (sql, params) => (await pool.query(sql, params)).rows;
const one = async (sql, params) => (await q(sql, params))[0] || {};
const n = (v) => (v == null ? 0 : Number(v));
const pct = (a, b) => (b > 0 ? Math.round((a / b) * 1000) / 10 : 0);
const round1 = (x) => Math.round(x * 10) / 10;
const iso = (d) => (d ? new Date(d).toISOString() : null);

// --- caching ------------------------------------------------------------------
const cache = new Map(); // key -> { at, payload }
async function cached(key, ttlMs, fn) {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < ttlMs) return hit.payload;
  const payload = await fn();
  cache.set(key, { at: Date.now(), payload });
  if (cache.size > 200) cache.delete(cache.keys().next().value);
  return payload;
}

// --- period resolution --------------------------------------------------------
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const PRESETS = ['today', 'yesterday', '7d', '30d', '90d', 'all'];

async function resolvePeriod(params) {
  const { today, first } = await one(
    `select to_char((now() at time zone '${TZ}')::date, 'YYYY-MM-DD') as today,
            to_char(coalesce(
              (select min((signup_at at time zone '${TZ}')::date) from analytics.users),
              (now() at time zone '${TZ}')::date), 'YYYY-MM-DD') as first`
  );
  const addDays = (s, k) => {
    const d = new Date(`${s}T00:00:00Z`);
    d.setUTCDate(d.getUTCDate() + k);
    return d.toISOString().slice(0, 10);
  };
  let from;
  let to;
  let preset = params.get('preset');
  const f = params.get('from');
  const t = params.get('to');
  if (f && t && DATE_RE.test(f) && DATE_RE.test(t)) {
    from = f <= t ? f : t;
    to = f <= t ? t : f;
    if (to > today) to = today;
    if (from > to) from = to;
    preset = 'custom';
  } else {
    if (!PRESETS.includes(preset)) preset = '7d';
    to = today;
    if (preset === 'today') from = today;
    else if (preset === 'yesterday') { from = addDays(today, -1); to = from; }
    else if (preset === '7d') from = addDays(today, -6);
    else if (preset === '30d') from = addDays(today, -29);
    else if (preset === '90d') from = addDays(today, -89);
    else from = first < today ? first : today;
  }
  const days = Math.round((new Date(`${to}T00:00:00Z`) - new Date(`${from}T00:00:00Z`)) / 86400000) + 1;
  const prevTo = addDays(from, -1);
  const prevFrom = addDays(from, -days);
  const unit = days <= 92 ? 'day' : days <= 730 ? 'week' : 'month';
  const b = await one(
    `select ($1::date)::timestamp at time zone '${TZ}' as f,
            ($2::date + 1)::timestamp at time zone '${TZ}' as t,
            ($3::date)::timestamp at time zone '${TZ}' as pf`,
    [from, to, prevFrom]
  );
  return { preset, from, to, days, prevFrom, prevTo, unit, today, fromTs: b.f, toTs: b.t, prevFromTs: b.pf };
}

// Actor events ("did something in the app"). $1/$2 bound the window.
const ACTOR_EVENTS = `
  select 'signup'::text k, id u, signup_at ts from analytics.users where signup_at >= $1 and signup_at < $2
  union all select 'post', user_id, created_at from analytics.posts where created_at >= $1 and created_at < $2
  union all select 'story', user_id, created_at from analytics.stories where created_at >= $1 and created_at < $2
  union all select 'like', user_id, created_at from analytics.likes where created_at >= $1 and created_at < $2
  union all select 'comment', user_id, created_at from analytics.comments where created_at >= $1 and created_at < $2
  union all select 'follow', subscriber_id, created_at from analytics.follows where created_at >= $1 and created_at < $2
  union all select 'save', user_id, created_at from analytics.saves where created_at >= $1 and created_at < $2
  union all select 'open', user_id, minute from analytics.activity where minute >= $1 and minute < $2`;

// --- dashboard sections ----------------------------------------------------------

async function periodTotals(p) {
  // Current window [fromTs, toTs) and the previous one [prevFromTs, fromTs).
  const r = await one(
    `with ev as (${ACTOR_EVENTS}
       union all select 'referral', referrer_id, created_at from analytics.referrals where created_at >= $1 and created_at < $2
       union all select 'storyview', null::uuid, created_at from analytics.story_view_events where created_at >= $1 and created_at < $2
       union all select 'highlight', user_id, created_at from analytics.highlights where created_at >= $1 and created_at < $2)
     select
       ${['signup', 'post', 'story', 'like', 'comment', 'follow', 'save', 'referral', 'storyview', 'highlight']
         .map((k) => `count(*) filter (where k='${k}' and ts >= $3) c_${k}, count(*) filter (where k='${k}' and ts < $3) p_${k}`)
         .join(',\n       ')},
       count(distinct u) filter (where k not in ('referral','storyview','highlight') and ts >= $3) c_active,
       count(distinct u) filter (where k not in ('referral','storyview','highlight') and ts < $3) p_active,
       count(distinct u) filter (where k = 'post' and ts >= $3) c_creators,
       count(distinct u) filter (where k in ('like','comment') and ts >= $3) c_engagers
     from ev`,
    [p.prevFromTs, p.toTs, p.fromTs]
  );
  const keys = ['signup', 'post', 'story', 'like', 'comment', 'follow', 'save', 'referral', 'storyview', 'highlight', 'active'];
  const out = {};
  for (const k of keys) out[k] = { value: n(r[`c_${k}`]), previous: n(r[`p_${k}`]) };
  out.creators = n(r.c_creators);
  out.engagers = n(r.c_engagers);
  return out;
}

async function snapshot() {
  const k = await one('select * from analytics.kpis');
  const a = await one('select * from analytics.active_users');
  const s = await one(
    `select
       (select count(distinct user_id) from analytics.activity where minute >= date_trunc('minute', now()) - interval '2 minutes') online_now,
       (select count(distinct user_id) from analytics.activity where minute >= now() - interval '15 minutes') online_15m,
       (select min(minute) from analytics.activity) tracking_since,
       (select count(*) from analytics.stories where is_active) active_stories,
       (select count(*) from analytics.highlights) highlights,
       (select count(*) from analytics.saves) saves,
       (select count(*) from analytics.follows where status = 'pending') pending_follows`
  );
  return {
    totalUsers: n(k.total_users),
    onlineNow: n(s.online_now),
    online15m: n(s.online_15m),
    trackingSince: iso(s.tracking_since),
    dau: n(a.dau),
    wau: n(a.wau),
    mau: n(a.mau),
    stickiness: pct(n(a.dau), n(a.mau)),
    totals: {
      posts: n(k.total_posts),
      stories: n(k.total_stories),
      activeStories: n(s.active_stories),
      highlights: n(s.highlights),
      likes: n(k.total_likes),
      comments: n(k.total_comments),
      follows: n(k.total_follows),
      pendingFollows: n(s.pending_follows),
      referrals: n(k.total_referrals),
      saves: n(s.saves),
    },
  };
}

async function series(p) {
  const bucket = (col) => p.unit === 'day'
    ? `(${col} at time zone '${TZ}')::date`
    : `date_trunc('${p.unit}', ${col} at time zone '${TZ}')::date`;
  const rows = await q(
    `with ev as (${ACTOR_EVENTS}),
     g as (
       select ${bucket('ts')} b,
         count(*) filter (where k='signup') signups,
         count(*) filter (where k='post') posts,
         count(*) filter (where k='story') stories,
         count(*) filter (where k='like') likes,
         count(*) filter (where k='comment') comments,
         count(*) filter (where k='follow') follows,
         count(distinct u) active,
         count(distinct u) filter (where k='open') opened
       from ev group by 1
     ),
     bk as (
       select generate_series(
         ${p.unit === 'day' ? '$3::date' : `date_trunc('${p.unit}', $3::date)::date`},
         $4::date, interval '1 ${p.unit}')::date b
     )
     select to_char(bk.b, 'YYYY-MM-DD') d,
       coalesce(g.signups,0) signups, coalesce(g.posts,0) posts, coalesce(g.stories,0) stories,
       coalesce(g.likes,0) likes, coalesce(g.comments,0) comments, coalesce(g.follows,0) follows,
       coalesce(g.active,0) active, coalesce(g.opened,0) opened,
       ${p.unit === 'day' ? 'da.dau' : 'null'} snapshot_dau
     from bk left join g on g.b = bk.b
     ${p.unit === 'day' ? 'left join analytics.daily_active da on da.day = bk.b' : ''}
     order by bk.b`,
    [p.fromTs, p.toTs, p.from, p.to]
  );
  return rows.map((r) => ({
    date: r.d,
    signups: n(r.signups),
    posts: n(r.posts),
    stories: n(r.stories),
    likes: n(r.likes),
    comments: n(r.comments),
    follows: n(r.follows),
    // Active = opened the app (presence log) or did anything. Before presence
    // tracking existed only actions are known, so the nightly last_seen
    // snapshot is folded in as a floor for those days.
    active: Math.max(n(r.active), r.snapshot_dau == null || n(r.opened) > 0 ? 0 : n(r.snapshot_dau)),
    estimated: n(r.opened) === 0,
  }));
}

async function sessions(p) {
  const r = await one(
    `with a as (
       select user_id, minute,
         case when minute - lag(minute) over (partition by user_id order by minute) <= interval '5 minutes'
              then 0 else 1 end as brk
       from analytics.activity where minute >= $1 and minute < $2
     ), s as (
       select user_id, minute, sum(brk) over (partition by user_id order by minute) sid from a
     ), d as (
       select user_id, sid, extract(epoch from max(minute) - min(minute)) / 60 + 1 as mins,
              min((minute at time zone '${TZ}')::date) as day
       from s group by 1, 2
     )
     select count(*) sessions,
            avg(mins) avg_min,
            percentile_cont(0.5) within group (order by mins) median_min,
            sum(mins) total_min,
            count(distinct (user_id, day)) user_days,
            count(distinct user_id) users
     from d`,
    [p.fromTs, p.toTs]
  );
  const sessionsCount = n(r.sessions);
  if (!sessionsCount) return null;
  const userDays = n(r.user_days);
  return {
    sessions: sessionsCount,
    users: n(r.users),
    avgMinutes: round1(n(r.avg_min)),
    medianMinutes: round1(n(r.median_min)),
    sessionsPerUserDay: userDays ? round1(sessionsCount / userDays) : 0,
    minutesPerUserDay: userDays ? round1(n(r.total_min) / userDays) : 0,
  };
}

async function hourly(p) {
  const rows = await q(
    `with ev as (${ACTOR_EVENTS})
     select extract(hour from ts at time zone '${TZ}')::int h,
            count(distinct u) users, count(*) events
     from ev group by 1`,
    [p.fromTs, p.toTs]
  );
  const by = new Map(rows.map((r) => [n(r.h), r]));
  return Array.from({ length: 24 }, (_, h) => ({
    hour: h,
    users: n(by.get(h)?.users),
    events: n(by.get(h)?.events),
  }));
}

async function audience() {
  const seg = await one(
    `select
       count(*) filter (where last_seen_at >= now() - interval '1 day') d,
       count(*) filter (where last_seen_at >= now() - interval '7 days' and last_seen_at < now() - interval '1 day') w,
       count(*) filter (where last_seen_at >= now() - interval '30 days' and last_seen_at < now() - interval '7 days') m,
       count(*) filter (where last_seen_at < now() - interval '30 days' or last_seen_at is null) dormant,
       count(*) total,
       count(*) filter (where has_avatar) avatar,
       count(*) filter (where has_bio) bio,
       count(*) filter (where is_private) priv,
       count(*) filter (where has_push_token) push,
       count(*) filter (where onboarded_at is not null) onboarded,
       count(*) filter (where birth_year < 1990) b1,
       count(*) filter (where birth_year between 1990 and 1995) b2,
       count(*) filter (where birth_year between 1996 and 2000) b3,
       count(*) filter (where birth_year between 2001 and 2005) b4,
       count(*) filter (where birth_year >= 2006) b5,
       count(*) filter (where birth_year is null) bnull
     from analytics.users`
  );
  const total = n(seg.total);
  const item = (key, c) => ({ key, count: n(c), pct: pct(n(c), total) });
  return {
    segments: [item('today', seg.d), item('week', seg.w), item('month', seg.m), item('dormant', seg.dormant)],
    completeness: [
      item('avatar', seg.avatar), item('bio', seg.bio), item('onboarded', seg.onboarded),
      item('push', seg.push), item('private', seg.priv),
    ],
    birthYears: [
      item('lt1990', seg.b1), item('1990_1995', seg.b2), item('1996_2000', seg.b3),
      item('2001_2005', seg.b4), item('gte2006', seg.b5), item('unknown', seg.bnull),
    ],
  };
}

async function content(p) {
  const s = await one(
    `select
       count(*) filter (where content_type in ('image','photo')) photo,
       count(*) filter (where content_type = 'video') video
     from analytics.stories where created_at >= $1 and created_at < $2`,
    [p.fromTs, p.toTs]
  );
  const geo = await one(
    `select count(*) filter (where has_location) geo, count(*) total
     from analytics.posts where created_at >= $1 and created_at < $2`,
    [p.fromTs, p.toTs]
  );
  const topPosts = await q(
    `select * from (
       select p.id, u.username, p.created_at, p.location_country, p.location_region, p.location_name,
              (select count(*) from analytics.likes l where l.post_id = p.id) likes,
              (select count(*) from analytics.comments c where c.post_id = p.id) comments,
              (select count(*) from analytics.saves s where s.post_id = p.id) saves
       from analytics.posts p join analytics.users u on u.id = p.user_id
       where p.created_at >= $1 and p.created_at < $2
     ) x
     order by likes + comments desc, created_at desc
     limit 10`,
    [p.fromTs, p.toTs]
  );
  const topCreators = await q(
    `select u.username, count(*) posts,
            (select count(*) from analytics.likes l join analytics.posts pp on pp.id = l.post_id
              where pp.user_id = p.user_id and pp.created_at >= $1 and pp.created_at < $2) likes
     from analytics.posts p join analytics.users u on u.id = p.user_id
     where p.created_at >= $1 and p.created_at < $2
     group by p.user_id, u.username
     order by posts desc, likes desc
     limit 10`,
    [p.fromTs, p.toTs]
  );
  return {
    storiesPhoto: n(s.photo),
    storiesVideo: n(s.video),
    geoTaggedPct: pct(n(geo.geo), n(geo.total)),
    topPosts: topPosts.map((r) => ({
      id: r.id,
      username: r.username,
      createdAt: iso(r.created_at),
      place: [r.location_name, r.location_region, r.location_country].filter(Boolean).join(', ') || null,
      likes: n(r.likes),
      comments: n(r.comments),
      saves: n(r.saves),
    })),
    topCreators: topCreators.map((r) => ({ username: r.username, posts: n(r.posts), likes: n(r.likes) })),
  };
}

async function engagement(p) {
  const e = await one(
    `select
       (select count(*) from analytics.comments where is_reply and created_at >= $1 and created_at < $2) replies,
       (select count(*) from analytics.push where created_at >= $1 and created_at < $2 and status = 'sent') push_sent,
       (select count(*) from analytics.push where created_at >= $1 and created_at < $2 and status = 'failed') push_failed,
       (select count(*) from analytics.push where created_at >= $1 and created_at < $2 and status not in ('sent','failed')) push_pending`,
    [p.fromTs, p.toTs]
  );
  const topLiked = await q(
    `select u.username, count(*) likes
     from analytics.likes l
     join analytics.posts po on po.id = l.post_id
     join analytics.users u on u.id = po.user_id
     where l.created_at >= $1 and l.created_at < $2
     group by u.username order by likes desc limit 10`,
    [p.fromTs, p.toTs]
  );
  const sent = n(e.push_sent);
  const failed = n(e.push_failed);
  return {
    replies: n(e.replies),
    push: { sent, failed, pending: n(e.push_pending), successPct: pct(sent, sent + failed) },
    topLiked: topLiked.map((r) => ({ username: r.username, likes: n(r.likes) })),
  };
}

const tierOf = (invited) => (invited >= 51 ? 'Platinum' : invited >= 21 ? 'Gold' : invited >= 6 ? 'Silver' : 'Bronze');

async function referrals(p) {
  const period = await q(
    `select u.username, count(*) invited,
            count(*) filter (where iu.last_seen_at >= now() - interval '30 days') active
     from analytics.referrals r
     join analytics.users u on u.id = r.referrer_id
     left join analytics.users iu on iu.id = r.invited_id
     where r.created_at >= $1 and r.created_at < $2
     group by u.username order by invited desc limit 10`,
    [p.fromTs, p.toTs]
  );
  const allTime = await q(
    `select rc.username, rc.invited_count invited,
            (select count(*) from analytics.referrals r join analytics.users iu on iu.id = r.invited_id
              where r.referrer_id = rc.user_id and iu.last_seen_at >= now() - interval '30 days') active
     from analytics.referral_counts rc order by rc.invited_count desc limit 10`
  );
  const tiers = await one(
    `select
       count(*) filter (where invited_count between 1 and 5) bronze,
       count(*) filter (where invited_count between 6 and 20) silver,
       count(*) filter (where invited_count between 21 and 50) gold,
       count(*) filter (where invited_count > 50) platinum,
       count(*) inviters
     from analytics.referral_counts`
  );
  const row = (r) => {
    const invited = n(r.invited);
    const active = n(r.active);
    return { username: r.username, invited, active, activePct: pct(active, invited), tier: tierOf(invited) };
  };
  return {
    leaderboardPeriod: period.map(row),
    leaderboardAllTime: allTime.map(row),
    inviters: n(tiers.inviters),
    tiers: { Bronze: n(tiers.bronze), Silver: n(tiers.silver), Gold: n(tiers.gold), Platinum: n(tiers.platinum) },
  };
}

async function geography(p) {
  const countries = await q(
    `select coalesce(location_country, '—') country, count(*) posts, count(distinct user_id) authors
     from analytics.posts
     where has_location and created_at >= $1 and created_at < $2
     group by 1 order by posts desc limit 15`,
    [p.fromTs, p.toTs]
  );
  const regions = await q(
    `select coalesce(location_country, '—') country, coalesce(location_region, '—') region,
            count(*) posts, count(distinct user_id) authors
     from analytics.posts
     where has_location and created_at >= $1 and created_at < $2
     group by 1, 2 order by posts desc limit 15`,
    [p.fromTs, p.toTs]
  );
  const marked = await one(
    `select count(*) marks, count(distinct user_id) users
     from analytics.visited_regions where created_at >= $1 and created_at < $2`,
    [p.fromTs, p.toTs]
  );
  const travelers = await q(
    `select u.username, count(distinct v.region_iso) regions,
            (select count(*) from analytics.posts po where po.user_id = v.user_id) posts
     from analytics.visited_regions v join analytics.users u on u.id = v.user_id
     group by v.user_id, u.username order by regions desc, posts desc limit 10`
  );
  const total = countries.reduce((s, r) => s + n(r.posts), 0);
  return {
    countries: countries.map((r) => ({ country: r.country, posts: n(r.posts), authors: n(r.authors), pct: pct(n(r.posts), total) })),
    regions: regions.map((r) => ({ country: r.country, region: r.region, posts: n(r.posts), authors: n(r.authors) })),
    regionMarks: n(marked.marks),
    regionMarkUsers: n(marked.users),
    topTravelers: travelers.map((r) => ({ username: r.username, regions: n(r.regions), posts: n(r.posts) })),
  };
}

async function recentSignups(p) {
  const rows = await q(
    `select u.username, u.signup_at, u.signup_estimated, u.last_seen_at,
            exists (select 1 from analytics.activity a where a.user_id = u.id
                      and a.minute >= date_trunc('minute', now()) - interval '2 minutes') online
     from analytics.users u
     where u.signup_at >= $1 and u.signup_at < $2
     order by u.signup_at desc limit 50`,
    [p.fromTs, p.toTs]
  );
  return rows.map((r) => ({
    username: r.username,
    signupAt: iso(r.signup_at),
    signupEstimated: !!r.signup_estimated,
    lastSeenAt: iso(r.last_seen_at),
    online: !!r.online,
  }));
}

async function buildDashboard(p) {
  const [totals, snap, ser, sess, hours, aud, cont, eng, ref, geo, recent] = await Promise.all([
    periodTotals(p), snapshot(), series(p), sessions(p), hourly(p), audience(),
    content(p), engagement(p), referrals(p), geography(p), recentSignups(p),
  ]);
  return {
    generatedAt: new Date().toISOString(),
    timezone: TZ,
    period: {
      preset: p.preset, from: p.from, to: p.to, days: p.days,
      previousFrom: p.prevFrom, previousTo: p.prevTo, unit: p.unit, today: p.today,
    },
    snapshot: snap,
    totals,
    series: ser,
    sessions: sess,
    hourly: hours,
    audience: aud,
    content: cont,
    engagement: eng,
    referrals: ref,
    geography: geo,
    recentSignups: recent,
  };
}

async function buildUsers() {
  const rows = await q(
    `select u.id, u.username, u.has_avatar, u.has_bio, u.is_private, u.birth_year, u.has_push_token,
            u.signup_at, u.signup_estimated, u.last_seen_at,
            (select count(*) from analytics.posts p where p.user_id = u.id) posts,
            (select count(*) from analytics.stories s where s.user_id = u.id) stories,
            (select count(*) from analytics.follows f where f.subscribed_to_id = u.id and f.status = 'accepted') followers,
            (select count(*) from analytics.follows f where f.subscriber_id = u.id and f.status = 'accepted') following,
            coalesce(rc.invited_count, 0) invited,
            (select count(distinct region_iso) from analytics.visited_regions v where v.user_id = u.id) regions,
            exists (select 1 from analytics.activity a where a.user_id = u.id
                      and a.minute >= date_trunc('minute', now()) - interval '2 minutes') online
     from analytics.users u
     left join analytics.referral_counts rc on rc.user_id = u.id
     order by u.signup_at desc nulls last`
  );
  const now = Date.now();
  const status = (ls) => {
    if (!ls) return 'dormant';
    const d = (now - new Date(ls).getTime()) / 86400000;
    return d <= 1 ? 'today' : d <= 7 ? 'week' : d <= 30 ? 'month' : 'dormant';
  };
  return {
    generatedAt: new Date().toISOString(),
    users: rows.map((r) => ({
      id: r.id,
      username: r.username,
      hasAvatar: !!r.has_avatar,
      hasBio: !!r.has_bio,
      isPrivate: !!r.is_private,
      hasPush: !!r.has_push_token,
      birthYear: r.birth_year == null ? null : n(r.birth_year),
      signupAt: iso(r.signup_at),
      signupEstimated: !!r.signup_estimated,
      lastSeenAt: iso(r.last_seen_at),
      online: !!r.online,
      status: status(r.last_seen_at),
      posts: n(r.posts),
      stories: n(r.stories),
      followers: n(r.followers),
      following: n(r.following),
      invited: n(r.invited),
      regions: n(r.regions),
    })),
  };
}

async function buildOnline() {
  const r = await one(
    `select
       (select count(distinct user_id) from analytics.activity where minute >= date_trunc('minute', now()) - interval '2 minutes') now,
       (select count(distinct user_id) from analytics.activity where minute >= now() - interval '15 minutes') m15,
       (select count(distinct user_id) from analytics.activity where minute >= now() - interval '60 minutes') m60,
       (select min(minute) from analytics.activity) since`
  );
  return {
    asOf: new Date().toISOString(),
    onlineNow: n(r.now),
    online15m: n(r.m15),
    online60m: n(r.m60),
    trackingSince: iso(r.since),
  };
}

// --- http -----------------------------------------------------------------------
function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (req.method !== 'GET') return sendJson(res, 405, { error: 'method_not_allowed' });
    if (url.pathname === '/health') {
      await q('select 1');
      return sendJson(res, 200, { ok: true });
    }
    if (url.pathname === '/dashboard') {
      const p = await resolvePeriod(url.searchParams);
      const payload = await cached(`d:${p.from}:${p.to}:${p.preset}`, 30000, () => buildDashboard(p));
      return sendJson(res, 200, payload);
    }
    if (url.pathname === '/users') {
      return sendJson(res, 200, await cached('users', 30000, buildUsers));
    }
    if (url.pathname === '/online') {
      return sendJson(res, 200, await cached('online', 10000, buildOnline));
    }
    sendJson(res, 404, { error: 'not_found' });
  } catch (err) {
    console.error('analytics-api error:', err.message);
    sendJson(res, 500, { error: 'internal_error' });
  }
});

server.listen(PORT, () => console.log(`analytics-api listening on :${PORT}`));
