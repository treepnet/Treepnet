const path = require('path');

// Muhit fayli APP_ENV / NODE_ENV ga qarab tanlanadi.
const appEnv = process.env.APP_ENV || process.env.NODE_ENV || 'local';
const envFile =
    appEnv === 'production' || appEnv === 'prod' ? '.env.production' : '.env.local';
require('dotenv').config({ path: path.join(__dirname, envFile) });

const express = require('express');
const http = require('http');
const helmet = require('helmet');
const cors = require('cors');

const { PORT, CORS_ORIGIN } = require('./src/infrastructure/config/constants');
const socketManager = require('./src/infrastructure/sockets/socket_manager');
const prisma = require('./src/infrastructure/database/prisma');
const cacheService = require('./src/infrastructure/cache/cache_service');
const loggerMiddleware = require('./src/interfaces/http/middlewares/logger_middleware');
const { apiLimiter } = require('./src/interfaces/http/middlewares/rate_limiter');

// Biror joyda ushlanmagan xato butun chat jarayonini (va hamma ulanishlarni)
// to'xtatmasin: logga yoziladi, server ishlashda davom etadi.
process.on('unhandledRejection', (reason) => {
    console.error('[unhandledRejection]', reason);
});

const app = express();
// Behind Caddy (one proxy hop): take the client's address from
// X-Forwarded-For. Without this every request came from Caddy's address, so
// all users shared one rate-limit allowance — a busy hour (or one abuser)
// locked everyone out of chat.
app.set('trust proxy', 1);
const server = http.createServer(app);

app.use(loggerMiddleware);

// Xavfsizlik
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: CORS_ORIGIN }));
// Chat is text only (no uploads): a message is at most 8000 characters.
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.use(apiLimiter);

cacheService.connect();
socketManager.init(server);

// Yagona API - messenger (user <-> user)
app.use('/chat/dm', require('./src/interfaces/http/routes/dm_routes'));

// Asks the database (a second at most): it said "ok" with Postgres down, so
// neither Docker's check nor the monitors saw chat failing.
app.get('/health', async (req, res) => {
    let timer;
    try {
        await Promise.race([
            prisma.$queryRaw`SELECT 1`,
            new Promise((_, reject) => {
                timer = setTimeout(() => reject(new Error('timeout')), 1000);
            }),
        ]);
        res.json({ status: 'ok' });
    } catch (e) {
        res.status(503).json({ status: 'database_unavailable' });
    } finally {
        clearTimeout(timer);
    }
});

app.use((err, req, res, next) => {
    console.error('[GlobalError]', err.stack);
    const status = err.status || 500;
    // A server error's own message (Prisma's includes file paths) stays in
    // the log above; the client gets a plain one.
    res.status(status).json({
        error: status < 500 ? err.message || 'Bad request' : 'Internal Server Error',
        code: err.code || 'INTERNAL_ERROR',
    });
});

server.listen(PORT, () => {
    console.log(`Messenger backend ${PORT}-portda ishlamoqda`);
});

// A stop (a deploy): sockets are closed (the app reconnects to the new
// container), no new connections are taken, the database is let go. Eight
// seconds at most, inside Docker's ten.
let stopping = false;
function shutdown(signal) {
    if (stopping) return;
    stopping = true;
    console.log(`[${signal}] to'xtatilmoqda`);
    setTimeout(() => process.exit(0), 8000).unref();
    const io = socketManager.io;
    new Promise((resolve) => (io ? io.close(() => resolve()) : server.close(() => resolve())))
        .finally(() => prisma.$disconnect())
        .finally(() => process.exit(0));
    server.closeIdleConnections?.();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
