const express = require('express');

const prisma = require('../../../infrastructure/database/prisma');
const checkUser = require('../middlewares/check_user');
const { isBlockedBetween } = require('../../../infrastructure/external/blocks');
const { profileCard } = require('../../../infrastructure/external/profiles');
const { apiLimiter } = require('../middlewares/rate_limiter');

const router = express.Router();

/**
 * Messenger (user <-> user) suhbatlari.
 *
 * Mavjud `/chat/client/*` yo'llari CRM (foydalanuvchi <-> operator) uchun
 * qoladi. Bu yerda esa foydalanuvchilar o'zaro yozishadi: bir foydalanuvchida
 * ko'p suhbat bo'lishi mumkin.
 */

const toMessageDto = (message) => ({
    id: String(message.id),
    conversationId: String(message.conversationId),
    senderId: String(message.senderId),
    content: message.content,
    contentType: message.contentType,
    key: message.key,
    isRead: message.isRead,
    isEdited: message.isEdited,
    isDeleted: message.isDeleted,
    date: message.date,
    svg: message.svg,
    png: message.png,
    duration: message.duration,
    size: message.size,
    replyToId: message.replyToId,
    replyToContent: message.replyToContent,
    replyToSenderId: message.replyToSenderId,
});

const { isOnline, invalidateParticipants } = require('../../../infrastructure/sockets/dm_socket');

const toUserDto = (user) => ({
    id: String(user.id),
    uuid: user.uuid,
    name: user.name || user.deviceName || user.uuid,
    avatar: user.avatar,
    // Dastlabki holat REST orqali keladi, keyingi o'zgarishlar socketdagi
    // `dm.presence` hodisasi bilan.
    isOnline: isOnline(user.id),
});

/**
 * Suhbatning ikkinchi ishtirokchisini topadi (1:1 uchun).
 */
const peerOf = (conversation, meId) =>
    conversation.participants.find((p) => p.userId !== meId);

/**
 * Har suhbatning oxirgi xabari - bittadan.
 *
 * Avval `include: { messages: { take: 1 } }` ishlatilardi: Prisma uni SQL da
 * cheklamaydi, sahifadagi suhbatlarning HAMMA xabarlarini o'qib, xotirada
 * bittadan qoldiradi - suhbatlar uzaygani sari ro'yxat og'irlashardi. Bu yerda
 * har suhbat uchun (conversationId, date) indeksi bo'yicha bitta qator
 * o'qiladi.
 */
async function lastMessagesOf(conversationIds) {
    if (conversationIds.length === 0) return new Map();
    const rows = await prisma.$queryRaw`
        SELECT m.* FROM unnest(${conversationIds}::int[]) AS c(id)
        CROSS JOIN LATERAL (
            SELECT * FROM "DirectMessage"
             WHERE "conversationId" = c.id
             ORDER BY "date" DESC, "id" DESC
             LIMIT 1
        ) m`;
    return new Map(rows.map((message) => [message.conversationId, message]));
}

/**
 * GET /chat/dm/conversations
 * Joriy foydalanuvchining barcha suhbatlari: suhbatdosh, oxirgi xabar,
 * o'qilmaganlar soni.
 */
