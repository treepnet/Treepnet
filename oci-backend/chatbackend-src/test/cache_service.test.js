// The in-process cache (cache_service.js).
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const { src } = require('./helpers');

const cache = require(path.join(src, 'infrastructure/cache/cache_service.js'));

test('keeps a value until it expires', async () => {
    await cache.set('a', '1', 60);
    assert.strictEqual(await cache.get('a'), '1');
    await cache.set('b', '2', -1);
    assert.strictEqual(await cache.get('b'), null);
});

test('stays bounded: the oldest go first', async () => {
    for (let i = 0; i < 6000; i++) await cache.set(`k${i}`, 'v', 60);
    assert.ok(cache.entries.size <= 5000);
    assert.strictEqual(await cache.get('k5999'), 'v');
    assert.strictEqual(await cache.get('k0'), null);
});

test('redis is not loaded', () => {
    assert.ok(!Object.keys(require.cache).some((k) => /[\\/]@?redis[\\/]/.test(k)));
});
