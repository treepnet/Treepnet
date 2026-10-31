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
//   /media/upload-url  { bucket, path, contentType } + Bearer ID token -> {uploadUrl, path}
//       a one-object, 15-minute write link for a post, story or avatar file
const http = require('http');
const crypto = require('crypto');
const { Pool } = require('pg');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
const admin = require('firebase-admin');

// --- Firebase Admin (custom-token minting) — signs locally with the service
//     account private key, no network call needed. ------------------------
const serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_FILE ||
  '/secrets/fcm-service-account.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

// Codes are stored as an HMAC, never as-is, so reading auth_codes (a leaked
// dump, a stray grant) hands out no live codes. The key comes from the service
// account's private key, which lives outside the database.
const CODE_KEY = crypto
  .createHash('sha256')
  .update(`treepnet-auth-codes:${serviceAccount.private_key}`)
  .digest();

const pool = new Pool({
  connectionString: process.env.PG_CONNECTION_STRING, // superuser -> bypasses RLS
  ssl: false, // internal docker network
  max: 5,
});

const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || '*';
const CODE_TTL_MIN = parseInt(process.env.CODE_TTL_MIN || '15', 10);
const PORT = parseInt(process.env.PORT || '4100', 10);

// --- Media uploads ------------------------------------------------------
// The app used to ship one bucket-wide write link valid until 2035. Now it asks
// here for each file: the caller's Firebase ID token is checked, the object
// name must be theirs to write, and the link it gets writes only that object,
// for 15 minutes. Signed in as this server (OCI instance principal; dynamic
// group treepnet-server, policy treepnet-server-media-delete).
const MEDIA_REGION = 'eu-frankfurt-1';
const MEDIA_NAMESPACE = 'fryarohmp0gm';
const MEDIA_BUCKET = 'treepnet-media';
const UPLOAD_LINK_MIN = 15;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SEGMENT_RE = /^[A-Za-z0-9._:-]{1,120}$/;
// Photos and videos only (no SVG: it can carry script).
const CONTENT_TYPE_RE = /^(image\/(jpeg|jpg|png|heic|heif|webp|gif)|video\/[a-z0-9.+-]{1,30})$/;
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
// New names: the app's rule (sign-up, profile edit). It was 3-20 here while
// the database allows 3-16, so 17-20 passed this check and then failed in the
// database with an unclear error. The database keeps 3-16 for older names.
const isUsername = (s) => /^[a-z0-9_.]{6,16}$/.test(s);
const genCode = () =>
  String(crypto.randomInt(0, 10 ** CODE_LENGTH)).padStart(CODE_LENGTH, '0');

// Bound to the email and purpose, so a stored hash can't be reused elsewhere.
const hashCode = (email, purpose, code) =>
  'h1:' +
  crypto.createHmac('sha256', CODE_KEY).update(`${purpose}:${email}:${code}`).digest('hex');

