// Editing and deleting a message (dm.edit / dm.delete in dm_socket.js).
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const { src, stub } = require('./helpers');

let messages;
let blocked;
const pick = (where) => messages.filter((m) =>
    (where.conversationId == null || m.conversationId === where.conversationId) &&
    (where.replyToId == null || m.replyToId === where.replyToId) &&
    (where.isDeleted == null || m.isDeleted === where.isDeleted) &&
    (where.id?.in == null || where.id.in.includes(m.id)));
stub('infrastructure/database/prisma.js', {
    directMessage: {
        findUnique: async ({ where }) => messages.find((m) => m.id === where.id) || null,
        update: async ({ where, data }) => Object.assign(messages.find((m) => m.id === where.id), data),
        findMany: async ({ where }) => pick(where),
        updateMany: async ({ where, data }) => {
            const rows = pick(where);
            rows.forEach((m) => Object.assign(m, data));
            return { count: rows.length };
        },
    },
    conversationParticipant: {
        findMany: async () => [{ userId: 1 }, { userId: 2 }],
    },
    user: { findUnique: async ({ where }) => ({ uuid: `u${where.id}` }) },
});
stub('infrastructure/external/blocks.js', { isBlockedBetween: async () => blocked });
stub('infrastructure/external/fcm_service.js', { sendToUser: async () => {} });

const { register } = require(path.join(src, 'infrastructure/sockets/dm_socket.js'));

function connect() {
    const handlers = {};
    const emitted = [];
    const io = { to: (room) => ({ emit: (event, dto) => emitted.push({ room, event, dto }) }) };
    const socket = {
        userId: 1, uuid: 'u1', authReady: Promise.resolve(true), disconnected: false,
        on: (event, fn) => { handlers[event] = fn; },
        join: () => {},
    };
    register(io, socket);
    const call = (event, data) => new Promise((resolve) => handlers[event](data, resolve));
    return { call, emitted };
}

test.beforeEach(() => {
    blocked = false;
    messages = [
        { id: 10, conversationId: 5, senderId: 1, content: 'secret plan', isDeleted: false, isEdited: false, date: new Date() },
        { id: 11, conversationId: 5, senderId: 2, content: 'ok', replyToId: '10', replyToContent: 'secret plan', isDeleted: false, date: new Date() },
        { id: 12, conversationId: 5, senderId: 2, content: 'sure', replyToId: '10', replyToContent: 'secret plan', isDeleted: false, date: new Date() },
        { id: 13, conversationId: 6, senderId: 3, content: 'elsewhere', replyToId: '10', replyToContent: 'secret plan', isDeleted: false, date: new Date() },
    ];
});

test('a deleted message leaves no text in the replies quoting it', async () => {
    const { call, emitted } = connect();
    const r = await call('dm.delete', { messageId: 10 });
    assert.strictEqual(r.status, 'ok');
    await new Promise((resolve) => setImmediate(resolve));
    assert.strictEqual(messages[1].replyToContent, '');
    assert.strictEqual(messages[2].replyToContent, '');
    assert.strictEqual(messages[3].replyToContent, 'secret plan', 'another conversation is not touched');
    const refreshed = emitted.filter((e) => e.event === 'dm.messageEdited').map((e) => e.dto.id);
    assert.deepStrictEqual([...new Set(refreshed)].sort(), ['11', '12'], 'open chats get the replies again');
});

test('an edit updates the quotes', async () => {
    const { call } = connect();
    const r = await call('dm.edit', { messageId: 10, content: 'new plan' });
    assert.strictEqual(r.status, 'ok');
    await new Promise((resolve) => setImmediate(resolve));
    assert.strictEqual(messages[0].content, 'new plan');
    assert.strictEqual(messages[1].replyToContent, 'new plan');
});

test('blocked: an edit is refused, a delete still works', async () => {
    blocked = true;
    const { call } = connect();
    const edit = await call('dm.edit', { messageId: 10, content: 'rewritten' });
    assert.strictEqual(edit.code, 'BLOCKED');
    assert.strictEqual(messages[0].content, 'secret plan');
    const del = await call('dm.delete', { messageId: 10 });
    assert.strictEqual(del.status, 'ok');
});
