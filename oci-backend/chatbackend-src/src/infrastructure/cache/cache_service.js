const redis = require('redis');

class CacheService {
    constructor() {
        this.client = redis.createClient({
            url: process.env.REDIS_URL || 'redis://localhost:6379'
        });
        this.client.on('error', (err) => {
            if (this.isConnected) {
                console.log('Redis Client Error', err);
            }
        });
        this.isConnected = false;
    }

    async connect() {
        if (!this.isConnected) {
            try {
                await this.client.connect();
                this.isConnected = true;
                console.log('Redis connected successfully');
            } catch (e) {
                // Connection failed, we will work without cache
                this.isConnected = false;
            }
        }
    }

    async get(key) {
        if (!this.isConnected) return null;
        return await this.client.get(key);
    }

    async set(key, value, ttl = 300) {
        if (!this.isConnected) return;
        await this.client.set(key, value, {
            EX: ttl
        });
    }

    /**
     * Bitta yoki bir nechta kalitni o'chiradi.
     *
     * Sozlama o'zgarganda keshni tozalash uchun kerak - aks holda eski qiymat
     * TTL tugaguncha (1 soatgacha) ishlatilib turadi.
     */
    async del(...keys) {
        if (!this.isConnected || keys.length === 0) return;
        try {
            await this.client.del(keys.flat());
        } catch (e) {
            console.warn('[Cache] del failed:', e.message);
        }
    }

    /**
     * Namunaga mos kalitlarni o'chiradi (masalan `project:*`).
     *
     * `SCAN` ishlatiladi - `KEYS` katta bazada serverni bloklaydi.
     */
    async delByPattern(pattern) {
        if (!this.isConnected) return;
        try {
            for await (const key of this.client.scanIterator({ MATCH: pattern, COUNT: 100 })) {
                await this.client.del(key);
            }
        } catch (e) {
            console.warn('[Cache] delByPattern failed:', e.message);
        }
    }
}

module.exports = new CacheService();
