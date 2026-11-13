// Standalone push worker for the OCI stack — the Azure Function `sendPush`
// adapted to run as a plain Node service. Sends push_outbox rows over FCM v1
// as soon as they're added (LISTEN push_outbox, see
// oci-backend/sql/push_outbox_notify.sql), ten at a time until the queue is
// empty; a 15s poll catches anything a notification missed, and retries.
const fs = require('fs');
const { Client, Pool } = require('pg');
const { GoogleAuth } = require('google-auth-library');

const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  ssl: false, // internal docker network, no TLS
  max: 3,
});

const BATCH = 50;
// Sends in flight at once (each is one FCM request).
const CONCURRENCY = 10;
const MAX_ATTEMPTS = 5;
const INTERVAL_MS = 15000;
// After the 1st, 2nd, 3rd and 4th failed send, the next try waits this many
// seconds (or longer, if FCM's Retry-After says so): ~36 minutes in all. It
// was a flat 15 s, so a short FCM outage (429 / 503) dropped those pushes for
// good within about a minute.
const BACKOFF_S = [15, 60, 300, 1800];

// How long FCM / APNs keep trying to deliver a push to a phone that's away.
const SOCIAL_TTL_S = 2 * 24 * 3600;

function backoffSeconds(attempts, retryAfter) {
  const step = BACKOFF_S[Math.min(Math.max(attempts, 1), BACKOFF_S.length) - 1];
  return Math.max(step, retryAfter || 0);
}

// Retry-After as seconds (a number, or an HTTP date); 0 when absent or odd.
function retryAfterSeconds(header) {
  if (!header) return 0;
  const n = Number(header);
  if (Number.isFinite(n)) return Math.max(0, Math.min(n, 3600));
  const at = Date.parse(header);
  return Number.isFinite(at) ? Math.max(0, Math.min((at - Date.now()) / 1000, 3600)) : 0;
}

// What a failed FCM answer means. A dead token (the app was removed, or the
// token belongs to another Firebase project) is cleared and not tried again;
// a malformed message won't go through either; anything else — FCM busy or
// down, or the Apple / Firebase credentials (THIRD_PARTY_AUTH_ERROR, which the
// monitor reports) — is tried again later. Token-level errors were retried and
// the token kept.
function classify(httpStatus, code, message) {
  const deadToken =
    httpStatus === 404 ||
    code === 'UNREGISTERED' ||
    code === 'NOT_FOUND' ||
    code === 'SENDER_ID_MISMATCH' ||
    (code === 'INVALID_ARGUMENT' && /registration token/i.test(message || ''));
  if (deadToken) return { deadToken: true, retry: false };
  if (code === 'INVALID_ARGUMENT') return { deadToken: false, retry: false };
  return { deadToken: false, retry: true };
}

// An idle client's connection dropping (Postgres restarting) must not take
// the worker down; the pool reconnects on its next query.
pool.on('error', (e) => console.error('push pool error:', e.message));

let authClient;
function getAuth() {
  if (!authClient) {
    const credentials = JSON.parse(
      fs.readFileSync(process.env.FCM_SERVICE_ACCOUNT_FILE, 'utf8'),
    );
    authClient = new GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
  }
  return authClient;
}

async function fcmAccessToken() {
  const client = await getAuth().getClient();
  const { token } = await client.getAccessToken();
  return token;
}

// The triggers write the body in English; it is reworded here in the
// recipient's app language (profiles.lang, set by the app: 'en' / 'ru').
const BODIES = {
  ru: {
    like: 'нравится ваша публикация',
    follow: 'подписался(-ась) на вас',
    follow_request: 'хочет подписаться на вас',
    comment_like: 'нравится ваш комментарий',
    follow_accepted: 'принял(а) ваш запрос на подписку',
  },
};
// Kinds whose body is a lead-in and the comment's text.
const PREFIXES = {
  comment: { en: 'commented: ', ru: 'прокомментировал(а): ' },
  reply: { en: 'replied: ', ru: 'ответил(а): ' },
};

function localizedBody(row, lang) {
  const type = row.data && row.data.type;
  const body = row.body || '';
  const texts = BODIES[lang];
  if (!texts) return body;
  const prefix = PREFIXES[type];
  if (prefix && prefix[lang] && body.startsWith(prefix.en)) {
    return prefix[lang] + body.slice(prefix.en.length);
  }
  return texts[type] || body;
}

