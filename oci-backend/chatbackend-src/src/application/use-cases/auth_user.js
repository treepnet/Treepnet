const userRepository = require('../../infrastructure/repositories/user_repository');
const cacheService = require('../../infrastructure/cache/cache_service');
const { profileCard } = require('../../infrastructure/external/profiles');

/**
 * Mijozni sarlavhalar asosida tanib oladi.
 *
 * Messenger'da alohida ro'yxatdan o'tish yo'q: ilova `x-uuid` va loyiha
 * kalitini yuboradi, foydalanuvchi shu asosda yaratiladi yoki yangilanadi.
 */
class AuthUserUseCase {
    async execute(params) {
        const { uuid, apiKey, appName, deviceData } = params;

        // 1. Loyiha (kesh bilan)
        const projectCacheKey = apiKey
            ? `project:key:${apiKey}`
            : `project:name:${appName}`;

        let project;
        const cached = await cacheService.get(projectCacheKey);
        if (cached) {
            project = JSON.parse(cached);
        } else {
            project = apiKey
                ? await userRepository.findByApiKey(apiKey)
                : await userRepository.findByProjectName(appName);
            if (project) {
                await cacheService.set(projectCacheKey, JSON.stringify(project), 3600);
            }
        }

        if (!project) throw { status: 403, message: 'Invalid Project' };

        // 2. Foydalanuvchi keshi
        const userCacheKey = `user:${project.id}:${uuid}`;
        const cachedUser = await cacheService.get(userCacheKey);
        if (cachedUser) {
            return { user: JSON.parse(cachedUser), project };
        }

        // 3. Yaratish/yangilash
        //
        // Telefon va email faqat yangi qiymat kelganda yoziladi: socket
        // orqali ulanishda ular yuborilmaydi va aks holda mavjud qiymat null
        // bilan o'chib ketardi.
        //
        // Ism va avatar esa ilovadan olinmaydi (`x-name` / `x-avatar` e'tiborsiz
        // qoldiriladi): ular profiles jadvalidan keladi, aks holda har kim
        // push xabarlarda o'zini boshqa ism bilan ko'rsata olardi. Profilni
        // so'rab bo'lmasa, saqlangan qiymat o'zgarmaydi.
        const optional = {
            phone: deviceData.phone,
            email: deviceData.email,
        };

        const userData = { ...deviceData };
        delete userData.phone;
        delete userData.email;
        delete userData.avatar;

        for (const [field, value] of Object.entries(optional)) {
            if (value !== undefined && value !== null && value !== '') {
                userData[field] = value;
            }
        }

        const card = await profileCard(uuid);
        if (card) {
            userData.name = card.name;
            userData.avatar = card.avatar;
        }

        const user = await userRepository.upsertUser(uuid, project.id, userData);

        await cacheService.set(userCacheKey, JSON.stringify(user), 600);

        return { user, project };
    }
}

module.exports = new AuthUserUseCase();
