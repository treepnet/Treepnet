const rateLimit = require('express-rate-limit');

const isDev = process.env.NODE_ENV === 'development' || process.env.APP_ENV === 'local';

const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: isDev ? 100000 : 2000, // Very high for dev, reasonable for prod
    skip: (req, res) => isDev, // Completely skip in development if you prefer
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Too many requests from this IP, please try again after 15 minutes',
        code: 'TOO_MANY_REQUESTS'
    }
});

const socketLimiter = (socket, next) => {
    // Simple socket-level rate limiting can be implemented here if needed
    next();
};

module.exports = { apiLimiter, socketLimiter };
