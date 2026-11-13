const express = require('express');

const prisma = require('../../../infrastructure/database/prisma');
const checkUser = require('../middlewares/check_user');
const { isBlockedBetween } = require('../../../infrastructure/external/blocks');
const { profileCard } = require('../../../infrastructure/external/profiles');
// The address limit runs once for every request (index.js); here each
// signed-in user is counted on their own.
const { userLimiter } = require('../middlewares/rate_limiter');

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
    key: clientKey(message),
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

const { isOnline, invalidateParticipants, clientKey } = require('../../../infrastructure/sockets/dm_socket');

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
router.get('/conversations', checkUser, userLimiter, async (req, res, next) => {
    try {
        const page = Math.max(1, Number(req.query.page) || 1);
        const size = Math.min(Math.max(1, Number(req.query.size) || 30), 100);

        // Only conversations with a message, and one this user "deleted"
        // (clearedAt) only once a newer message came: filtered in the query,
        // so every page holds real chats. Filtered after the page was taken,
        // most pages could be empty (a profile's Message button opens a
        // conversation that is often never written in), and the app took an
        // empty page for "no chats" and asked for no more.
        const cleared = await prisma.conversationParticipant.findMany({
            where: { userId: req.user.id, clearedAt: { not: null } },
            select: {
                conversationId: true,
                clearedAt: true,
                conversation: { select: { lastMessageAt: true } },
            },
        });
        const reappeared = cleared
            .filter((m) => {
                const lastAt = m.conversation.lastMessageAt;
                return lastAt != null && new Date(lastAt) > new Date(m.clearedAt);
            })
            .map((m) => m.conversationId);

        const memberships = await prisma.conversationParticipant.findMany({
            where: {
                userId: req.user.id,
                conversation: { messages: { some: {} } },
                OR: [{ clearedAt: null }, { conversationId: { in: reappeared } }],
            },
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

        // A reappeared conversation shows only the messages after the clear
        // (see the messages route).
        const data = items
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

router.post('/conversations', checkUser, userLimiter, async (req, res, next) => {
    try {
        const { peerId, peerUuid } = req.body || {};
        if (!peerId && !peerUuid) {
            return res.status(400).json({ error: 'peerId or peerUuid is required' });
        }

        if (peerId && !Number.isSafeInteger(Number(peerId))) {
            return res.status(400).json({ error: 'peerId must be a number' });
        }

        let peer = peerId
            ? await prisma.user.findFirst({
                where: { id: Number(peerId), projectId: req.projectId },
            })
            : await prisma.user.findUnique({
                where: { uuid_projectId: { uuid: String(peerUuid), projectId: req.projectId } },
            });
        if (!peer && peerId) return res.status(404).json({ error: 'Peer not found' });
        const peerAccount = peer?.uuid || String(peerUuid);

        // The peer's name/avatar come from their profile, never from the
        // caller: `peerName` / `peerAvatar` are ignored, or anyone could label
        // someone else in pushes and chat lists (profiles.js).
        //
        // No such account (an id that isn't a user's, or a deleted one): no
        // chat, and no row for it. For someone without a row yet the profile
        // is asked of the database, not the cache (auth_user.js).
        const card = await profileCard(peerAccount, { fresh: !peer });
        if (card === null) return res.status(404).json({ error: 'Peer not found' });
        if (peerAccount === req.user.uuid) {
            return res.status(400).json({ error: 'Cannot open a chat with yourself' });
        }
        // Ikkalasidan biri ikkinchisini bloklagan bo'lsa - suhbat ochilmaydi.
        if (await isBlockedBetween(req.user.uuid, peerAccount)) {
            return res.status(403).json({ error: 'Blocked', code: 'BLOCKED' });
        }

        // Ikkalasi ham ishtirok etadigan mavjud suhbatni qidiramiz (chatni hali
        // ochmagan odamda u yo'q).
        const existing = peer
            ? await prisma.conversation.findFirst({
                where: {
                    projectId: req.projectId,
                    AND: [
                        { participants: { some: { userId: req.user.id } } },
                        { participants: { some: { userId: peer.id } } },
                    ],
                },
            })
            : null;

        if (!existing && !allowNewChat(req.user.id)) {
            return res.status(429).json({
                error: 'Too many new chats, try again later',
                code: 'TOO_MANY_NEW_CHATS',
            });
        }

        // Cold-start: in a social app you can message anyone from their profile,
        // even a user who has never opened chat (so has no row yet). Create a
        // stub keyed by their stable app uuid; device fields are placeholders
        // that their own first connection overwrites. Only now - after the
        // block and the new-chat limit - so a refused request leaves nothing.
        if (!peer) {
            peer = await prisma.user.upsert({
                where: { uuid_projectId: { uuid: peerAccount, projectId: req.projectId } },
                update: {},
                create: {
                    uuid: peerAccount,
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
        } else if (card && (peer.name !== card.name || peer.avatar !== card.avatar)) {
            // An older row may still carry a name a caller wrote: put the
            // profile's back.
            peer = await prisma.user.update({
                where: { id: peer.id },
                data: { name: card.name, avatar: card.avatar },
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
router.get('/conversations/:id/messages', checkUser, userLimiter, async (req, res, next) => {
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
router.get('/me', checkUser, userLimiter, async (req, res, next) => {
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
router.get('/users', checkUser, userLimiter, async (req, res, next) => {
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
router.post('/device-token', checkUser, userLimiter, async (req, res, next) => {
    try {
        const token = (req.body?.token || '').toString().trim();
        if (!token) return res.status(400).json({ error: 'token is required' });
        const platform = (req.body?.platform || 'mobile').toString();

        // The app sends it on every start: written only when it is new or
        // belonged to someone else (or another platform), not each time.
        const current = await prisma.deviceToken.findUnique({
            where: { token },
            select: { userId: true, platform: true },
        });
        if (!current || current.userId !== req.user.id || current.platform !== platform) {
            await prisma.deviceToken.upsert({
                where: { token },
                update: { userId: req.user.id, platform, updatedAt: new Date() },
                create: { userId: req.user.id, token, platform },
            });
        }

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
router.delete('/device-token', checkUser, userLimiter, async (req, res, next) => {
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
router.delete('/conversations/:id', checkUser, userLimiter, async (req, res, next) => {
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
