// A new message's push: its words in the recipient's app language.
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const { src, stub } = require('./helpers');

let cards;
stub('infrastructure/database/prisma.js', {});
stub('infrastructure/external/blocks.js', { isBlockedBetween: async () => false });
stub('infrastructure/external/fcm_service.js', { sendToUser: async () => {} });
stub('infrastructure/external/profiles.js', { profileCard: async (uuid) => cards[uuid] });

const { pushText, recipientLang } = require(path.join(src, 'infrastructure/sockets/dm_socket.js'));

test('the language comes from the app profile, not the connection header', async () => {
    cards = { a: { name: 'a', avatar: null, lang: 'ru' } };
    assert.strictEqual(await recipientLang({ uuid: 'a', lang: 'uz' }), 'ru');
});

test('a profile without a language (an old build) falls back to the header', async () => {
    cards = { a: { name: 'a', avatar: null, lang: null }, b: undefined };
    assert.strictEqual(await recipientLang({ uuid: 'a', lang: 'ru' }), 'ru');
    // The profile database didn't answer: the header too.
    assert.strictEqual(await recipientLang({ uuid: 'b', lang: 'en' }), 'en');
    assert.strictEqual(await recipientLang(null), undefined);
});

test('shares and media are labelled in Russian for a Russian recipient', () => {
    const sender = { name: 'ali' };
    const post = pushText({ lang: 'ru', sender, contentType: 'text', content: 'treepnet:share:post:1' });
    assert.deepStrictEqual(post, { title: 'ali', body: '📷 Пост' });
    const story = pushText({ lang: 'ru', sender, contentType: 'text', content: 'treepnet:share:story:1' });
    assert.strictEqual(story.body, '📖 История');
    assert.strictEqual(pushText({ lang: 'ru', sender: null, contentType: 'photo', content: '' }).title, 'Новое сообщение');
});

test('anything else is English; text goes as it is', () => {
    const sender = { name: 'ali' };
    assert.strictEqual(pushText({ lang: 'uz', sender, contentType: 'text', content: 'treepnet:share:post:1' }).body, '📷 Post');
    assert.strictEqual(pushText({ lang: 'en', sender, contentType: 'text', content: 'salom' }).body, 'salom');
});
