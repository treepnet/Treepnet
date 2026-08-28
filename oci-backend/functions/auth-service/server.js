// Treepnet auth-service — the custom-token bridge that replaced Microsoft Entra.
//
// The app owns every auth screen; this service verifies credentials itself
// (bcrypt hashes in `auth_credentials`), then mints a Firebase **custom token**
// whose uid is the account's `profiles.id` UUID. The app exchanges it via
// `signInWithCustomToken`, so the resulting Firebase ID token has `sub == UUID`
// — which PowerSync + PostgREST validate, keeping `profiles.id` a real uuid.
//
// Behind Caddy at https://api.treepnet.com/auth/* (prefix stripped -> /*).
// Endpoints (all POST, JSON):
//   /signup/send-code  { email, password, fullName }                 -> emails a 6-digit code
//   /signup/verify     { email, code, username, fullName, password, birthday? } -> {token}
//   /login             { usernameOrEmail, password }                 -> {token}
//   /reset/send-code   { usernameOrEmail }                           -> emails a code
//   /reset/verify      { continuationToken(email), code, newPassword }-> {ok}
//   /verify-password   { usernameOrEmail, password }                 -> {ok}  (delete re-auth)
const http = require('http');
const crypto = require('crypto');
const { Pool } = require('pg');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
const admin = require('firebase-admin');

// --- Firebase Admin (custom-token minting) — signs locally with the service
//     account private key, no network call needed. ------------------------
admin.initializeApp({
  credential: admin.credential.cert(
    require(process.env.FIREBASE_SERVICE_ACCOUNT_FILE ||
      '/secrets/fcm-service-account.json'),
  ),
});

const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING, // superuser -> bypasses RLS
  ssl: false, // internal docker network
  max: 5,
});

const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || '*';
const CODE_TTL_MIN = parseInt(process.env.CODE_TTL_MIN || '15', 10);
const PORT = parseInt(process.env.PORT || '4100', 10);
const BCRYPT_COST = parseInt(process.env.BCRYPT_COST || '10', 10);
const CODE_LENGTH = 6;

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

// --- helpers ------------------------------------------------------------
function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    Vary: 'Origin',
  };
}

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json', ...corsHeaders() });
  res.end(JSON.stringify(body));
}

// Mirrors the app's error shape: { error, code } so the client can map a
// friendly message; `code` is optional.
function fail(res, status, error, code) {
  return send(res, status, code ? { error, code } : { error });
}

