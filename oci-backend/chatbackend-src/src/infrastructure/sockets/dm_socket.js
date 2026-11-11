const prisma = require('../database/prisma');
const fcmService = require('../external/fcm_service');
const { isBlockedBetween } = require('../external/blocks');

/**
 * Messenger (user <-> user) uchun socket hodisalari.
 *
 * CRM hodisalari (`appSendMessage`, `newMessage`, ...) tegilmaydi - bu yerdagi
 * hamma narsa `dm.` prefiksi bilan boradi.
 *
 * Har bir foydalanuvchi o'z shaxsiy xonasida (`user_<id>`) turadi, shuning
 * uchun xabar qaysi ekran ochiq bo'lishidan qat'i nazar yetib boradi -
 * suhbat ekraniga ham, suhbatlar ro'yxatiga ham.
 */

const userRoom = (userId) => `user_${userId}`;

/// Ruxsat etilgan xabar turlari - ixtiyoriy satr qabul qilinmaydi.
const ALLOWED_CONTENT_TYPES = new Set(['text', 'photo', 'video', 'voice', 'document']);

/**
 * Bitta xabar uchun chegara.
 *
 * Cheklovsiz matn ham bazani, ham klient UI sini og'irlashtiradi - 60 000
 * belgili xabar sinovda muammosiz o'tib ketdi.
 */
const MAX_CONTENT_LENGTH = 8000;

/**
 * Socket uchun oddiy token-bucket cheklovi.
 *
 * HTTP so'rovlar `express-rate-limit` bilan himoyalangan, socket hodisalari
 * esa umuman cheklanmagan edi - ya'ni bitta klient `dm.send` ni cheksiz
 * yuborib bazani ko'mib tashlashi mumkin edi.
 */
const RATE_LIMIT = { capacity: 30, refillPerSec: 5 };

function allow(socket) {
    const now = Date.now();
    const bucket = socket._dmBucket || { tokens: RATE_LIMIT.capacity, at: now };

    const elapsed = (now - bucket.at) / 1000;
    bucket.tokens = Math.min(
        RATE_LIMIT.capacity,
        bucket.tokens + elapsed * RATE_LIMIT.refillPerSec,
    );
    bucket.at = now;

    if (bucket.tokens < 1) {
        socket._dmBucket = bucket;
        return false;
    }

    bucket.tokens -= 1;
    socket._dmBucket = bucket;
    return true;
}

// Xabar kaliti bazada `<yuboruvchi>:<suhbat>:<kalit>` ko'rinishida saqlanadi:
// kalit faqat bitta yuboruvchining bitta suhbatida yagona. Ilova o'z kalitini
// qaytarib oladi (shu bilan yuborilgan xabarini taniydi); eski xabarlarda
// prefiks yo'q.
const storedKey = (senderId, conversationId, key) => `${senderId}:${conversationId}:${key}`;

const clientKey = (message) => {
    const prefix = `${message.senderId}:${message.conversationId}:`;
    return message.key && message.key.startsWith(prefix)
        ? message.key.slice(prefix.length)
        : message.key;
};

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

/**
 * Ishtirokchilar keshi.
 *
 * 1:1 suhbatda ishtirokchilar deyarli o'zgarmaydi, lekin ular har bir xabar
 * va har bir "yozmoqda" hodisasida kerak bo'ladi. Keshsiz har bir tugma
 * bosilishi bazaga so'rov yuborardi - bu server uchun eng katta ortiqcha yuk
 * edi.
 */
const PARTICIPANTS_TTL_MS = 5 * 60 * 1000;
const participantsCache = new Map(); // conversationId -> { userIds, expiresAt }

function invalidateParticipants(conversationId) {
    participantsCache.delete(conversationId);
}

/**
 * Suhbat ishtirokchilarini qaytaradi (foydalanuvchi a'zoligini tekshirish
 * bilan birga). A'zo bo'lmasa - `null`.
 */
