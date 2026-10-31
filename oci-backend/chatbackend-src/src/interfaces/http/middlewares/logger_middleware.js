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

        // Logger utilitini chaqiramiz
        Logger.http(method, url, status, duration);
    });

    next();
};

module.exports = loggerMiddleware;
