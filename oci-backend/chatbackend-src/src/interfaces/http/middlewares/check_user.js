const authUserUseCase = require('../../../application/use-cases/auth_user');
const { resolveIdentity, bearerToken } = require('../../../application/use-cases/resolve_identity');

const checkUserMiddleware = async (req, res, next) => {
    const apiKey = req.headers['x-app-key'];
    const appName = req.headers['x-app'] || 'unknown';

    let uuid;
    try {
        uuid = await resolveIdentity({
            token: bearerToken(req.headers.authorization),
            headerUuid: req.headers['x-uuid'] || null,
        });
    } catch (err) {
        return res.status(err.status || 401).json({ error: err.message, code: err.code });
    }

    const deviceName = req.headers['x-device-name'];
    if (!deviceName || deviceName === 'unknown') {
        return res.status(400).json({ error: 'Missing or invalid x-device-name header. This field is mandatory for integration.' });
    }

    try {
        const deviceData = {
            appName,
            appVersion: req.headers['x-app-version'] || 'unknown',
            packageVersion: req.headers['x-package-version'] || 'unknown',
            deviceId: req.headers['x-device-id'] || 'unknown',
            deviceName,
            deviceType: req.headers['x-device-type'] || 'mobile',
            osVersion: req.headers['x-os-version'] || 'unknown',
            lang: req.headers['x-lang'] || 'uz',
            phone: req.headers['x-phone'] || null,
            email: req.headers['x-email'] || null,
            avatar: req.headers['x-avatar'] || null,
            ipAddress: req.headers['x-forwarded-for']?.split(',')[0] || req.socket.remoteAddress
        };

        const { user, project } = await authUserUseCase.execute({
            uuid,
            apiKey,
            appName,
            name: req.headers['x-name'] || null,
            deviceData
        });

        req.user = user;
        req.projectId = project.id;
        next();
    } catch (err) {
        res.status(err.status || 500).json({ error: err.message || 'Server error' });
    }
};

module.exports = checkUserMiddleware;