// Pushes about one post share a slot on the phone: a newer like (or comment)
// on it replaces the last instead of piling up in the notification shade.
function groupKey(row) {
  const d = row.data || {};
  if (d.post_id && (d.type === 'like' || d.type === 'comment' || d.type === 'reply')) {
    return `${d.type}-${d.post_id}`;
  }
  // Likes on one comment share a slot.
  if (d.comment_id && d.type === 'comment_like') return `comment_like-${d.comment_id}`;
  return null;
}

// The FCM v1 message for one outbox [row] to the device [token].
function buildMessage(token, row) {
  const group = groupKey(row);
  return {
    token,
    notification: {
      title: row.title || 'Treepnet',
      body: localizedBody(row, row.lang),
    },
    data: Object.fromEntries(
      Object.entries(row.data || {}).map(([k, v]) => [k, String(v)]),
    ),
    // A like, comment or follow is news for 2 days: a phone offline
    // longer doesn't get a week's old pushes when it comes back (FCM
    // keeps them 4 weeks unless told).
    android: {
      priority: 'high',
      ttl: `${SOCIAL_TTL_S}s`,
      notification: { sound: 'default', ...(group && { tag: group }) },
    },
    // iOS: force immediate delivery. Without apns-priority 10 APNs may
    // batch/throttle the push and deliver it up to ~an hour late.
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
        'apns-expiration': String(Math.floor(Date.now() / 1000) + SOCIAL_TTL_S),
        ...(group && { 'apns-collapse-id': group }),
      },
      payload: {
        aps: { sound: 'default' },
      },
    },
  };
}

async function sendOne(accessToken, projectId, token, row) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message: buildMessage(token, row) }),
    },
  );
  if (res.ok) return { ok: true };
  let err = {};
  try { err = await res.json(); } catch (_) {}
  const details = Array.isArray(err?.error?.details) ? err.error.details : [];
  const code =
    details.map((d) => d && d.errorCode).find(Boolean) ||
    err?.error?.status ||
    String(res.status);
  const message = err?.error?.message || '';
  return {
    ok: false,
    ...classify(res.status, code, message),
    retryAfter: retryAfterSeconds(res.headers.get('retry-after')),
    // "CODE: message", so the monitor can tell the kinds apart.
    error: `${code}: ${message}`.slice(0, 400),
  };
}

async function runOnce() {
  const projectId = process.env.FCM_PROJECT_ID;
  if (!process.env.PG_CONNECTION_STRING || !process.env.FCM_SERVICE_ACCOUNT_FILE) {
    console.log('push: missing PG_CONNECTION_STRING or FCM_SERVICE_ACCOUNT_FILE');
    return 0;
  }

  const client = await pool.connect();
  let rows;
  try {
    await client.query(
      `UPDATE public.push_outbox
          SET status='pending'
        WHERE status='sending' AND claimed_at < now() - interval '2 minutes'`,
    );
    // Each recipient's token and language come with the claim: they were
    // asked for once per push.
    const claimed = await client.query(
      `WITH claimed AS (
         UPDATE public.push_outbox o
            SET status = 'sending', attempts = attempts + 1, claimed_at = now()
          WHERE o.id IN (
            SELECT id FROM public.push_outbox
             WHERE status = 'pending'
               AND (next_attempt_at IS NULL OR next_attempt_at <= now())
             ORDER BY created_at
             LIMIT $1
             FOR UPDATE SKIP LOCKED
          )
        RETURNING o.id, o.recipient_id, o.title, o.body, o.data, o.attempts
       )
       SELECT c.*, p.push_token, p.lang
         FROM claimed c
         LEFT JOIN public.profiles p ON p.id = c.recipient_id`,
      [BATCH],
    );
    rows = claimed.rows;
  } finally {
    client.release();
  }

  if (!rows || rows.length === 0) return 0;
  const accessToken = await fcmAccessToken();

  // CONCURRENCY sends at a time; they used to go strictly one by one.
  let next = 0;
  const sender = async () => {
    while (next < rows.length) await sendRow(rows[next++], accessToken, projectId);
  };
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, rows.length) }, sender));
  console.log(`push: processed ${rows.length} row(s)`);
  return rows.length;
}

