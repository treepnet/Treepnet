const fs = require('fs');
const admin = require('firebase-admin');

/**
 * Yagona Firebase Admin ilovasi - push (FCM) ham, kirish tokenlarini
 * tekshirish ham shuni ishlatadi. `initializeApp` faqat bir marta chaqirilishi
 * mumkin, shuning uchun u shu yerda turadi.
 *
 * Servis-akkaunt fayli topilmasa `null` qaytadi.
 */
let tried = false;
let app = null;

function getFirebaseApp() {
    if (tried) return app;
    tried = true;

    const path =
        process.env.FCM_SERVICE_ACCOUNT || '/app/fcm-service-account.json';
    if (!fs.existsSync(path)) {
        console.warn('[Firebase] service account topilmadi:', path);
        return null;
    }
    try {
        const serviceAccount = JSON.parse(fs.readFileSync(path, 'utf8'));
        app = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
        console.log('[Firebase] ishga tushdi (project:', serviceAccount.project_id, ')');
    } catch (e) {
        console.error('[Firebase] init xatosi:', e.message);
    }
    return app;
}

module.exports = { getFirebaseApp };
