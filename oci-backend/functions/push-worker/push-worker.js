// Standalone push worker for the OCI stack — the Azure Function `sendPush`
// adapted to run as a plain Node service (setInterval loop instead of the
// Azure timer trigger). Polls push_outbox every 15s and sends FCM v1.
const fs = require('fs');
const { Pool } = require('pg');
const { GoogleAuth } = require('google-auth-library');

const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  ssl: false, // internal docker network, no TLS
  max: 3,
});

const BATCH = 20;
const MAX_ATTEMPTS = 5;
const INTERVAL_MS = 15000;

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

async function sendOne(accessToken, projectId, token, row) {
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
          notification: { title: row.title || 'Treepnet', body: row.body || '' },
          data: Object.fromEntries(
            Object.entries(row.data || {}).map(([k, v]) => [k, String(v)]),
          ),
          android: { priority: 'high', notification: { sound: 'default' } },
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
    return;
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

  if (!rows || rows.length === 0) return;
  const accessToken = await fcmAccessToken();

  for (const row of rows) {
    try {
      const tok = await pool.query(
        'SELECT push_token FROM public.profiles WHERE id = $1',
        [row.recipient_id],
      );
      const pushToken = tok.rows[0]?.push_token;
      if (!pushToken) {
        await pool.query(
          `UPDATE public.push_outbox SET status='failed', last_error='no token' WHERE id=$1`,
          [row.id],
        );
        continue;
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
  console.log(`push: processed ${rows.length} row(s)`);
}

async function loop() {
  try {
    await runOnce();
  } catch (e) {
    console.error('push loop error:', String(e).slice(0, 400));
  }
}

console.log('push worker started; polling every 15s');
loop();
setInterval(loop, INTERVAL_MS);