async function sendRow(row, accessToken, projectId) {
  try {
    // Claimed rows carry the token and language (runOnce); others look them up.
    if (!('push_token' in row)) {
      const tok = await pool.query(
        'SELECT push_token, lang FROM public.profiles WHERE id = $1',
        [row.recipient_id],
      );
      row.push_token = tok.rows[0]?.push_token ?? null;
      row.lang = tok.rows[0]?.lang;
    }
    const pushToken = row.push_token;
    if (!pushToken) {
      await pool.query(
        `UPDATE public.push_outbox SET status='failed', last_error='no token' WHERE id=$1`,
        [row.id],
      );
      return;
    }
    const result = await sendOne(accessToken, projectId, pushToken, row);
    if (result.ok) {
      await pool.query(
        `UPDATE public.push_outbox SET status='sent', sent_at=now() WHERE id=$1`,
        [row.id],
      );
      return;
    }
    if (result.deadToken) {
      // Only if it is still that token: the app may have registered a new
      // one meanwhile, which must not be wiped.
      await pool.query(
        'UPDATE public.profiles SET push_token=NULL WHERE id=$1 AND push_token=$2',
        [row.recipient_id, pushToken],
      );
    }
    await failed(row, result.error, result.retry, result.retryAfter);
  } catch (e) {
    await failed(row, String(e).slice(0, 400), true, 0);
  }
}

// Marks a send that didn't go through: tried again later (backing off), or
// failed for good once it can't succeed or has had MAX_ATTEMPTS.
async function failed(row, error, retry, retryAfter) {
  const again = retry && row.attempts < MAX_ATTEMPTS;
  await pool.query(
    `UPDATE public.push_outbox
        SET status = $2, last_error = $3,
            next_attempt_at = CASE WHEN $2 = 'pending'
              THEN now() + make_interval(secs => $4) END
      WHERE id = $1`,
    [row.id, again ? 'pending' : 'failed', error, backoffSeconds(row.attempts, retryAfter)],
  );
}

// Touched after every pass that reached the database; the container's
// healthcheck reads its age (docker-compose.yml), so a worker that is stuck
// or can't reach Postgres shows as unhealthy.
const HEARTBEAT = '/tmp/push-worker-alive';

// Sends until the queue is empty. One drain at a time: a wake-up that comes
// while one runs makes it go round once more.
let draining = false;
let wakeAgain = false;

async function drain() {
  if (draining) {
    wakeAgain = true;
    return;
  }
  draining = true;
  try {
    do {
      wakeAgain = false;
      // A full batch: there may be more behind it.
      while ((await runOnce()) === BATCH) {}
      fs.writeFileSync(HEARTBEAT, String(Date.now()));
    } while (wakeAgain);
  } catch (e) {
    console.error('push loop error:', String(e).slice(0, 400));
  } finally {
    draining = false;
  }
}

// A dedicated connection that LISTENs for new rows (the pool's connections
// come and go). Reconnects on its own; every (re)connect drains once, for
// whatever came in while it was away.
let listenRetry = null;
function listenLater() {
  if (listenRetry) return;
  listenRetry = setTimeout(() => {
    listenRetry = null;
    listen();
  }, 5000);
}

async function listen() {
  const client = new Client({ connectionString: process.env.PG_CONNECTION_STRING, ssl: false });
  client.on('notification', () => drain());
  client.on('error', (e) => console.error('push listen error:', e.message));
  client.on('end', listenLater);
  try {
    await client.connect();
    await client.query('LISTEN push_outbox');
    console.log('push: listening for new rows');
    drain();
  } catch (e) {
    console.error('push listen failed:', e.message);
    client.end().catch(() => {});
    listenLater();
  }
}

// Old rows: after 14 days a sent or failed push keeps only what the admin
// panel counts (type, status, times) — the title, the text (a comment, a
// name) and the data go; after a year the row goes. Every 6 hours.
async function prune() {
  try {
    const scrubbed = await pool.query(
      `UPDATE public.push_outbox
          SET title = NULL, body = NULL, data = '{}'::jsonb
        WHERE created_at < now() - interval '14 days'
          AND status IN ('sent', 'failed')
          AND (title IS NOT NULL OR body IS NOT NULL OR data <> '{}'::jsonb)`,
    );
    const deleted = await pool.query(
      `DELETE FROM public.push_outbox WHERE created_at < now() - interval '1 year'`,
    );
    if (scrubbed.rowCount || deleted.rowCount) {
      console.log(`push: pruned (${scrubbed.rowCount} emptied, ${deleted.rowCount} deleted)`);
    }
  } catch (e) {
    console.error('push prune error:', String(e).slice(0, 400));
  }
}

module.exports = {
  classify, backoffSeconds, retryAfterSeconds, sendRow, buildMessage, fcmAccessToken,
  localizedBody, groupKey,
};

if (require.main === module) {
  console.log('push worker started');
  listen();
  drain();
  setInterval(drain, INTERVAL_MS);
  prune();
  setInterval(prune, 6 * 60 * 60 * 1000);
}
