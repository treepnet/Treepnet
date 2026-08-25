const { app } = require('@azure/functions');
const { Pool } = require('pg');
const { GoogleAuth } = require('google-auth-library');

// One pool for the whole process (Functions reuses the worker between runs).
const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  ssl: { rejectUnauthorized: false },
  max: 3,
});

const BATCH = 20;
const MAX_ATTEMPTS = 5;

let authClient; // cached GoogleAuth, mints short-lived FCM access tokens
function getAuth() {
  if (!authClient) {
    const credentials = JSON.parse(process.env.FCM_SERVICE_ACCOUNT_JSON);
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

// Sends one message. Returns { ok } or { ok:false, unregistered, error }.
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
          // Data is all-strings for FCM; used for tap routing on the client.
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

app.timer('sendPush', {
  // Every 15 seconds.
  schedule: '*/15 * * * * *',
  handler: async (_timer, context) => {
    const projectId = process.env.FCM_PROJECT_ID;
    if (!process.env.PG_CONNECTION_STRING || !process.env.FCM_SERVICE_ACCOUNT_JSON) {
      context.log('push: missing PG_CONNECTION_STRING or FCM_SERVICE_ACCOUNT_JSON');
      return;
    }

    const client = await pool.connect();
    let rows;
    try {
      // Reclaim rows a previous run picked up but never finished (crash / timeout).
      await client.query(
        `UPDATE public.push_outbox
            SET status='pending'
          WHERE status='sending' AND claimed_at < now() - interval '2 minutes'`,
      );
      // Claim a batch atomically so overlapping runs don't double-send.
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
            // Dead token — drop it so we stop trying.
            await pool.query(
              'UPDATE public.profiles SET push_token=NULL WHERE id=$1',
              [row.recipient_id],
            );
          }
          const dead = result.unregistered || row.attempts >= MAX_ATTEMPTS;
          await pool.query(
            `UPDATE public.push_outbox
                SET status=$2, last_error=$3
              WHERE id=$1`,
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

    context.log(`push: processed ${rows.length} row(s)`);
  },
});
