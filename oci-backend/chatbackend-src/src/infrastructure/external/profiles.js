const { db } = require('./blocks');

/**
 * Foydalanuvchining ilovadagi ismi (username) va avatari.
 *
 * Ilgari ularni ilova o'zi yuborardi (`x-name` / `x-avatar`, suhbat
 * ochilganda esa suhbatdoshniki - `peerName` / `peerAvatar`) va server
 * tekshirmay saqlardi: har kim push xabarlarda o'zini yoki boshqani istalgan
 * ism bilan ko'rsata olardi. Endi ular asosiy bazadagi profiles jadvalidan
 * olinadi - `chat_profile_card(id)` funksiyasi orqali, bloklar bilan bir xil
 * `chat_blocks_ro` ulanishida (oci-backend/sql/chat_profile_card.sql).
 *
 * Natija 10 daqiqa keshlanadi: username o'zgarsa, ko'pi bilan 10 daqiqada
 * yangilanadi. Baza javob bermasa `undefined` qaytadi (1 daqiqa eslab
 * qolinadi) va chaqiruvchi saqlangan qiymatga tegmaydi.
 */
const TTL_MS = 10 * 60 * 1000;
const FAILED_TTL_MS = 60 * 1000;
const cache = new Map(); // uuid -> { card, expiresAt }

/**
 * @returns {Promise<{name: string|null, avatar: string|null}|null|undefined>}
 *   `null` - bunday profil yo'q, `undefined` - so'rab bo'lmadi.
 */
async function profileCard(uuid) {
    if (!db || !uuid) return undefined;
    const hit = cache.get(uuid);
    if (hit && hit.expiresAt > Date.now()) return hit.card;
    let card;
    let ttl = TTL_MS;
    try {
        const rows = await db.$queryRaw`
            select username, avatar_url from public.chat_profile_card(${uuid}::uuid)`;
        const row = rows[0];
        card = row
            ? { name: row.username || null, avatar: row.avatar_url || null }
            : null;
    } catch (error) {
        console.error('[Profiles] lookup failed:', error.message);
        card = undefined;
        ttl = FAILED_TTL_MS;
    }
    if (cache.size > 10000) cache.clear();
    cache.set(uuid, { card, expiresAt: Date.now() + ttl });
    return card;
}

module.exports = { profileCard };
