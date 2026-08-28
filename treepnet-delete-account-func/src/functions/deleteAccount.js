// Treepnet — web "Delete account" backend (Azure Functions, Node.js v4).
//
// Two HTTP endpoints called by https://treepnet.com/delete-account :
//   POST /api/request-code  { username }          -> emails a 6-digit code
//   POST /api/confirm        { username, code }    -> deletes the account
//
// It connects to Azure Postgres with an admin/service user, resolves the
// username to its email + id, verifies the emailed code, then runs
// delete_account_by_id() (see sql/account_deletion_web.sql). Deleting the Entra
// (Azure AD) login identity needs Microsoft Graph and is out of scope here — the
// same limitation as the in-app "Delete account".
//
// Required app settings (Configuration):
//   PG_CONNECTION_STRING  postgres admin connection string (sslmode=require)
//   SMTP_USER             treepnetofficial@gmail.com
//   SMTP_PASS             Gmail App Password (16 chars, needs 2FA on the account)
//   ALLOWED_ORIGIN        https://www.treepnet.com   (CORS; or https://treepnet.com)
//   CODE_TTL_MIN          15   (optional)

const { app } = require('@azure/functions');
const { Pool } = require('pg');
const nodemailer = require('nodemailer');

const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  ssl: { rejectUnauthorized: false },
  max: 3,
});

const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || '*';
const CODE_TTL_MIN = parseInt(process.env.CODE_TTL_MIN || '15', 10);

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

function cors() {
  return {
    'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    Vary: 'Origin',
  };
}

function json(status, body) {
  return {
    status,
    headers: { 'Content-Type': 'application/json', ...cors() },
    jsonBody: body,
  };
}

async function findUser(username) {
  const r = await pool.query(
    'select id, email from profiles where lower(username) = lower($1) limit 1',
    [username],
  );
  return r.rows[0] || null;
}

// ---- POST /api/request-code -------------------------------------------------
app.http('request-code', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: async (req) => {
    if (req.method === 'OPTIONS') return { status: 204, headers: cors() };

    let body;
    try { body = await req.json(); } catch { return json(400, { error: 'Bad request.' }); }
    const username = (body.username || '').trim();
    if (!username) return json(400, { error: 'Username is required.' });

    try {
      const user = await findUser(username);
      // Always return ok, so the page can't be used to probe which usernames
      // exist. Only actually send a code when the account is found.
      if (user && user.email) {
        const code = String(Math.floor(100000 + Math.random() * 900000));
        const expires = new Date(Date.now() + CODE_TTL_MIN * 60000).toISOString();
        await pool.query(
          `insert into account_deletion_codes(email, code, expires_at, attempts)
           values ($1, $2, $3, 0)
           on conflict (email) do update
             set code = excluded.code, expires_at = excluded.expires_at, attempts = 0`,
          [user.email, code, expires],
        );
        await transporter.sendMail({
          from: `Treepnet <${process.env.SMTP_USER}>`,
          to: user.email,
          subject: 'Your Treepnet account deletion code',
          text:
            `Your Treepnet account deletion code is ${code}.\n\n` +
            `It expires in ${CODE_TTL_MIN} minutes. Enter it on the delete page ` +
            `to permanently delete your account.\n\n` +
            `If you did not request this, you can ignore this email — nothing will happen.`,
        });
      }
      return json(200, { ok: true });
    } catch (e) {
      return json(500, { error: 'Something went wrong. Please try again.' });
    }
  },
});

// ---- POST /api/confirm ------------------------------------------------------
app.http('confirm', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: async (req) => {
    if (req.method === 'OPTIONS') return { status: 204, headers: cors() };

    let body;
    try { body = await req.json(); } catch { return json(400, { error: 'Bad request.' }); }
    const username = (body.username || '').trim();
    const code = (body.code || '').trim();
    if (!username || !code) return json(400, { error: 'Username and code are required.' });

    try {
      const user = await findUser(username);
      if (!user) return json(400, { error: 'Invalid or expired code.' });

      const r = await pool.query(
        'select code, expires_at, attempts from account_deletion_codes where email = $1',
        [user.email],
      );
      const row = r.rows[0];
      if (!row) return json(400, { error: 'Invalid or expired code. Request a new one.' });
      if (new Date(row.expires_at) < new Date()) {
        return json(400, { error: 'Code has expired. Request a new one.' });
      }
      if (row.attempts >= 5) {
        return json(400, { error: 'Too many attempts. Request a new code.' });
      }
      if (row.code !== code) {
        await pool.query(
          'update account_deletion_codes set attempts = attempts + 1 where email = $1',
          [user.email],
        );
        return json(400, { error: 'Invalid code.' });
      }

      // Verified — delete everything for this account, then drop the code.
      await pool.query('select delete_account_by_id($1)', [user.id]);
      await pool.query('delete from account_deletion_codes where email = $1', [user.email]);
      return json(200, { ok: true });
    } catch (e) {
      return json(500, { error: 'Something went wrong. Please try again.' });
    }
  },
});
