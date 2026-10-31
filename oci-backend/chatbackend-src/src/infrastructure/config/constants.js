/**
 * Muhit sozlamalari.
 *
 * Muhim qiymatlar yo'q bo'lsa server ishga tushmaydi - noto'g'ri sozlangan
 * holda jimgina ishlab ketgandan ko'ra darhol to'xtagani yaxshi.
 */
const requiredEnv = (name) => {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Environment variable ${name} is required but not set`);
    }
    return value;
};

const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';
const UPLOAD_DIR = process.env.UPLOAD_DIR || 'uploads';

const DATABASE_URL = requiredEnv('DATABASE_URL');
const CORS_ORIGIN = requiredEnv('CORS_ORIGIN');

module.exports = {
    PORT,
    DATABASE_URL,
    NODE_ENV,
    UPLOAD_DIR,
    CORS_ORIGIN,
};
