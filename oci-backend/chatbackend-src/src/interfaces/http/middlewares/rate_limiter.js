const rateLimit = require('express-rate-limit');

const isDev = process.env.NODE_ENV === 'development' || process.env.APP_ENV === 'local';

// Every request, by address: only a guard against floods, so it is wide.
// Mobile operators put many subscribers behind one address (CGNAT), and at
// 2000 (counted twice per request, once here and once per route) a few dozen
// people on one network locked each other out of chat.
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: isDev ? 100000 : 10000,
    skip: (req, res) => isDev,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Too many requests from this IP, please try again after 15 minutes',
        code: 'TOO_MANY_REQUESTS'
    }
});

// A signed-in user's own budget, after checkUser: people sharing an address
// don't use up each other's.
const userLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: isDev ? 100000 : 1000,
    skip: (req, res) => isDev,
    keyGenerator: (req) => `user:${req.user.id}`,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Too many requests, please try again after 15 minutes',
        code: 'TOO_MANY_REQUESTS'
    }
});

module.exports = { apiLimiter, userLimiter };