function codeMatches(stored, email, purpose, code) {
  const a = Buffer.from(String(stored || ''));
  const b = Buffer.from(hashCode(email, purpose, code));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

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

async function upsertCode(email, code, purpose, payload = null) {
  const expires = new Date(Date.now() + CODE_TTL_MIN * 60000).toISOString();
  await pool.query(
    `insert into auth_codes(email, code, purpose, expires_at, attempts, payload)
       values ($1, $2, $3, $4, 0, $5)
     on conflict (email) do update
       set code = excluded.code, purpose = excluded.purpose,
           expires_at = excluded.expires_at, attempts = 0,
           payload = excluded.payload`,
    [email, hashCode(email, purpose, code), purpose, expires, payload],
  );
}

// The app repeats a request whose answer was slow. Within this many seconds
// a repeated send-code keeps the code already mailed instead of mailing a new
// one that would void it (codes are stored hashed, so the same code can't be
// sent again).
const RESEND_GAP_SEC = 60;

// The row of a code mailed less than RESEND_GAP_SEC ago, if any.
async function codeJustSent(email, purpose) {
  const r = await pool.query(
    `select payload from auth_codes
      where email = $1 and purpose = $2 and attempts = 0
        and expires_at - make_interval(mins => $3::int)
              > now() - make_interval(secs => $4::int)`,
    [email, purpose, CODE_TTL_MIN, RESEND_GAP_SEC],
  );
  return r.rows[0] || null;
}

// The password-reset flow's continuation token: random and meaningless. It
// used to be the account's email, so anyone could look up the address behind
// a username (and tell which usernames exist). The token is kept with the
// code (auth_codes.payload) and leads back to the email on verify.
const newResetToken = () => crypto.randomBytes(24).toString('hex');

async function emailForResetToken(token) {
  if (!token) return null;
  const r = await pool.query(
    `select email from auth_codes
      where purpose in ('reset', 'reset_done') and payload->>'token' = $1`,
    [token],
  );
  return r.rows[0]?.email || null;
}

// "Your password was changed", to the account's owner — in their app
// language. Best-effort: a reset doesn't fail over it.
async function sendPasswordChangedEmail(uid, email) {
  const r = await pool.query('select lang from profiles where id = $1', [uid]);
  const ru = r.rows[0]?.lang === 'ru';
  await transporter.sendMail({
    from: `Treepnet <${process.env.SMTP_USER}>`,
    to: email,
    subject: ru ? 'Пароль Treepnet изменён' : 'Your Treepnet password was changed',
    text: ru
      ? 'Пароль вашего аккаунта Treepnet только что изменён, и все устройства ' +
        'вышли из аккаунта.\n\nЕсли это сделали вы, ничего делать не нужно.\n\n' +
        'Если это были не вы, сразу восстановите пароль в приложении ' +
        '(«Забыли пароль?»).'
      : 'The password of your Treepnet account was just changed, and every ' +
        'device was signed out.\n\nIf this was you, there is nothing else to ' +
        "do.\n\nIf it wasn't you, reset your password in the app right away " +
        '("Forgot password?").',
  });
}

// A repeated verify after a slow answer finds its code already used up by the
// first, which succeeded. These recognise that first success — only for a
// change made in the last few minutes, by someone who knows the password.
const REPEAT_WINDOW = "interval '10 minutes'";

async function credentialsIfPassword(email, password, changedColumn) {
  const r = await pool.query(
    `select c.user_id, c.password_hash
       from profiles p join auth_credentials c on c.user_id = p.id
      where lower(p.email) = $1 and c.${changedColumn} > now() - ${REPEAT_WINDOW}
      limit 1`,
    [email],
  );
  const row = r.rows[0];
  if (!row || !(await bcrypt.compare(password, row.password_hash))) return null;
  return row.user_id;
}

// Validates a code for `email`; returns null on success or { error, code }
// (the app shows its own text for each code, in its language). Increments
// attempts on a wrong code. Deletes nothing (caller decides).
async function checkCode(email, code, purpose) {
  const r = await pool.query(
    'select code, purpose, expires_at, attempts from auth_codes where email = $1',
    [email],
  );
  const row = r.rows[0];
  if (!row || row.purpose !== purpose)
    return { error: 'Invalid or expired code.', code: 'invalid_code' };
  if (new Date(row.expires_at) < new Date())
    return { error: 'Code has expired. Request a new one.', code: 'code_expired' };
  if (row.attempts >= 5)
    return { error: 'Too many attempts. Request a new code.', code: 'code_attempts' };
  if (!codeMatches(row.code, email, purpose, code)) {
    await pool.query(
      'update auth_codes set attempts = attempts + 1 where email = $1',
      [email],
    );
    return { error: 'Invalid code.', code: 'invalid_code' };
  }
  return null;
}

let objectStorage = null;
async function storageClient() {
  if (!objectStorage) {
    const common = require('oci-common');
    const { ObjectStorageClient } = require('oci-objectstorage');
    const provider = await new common.InstancePrincipalsAuthenticationDetailsProviderBuilder().build();
    objectStorage = new ObjectStorageClient({ authenticationDetailsProvider: provider });
    objectStorage.regionId = MEDIA_REGION;
  }
  return objectStorage;
}

// Where [uid] may write `<bucket>/<path>`: their own new or existing post or
// story, or their own avatar folder (an avatar is always placed under it).
// Returns { objectName, path, owner } or null when the name isn't allowed.
function uploadTarget(uid, bucket, path) {
  const parts = String(path || '').split('/');
  if (parts.some((p) => !SEGMENT_RE.test(p) || p === '.' || p === '..')) return null;
  if (bucket === 'posts') {
    if (parts.length !== 2 || !UUID_RE.test(parts[0])) return null;
    // thumb_<i>: the small copy of image_<i> that grids show.
    if (!/^(image|thumb|video|video_first_frame)_\d{1,2}$/.test(parts[1])) return null;
    return { objectName: `posts/${parts.join('/')}`, path: parts.join('/'), owner: { table: 'posts', id: parts[0] } };
  }
  if (bucket === 'stories') {
    if (parts.length !== 2 || !UUID_RE.test(parts[0]) || parts[1] !== 'image') return null;
    return { objectName: `stories/${parts.join('/')}`, path: parts.join('/'), owner: { table: 'stories', id: parts[0] } };
  }
  if (bucket === 'avatars') {
    const name = parts[parts.length - 1];
    return { objectName: `avatars/${uid}/${name}`, path: `${uid}/${name}`, owner: null };
  }
  return null;
}

async function uidFromRequest(headers) {
  const match = /^Bearer\s+(.+)$/i.exec(headers.authorization || '');
  if (!match) return null;
  try {
    return (await admin.auth().verifyIdToken(match[1].trim())).uid;
  } catch (_) {
    return null;
  }
}

async function mediaUploadUrl(res, b, headers) {
  const uid = await uidFromRequest(headers);
  if (!uid) return fail(res, 401, 'Sign in again.', 'unauthorized');
  const contentType = String(b.contentType || '');
  if (!CONTENT_TYPE_RE.test(contentType)) return fail(res, 400, 'Unsupported file type.');
  const target = uploadTarget(uid, b.bucket, b.path);
  if (!target) return fail(res, 400, 'Invalid file name.');

  // A post or story that already exists must be the caller's.
  if (target.owner) {
    const r = await pool.query(
      `select user_id from ${target.owner.table} where id = $1`,
      [target.owner.id],
    );
    if (r.rows[0] && r.rows[0].user_id !== uid) {
      return fail(res, 403, 'Not allowed.', 'forbidden');
    }
  }

  const client = await storageClient();
  const expires = new Date(Date.now() + UPLOAD_LINK_MIN * 60000);
  const par = await client.createPreauthenticatedRequest({
    namespaceName: MEDIA_NAMESPACE,
    bucketName: MEDIA_BUCKET,
    createPreauthenticatedRequestDetails: {
      name: `upload-${uid}-${Date.now()}`,
      objectName: target.objectName,
      accessType: 'ObjectWrite',
      timeExpires: expires,
    },
  });
  // accessUri is /p/<token>/n/<ns>/b/<bucket>/o/<object>; rebuild the object
  // part percent-encoded per segment, exactly as the app names its URLs.
  const accessUri = par.preauthenticatedRequest.accessUri;
  const tokenPart = accessUri.slice(0, accessUri.indexOf('/n/'));
  const encoded = target.objectName.split('/').map(encodeURIComponent).join('/');
  const uploadUrl =
    `https://objectstorage.${MEDIA_REGION}.oraclecloud.com${tokenPart}` +
    `/n/${MEDIA_NAMESPACE}/b/${MEDIA_BUCKET}/o/${encoded}`;
  return send(res, 200, { uploadUrl, path: target.path, expiresAt: expires.toISOString() });
}

// Expired upload links stay listed on the bucket; clear them hourly.
async function deleteExpiredUploadLinks() {
  try {
    const client = await storageClient();
    const cutoff = Date.now() - 5 * 60000;
    let page;
    do {
      const r = await client.listPreauthenticatedRequests({
        namespaceName: MEDIA_NAMESPACE,
        bucketName: MEDIA_BUCKET,
        limit: 1000,
        page,
      });
      for (const item of r.items) {
        if (!String(item.name).startsWith('upload-')) continue;
        if (new Date(item.timeExpires).getTime() > cutoff) continue;
        await client.deletePreauthenticatedRequest({
          namespaceName: MEDIA_NAMESPACE,
          bucketName: MEDIA_BUCKET,
          parId: item.id,
        });
      }
      page = r.opcNextPage;
    } while (page);
  } catch (e) {
    console.error('auth-service: clearing expired upload links failed:', e.message);
  }
}
setInterval(deleteExpiredUploadLinks, 60 * 60000).unref();

async function mintToken(uid) {
  return admin.auth().createCustomToken(uid);
}

// Signs the account out everywhere: refresh tokens issued before now stop
// working, so every signed-in device loses its session once its current ID
// token (at most an hour old) expires. An account that never signed in to
// Firebase has nothing to revoke.
async function revokeSessions(uid) {
  try {
    await admin.auth().revokeRefreshTokens(uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
}

// --- handlers -----------------------------------------------------------
async function signupSendCode(res, b) {
  const email = (b.email || '').trim().toLowerCase();
  const password = b.password || '';
  if (!isEmail(email))
    return fail(res, 400, 'Enter a valid email address.', 'invalid_email');
  if (password.length < 8)
    return fail(res, 400, 'Password must be at least 8 characters.', 'password_too_short');
  const existing = await pool.query(
    'select 1 from profiles where lower(email) = $1 limit 1',
    [email],
  );
  if (existing.rowCount > 0)
    return fail(res, 409, 'An account with this email already exists.', 'user_already_exists');

  if (!(await codeJustSent(email, 'signup'))) {
    const code = genCode();
    await upsertCode(email, code, 'signup');
    await sendCodeEmail(email, code, 'signup');
  }
  return send(res, 200, { ok: true, continuationToken: email, codeLength: CODE_LENGTH });
}

async function signupVerify(res, b) {
  const email = (b.email || '').trim().toLowerCase();
  const code = (b.code || '').trim();
  const username = (b.username || '').trim().toLowerCase();
  const fullName = (b.fullName || '').trim();
  const password = b.password || '';
  const birthday = b.birthday || null;

  if (!isEmail(email) || !code)
    return fail(res, 400, 'Invalid or expired code.', 'invalid_code');
  if (!isUsername(username))
    return fail(res, 400, 'That username is not valid.', 'invalid_username');
  if (password.length < 8)
    return fail(res, 400, 'Password must be at least 8 characters.', 'password_too_short');

  const codeErr = await checkCode(email, code, 'signup');
  if (codeErr) {
    // The same sign-up again: the first created the account. Sign in.
    const uid = await credentialsIfPassword(email, password, 'created_at');
    if (uid) return send(res, 200, { token: await mintToken(uid), userId: uid });
    return fail(res, 400, codeErr.error, codeErr.code);
  }

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
      // full_name is NOT NULL, so keep the empty string rather than nulling it
      // (the sign-up form doesn't collect a name; the user sets it later).
      `insert into profiles(id, email, full_name, username, birthday)
         values (gen_random_uuid(), $1, $2, $3, $4)
       returning id`,
      [email, fullName, username, birthday],
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
    console.error('auth-service /signup/verify error:', e);
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
  // Always the same answer — ok and a fresh-looking token — so the endpoint
  // tells nothing about which accounts exist or their email addresses.
  let token = newResetToken();
  if (email) {
    const hasCreds = await pool.query(
      `select 1 from profiles p join auth_credentials c on c.user_id = p.id
        where lower(p.email) = $1 limit 1`,
      [email],
    );
    if (hasCreds.rowCount > 0) {
      const recent = await codeJustSent(email, 'reset');
      if (recent?.payload?.token) {
        // A repeat: the code already mailed stays, with its token.
        token = recent.payload.token;
      } else {
        const code = genCode();
        await upsertCode(email, code, 'reset', { token });
        await sendCodeEmail(email, code, 'reset');
      }
    }
  }
  return send(res, 200, { ok: true, continuationToken: token, codeLength: CODE_LENGTH });
}

async function resetVerify(res, b) {
  // continuationToken is the token reset/send-code returned. A reset begun
  // before the tokens were opaque carries the email itself.
  const token = (b.continuationToken || '').trim();
  const email =
    (await emailForResetToken(token)) ||
    (token || b.email || '').trim().toLowerCase();
  const code = (b.code || '').trim();
  const newPassword = b.newPassword || '';
  if (!isEmail(email) || !code)
    return fail(res, 400, 'Invalid or expired code.', 'invalid_code');
  if (newPassword.length < 8)
    return fail(res, 400, 'Choose a stronger password.', 'password_too_short');

  const codeErr = await checkCode(email, code, 'reset');
  if (codeErr) {
    // The same reset again: the first already set this very password.
    if (await credentialsIfPassword(email, newPassword, 'updated_at')) {
      return send(res, 200, { ok: true });
    }
    return fail(res, 400, codeErr.error, codeErr.code);
  }

  const r = await pool.query(
    `select c.user_id
       from profiles p join auth_credentials c on c.user_id = p.id
      where lower(p.email) = $1 limit 1`,
    [email],
  );
  const uid = r.rows[0]?.user_id;
  if (!uid) return fail(res, 400, 'Invalid or expired code.', 'invalid_code');

  // Before the password changes: if revoking fails, nothing has changed and
  // the same code still works for a retry.
  await revokeSessions(uid);

  const hash = await bcrypt.hash(newPassword, BCRYPT_COST);
  await pool.query(
    'update auth_credentials set password_hash = $2, updated_at = now() where user_id = $1',
    [uid, hash],
  );
  // The code is used up, but its token still leads to the email for a few
  // minutes, so a repeat of this request (after a slow answer) is recognised.
  await pool.query(
    `update auth_codes set code = '', purpose = 'reset_done',
       expires_at = now() + interval '10 minutes'
     where email = $1`,
    [email],
  );
  sendPasswordChangedEmail(uid, email).catch((e) =>
    console.error('auth-service password-changed email failed:', e.message),
  );
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
  '/media/upload-url': mediaUploadUrl,
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
      await handler(res, body, req.headers);
    } catch (e) {
      console.error(`auth-service ${path} error:`, e);
      if (!res.headersSent) fail(res, 500, 'Something went wrong. Please try again.');
    }
  });
});

server.listen(PORT, () => console.log(`auth-service on :${PORT}`));
