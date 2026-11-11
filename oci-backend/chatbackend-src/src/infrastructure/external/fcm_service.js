const admin = require('firebase-admin');
const prisma = require('../database/prisma');
const { getFirebaseApp } = require('./firebase_app');

/**
 * FCM (push) xizmati. Servis-akkaunt fayli topilmasa - push jimgina o'chadi
 * (backend baribir ishlayveradi).
 */
let initialized = false;
let enabled = false;

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

    const message = {
        tokens,
        notification: { title, body },
        data: data || {},
        android: { priority: 'high', notification: { sound: 'default' } },
        // iOS: darhol yetkazish. apns-priority 10 bo'lmasa APNs pushni
        // to'plab, bir soatgacha kechiktirishi mumkin (push-worker bilan bir xil).
        apns: {
            headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
            payload: { aps: { sound: 'default' } },
        },
    };

    try {
        const res = await admin.messaging().sendEachForMulticast(message);
        const stale = [];
        const failures = [];
        res.responses.forEach((r, i) => {
            if (!r.success) {
                const code = r.error?.code || '';
                failures.push(code || 'unknown');
                if (
                    code.includes('registration-token-not-registered') ||
                    code.includes('invalid-argument')
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
        console.error('[FCM] send xatosi:', e.message);
    }
}

module.exports = { init, sendToUser };