async function participantsOf(conversationId, userId) {
    const now = Date.now();
    const cached = participantsCache.get(conversationId);

    let userIds;
    if (cached && cached.expiresAt > now) {
        userIds = cached.userIds;
    } else {
        const rows = await prisma.conversationParticipant.findMany({
            where: { conversationId },
            select: { userId: true },
        });
        userIds = rows.map((r) => r.userId);
        participantsCache.set(conversationId, {
            userIds,
            expiresAt: now + PARTICIPANTS_TTL_MS,
        });
    }

    return userIds.includes(userId) ? userIds : null;
}

/** Chat foydalanuvchisining ilovadagi uuid si (o'zgarmaydi, keshlanadi). */
const uuidCache = new Map(); // userId -> uuid

async function uuidOf(userId) {
    if (uuidCache.has(userId)) return uuidCache.get(userId);
    const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { uuid: true },
    });
    const uuid = user?.uuid || null;
    if (uuidCache.size > 10000) uuidCache.clear();
    uuidCache.set(userId, uuid);
    return uuid;
}

/**
 * Suhbatdoshlardan biri bilan blok bormi (qaysi tomon bloklaganidan qat'i
 * nazar)? Bo'lsa, xabar ham, "yozmoqda" ham, push ham yuborilmaydi.
 */
async function blockedInConversation(socket, participants) {
    for (const participantId of participants) {
        if (participantId === socket.userId) continue;
        if (await isBlockedBetween(socket.uuid, await uuidOf(participantId))) {
            return true;
        }
    }
    return false;
}

/**
 * Onlayn foydalanuvchilar.
 *
 * Bitta foydalanuvchi bir necha qurilmadan ulanishi mumkin, shuning uchun
 * oddiy Set emas - ulanishlar soni sanaladi. Oxirgi ulanish uzilgandagina
 * foydalanuvchi oflayn hisoblanadi.
 */
const onlineCounts = new Map(); // userId -> ochiq socketlar soni

function isOnline(userId) {
    return (onlineCounts.get(userId) || 0) > 0;
}

/**
 * Foydalanuvchi bilan suhbatda bo'lgan barcha odamlarni topadi.
 *
 * Holat o'zgarishi faqat shularga yuboriladi - butun serverga emas.
 */
async function partnersOf(userId) {
    const myConversations = await prisma.conversationParticipant.findMany({
        where: { userId },
        select: { conversationId: true },
    });
    if (myConversations.length === 0) return [];

    const others = await prisma.conversationParticipant.findMany({
        where: {
            conversationId: { in: myConversations.map((c) => c.conversationId) },
            NOT: { userId },
        },
        select: { userId: true },
    });

    return [...new Set(others.map((o) => o.userId))];
}

async function broadcastPresence(io, userId, online) {
    try {
        const partners = await partnersOf(userId);
        const payload = {
            userId: String(userId),
            isOnline: online,
            lastSeen: online ? null : new Date().toISOString(),
        };
        for (const partnerId of partners) {
            io.to(userRoom(partnerId)).emit('dm.presence', payload);
        }
    } catch (error) {
        console.error('[DM] presence broadcast error:', error);
    }
}

