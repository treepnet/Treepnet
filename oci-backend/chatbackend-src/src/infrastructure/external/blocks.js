const { PrismaClient } = require('@prisma/client');

/**
 * Ilovadagi bloklar.
 *
 * Bloklar asosiy (treepnet) bazada turadi, chat bazasida emas. Bu yerdan
 * faqat bitta savol so'raladi - `blocked_between(a, b)`: ikkalasidan biri
 * ikkinchisini bloklaganmi? Ulanish `chat_blocks_ro` roli bilan, u faqat shu
 * funksiyani chaqira oladi (oci-backend/sql/chat_blocks_ro.sql).
 *
 * Natija 1 daqiqa keshlanadi, shuning uchun har xabarda bazaga borilmaydi;
 * bloklash/blokdan chiqarish ko'pi bilan 1 daqiqada kuchga kiradi. Tekshiruv
 * ishlamay qolsa, chat to'xtamasligi uchun "bloklanmagan" deb olinadi va
 * xato logga yoziladi.
 */
const url = process.env.BLOCKS_DATABASE_URL;
const db = url ? new PrismaClient({ datasources: { db: { url } } }) : null;
if (!db) console.warn('[Blocks] BLOCKS_DATABASE_URL is not set - blocks are not checked');

const TTL_MS = 60 * 1000;
const cache = new Map(); // "a|b" -> { blocked, expiresAt }

async function isBlockedBetween(uuidA, uuidB) {
    if (!db || !uuidA || !uuidB || uuidA === uuidB) return false;
    const key = uuidA < uuidB ? `${uuidA}|${uuidB}` : `${uuidB}|${uuidA}`;
    const hit = cache.get(key);
    if (hit && hit.expiresAt > Date.now()) return hit.blocked;
    try {
        const rows = await db.$queryRaw`
            select public.blocked_between(${uuidA}::uuid, ${uuidB}::uuid) as blocked`;
        const blocked = rows[0]?.blocked === true;
        if (cache.size > 10000) cache.clear();
        cache.set(key, { blocked, expiresAt: Date.now() + TTL_MS });
        return blocked;
    } catch (error) {
        // Also remembered, so a bad id or a down database isn't asked again
        // on every message.
        console.error('[Blocks] check failed:', error.message);
        cache.set(key, { blocked: false, expiresAt: Date.now() + TTL_MS });
        return false;
    }
}

module.exports = { isBlockedBetween };
