'use strict';

// Sign in with Google / Sign in with Apple, for server.js.
//
// The phone signs in with Google or Apple itself and sends us the ID token it
// got (a JWT). It is checked here against the provider's published keys —
// signature, issuer, audience (our app), expiry and, for Apple, the nonce the
// app made for this sign-in — and nothing in it is taken from the phone's say.
// No library: Node's crypto verifies RS256 against a JWK and signs ES256.

const crypto = require('crypto');

class SocialError extends Error {
  constructor(code, message) {
    super(message || code);
    this.code = code;
  }
}

const PROVIDERS = {
  google: {
    jwks: 'https://www.googleapis.com/oauth2/v3/certs',
    issuers: ['https://accounts.google.com', 'accounts.google.com'],
  },
  apple: {
    jwks: 'https://appleid.apple.com/auth/keys',
    issuers: ['https://appleid.apple.com'],
  },
};

// --- keys -----------------------------------------------------------------
// Each provider's keys, kept six hours; an unknown key id fetches again (they
// rotate), at most once a minute. A failed fetch keeps the keys there were.
const KEYS_TTL_MS = 6 * 3600 * 1000;
const REFETCH_MS = 60 * 1000;
const keySets = new Map(); // url -> { at, keys: Map(kid -> KeyObject) }

let fetchJson = async (url) => {
  const r = await fetch(url, { signal: AbortSignal.timeout(5000) });
  if (!r.ok) throw new Error(`${url}: ${r.status}`);
  return r.json();
};

async function loadKeys(url) {
  const body = await fetchJson(url);
  const keys = new Map();
  for (const jwk of body.keys || []) {
    if (jwk.kty !== 'RSA' || !jwk.kid) continue;
    try {
      keys.set(jwk.kid, crypto.createPublicKey({ key: jwk, format: 'jwk' }));
    } catch (_) {
      // A key we can't read is one we never match.
    }
  }
  return { at: Date.now(), keys };
}

async function keyFor(url, kid) {
  const held = keySets.get(url);
  const age = held ? Date.now() - held.at : Infinity;
  if (held && age < KEYS_TTL_MS && held.keys.has(kid)) return held.keys.get(kid);
  if (!held || age >= KEYS_TTL_MS || age >= REFETCH_MS) {
    try {
      const fresh = await loadKeys(url);
      keySets.set(url, fresh);
      return fresh.keys.get(kid) || null;
    } catch (e) {
      console.error('auth-service: provider keys fetch failed:', e.message);
      if (!held) throw new SocialError('provider_unreachable');
    }
  }
  return held.keys.get(kid) || null;
}

// --- tokens ---------------------------------------------------------------
const b64json = (part) => JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));
const sha256hex = (s) => crypto.createHash('sha256').update(s, 'utf8').digest('hex');

/**
 * The claims of [token] from [provider] ('google' | 'apple') once it checks
 * out, else a SocialError('invalid_token'). [audiences]: our client ids.
 * [nonce]: the raw nonce the app made (Apple: the token carries its SHA-256).
 */
async function verifyIdToken(provider, token, { audiences, nonce, now = Date.now() } = {}) {
  const p = PROVIDERS[provider];
  if (!p) throw new SocialError('invalid_provider');
  if (typeof token !== 'string' || token.length > 8192) throw new SocialError('invalid_token');
  const parts = token.split('.');
  if (parts.length !== 3) throw new SocialError('invalid_token');

  let header;
  let claims;
  try {
    header = b64json(parts[0]);
    claims = b64json(parts[1]);
  } catch (_) {
    throw new SocialError('invalid_token');
  }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') throw new SocialError('invalid_token');

  const key = await keyFor(p.jwks, header.kid);
  if (!key) throw new SocialError('invalid_token');
  const signed = crypto.verify(
    'RSA-SHA256',
    Buffer.from(`${parts[0]}.${parts[1]}`),
    key,
    Buffer.from(parts[2], 'base64url'),
  );
  if (!signed) throw new SocialError('invalid_token');

  const nowSec = Math.floor(now / 1000);
  const skew = 120;
  if (!p.issuers.includes(claims.iss)) throw new SocialError('invalid_token');
  const aud = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!aud.some((a) => (audiences || []).includes(a))) throw new SocialError('invalid_token');
  if (typeof claims.exp !== 'number' || claims.exp + skew < nowSec) throw new SocialError('token_expired');
  if (typeof claims.iat === 'number' && claims.iat - skew > nowSec) throw new SocialError('invalid_token');
  if (typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 255) {
    throw new SocialError('invalid_token');
  }
  if (provider === 'apple') {
    // Made by the app for this one sign-in: a token caught on the way can't
    // be replayed without it.
    if (typeof nonce !== 'string' || !nonce || claims.nonce !== sha256hex(nonce)) {
      throw new SocialError('invalid_token');
    }
  }
  return claims;
}

