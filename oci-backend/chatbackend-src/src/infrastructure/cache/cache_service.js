/**
 * Server ichidagi kichik kesh (muddatli kalit -> qiymat).
 *
 * Avval bu Redis edi, lekin serverda Redis yo'q: har bir `get` null
 * qaytarardi, kesh hech narsani saqlamasdi, fonda esa node-redis
 * localhost:6379 ga to'xtovsiz qayta ulanishga urinib turardi (xatolari
 * yashirilgan). Bitta jarayon uchun shu yetarli: blocks.js va profiles.js ham
 * shunday ishlaydi.
 *
 * Interfeys o'zgarmadi (async get/set), shuning uchun chaqiruvchilar
 * tegilmaydi.
 */
const MAX_ENTRIES = 5000;

class CacheService {
    constructor() {
        this.entries = new Map(); // key -> { value, expiresAt }
    }

    /** Eski chaqiruv uchun (index.js): ulanadigan narsa yo'q. */
    async connect() {}

    async get(key) {
        const entry = this.entries.get(key);
        if (!entry) return null;
        if (entry.expiresAt <= Date.now()) {
            this.entries.delete(key);
            return null;
        }
        return entry.value;
    }

    async set(key, value, ttl = 300) {
        this.entries.delete(key);
        this.entries.set(key, { value, expiresAt: Date.now() + ttl * 1000 });
        // Eng eskisi (birinchi qo'yilgani) chiqariladi.
        while (this.entries.size > MAX_ENTRIES) {
            this.entries.delete(this.entries.keys().next().value);
        }
    }
}

module.exports = new CacheService();
