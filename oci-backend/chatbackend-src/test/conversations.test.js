// Opening a chat: one conversation per pair (POST /chat/dm/conversations).
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const express = require('express');
const { src, stub } = require('./helpers');

let convs;
let nextId;
let users;
let createDelay;
const unique = () => Object.assign(new Error('Unique constraint failed on pairKey'), { code: 'P2002' });
stub('infrastructure/database/prisma.js', {
    user: {
        findFirst: async ({ where }) => users.find((u) => u.id === where.id) || null,
        findUnique: async ({ where }) => users.find((u) => u.uuid === where.uuid_projectId.uuid) || null,
        update: async ({ where, data }) => Object.assign(users.find((u) => u.id === where.id), data),
    },
    conversation: {
        findUnique: async ({ where }) => convs.find((c) => c.pairKey === where.pairKey) || null,
        findFirst: async ({ where }) => {
            const [a, b] = where.AND.map((x) => x.participants.some.userId);
            return convs.find((c) => c.pairKey === null && c.users.includes(a) && c.users.includes(b)) || null;
        },
        update: async ({ where, data }) => {
            if (convs.some((c) => c.pairKey === data.pairKey && c.id !== where.id)) throw unique();
            return Object.assign(convs.find((c) => c.id === where.id), data);
        },
        create: async ({ data }) => {
            await new Promise((r) => setTimeout(r, createDelay));
            if (convs.some((c) => c.pairKey === data.pairKey)) throw unique();
            const c = { id: nextId++, pairKey: data.pairKey, users: data.participants.create.map((x) => x.userId) };
            convs.push(c);
            return c;
        },
    },
});
stub('interfaces/http/middlewares/check_user.js', (req, res, next) => {
    req.user = users.find((u) => u.id === Number(req.headers['x-me']));
    req.projectId = 1;
    next();
});
stub('infrastructure/external/blocks.js', { isBlockedBetween: async () => false });
stub('infrastructure/external/profiles.js', { profileCard: async (uuid) => ({ name: uuid, avatar: null }) });
stub('interfaces/http/middlewares/rate_limiter.js', { userLimiter: (req, res, next) => next() });
stub('infrastructure/sockets/dm_socket.js', { invalidateParticipants: () => {}, isOnline: () => false, clientKey: () => '' });

const router = require(path.join(src, 'interfaces/http/routes/dm_routes.js'));
const app = express();
app.use(express.json());
app.use('/chat/dm', router);
app.use((err, req, res, next) => res.status(500).json({ error: err.message }));

let server;
let port;
test.before(() => new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', () => {
        port = server.address().port;
        resolve();
    });
}));
test.after(() => server.close());
test.beforeEach(() => {
    convs = [];
    nextId = 1;
    createDelay = 0;
    users = [
        { id: 3041, uuid: 'a', name: 'a', avatar: null },
        { id: 3878, uuid: 'b', name: 'b', avatar: null },
        { id: 5, uuid: 'c', name: 'c', avatar: null },
    ];
});

const open = (me, peerId) => fetch(`http://127.0.0.1:${port}/chat/dm/conversations`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-me': String(me) },
    body: JSON.stringify({ peerId }),
}).then(async (r) => ({ status: r.status, body: await r.json() }));

test('a new chat gets the pair key; the other person opens the same one', async () => {
    const first = await open(3041, 3878);
    assert.strictEqual(first.status, 200);
    assert.strictEqual(convs[0].pairKey, '3041:3878');
    const again = await open(3878, 3041);
    assert.strictEqual(again.body.id, first.body.id);
    assert.strictEqual(convs.length, 1);
});

test('opened three times at once: one chat, no error', async () => {
    createDelay = 30;
    const all = await Promise.all([open(3041, 3878), open(3878, 3041), open(3041, 3878)]);
    assert.ok(all.every((r) => r.status === 200), JSON.stringify(all));
    assert.strictEqual(new Set(all.map((r) => r.body.id)).size, 1);
    assert.strictEqual(convs.length, 1);
});

test('a chat made before keys is found and given its key', async () => {
    convs.push({ id: 87, pairKey: null, users: [3041, 3878] });
    nextId = 100;
    const r = await open(3878, 3041);
    assert.strictEqual(r.body.id, '87');
    assert.strictEqual(convs[0].pairKey, '3041:3878');
    assert.strictEqual(convs.length, 1);
});

test('different people: different chats', async () => {
    await open(3041, 3878);
    await open(3041, 5);
    assert.deepStrictEqual(convs.map((c) => c.pairKey), ['3041:3878', '5:3041']);
});
