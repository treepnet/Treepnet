const admin = require('firebase-admin');
const prisma = require('../database/prisma');
const { getFirebaseApp } = require('./firebase_app');

/**
 * FCM (push) xizmati. Servis-akkaunt fayli topilmasa - push jimgina o'chadi
 * (backend baribir ishlayveradi).
 */
let initialized = false;
let enabled = false;

/**
 * Bir soatlik hisob: nechta push yetdi va qaysi xatolar bilan qaytdi. Har bir
 * yuborish o'z qatorida bor edi, lekin umumiy holat (masalan Apple kaliti
 * eskirib, iOS pushlarining hammasi qaytayotgani) hech qayerda ko'rinmasdi.
 * Soatda bir marta, bo'lsa, logga yoziladi ([Auth] hisobidek).
 */
const hourly = { sent: 0, failed: new Map(), errors: 0 };
setInterval(() => {
    const failed = [...hourly.failed.values()].reduce((a, b) => a + b, 0);
    if (hourly.sent || failed || hourly.errors) {
        const codes = [...hourly.failed].map(([code, n]) => `${code} ×${n}`).join(', ');
        console.log(
            `[FCM] oxirgi soatda: ${hourly.sent} ta yetdi, ${failed} ta xato` +
            (codes ? ` (${codes})` : '') +
            (hourly.errors ? `; ${hourly.errors} marta FCM'ga yuborib bo'lmadi` : ''),
        );
    }
    hourly.sent = 0;
    hourly.failed.clear();
    hourly.errors = 0;
}, 60 * 60 * 1000).unref();

function init() {
    if (initialized) return enabled;
    initialized = true;

    enabled = getFirebaseApp() != null;
    if (!enabled) console.warn('[FCM] push o\'chirilgan');
    return enabled;
}

/**
 * Foydalanuvchining barcha qurilma tokenlariga push yuboradi. FCM
 * "yaroqsiz token" desa - o'sha tokenni bazadan o'chiradi.
 */
async function sendToUser(userId, { title, body, data }) {
    if (!init()) return;

    const rows = await prisma.deviceToken.findMany({ where: { userId } });
    const tokens = rows.map((t) => t.token);
    if (tokens.length === 0) {
        console.log(`[FCM] user ${userId}: qurilma tokeni yo'q, push yuborilmadi`);
        return;
    }

    // Bitta suhbatning pushlari birga turadi: Android'da yangisi oldingisining
    // o'rnini egallaydi (tag), iOS'da bir guruhga yig'iladi (thread-id).
    // Har bir xabar alohida qatorda turardi. Boshqa suhbatlarniki bir-birini
    // yashirmaydi. 7 kundan eski xabar pushi endi yetkazilmaydi (FCM aks holda
    // 4 hafta saqlaydi va uzoq oflayn bo'lgan telefonga eski pushlar keladi).
    const thread = data && data.conversationId ? `dm-${data.conversationId}` : null;
    const ttlSeconds = 7 * 24 * 3600;
    const message = {
        tokens,
        notification: { title, body },
        data: data || {},
        android: {
            priority: 'high',
            ttl: ttlSeconds * 1000,
            notification: { sound: 'default', ...(thread && { tag: thread }) },
        },
        // iOS: darhol yetkazish. apns-priority 10 bo'lmasa APNs pushni
        // to'plab, bir soatgacha kechiktirishi mumkin (push-worker bilan bir xil).
        apns: {
            headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
                'apns-expiration': String(Math.floor(Date.now() / 1000) + ttlSeconds),
            },
            payload: { aps: { sound: 'default', ...(thread && { threadId: thread }) } },
        },
    };

    try {
        const res = await admin.messaging().sendEachForMulticast(message);
        hourly.sent += res.successCount;
        const stale = [];
        const failures = [];
        res.responses.forEach((r, i) => {
            if (!r.success) {
                const code = r.error?.code || '';
                failures.push(code || 'unknown');
                hourly.failed.set(code || 'unknown', (hourly.failed.get(code || 'unknown') || 0) + 1);
                // Boshqa Firebase loyihasining tokeni ham o'lik.
                if (
                    code.includes('registration-token-not-registered') ||
                    code.includes('invalid-argument') ||
                    code.includes('mismatched-credential')
                ) {
                    stale.push(tokens[i]);
                }
            }
        });
        // Push nima uchun kelmaganini taxmin qilmaslik uchun (token va matn
        // yozilmaydi).
        console.log(
            `[FCM] user ${userId}: ${res.successCount}/${tokens.length} yuborildi` +
            (failures.length ? ` (xatolar: ${failures.join(', ')})` : ''),
        );
        if (stale.length) {
            await prisma.deviceToken.deleteMany({ where: { token: { in: stale } } });
        }
    } catch (e) {
        hourly.errors += 1;
        console.error('[FCM] send xatosi:', e.message);
    }
}

module.exports = { init, sendToUser };