router.get('/conversations', apiLimiter, checkUser, async (req, res, next) => {
    try {
        const page = Math.max(1, Number(req.query.page) || 1);
        const size = Math.min(Math.max(1, Number(req.query.size) || 30), 100);

        const memberships = await prisma.conversationParticipant.findMany({
            where: { userId: req.user.id },
            include: {
                conversation: {
                    include: {
                        participants: { include: { user: true } },
                    },
                },
            },
            // Eski yozuvlarda `lastMessageAt` NULL bo'lishi mumkin - ular
            // oxirida turishi kerak, tepada emas.
            orderBy: { conversation: { lastMessageAt: { sort: 'desc', nulls: 'last' } } },
            skip: (page - 1) * size,
            take: size + 1,
        });

        const hasMore = memberships.length > size;
        const items = hasMore ? memberships.slice(0, size) : memberships;
        const lastMessages = await lastMessagesOf(
            items.map((membership) => membership.conversation.id),
        );

        const data = items
            // A conversation this user has "deleted" (clearedAt set) stays hidden
            // until a message newer than the clear arrives — then it reappears
            // (showing only the messages after the clear, see the messages route).
            .filter((membership) => {
                const clearedAt = membership.clearedAt;
                if (!clearedAt) return true;
                const lastAt = membership.conversation.lastMessageAt;
                return lastAt != null && new Date(lastAt) > new Date(clearedAt);
            })
            .map((membership) => {
                const conversation = membership.conversation;
                const peer = peerOf(conversation, req.user.id);
                const last = lastMessages.get(conversation.id) || null;

                return {
                    id: String(conversation.id),
                    peer: peer ? toUserDto(peer.user) : null,
                    unreadCount: membership.unreadCount,
                    lastMessage: last ? toMessageDto(last) : null,
                    lastMessageAt: conversation.lastMessageAt,
                };
            });

        // Unread across ALL the user's conversations, not just this page: the
        // app's badge would otherwise count only the chats it has loaded. A
        // hidden (cleared) conversation has 0 until a new message shows it.
        const unread = await prisma.conversationParticipant.aggregate({
            where: { userId: req.user.id },
            _sum: { unreadCount: true },
        });

        res.json({ data, hasMore, page, unreadTotal: unread._sum.unreadCount || 0 });
    } catch (err) {
        next(err);
    }
});

/**
 * POST /chat/dm/conversations  { peerId } yoki { peerUuid }
 * Suhbatni topadi yoki yaratadi.
 *
 * DM API ning qolgan qismi raqamli `id` bilan ishlaydi (xabarlardagi
 * `senderId`, `/users` javobidagi `id`), shuning uchun `peerId` asosiy yo'l.
 * `peerUuid` mos kelish uchun qoldirilgan.
 */
/**
 * Spam guard: one account may start at most NEW_CHATS_PER_HOUR new
 * conversations an hour (opening an existing one doesn't count), so it
 * can't message an endless stream of strangers.
 */
const NEW_CHATS_PER_HOUR = 30;
const newChatsByUser = new Map();

function allowNewChat(userId) {
    const hourAgo = Date.now() - 60 * 60 * 1000;
    const recent = (newChatsByUser.get(userId) || []).filter((t) => t > hourAgo);
    const allowed = recent.length < NEW_CHATS_PER_HOUR;
    if (allowed) recent.push(Date.now());
    if (recent.length) newChatsByUser.set(userId, recent);
    else newChatsByUser.delete(userId);
    return allowed;
}

