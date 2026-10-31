// Treepnet web "Delete account" backend — the Azure Function adapted to a plain
// Node HTTP server for the OCI stack. Two endpoints (called by the website):
//   POST /api/request-code  { username }        -> emails a 6-digit code
//   POST /api/confirm        { username, code }  -> verifies + deletes account
// It also runs the account-deletion cleanup worker (cleanup.js) for every
// deletion, from the app or the website.
// Behind Caddy at https://api.treepnet.com/delete-account/* (prefix stripped).
const http = require('http');
const crypto = require('crypto');
const { Pool } = require('pg');
const nodemailer = require('nodemailer');
const admin = require('firebase-admin');
const { createCleanup } = require('./cleanup');

// Firebase Admin — so deleting an account also removes its Firebase Auth user
// (uid == the profile UUID). Signs locally with the service-account key.
const serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_FILE ||
  '/secrets/fcm-service-account.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

// Codes are stored as an HMAC, never as-is, so reading account_deletion_codes
// (a leaked dump, a stray grant) hands out no live codes. The key comes from
// the service account's private key, which lives outside the database.
const CODE_KEY = crypto
  .createHash('sha256')
  .update(`treepnet-deletion-codes:${serviceAccount.private_key}`)
  .digest();

const hashCode = (email, code) =>
  'h1:' + crypto.createHmac('sha256', CODE_KEY).update(`${email}:${code}`).digest('hex');

function codeMatches(stored, email, code) {
  const a = Buffer.from(String(stored || ''));
  const b = Buffer.from(hashCode(email, code));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  ssl: false, // internal docker network
  max: 3,
});

// Comma-separated: the page is served on both treepnet.com and www.treepnet.com.
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGIN || '*')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);
const CODE_TTL_MIN = parseInt(process.env.CODE_TTL_MIN || '15', 10);
const PORT = parseInt(process.env.PORT || '4000', 10);

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

// Browsers accept a single origin per response, so echo the caller's when it
// is one of ours.
function allowOriginFor(origin) {
  if (ALLOWED_ORIGINS.includes('*')) return '*';
  return ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
}

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    Vary: 'Origin',
  };
}

function send(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    ...corsHeaders(res.allowOrigin),
  });
  res.end(JSON.stringify(body));
}

// The deletion code email, in the account's language (Russian or English, as
// the app), as HTML with a plain-text twin. Inline styles and tables only:
// mail apps drop <style>. Our own text and the code's digits only — nothing
// to escape.
const DELETION_EMAIL = {
  en: {
    subject: 'Your Treepnet account deletion code',
    lead: 'Enter this code on the delete page to permanently delete your Treepnet account.',
    expires: (min) => `The code expires in ${min} minutes.`,
    ignore: "If you didn't ask for it, ignore this email — nothing will happen.",
  },
  ru: {
    subject: 'Код удаления аккаунта Treepnet',
    lead: 'Введите этот код на странице удаления, чтобы навсегда удалить аккаунт Treepnet.',
    expires: (min) => `Код действует ${min} мин.`,
    ignore: 'Если вы его не запрашивали, проигнорируйте это письмо — ничего не произойдёт.',
  },
};

async function sendDeletionCodeEmail(email, code, lang) {
  const l = lang === 'ru' ? 'ru' : 'en';
  const t = DELETION_EMAIL[l];
  const expires = t.expires(CODE_TTL_MIN);
  await transporter.sendMail({
    from: `Treepnet <${process.env.SMTP_USER}>`,
    to: email,
    subject: t.subject,
    text: `${t.lead}\n\n${code}\n\n${expires}\n${t.ignore}`,
    html: `<!doctype html>
<html lang="${l}"><body style="margin:0;padding:0;background:#f2f3f5">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f2f3f5;padding:32px 16px">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:440px;background:#ffffff;border-radius:16px;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#17191c">
<tr><td style="padding:28px 28px 0;font-size:20px;font-weight:700">Treepnet</td></tr>
<tr><td style="padding:16px 28px 0;font-size:15px;line-height:1.5">${t.lead}</td></tr>
<tr><td style="padding:24px 28px">
<div style="background:#f2f3f5;border-radius:12px;padding:16px 0;text-align:center;font-family:Menlo,Consolas,'Courier New',monospace;font-size:32px;font-weight:700;letter-spacing:8px">${code}</div>
</td></tr>
<tr><td style="padding:0 28px 28px;font-size:13px;line-height:1.5;color:#5f6570">${expires}<br>${t.ignore}</td></tr>
</table>
</td></tr>
</table>
</body></html>`,
  });
}

