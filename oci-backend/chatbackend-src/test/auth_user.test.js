// Who a request is, and when the User row is written (auth_user.js).
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const { src, stub } = require('./helpers');

const calls = { project: 0, upsert: 0, find: 0 };
let row = null;
let card = { name: 'Ali', avatar: 'a.jpg' };
stub('infrastructure/database/prisma.js', {
    project: { findUnique: async () => { calls.project++; return { id: 1, name: 'treepnet' }; } },
    user: {
        findUnique: async () => { calls.find++; return row; },
        upsert: async ({ update, create }) => {
            calls.upsert++;
            row = { id: 7, ...(row ? { ...row, ...update } : create), updatedAt: new Date() };
            return row;
        },
    },
});
stub('infrastructure/external/profiles.js', { profileCard: async () => card });

const auth = require(path.join(src, 'application/use-cases/auth_user.js'));

const device = (o = {}) => ({
    appName: 'treepnet', appVersion: 'unknown', packageVersion: 'unknown',
    deviceId: 'd1', deviceName: 'iPhone', deviceType: 'mobile', osVersion: 'unknown',
    lang: 'ru', phone: null, email: null, ipAddress: '1.1.1.1', ...o,
});
const run = (o) => auth.execute({ uuid: 'u1', apiKey: 'k', appName: 'treepnet', deviceData: device(o) });

test('userChanged: what counts as a change', () => {
    const base = { ...device(), name: 'Ali', avatar: 'a.jpg', updatedAt: new Date() };
    const same = { ...device(), name: 'Ali', avatar: 'a.jpg' };
    assert.strictEqual(auth.userChanged(base, same), false);
    assert.strictEqual(auth.userChanged(base, { ...same, ipAddress: '2.2.2.2' }), false, 'the IP alone');
    assert.strictEqual(auth.userChanged(base, { ...same, lang: 'en' }), true, 'language');
    assert.strictEqual(auth.userChanged(base, { ...same, name: 'Vali' }), true, 'name');
    assert.strictEqual(
        auth.userChanged({ ...base, updatedAt: new Date(Date.now() - 61 * 60e3) }, same),
        true,
        'an hour old',
    );
    assert.strictEqual(auth.userChanged({ ...base, phone: '+998' }, { ...same, phone: undefined }), false, 'not sent');
});

test('requests write the row only when something changed', async () => {
    row = null;
    card = null;
    await assert.rejects(run(), (e) => e.code === 'NO_ACCOUNT', 'no TreepNet account: refused');
    card = { name: 'Ali', avatar: 'a.jpg' };
    await run();
    assert.strictEqual(calls.upsert, 1, 'created');
    for (let i = 0; i < 5; i++) await run({ ipAddress: `9.9.9.${i}` });
    assert.strictEqual(calls.upsert, 1, 'nothing changed: no writes');
    assert.strictEqual(calls.find, 7, 'read from the database every time');
    assert.strictEqual(calls.project, 1, 'the project is looked up once');
    await run({ lang: 'en' });
    assert.strictEqual(row.lang, 'en');
    card = { name: 'Vali', avatar: 'a.jpg' };
    await run({ lang: 'en' });
    assert.strictEqual(row.name, 'Vali');
    assert.strictEqual(calls.upsert, 3);
    const { user } = await run({ lang: 'en' });
    assert.strictEqual(user.id, 7);
    assert.strictEqual(calls.upsert, 3);
});
