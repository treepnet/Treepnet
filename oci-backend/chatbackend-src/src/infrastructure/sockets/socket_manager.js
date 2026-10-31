const { Server } = require('socket.io');
const authUserUseCase = require('../../application/use-cases/auth_user');
const { resolveIdentity, bearerToken } = require('../../application/use-cases/resolve_identity');
const { CORS_ORIGIN } = require('../config/constants');
const Logger = require('../utils/logger');

/**
 * Messenger uchun socket qatlami.
 *
 * Vazifasi ikkitagina: ulangan mijozni autentifikatsiya qilish va DM
 * hodisalarini ro'yxatga olish. Xabar mantig'i `dm_socket.js` da.
 */
class SocketManager {
    constructor() {
        this.io = null;
    }

    init(server) {
        this.io = new Server(server, {
            cors: { origin: CORS_ORIGIN, methods: ['GET', 'POST'] },
            maxHttpBufferSize: 1e8,
        });

        this.io.on('connection', (socket) => this.handleConnection(socket));

        Logger.info?.('SocketManager ishga tushdi');
        return this.io;
    }

    handleConnection(socket) {
        const headers = socket.handshake.headers;
        const apiKey = headers['x-app-key'];
        const appName = headers['x-app'] || 'messenger';
        const token =
            (typeof socket.handshake.auth?.token === 'string' && socket.handshake.auth.token) ||
            bearerToken(headers.authorization);
        const headerUuid = headers['x-uuid'] || null;

        if (!token && !headerUuid) {
            socket.disconnect();
            return;
        }

        // MUHIM: autentifikatsiyani `await` qilmaymiz.
        //
        // Aks holda hodisa ishlovchilari faqat u tugagach ro'yxatga olinardi
        // va klient ulanib darrov xabar yuborsa, o'sha xabar hech qanday
        // xatosiz yo'qolardi. Ishlovchilar darhol ro'yxatga olinadi, ular esa
        // ish boshlashdan oldin `socket.authReady` ni kutadi.
        //
        // Token yaroqsiz yoki muddati o'tgan bo'lsa, ulanishni uzishdan oldin
        // `dm.authError` yuboriladi: server uzgan socket o'zi qayta ulanmaydi,
        // shuning uchun ilova tokenni yangilab, o'zi qayta ulanadi.
        socket.authReady = resolveIdentity({ token, headerUuid })
            .then((uuid) =>
                authUserUseCase
                    .execute({
                        uuid,
                        apiKey,
                        appName,
                        deviceData: this.getDeviceData(headers),
                    })
                    .then(({ user, project }) => {
                        socket.uuid = uuid;
                        socket.userId = user.id;
                        socket.projectId = project.id;
                        return true;
                    }),
            )
            .catch((error) => {
                console.error('[Socket Auth Failure]', error.message);
                if (error.code) socket.emit('dm.authError', { code: error.code });
                socket.disconnect();
                return false;
            });

        require('./dm_socket').register(this.io, socket);
    }

    getDeviceData(headers) {
        return {
            appName: headers['x-app'] || 'messenger',
            appVersion: headers['x-app-version'] || 'unknown',
            packageVersion: headers['x-package-version'] || 'unknown',
            deviceId: headers['x-device-id'] || 'unknown',
            deviceName: headers['x-device-name'] || 'unknown',
            deviceType: headers['x-device-type'] || 'mobile',
            osVersion: headers['x-os-version'] || 'unknown',
            lang: headers['x-lang'] || 'uz',
            phone: headers['x-phone'] || null,
            email: headers['x-email'] || null,
            ipAddress:
                headers['x-forwarded-for']?.split(',')[0] || undefined,
        };
    }

    /** Belgilangan xonaga hodisa yuboradi. */
    toRoom(room, event, data) {
        this.io?.to(room).emit(event, data);
    }
}

module.exports = new SocketManager();