router.post('/conversations', apiLimiter, checkUser, async (req, res, next) => {
    try {
        const { peerId, peerUuid } = req.body || {};
        if (!peerId && !peerUuid) {
            return res.status(400).json({ error: 'peerId or peerUuid is required' });
        }

        let peer = peerId
            ? await prisma.user.findFirst({
                where: { id: Number(peerId), projectId: req.projectId },
            })
            : await prisma.user.findUnique({
                where: { uuid_projectId: { uuid: peerUuid, projectId: req.projectId } },
            });

        // The peer's name/avatar come from their profile, never from the
        // caller: `peerName` / `peerAvatar` are ignored, or anyone could label
        // someone else in pushes and chat lists (profiles.js).
        const card = await profileCard(peer?.uuid || peerUuid);

        // Cold-start: in a social app you can message anyone from their profile,
        // even a user who has never opened chat (so has no row yet). Create a
        // stub keyed by their stable app uuid; device fields are placeholders
        // that their own first connection overwrites.
        if (!peer && peerUuid) {
            peer = await prisma.user.upsert({
                where: { uuid_projectId: { uuid: peerUuid, projectId: req.projectId } },
                update: {},
                create: {
                    uuid: peerUuid,
                    projectId: req.projectId,
                    name: card?.name ?? null,
                    avatar: card?.avatar ?? null,
                    appName: req.headers['x-app'] || 'unknown',
                    deviceId: 'pending',
                    deviceName: 'pending',
                    deviceType: 'mobile',
                    lang: 'uz',
                },
            });
        }
        if (!peer) return res.status(404).json({ error: 'Peer not found' });
        if (peer.id === req.user.id) {
            return res.status(400).json({ error: 'Cannot open a chat with yourself' });
        }
        // An older row may still carry a name a caller wrote: put the
        // profile's back.
        if (card && (peer.name !== card.name || peer.avatar !== card.avatar)) {
            peer = await prisma.user.update({
                where: { id: peer.id },
                data: { name: card.name, avatar: card.avatar },
            });
        }
        // Ikkalasidan biri ikkinchisini bloklagan bo'lsa - suhbat ochilmaydi.
        if (await isBlockedBetween(req.user.uuid, peer.uuid)) {
            return res.status(403).json({ error: 'Blocked', code: 'BLOCKED' });
        }

        // Ikkalasi ham ishtirok etadigan mavjud suhbatni qidiramiz.
        const existing = await prisma.conversation.findFirst({
            where: {
                projectId: req.projectId,
                AND: [
                    { participants: { some: { userId: req.user.id } } },
                    { participants: { some: { userId: peer.id } } },
                ],
            },
        });

        if (!existing && !allowNewChat(req.user.id)) {
            return res.status(429).json({
                error: 'Too many new chats, try again later',
                code: 'TOO_MANY_NEW_CHATS',
            });
        }

        const conversation = existing
            ? existing
            : await prisma.conversation.create({
                data: {
                    projectId: req.projectId,
                    // Bo'sh qolganda ham tartiblash uchun qiymat bo'lishi shart:
                    // NULL bo'lsa Postgres uni `DESC` da eng tepaga chiqaradi va
                    // yangi bo'sh suhbat faol suhbatlardan yuqorida qotib qoladi.
                    lastMessageAt: new Date(),
                    participants: {
                        create: [{ userId: req.user.id }, { userId: peer.id }],
                    },
                },
            });

        // Yangi suhbat yaratilgan bo'lsa, socket qatlamidagi ishtirokchilar
        // keshi eskirmasligi uchun tozalaymiz.
        if (!existing) {
            require('../../../infrastructure/sockets/dm_socket')
                .invalidateParticipants(conversation.id);
        }

        res.json({ id: String(conversation.id), peer: toUserDto(peer) });
    } catch (err) {
        next(err);
    }
});

/**
 * GET /chat/dm/conversations/:id/messages
 */
router.get('/conversations/:id/messages', apiLimiter, checkUser, async (req, res, next) => {
    try {
        const conversationId = Number(req.params.id);
        // Salbiy yoki nol qiymat Prisma `skip` ga tushib 500 berardi.
        const page = Math.max(1, Number(req.query.page) || 1);
        const size = Math.min(Math.max(1, Number(req.query.size) || 25), 100);

        const membership = await prisma.conversationParticipant.findUnique({
            where: {
                conversationId_userId: { conversationId, userId: req.user.id },
            },
        });
        if (!membership) return res.status(403).json({ error: 'Not a participant' });

        const messages = await prisma.directMessage.findMany({
            where: {
                conversationId,
                // If this user cleared the chat, only show messages sent after
                // the clear — old history stays hidden for them (the peer keeps
                // everything).
                ...(membership.clearedAt ? { date: { gt: membership.clearedAt } } : {}),
            },
            orderBy: { date: 'desc' },
            skip: (page - 1) * size,
            take: size + 1,
        });

        const hasMore = messages.length > size;
        const items = hasMore ? messages.slice(0, size) : messages;

        res.json({ data: items.map(toMessageDto), hasMore, page });
    } catch (err) {
        next(err);
    }
});

