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
const cacheService = require('./src/infrastructure/cache/cache_service');
const loggerMiddleware = require('./src/interfaces/http/middlewares/logger_middleware');
const { apiLimiter } = require('./src/interfaces/http/middlewares/rate_limiter');

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

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use((err, req, res, next) => {
    console.error('[GlobalError]', err.stack);
    res.status(err.status || 500).json({
        error: err.message || 'Internal Server Error',
        code: err.code || 'INTERNAL_ERROR',
    });
});

server.listen(PORT, () => {
    console.log(`Messenger backend ${PORT}-portda ishlamoqda`);
});
