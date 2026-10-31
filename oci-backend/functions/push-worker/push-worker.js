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
// A failed send is tried again no sooner than this.
const RETRY_GAP = '15 seconds';

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
  },
};
const COMMENT_PREFIX = { en: 'commented: ', ru: 'прокомментировал(а): ' };

function localizedBody(row, lang) {
  const type = row.data && row.data.type;
  const body = row.body || '';
  const texts = BODIES[lang];
  if (!texts) return body;
  if (type === 'comment' && body.startsWith(COMMENT_PREFIX.en)) {
    return COMMENT_PREFIX[lang] + body.slice(COMMENT_PREFIX.en.length);
  }
  return texts[type] || body;
}

// Pushes about one post share a slot on the phone: a newer like (or comment)
// on it replaces the last instead of piling up in the notification shade.
function groupKey(row) {
  const d = row.data || {};
  if (d.post_id && (d.type === 'like' || d.type === 'comment')) {
    return `${d.type}-${d.post_id}`;
  }
  return null;
}

async function sendOne(accessToken, projectId, token, row) {
  const group = groupKey(row);
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: row.title || 'Treepnet',
            body: localizedBody(row, row.lang),
          },
          data: Object.fromEntries(
            Object.entries(row.data || {}).map(([k, v]) => [k, String(v)]),
          ),
          android: {
            priority: 'high',
            notification: { sound: 'default', ...(group && { tag: group }) },
          },
          // iOS: force immediate delivery. Without apns-priority 10 APNs may
          // batch/throttle the push and deliver it up to ~an hour late.
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-push-type': 'alert',
              ...(group && { 'apns-collapse-id': group }),
            },
            payload: {
              aps: { sound: 'default' },
            },
          },
        },
      }),
    },
  );
  if (res.ok) return { ok: true };
  let err = {};
  try { err = await res.json(); } catch (_) {}
  const status = err?.error?.details?.[0]?.errorCode || err?.error?.status || '';
  const unregistered =
    res.status === 404 || status === 'UNREGISTERED' || status === 'NOT_FOUND';
  return { ok: false, unregistered, error: JSON.stringify(err).slice(0, 400) };
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
    const claimed = await client.query(
      `UPDATE public.push_outbox o
          SET status = 'sending', attempts = attempts + 1, claimed_at = now()
        WHERE o.id IN (
          SELECT id FROM public.push_outbox
           WHERE status = 'pending'
             AND (claimed_at IS NULL OR claimed_at < now() - interval '${RETRY_GAP}')
           ORDER BY created_at
           LIMIT $1
           FOR UPDATE SKIP LOCKED
        )
      RETURNING o.id, o.recipient_id, o.title, o.body, o.data, o.attempts`,
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
    const tok = await pool.query(
      'SELECT push_token, lang FROM public.profiles WHERE id = $1',
      [row.recipient_id],
    );
    const pushToken = tok.rows[0]?.push_token;
    row.lang = tok.rows[0]?.lang;
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
    } else {
      if (result.unregistered) {
        await pool.query(
          'UPDATE public.profiles SET push_token=NULL WHERE id=$1',
          [row.recipient_id],
        );
      }
      const dead = result.unregistered || row.attempts >= MAX_ATTEMPTS;
      await pool.query(
        `UPDATE public.push_outbox SET status=$2, last_error=$3 WHERE id=$1`,
        [row.id, dead ? 'failed' : 'pending', result.error],
      );
    }
  } catch (e) {
    await pool.query(
      `UPDATE public.push_outbox
          SET status = CASE WHEN attempts >= $2 THEN 'failed' ELSE 'pending' END,
              last_error = $3
        WHERE id = $1`,
      [row.id, MAX_ATTEMPTS, String(e).slice(0, 400)],
    );
  }
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

console.log('push worker started');
listen();
drain();
setInterval(drain, INTERVAL_MS);
prune();
setInterval(prune, 6 * 60 * 60 * 1000);
