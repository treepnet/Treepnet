// Treepnet web "Delete account" backend — the Azure Function adapted to a plain
// Node HTTP server for the OCI stack. Two endpoints (called by the website):
//   POST /api/request-code  { username }        -> emails a 6-digit code
//   POST /api/confirm        { username, code }  -> verifies + deletes account
// Behind Caddy at https://api.treepnet.com/delete-account/* (prefix stripped).
const http = require('http');
const { Pool } = require('pg');
const nodemailer = require('nodemailer');

const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING,
  ssl: false, // internal docker network
  max: 3,
});

const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || '*';
const CODE_TTL_MIN = parseInt(process.env.CODE_TTL_MIN || '15', 10);
const PORT = parseInt(process.env.PORT || '4000', 10);

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    Vary: 'Origin',
  };
}

function send(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    ...corsHeaders(),
  });
  res.end(JSON.stringify(body));
}

async function findUser(username) {
  const r = await pool.query(
    'select id, email from profiles where lower(username) = lower($1) limit 1',
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
    if (row.code !== code) {
      await pool.query(
        'update account_deletion_codes set attempts = attempts + 1 where email = $1',
        [user.email],
      );
      return send(res, 400, { error: 'Invalid code.' });
    }
    await pool.query('select delete_account_by_id($1)', [user.id]);
    await pool.query('delete from account_deletion_codes where email = $1', [user.email]);
    return send(res, 200, { ok: true });
  } catch (e) {
    return send(res, 500, { error: 'Something went wrong. Please try again.' });
  }
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
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
