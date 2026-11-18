'use strict';
// node --test test/   (no dependencies)
const test = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const social = require('../social');

const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: 'k1', alg: 'RS256', use: 'sig' };
social._setFetchJson(async () => ({ keys: [jwk] }));

const enc = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
function jwt(claims, { kid = 'k1', key = privateKey, alg = 'RS256' } = {}) {
  const input = `${enc({ alg, kid, typ: 'JWT' })}.${enc(claims)}`;
  const sig = crypto.sign('RSA-SHA256', Buffer.from(input), key).toString('base64url');
  return `${input}.${sig}`;
}
const now = Date.now();
const sec = Math.floor(now / 1000);
const google = (over = {}) => ({
  iss: 'https://accounts.google.com', aud: 'web-client', sub: '1234567890',
  email: 'Someone@Gmail.com', email_verified: true, iat: sec, exp: sec + 3600, ...over,
});
const verifyGoogle = (token) => social.verifyIdToken('google', token, { audiences: ['web-client', 'ios-client'] });

test('a good Google token checks out', async () => {
  const claims = await verifyGoogle(jwt(google()));
  assert.equal(claims.sub, '1234567890');
  assert.equal(social.verifiedEmail(claims), 'someone@gmail.com');
});

test('another app, issuer, an old token or a forged one is refused', async () => {
  await assert.rejects(verifyGoogle(jwt(google({ aud: 'someone-elses-app' }))), { code: 'invalid_token' });
  await assert.rejects(verifyGoogle(jwt(google({ iss: 'https://evil.example' }))), { code: 'invalid_token' });
  await assert.rejects(verifyGoogle(jwt(google({ exp: sec - 3600 }))), { code: 'token_expired' });
  const other = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;
  await assert.rejects(verifyGoogle(jwt(google(), { key: other })), { code: 'invalid_token' });
  const t = jwt(google()).split('.');
  t[1] = enc(google({ sub: 'someone-else' }));
  await assert.rejects(verifyGoogle(t.join('.')), { code: 'invalid_token' });
  await assert.rejects(verifyGoogle(jwt(google(), { alg: 'none' })), { code: 'invalid_token' });
  await assert.rejects(verifyGoogle('not-a-jwt'), { code: 'invalid_token' });
});

test('an address Google does not vouch for is not taken', async () => {
  const claims = await verifyGoogle(jwt(google({ email_verified: false })));
  assert.equal(social.verifiedEmail(claims), null);
});

test('Apple: the nonce must be the one the app made', async () => {
  const nonce = 'raw-nonce-123';
  const apple = {
    iss: 'https://appleid.apple.com', aud: 'com.treepnet.application', sub: '001.abc',
    email: 'x@privaterelay.appleid.com', email_verified: 'true', iat: sec, exp: sec + 600,
    nonce: social.sha256hex(nonce),
  };
  const opts = (n) => ({ audiences: ['com.treepnet.application'], nonce: n });
  const claims = await social.verifyIdToken('apple', jwt(apple), opts(nonce));
  assert.equal(social.verifiedEmail(claims), 'x@privaterelay.appleid.com');
  await assert.rejects(social.verifyIdToken('apple', jwt(apple), opts('other')), { code: 'invalid_token' });
  await assert.rejects(social.verifyIdToken('apple', jwt(apple), opts(undefined)), { code: 'invalid_token' });
});

test('a ticket comes back as signed, and not forged or late', () => {
  const key = crypto.randomBytes(32);
  const t = social.signTicket(key, { p: 'google', s: '1', e: 'a@b.co' }, now);
  assert.deepEqual(
    (({ p, s, e }) => ({ p, s, e }))(social.readTicket(key, t, now)),
    { p: 'google', s: '1', e: 'a@b.co' },
  );
  assert.equal(social.readTicket(crypto.randomBytes(32), t, now), null);
  const [body, mac] = t.split('.');
  const forged = Buffer.from(JSON.stringify({ ...JSON.parse(Buffer.from(body, 'base64url')), s: '2' })).toString('base64url');
  assert.equal(social.readTicket(key, `${forged}.${mac}`, now), null);
  assert.equal(social.readTicket(key, t, now + 31 * 60 * 1000), null);
  assert.equal(social.readTicket(key, 'junk', now), null);
});

test('the Apple client secret is an ES256 JWT Apple can check', () => {
  const ec = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const secret = social.appleClientSecret({
    teamId: 'TEAM', keyId: 'KEY', clientId: 'com.treepnet.application',
    privateKey: ec.privateKey.export({ type: 'pkcs8', format: 'pem' }), now,
  });
  const [h, p, s] = secret.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(h, 'base64url')), { alg: 'ES256', kid: 'KEY' });
  const claims = JSON.parse(Buffer.from(p, 'base64url'));
  assert.equal(claims.iss, 'TEAM');
  assert.equal(claims.sub, 'com.treepnet.application');
  assert.equal(claims.aud, 'https://appleid.apple.com');
  const ok = crypto.verify('sha256', Buffer.from(`${h}.${p}`), { key: ec.publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url'));
  assert.ok(ok);
});

test('a suggested username fits the rules and is free', async () => {
  const name = await social.suggestUsername('John.Smith+tag@gmail.com', async () => true);
  assert.match(name, /^[a-z0-9_.]{6,16}$/);
  const taken = new Set(['johnsmithtag']);
  const other = await social.suggestUsername('johnsmithtag@gmail.com', async (n) => !taken.has(n));
  assert.match(other, /^johnsmithtag\d+$/);
  assert.equal(await social.suggestUsername('x@y.z', async () => false), null);
});
