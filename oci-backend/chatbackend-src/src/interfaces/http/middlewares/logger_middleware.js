const Logger = require('../../../infrastructure/utils/logger');

/**
 * HTTP Logger Middleware
 * Har bir so'rovning metodini, yo'lini, javob statusini va qancha vaqt davom etganini log qiladi.
 */
const loggerMiddleware = (req, res, next) => {
    const start = Date.now();
    const { method, url } = req;

    // So'rov tugagach (javob yuborilgach) ishlaydi
    res.on('finish', () => {
        const duration = Date.now() - start;
        const status = res.statusCode;

        // A passing health check (Docker's, every 30 s, and the monitors')
        // is not logged: it was most of the log. A failing one is.
        if (status === 200 && url.startsWith('/health')) return;
        Logger.http(method, url, status, duration);
    });

    next();
};

module.exports = loggerMiddleware;
