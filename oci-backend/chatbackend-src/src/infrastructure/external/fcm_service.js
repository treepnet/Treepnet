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
    if (tokens.length === 0) return;

    const message = {
        tokens,
        notification: { title, body },
        data: data || {},
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
    };

    try {
        const res = await admin.messaging().sendEachForMulticast(message);
        const stale = [];
        res.responses.forEach((r, i) => {
            if (!r.success) {
                const code = r.error?.code || '';
                if (
                    code.includes('registration-token-not-registered') ||
                    code.includes('invalid-argument')
                ) {
                    stale.push(tokens[i]);
                }
            }
        });
        if (stale.length) {
            await prisma.deviceToken.deleteMany({ where: { token: { in: stale } } });
        }
    } catch (e) {
        console.error('[FCM] send xatosi:', e.message);
    }
}

module.exports = { init, sendToUser };