function register(io, socket) {
    // Faqat autentifikatsiyadan o'tgan mijoz socketlari uchun.
    // `authReady` hali tugamagan bo'lishi mumkin - shuning uchun kutamiz.
    const ready = socket.authReady || Promise.resolve(true);

    // Uzilish darhol kuzatiladi: kirish tekshiruvi davomida uzilgan socket
    // uchun keyin qo'shilgan tinglovchi hech qachon ishlamasdi, foydalanuvchi
    // esa abadiy "onlayn" qolib, unga push ketmasdi. Sanoq faqat oshirilgan
    // bo'lsa kamayadi.
    let counted = false;
    socket.on('disconnect', () => {
        if (!counted) return;
        counted = false;
        const left = (onlineCounts.get(socket.userId) || 1) - 1;
        if (left <= 0) {
            onlineCounts.delete(socket.userId);
            broadcastPresence(io, socket.userId, false);
        } else {
            onlineCounts.set(socket.userId, left);
        }
    });

    ready.then((ok) => {
        if (ok === false || !socket.userId || socket.disconnected) return;

        socket.join(userRoom(socket.userId));

        const wasOnline = isOnline(socket.userId);
        onlineCounts.set(socket.userId, (onlineCounts.get(socket.userId) || 0) + 1);
        counted = true;
        if (!wasOnline) {
            broadcastPresence(io, socket.userId, true);
        }
    });

    // Mijoz `ack` o'rniga istalgan qiymat yubora oladi: faqat haqiqiy funksiya
    // chaqiriladi. Kirishi muvaffaqiyatsiz soket uchun ishlovchi ishlamaydi,
    // ishlovchidagi kutilmagan xato esa butun serverni yiqitmaydi.
    const on = (event, handler) => socket.on(event, async (data, ack) => {
        const reply = typeof ack === 'function' ? ack : undefined;
        try {
            if ((await socket.authReady) === false || !socket.userId) {
                return reply?.({ status: 'error', error: 'unauthorized' });
            }
            await handler(data, reply);
        } catch (error) {
            console.error(`[DM] ${event} error:`, error);
        }
    });

    /**
     * Xabar yuborish.
     * data: { conversationId, content, contentType, key, svg, duration, size }
     */
    on('dm.send', async (data, ack) => {
        try {
            await socket.authReady;

            if (!allow(socket)) {
                return ack?.({ status: 'error', error: 'rate limit exceeded' });
            }

            const conversationId = Number(data?.conversationId);
            const key = data?.key;
            if (!conversationId || !key) {
                return ack?.({ status: 'error', error: 'conversationId and key are required' });
            }

            // Postgres `0x00` baytini qabul qilmaydi - tozalamasak Prisma
            // xatosi (fayl yo'li va qator raqami bilan) klientga chiqib
            // ketardi.
            const content = String(data?.content ?? '').replace(/ /g, '');
            if (content.trim().length === 0) {
                return ack?.({ status: 'error', error: 'content must not be empty' });
            }
            if (content.length > MAX_CONTENT_LENGTH) {
                return ack?.({
                    status: 'error',
                    error: `content is too long (max ${MAX_CONTENT_LENGTH})`,
                });
            }

            const contentType = data?.contentType || 'text';
            if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
                return ack?.({ status: 'error', error: 'unsupported contentType' });
            }

            const participants = await participantsOf(conversationId, socket.userId);
            if (!participants) {
                return ack?.({ status: 'error', error: 'Not a participant' });
            }
            if (await blockedInConversation(socket, participants)) {
                return ack?.({ status: 'error', error: 'Blocked', code: 'BLOCKED' });
            }

            // Kalit bo'yicha idempotentlik: qayta yuborilgan xabar dublikat
            // yaratmaydi. Faqat shu yuboruvchining shu suhbatdagi xabari
            // qidiriladi (oddiy kalit - prefiks paydo bo'lishidan oldingi
            // xabarlar): boshqaning xabari hech qachon qaytarilmaydi.
            const existing = await prisma.directMessage.findFirst({
                where: {
                    key: { in: [storedKey(socket.userId, conversationId, key), String(key)] },
                    senderId: socket.userId,
                    conversationId,
                },
            });
            const message = existing || await prisma.directMessage.create({
                data: {
                    conversationId,
                    senderId: socket.userId,
                    content,
                    contentType,
                    key: storedKey(socket.userId, conversationId, key),
                    svg: data.svg || null,
                    png: data.png || null,
                    duration: data.duration != null ? String(data.duration) : null,
                    size: data.size != null ? String(data.size) : null,
                    replyToId: data.replyToId != null ? String(data.replyToId) : null,
                    replyToContent: data.replyToContent != null
                        ? String(data.replyToContent).slice(0, 500)
                        : null,
                    replyToSenderId: data.replyToSenderId != null
                        ? String(data.replyToSenderId)
                        : null,
                },
            });

            if (!existing) {
                // Ikkala yozish bitta borishda bajariladi - ketma-ket
                // so'rovlar xabar yuborishni sekinlashtirardi.
                await prisma.$transaction([
                    prisma.conversation.update({
                        where: { id: conversationId },
                        data: { lastMessageAt: message.date },
                    }),
                    // Qabul qiluvchilarning o'qilmaganlar soni oshadi.
                    prisma.conversationParticipant.updateMany({
                        where: { conversationId, NOT: { userId: socket.userId } },
                        data: { unreadCount: { increment: 1 } },
                    }),
                ]);
            }

            const dto = toMessageDto(message);
            for (const participantId of participants) {
                io.to(userRoom(participantId)).emit('dm.newMessage', dto);
            }

            // Oflayn qabul qiluvchilarga push (faqat yangi xabarda).
            if (!existing) {
                const offline = participants.filter(
                    (id) => id !== socket.userId && !isOnline(id),
                );
                if (offline.length > 0) {
                    const sender = await prisma.user.findUnique({
                        where: { id: socket.userId },
                    });
                    const isSharePost = contentType === 'text' && content.startsWith('treepnet:share:post:');
                    const isShareStory = contentType === 'text' && content.startsWith('treepnet:share:story:');
                    for (const participantId of offline) {
                        const recipient = await prisma.user.findUnique({ where: { id: participantId } });
                        const ru = recipient?.lang === 'ru';
                        const title = sender?.name || sender?.deviceName || (ru ? 'Новое сообщение' : 'New message');
                        const body = contentType !== 'text'
                            ? (ru ? '📎 Медиа' : '📎 Media')
                            : isSharePost ? (ru ? '📷 Пост' : '📷 Post')
                            : isShareStory ? (ru ? '📖 История' : '📖 Story')
                            : content.slice(0, 120);
                        fcmService
                            .sendToUser(participantId, {
                                title,
                                body,
                                // peerUuid/peerName let a tap open this chat.
                                data: {
                                    conversationId: String(conversationId),
                                    type: 'dm',
                                    peerUuid: sender?.uuid || '',
                                    peerName: title,
                                },
                            })
                            .catch(() => {});
                    }
                }
            }

            ack?.({ status: 'ok', message: dto });
        } catch (error) {
            console.error('[DM] dm.send error:', error);
            ack?.({ status: 'error', error: error.message });
        }
    });

    /**
     * "Yozmoqda" - faqat suhbatdoshlarga.
     */
    on('dm.typing', async (data) => {
        try {
            await socket.authReady;
            if (!allow(socket)) return;
            const conversationId = Number(data?.conversationId);
            const participants = await participantsOf(conversationId, socket.userId);
            if (!participants) return;
            if (await blockedInConversation(socket, participants)) return;

            for (const participantId of participants) {
                if (participantId === socket.userId) continue;
                io.to(userRoom(participantId)).emit('dm.typing', {
                    conversationId: String(conversationId),
                    userId: String(socket.userId),
                    isTyping: data?.isTyping !== false,
                    contentType: data?.contentType || '',
                });
            }
        } catch (error) {
            console.error('[DM] dm.typing error:', error);
        }
    });

    /**
     * O'qildi deb belgilash. messageId berilmasa - suhbatdagi hammasi.
     */
    on('dm.read', async (data, ack) => {
        try {
            await socket.authReady;
            const conversationId = Number(data?.conversationId);
            const participants = await participantsOf(conversationId, socket.userId);
            if (!participants) return ack?.({ status: 'error', error: 'Not a participant' });

            const messageId = data?.messageId ? Number(data.messageId) : null;

            await prisma.$transaction([
                prisma.directMessage.updateMany({
                    where: {
                        conversationId,
                        NOT: { senderId: socket.userId },
                        ...(messageId ? { id: messageId } : { isRead: false }),
                    },
                    data: { isRead: true },
                }),
                prisma.conversationParticipant.update({
                    where: { conversationId_userId: { conversationId, userId: socket.userId } },
                    data: { unreadCount: 0, lastReadAt: new Date() },
                }),
            ]);

            const payload = {
                conversationId: String(conversationId),
                messageId: messageId ? String(messageId) : null,
                all: !messageId,
                byUserId: String(socket.userId),
            };

            for (const participantId of participants) {
                io.to(userRoom(participantId)).emit('dm.read', payload);
            }

            ack?.({ status: 'ok' });
        } catch (error) {
            console.error('[DM] dm.read error:', error);
            ack?.({ status: 'error', error: error.message });
        }
    });

    // Xabarni tahrirlash - faqat o'z xabaringizni.
    on('dm.edit', async (data, ack) => {
        try {
            await socket.authReady;
            const messageId = Number(data?.messageId);
            const content = String(data?.content ?? '').replace(/\0/g, '');
            if (!messageId) return ack?.({ status: 'error', error: 'messageId is required' });
            if (content.trim().length === 0) return ack?.({ status: 'error', error: 'content must not be empty' });
            if (content.length > MAX_CONTENT_LENGTH) {
                return ack?.({ status: 'error', error: `content is too long (max ${MAX_CONTENT_LENGTH})` });
            }

            const message = await prisma.directMessage.findUnique({ where: { id: messageId } });
            if (!message) return ack?.({ status: 'error', error: 'Message not found' });
            if (message.senderId !== socket.userId) return ack?.({ status: 'error', error: 'Not your message' });
            if (message.isDeleted) return ack?.({ status: 'error', error: 'Message is deleted' });

            const participants = await participantsOf(message.conversationId, socket.userId);
            if (!participants) return ack?.({ status: 'error', error: 'Not a participant' });

            const updated = await prisma.directMessage.update({
                where: { id: messageId },
                data: { content, isEdited: true },
            });

            const dto = toMessageDto(updated);
            for (const participantId of participants) {
                io.to(userRoom(participantId)).emit('dm.messageEdited', dto);
            }
            ack?.({ status: 'ok', message: dto });
        } catch (error) {
            console.error('[DM] dm.edit error:', error);
            ack?.({ status: 'error', error: error.message });
        }
    });

    // Xabarni o'chirish (soft-delete) - faqat o'z xabaringizni. Yozuv qoladi,
    // lekin `isDeleted` bo'ladi va matn tozalanadi.
    on('dm.delete', async (data, ack) => {
        try {
            await socket.authReady;
            const messageId = Number(data?.messageId);
            if (!messageId) return ack?.({ status: 'error', error: 'messageId is required' });

            const message = await prisma.directMessage.findUnique({ where: { id: messageId } });
            if (!message) return ack?.({ status: 'error', error: 'Message not found' });
            if (message.senderId !== socket.userId) return ack?.({ status: 'error', error: 'Not your message' });

            const participants = await participantsOf(message.conversationId, socket.userId);
            if (!participants) return ack?.({ status: 'error', error: 'Not a participant' });

            const updated = await prisma.directMessage.update({
                where: { id: messageId },
                data: { isDeleted: true, content: '' },
            });

            const dto = toMessageDto(updated);
            for (const participantId of participants) {
                io.to(userRoom(participantId)).emit('dm.messageDeleted', dto);
            }
            ack?.({ status: 'ok', message: dto });
        } catch (error) {
            console.error('[DM] dm.delete error:', error);
            ack?.({ status: 'error', error: error.message });
        }
    });
}

module.exports = { register, userRoom, toMessageDto, clientKey, invalidateParticipants, isOnline };