const isEmail = (s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
const isUsername = (s) => /^[a-z0-9_.]{3,20}$/.test(s);
const genCode = () =>
  String(crypto.randomInt(0, 10 ** CODE_LENGTH)).padStart(CODE_LENGTH, '0');

async function emailForUsernameOrEmail(identifier) {
  const id = (identifier || '').trim();
  if (!id) return null;
  if (id.includes('@')) return id.toLowerCase();
  const r = await pool.query(
    'select email from profiles where lower(username) = lower($1) limit 1',
    [id],
  );
  return r.rows[0]?.email ? r.rows[0].email.toLowerCase() : null;
}

async function sendCodeEmail(email, code, purpose) {
  const what =
    purpose === 'signup'
      ? 'to finish creating your Treepnet account'
      : 'to reset your Treepnet password';
  await transporter.sendMail({
    from: `Treepnet <${process.env.SMTP_USER}>`,
    to: email,
    subject: `Your Treepnet code: ${code}`,
    text:
      `Your Treepnet verification code is ${code}.\n\n` +
      `Enter it ${what}. It expires in ${CODE_TTL_MIN} minutes.\n\n` +
      `If you did not request this, you can ignore this email.`,
  });
}

async function upsertCode(email, code, purpose) {
  const expires = new Date(Date.now() + CODE_TTL_MIN * 60000).toISOString();
  await pool.query(
    `insert into auth_codes(email, code, purpose, expires_at, attempts)
       values ($1, $2, $3, $4, 0)
     on conflict (email) do update
       set code = excluded.code, purpose = excluded.purpose,
           expires_at = excluded.expires_at, attempts = 0`,
    [email, code, purpose, expires],
  );
}

// Validates a code for `email`; returns null on success or an error string.
// Increments attempts on a wrong code. Deletes nothing (caller decides).
async function checkCode(email, code, purpose) {
  const r = await pool.query(
    'select code, purpose, expires_at, attempts from auth_codes where email = $1',
    [email],
  );
  const row = r.rows[0];
  if (!row || row.purpose !== purpose) return 'Invalid or expired code.';
  if (new Date(row.expires_at) < new Date())
    return 'Code has expired. Request a new one.';
  if (row.attempts >= 5) return 'Too many attempts. Request a new code.';
  if (row.code !== code) {
    await pool.query(
      'update auth_codes set attempts = attempts + 1 where email = $1',
      [email],
    );
    return 'Invalid code.';
  }
  return null;
}

async function mintToken(uid) {
  return admin.auth().createCustomToken(uid);
}

// --- handlers -----------------------------------------------------------
async function signupSendCode(res, b) {
  const email = (b.email || '').trim().toLowerCase();
  const password = b.password || '';
  if (!isEmail(email)) return fail(res, 400, 'Enter a valid email address.');
  if (password.length < 8)
    return fail(res, 400, 'Password must be at least 8 characters.', 'password_too_short');
  const existing = await pool.query(
    'select 1 from profiles where lower(email) = $1 limit 1',
    [email],
  );
  if (existing.rowCount > 0)
    return fail(res, 409, 'An account with this email already exists.', 'user_already_exists');

  const code = genCode();
  await upsertCode(email, code, 'signup');
  await sendCodeEmail(email, code, 'signup');
  return send(res, 200, { ok: true, continuationToken: email, codeLength: CODE_LENGTH });
}

async function signupVerify(res, b) {
  const email = (b.email || '').trim().toLowerCase();
  const code = (b.code || '').trim();
  const username = (b.username || '').trim().toLowerCase();
  const fullName = (b.fullName || '').trim();
  const password = b.password || '';
  const birthday = b.birthday || null;

  if (!isEmail(email) || !code) return fail(res, 400, 'Invalid or expired code.');
  if (!isUsername(username))
    return fail(res, 400, 'That username is not valid.', 'invalid_username');
  if (password.length < 8)
    return fail(res, 400, 'Password must be at least 8 characters.', 'password_too_short');

  const codeErr = await checkCode(email, code, 'signup');
  if (codeErr) return fail(res, 400, codeErr, 'invalid_oob_value');

  const client = await pool.connect();
  try {
    await client.query('begin');
    // Re-check uniqueness inside the tx (guards races since send-code).
    const taken = await client.query(
      'select (select 1 from profiles where lower(email)=$1) as email_taken, (select 1 from profiles where lower(username)=$2) as username_taken',
      [email, username],
    );
    if (taken.rows[0].email_taken) {
      await client.query('rollback');
      return fail(res, 409, 'An account with this email already exists.', 'user_already_exists');
    }
    if (taken.rows[0].username_taken) {
      await client.query('rollback');
      return fail(res, 409, 'That username is already taken.', 'username_taken');
    }
    const inserted = await client.query(
      `insert into profiles(id, email, full_name, username, birthday)
         values (gen_random_uuid(), $1, $2, $3, $4)
       returning id`,
      [email, fullName || null, username, birthday],
    );
    const uid = inserted.rows[0].id;
    const hash = await bcrypt.hash(password, BCRYPT_COST);
    await client.query(
      'insert into auth_credentials(user_id, password_hash) values ($1, $2)',
      [uid, hash],
    );
    await client.query('delete from auth_codes where email = $1', [email]);
    await client.query('commit');

    const token = await mintToken(uid);
    return send(res, 200, { token, userId: uid });
  } catch (e) {
    await client.query('rollback').catch(() => {});
    return fail(res, 500, 'Something went wrong. Please try again.');
  } finally {
    client.release();
  }
}

async function login(res, b) {
  const email = await emailForUsernameOrEmail(b.usernameOrEmail);
  const password = b.password || '';
  // Uniform failure so username existence can't be probed via timing/shape:
  // a missing account and a wrong password both return invalid_credentials.
  const deny = () =>
    fail(res, 401, 'Wrong username or password.', 'invalid_credentials');
  if (!email || !password) return deny();

  const r = await pool.query(
    `select p.id, c.password_hash
       from profiles p join auth_credentials c on c.user_id = p.id
      where lower(p.email) = $1 limit 1`,
    [email],
  );
  const row = r.rows[0];
  if (!row) return deny();
  const ok = await bcrypt.compare(password, row.password_hash);
  if (!ok) return deny();

  const token = await mintToken(row.id);
  return send(res, 200, { token, userId: row.id });
}

async function verifyPassword(res, b) {
  const email = await emailForUsernameOrEmail(b.usernameOrEmail);
  const password = b.password || '';
  const deny = () =>
    fail(res, 401, 'Wrong username or password.', 'invalid_credentials');
  if (!email || !password) return deny();
  const r = await pool.query(
    `select c.password_hash
       from profiles p join auth_credentials c on c.user_id = p.id
      where lower(p.email) = $1 limit 1`,
    [email],
  );
  if (!r.rows[0]) return deny();
  const ok = await bcrypt.compare(password, r.rows[0].password_hash);
  if (!ok) return deny();
  return send(res, 200, { ok: true });
}

async function resetSendCode(res, b) {
  const email = await emailForUsernameOrEmail(b.usernameOrEmail);
  // Always return ok so the endpoint can't confirm which accounts exist.
  if (email) {
    const hasCreds = await pool.query(
      `select 1 from profiles p join auth_credentials c on c.user_id = p.id
        where lower(p.email) = $1 limit 1`,
      [email],
    );
    if (hasCreds.rowCount > 0) {
      const code = genCode();
      await upsertCode(email, code, 'reset');
      await sendCodeEmail(email, code, 'reset');
    }
  }
  return send(res, 200, { ok: true, continuationToken: email || '', codeLength: CODE_LENGTH });
}

async function resetVerify(res, b) {
  // continuationToken is the email we returned from reset/send-code.
  const email = (b.continuationToken || b.email || '').trim().toLowerCase();
  const code = (b.code || '').trim();
  const newPassword = b.newPassword || '';
  if (!isEmail(email) || !code) return fail(res, 400, 'Invalid or expired code.');
  if (newPassword.length < 8)
    return fail(res, 400, 'Choose a stronger password.', 'password_too_short');

  const codeErr = await checkCode(email, code, 'reset');
  if (codeErr) return fail(res, 400, codeErr, 'invalid_oob_value');

  const hash = await bcrypt.hash(newPassword, BCRYPT_COST);
  const upd = await pool.query(
    `update auth_credentials c set password_hash = $2, updated_at = now()
       from profiles p
      where c.user_id = p.id and lower(p.email) = $1`,
    [email, hash],
  );
  if (upd.rowCount === 0)
    return fail(res, 400, 'Invalid or expired code.');
  await pool.query('delete from auth_codes where email = $1', [email]);
  return send(res, 200, { ok: true });
}

// --- routing ------------------------------------------------------------
const ROUTES = {
  '/signup/send-code': signupSendCode,
  '/signup/verify': signupVerify,
  '/login': login,
  '/verify-password': verifyPassword,
  '/reset/send-code': resetSendCode,
  '/reset/verify': resetVerify,
};

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
    return res.end();
  }
  const path = (req.url || '').split('?')[0].replace(/\/$/, '');
  if (req.method === 'GET' && path === '/health') return send(res, 200, { ok: true });
  const handler = req.method === 'POST' ? ROUTES[path] : null;
  if (!handler) return fail(res, 404, 'Not found.');

  let data = '';
  req.on('data', (c) => {
    data += c;
    if (data.length > 1e6) req.destroy();
  });
  req.on('end', async () => {
    let body;
    try {
      body = JSON.parse(data || '{}');
    } catch {
      return fail(res, 400, 'Bad request.');
    }
    try {
      await handler(res, body);
    } catch (e) {
      console.error(`auth-service ${path} error:`, e);
      if (!res.headersSent) fail(res, 500, 'Something went wrong. Please try again.');
    }
  });
});

server.listen(PORT, () => console.log(`auth-service on :${PORT}`));
