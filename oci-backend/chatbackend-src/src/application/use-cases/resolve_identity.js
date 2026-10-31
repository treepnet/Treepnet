const admin = require('firebase-admin');
const { getFirebaseApp } = require('../../infrastructure/external/firebase_app');

/**
 * Mijoz kimligini aniqlaydi.
 *
 * Ilova Firebase ID tokenini yuboradi (HTTP: `Authorization: Bearer ...`,
 * socket: `auth.token`). Token imzosi va muddati tekshiriladi, foydalanuvchi
 * esa tokendagi `uid` dan olinadi - ilova o'zi aytgan `x-uuid` ga endi
 * ishonilmaydi. `x-uuid` ham kelsa, u tokendagi bilan bir xil bo'lishi shart.
 *
 * O'tish davri: tokenni yubormaydigan eski ilova versiyalari hali bor.
 * `CHAT_AUTH_REQUIRED=true` bo'lmaguncha tokensiz so'rov eski usulda
 * (`x-uuid` bo'yicha) o'tadi. Ko'pchilik yangilangach o'zgaruvchi yoqiladi va
 * tokensiz so'rovlar rad etiladi. Qachon yoqish mumkinligini bilish uchun har
 * soatda nechta eski va yangi mijoz kelgani logga yoziladi.
 */
const REQUIRED = process.env.CHAT_AUTH_REQUIRED === 'true';

const stats = { token: new Set(), legacy: new Set() };
setInterval(() => {
    if (stats.token.size || stats.legacy.size) {
        console.log(
            `[Auth] oxirgi soatda: token bilan ${stats.token.size} ta, ` +
            `eski usulda ${stats.legacy.size} ta foydalanuvchi` +
            (REQUIRED ? ' (token majburiy)' : ''),
        );
    }
    stats.token.clear();
    stats.legacy.clear();
}, 60 * 60 * 1000).unref();

/** `Authorization: Bearer <token>` sarlavhasidan tokenni ajratadi. */
function bearerToken(header) {
    if (typeof header !== 'string') return null;
    const match = header.match(/^Bearer\s+(.+)$/i);
    return match ? match[1].trim() : null;
}

async function verify(token) {
    const app = getFirebaseApp();
    if (!app) {
        throw { status: 503, code: 'AUTH_UNAVAILABLE', message: 'Auth unavailable' };
    }
    try {
        const decoded = await admin.auth(app).verifyIdToken(token);
        return decoded.uid;
    } catch (_) {
        throw { status: 401, code: 'TOKEN_INVALID', message: 'Invalid or expired token' };
    }
}

/**
 * @param {{ token?: string|null, headerUuid?: string|null }} params
 * @returns {Promise<string>} foydalanuvchining uuid si
 */
async function resolveIdentity({ token, headerUuid }) {
    if (token) {
        const uid = await verify(token);
        if (headerUuid && headerUuid !== uid) {
            throw { status: 403, code: 'IDENTITY_MISMATCH', message: 'x-uuid does not match the token' };
        }
        stats.token.add(uid);
        return uid;
    }

    if (REQUIRED) {
        throw { status: 401, code: 'TOKEN_REQUIRED', message: 'Missing bearer token' };
    }
    if (!headerUuid) {
        throw { status: 401, code: 'MISSING_UUID', message: 'Missing x-uuid header' };
    }
    stats.legacy.add(headerUuid);
    return headerUuid;
}

module.exports = { resolveIdentity, bearerToken };