// Best-effort note to the private Telegram error bot (error-logger service).
function alertErrorBot(message) {
  if (!process.env.LOG_APP_KEY) return;
  fetch('http://errorlogger:4200/error', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-app-key': process.env.LOG_APP_KEY },
    body: JSON.stringify({ env: 'server', kind: 'deletion-email', message }),
  }).catch(() => {});
}

async function findUser(username) {
  const r = await pool.query(
    'select id, email, lang from profiles where lower(username) = lower($1) limit 1',
    [username],
  );
  return r.rows[0] || null;
}

async function requestCode(res, body) {
  const username = (body.username || '').trim();
  if (!username) return send(res, 400, { error: 'Username is required.' });
  try {
    const user = await findUser(username);
    // Always return ok so the endpoint can't probe which usernames exist.
    if (user && user.email) {
      const code = String(crypto.randomInt(100000, 1000000));
      const expires = new Date(Date.now() + CODE_TTL_MIN * 60000).toISOString();
      await pool.query(
        `insert into account_deletion_codes(email, code, expires_at, attempts)
         values ($1, $2, $3, 0)
         on conflict (email) do update
           set code = excluded.code, expires_at = excluded.expires_at, attempts = 0`,
        [user.email, hashCode(user.email, code), expires],
      );
      try {
        await sendDeletionCodeEmail(user.email, code, user.lang);
      } catch (e) {
        // Dropped, so a code that never arrived can't be used either; the
        // error bot hears about it (no address, no code).
        console.error('delete-account code email failed:', e.message);
        await pool
          .query('delete from account_deletion_codes where email = $1', [user.email])
          .catch(() => {});
        alertErrorBot(`deletion code email failed: ${e.message}`);
        return send(res, 424, {
          error: "Couldn't send the email. Please try again in a few minutes.",
          code: 'email_failed',
        });
      }
    }
    return send(res, 200, { ok: true });
  } catch (e) {
    return send(res, 500, { error: 'Something went wrong. Please try again.' });
  }
}

async function confirm(res, body) {
  const username = (body.username || '').trim();
  const code = (body.code || '').trim();
  if (!username || !code)
    return send(res, 400, { error: 'Username and code are required.' });
  try {
    const user = await findUser(username);
    if (!user) return send(res, 400, { error: 'Invalid or expired code.' });

    const r = await pool.query(
      'select code, expires_at, attempts from account_deletion_codes where email = $1',
      [user.email],
    );
    const row = r.rows[0];
    if (!row)
      return send(res, 400, { error: 'Invalid or expired code. Request a new one.' });
    if (new Date(row.expires_at) < new Date())
      return send(res, 400, { error: 'Code has expired. Request a new one.' });
    if (row.attempts >= 5)
      return send(res, 400, { error: 'Too many attempts. Request a new code.' });
    if (!codeMatches(row.code, user.email, code)) {
      await pool.query(
        'update account_deletion_codes set attempts = attempts + 1 where email = $1',
        [user.email],
      );
      return send(res, 400, { error: 'Invalid code.' });
    }
    // Deletes the rows and the code, and queues the rest (Firebase user, chats,
    // media files) for the cleanup worker — the same path the app's own
    // delete_account() takes.
    await pool.query('select delete_account_by_id($1)', [user.id]);
    return send(res, 200, { ok: true });
  } catch (e) {
    return send(res, 500, { error: 'Something went wrong. Please try again.' });
  }
}

const server = http.createServer((req, res) => {
  res.allowOrigin = allowOriginFor(req.headers.origin);
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders(res.allowOrigin));
    return res.end();
  }
  const path = (req.url || '').split('?')[0];
  if (req.method === 'POST' && (path === '/api/request-code' || path === '/api/confirm')) {
    let data = '';
    req.on('data', (c) => {
      data += c;
      if (data.length > 1e6) req.destroy();
    });
    req.on('end', async () => {
      let body;
      try { body = JSON.parse(data || '{}'); } catch { return send(res, 400, { error: 'Bad request.' }); }
      if (path === '/api/request-code') return requestCode(res, body);
      return confirm(res, body);
    });
    return;
  }
  if (req.method === 'GET' && path === '/health') return send(res, 200, { ok: true });
  send(res, 404, { error: 'Not found.' });
});

server.listen(PORT, () => console.log(`delete-account server on :${PORT}`));

createCleanup({ pool, admin }).start();