/** The address [claims] say is the person's own (lower-case), else null. */
function verifiedEmail(claims) {
  const email = typeof claims.email === 'string' ? claims.email.trim().toLowerCase() : '';
  const verified = claims.email_verified === true || claims.email_verified === 'true';
  return email && verified ? email : null;
}

// --- sign-up tickets ----------------------------------------------------------
// A new account needs a username first: the checked sign-in is handed back as
// a ticket (signed, 30 minutes) that /social/complete takes with the name, so
// the phone doesn't go through Google/Apple twice.
const TICKET_TTL_MS = 30 * 60 * 1000;

function signTicket(key, data, now = Date.now()) {
  const body = Buffer.from(JSON.stringify({ ...data, x: now + TICKET_TTL_MS })).toString('base64url');
  const mac = crypto.createHmac('sha256', key).update(`ticket:${body}`).digest('base64url');
  return `${body}.${mac}`;
}

/** The ticket's data, or null when it is forged or expired. */
function readTicket(key, ticket, now = Date.now()) {
  if (typeof ticket !== 'string' || ticket.length > 4096) return null;
  const [body, mac] = ticket.split('.');
  if (!body || !mac) return null;
  const want = Buffer.from(crypto.createHmac('sha256', key).update(`ticket:${body}`).digest('base64url'));
  const got = Buffer.from(mac);
  if (want.length !== got.length || !crypto.timingSafeEqual(want, got)) return null;
  let data;
  try {
    data = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch (_) {
    return null;
  }
  if (typeof data.x !== 'number' || data.x < now) return null;
  return data;
}

// --- Apple: revoking on account deletion ------------------------------------------
// Apple asks that an app made with Sign in with Apple revokes its tokens when
// the account is deleted. The app signs in with Apple once more to confirm the
// deletion; its fresh authorization code is traded here for a token, which is
// then revoked. Our client secret is a short JWT signed with the Sign in with
// Apple key (.p8).

function appleClientSecret({ teamId, keyId, privateKey, clientId, now = Date.now() }) {
  const iat = Math.floor(now / 1000);
  const enc = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const input = `${enc({ alg: 'ES256', kid: keyId })}.${enc({
    iss: teamId,
    iat,
    exp: iat + 300,
    aud: 'https://appleid.apple.com',
    sub: clientId,
  })}`;
  const sig = crypto.sign('sha256', Buffer.from(input), { key: privateKey, dsaEncoding: 'ieee-p1363' });
  return `${input}.${sig.toString('base64url')}`;
}

async function applePost(path, form) {
  const r = await fetch(`https://appleid.apple.com${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(form).toString(),
    signal: AbortSignal.timeout(8000),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`apple ${path}: ${r.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : {};
}

/** Trades [code] for Apple's token and revokes it. Throws on failure. */
async function appleRevokeWithCode({ code, clientId, teamId, keyId, privateKey }) {
  const secret = appleClientSecret({ teamId, keyId, privateKey, clientId });
  const tokens = await applePost('/auth/token', {
    client_id: clientId,
    client_secret: secret,
    code,
    grant_type: 'authorization_code',
  });
  const token = tokens.refresh_token || tokens.access_token;
  if (!token) throw new Error('apple /auth/token: no token');
  await applePost('/auth/revoke', {
    client_id: clientId,
    client_secret: secret,
    token,
    token_type_hint: tokens.refresh_token ? 'refresh_token' : 'access_token',
  });
}

// --- usernames ----------------------------------------------------------------
/** A username to offer, from [email]'s name part; checked by [isFree]. */
async function suggestUsername(email, isFree) {
  const local = String(email || '').split('@')[0].toLowerCase().replace(/[^a-z0-9_.]/g, '');
  let base = local.replace(/^[._]+|[._]+$/g, '').slice(0, 12);
  if (base.length < 3) base = 'user';
  const tries = [];
  if (base.length >= 6) tries.push(base.slice(0, 16));
  for (let i = 0; i < 4; i++) {
    tries.push(`${base}${crypto.randomInt(100, 10000)}`.slice(0, 16));
  }
  for (const candidate of tries) {
    if (/^[a-z0-9_.]{6,16}$/.test(candidate) && (await isFree(candidate))) return candidate;
  }
  return null;
}

module.exports = {
  SocialError,
  verifyIdToken,
  verifiedEmail,
  signTicket,
  readTicket,
  appleClientSecret,
  appleRevokeWithCode,
  suggestUsername,
  sha256hex,
  // Tests only.
  _setFetchJson: (fn) => {
    fetchJson = fn;
    keySets.clear();
  },
};
