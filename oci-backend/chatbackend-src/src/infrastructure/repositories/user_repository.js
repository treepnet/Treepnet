const prisma = require('../database/prisma');

class UserRepository {
    findByApiKey(apiKey) {
        return prisma.project.findUnique({ where: { apiKey } });
    }

    findByProjectName(name) {
        return prisma.project.findUnique({ where: { name } });
    }

    findById(id) {
        return prisma.user.findUnique({ where: { id } });
    }

    upsertUser(uuid, projectId, userData) {
        return prisma.user.upsert({
            where: { uuid_projectId: { uuid, projectId } },
            update: { ...userData, updatedAt: new Date() },
            create: { uuid, projectId, ...userData },
        });
    }
}

module.exports = new UserRepository();