/**
 * GET /chat/dm/me
 * Joriy foydalanuvchining serverdagi identifikatori - klient xabar kimdan
 * kelganini shu bilan aniqlaydi.
 */
router.get('/me', apiLimiter, checkUser, async (req, res, next) => {
    try {
        res.json(toUserDto(req.user));
    } catch (err) {
        next(err);
    }
});

/**
 * GET /chat/dm/users
 * Loyihadagi boshqa foydalanuvchilar - kim bilan suhbat boshlash mumkinligi.
 */
router.get('/users', apiLimiter, checkUser, async (req, res, next) => {
    try {
        // `q` berilsa ism yoki telefon bo'yicha qidiriladi.
        const q = (req.query.q || '').toString().trim();

        const users = await prisma.user.findMany({
            where: {
                projectId: req.projectId,
                NOT: { id: req.user.id },
                ...(q
                    ? {
                        OR: [
                            { name: { contains: q, mode: 'insensitive' } },
                            { phone: { contains: q } },
                            { deviceName: { contains: q, mode: 'insensitive' } },
                        ],
                    }
                    : {}),
            },
            orderBy: { updatedAt: 'desc' },
            take: 50,
        });
        res.json({ data: users.map(toUserDto) });
    } catch (err) {
        next(err);
    }
});

/**
 * POST /chat/dm/device-token  { token, platform }
 * Push (FCM) uchun qurilma tokenini ro'yxatdan o'tkazadi. Token boshqa
 * foydalanuvchida bo'lsa - shu foydalanuvchiga ko'chiriladi.
 */
router.post('/device-token', apiLimiter, checkUser, async (req, res, next) => {
    try {
        const token = (req.body?.token || '').toString().trim();
        if (!token) return res.status(400).json({ error: 'token is required' });
        const platform = (req.body?.platform || 'mobile').toString();

        await prisma.deviceToken.upsert({
            where: { token },
            update: { userId: req.user.id, platform, updatedAt: new Date() },
            create: { userId: req.user.id, token, platform },
        });

        res.json({ status: 'ok' });
    } catch (err) {
        next(err);
    }
});

/**
 * DELETE /chat/dm/device-token  { token }
 * Chiqishda: bu qurilma endi shu foydalanuvchining xabarlari uchun push
 * olmaydi (keyingi akkaunt oldingisining bildirishnomalarini ko'rmasin).
 */
router.delete('/device-token', apiLimiter, checkUser, async (req, res, next) => {
    try {
        const token = (req.body?.token || '').toString().trim();
        if (!token) return res.status(400).json({ error: 'token is required' });
        await prisma.deviceToken.deleteMany({
            where: { token, userId: req.user.id },
        });
        res.json({ status: 'ok' });
    } catch (err) {
        next(err);
    }
});

/**
 * DELETE /chat/dm/conversations/:id
 * Per-user hide, NOT a mutual delete. Marks only the requesting participant's
 * view as cleared (clearedAt = now) and zeroes their unread count. The peer
 * keeps the conversation and its history untouched; for this user the chat
 * disappears from the list and reappears only when a newer message arrives,
 * showing just the messages after the clear (see the clearedAt filters in the
 * list and messages routes). Messages are never destroyed.
 * Faqat suhbat ishtirokchisi o'chira oladi.
 */
router.delete('/conversations/:id', apiLimiter, checkUser, async (req, res, next) => {
    try {
        const conversationId = Number(req.params.id);
        if (!conversationId) return res.status(400).json({ error: 'invalid conversation id' });

        const membership = await prisma.conversationParticipant.findUnique({
            where: { conversationId_userId: { conversationId, userId: req.user.id } },
        });
        if (!membership) return res.status(404).json({ error: 'conversation not found' });

        await prisma.conversationParticipant.update({
            where: { conversationId_userId: { conversationId, userId: req.user.id } },
            data: { clearedAt: new Date(), unreadCount: 0 },
        });

        res.json({ status: 'ok' });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
