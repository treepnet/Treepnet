part of messenger_chat;

/// Suhbatdagi foydalanuvchi - o'zimiz yoki suhbatdosh.
///
/// Plagin foydalanuvchilarni o'zi yuklamaydi: ilova kim bilan yozishayotganini
/// biladi va bu ma'lumotni tayyor holda beradi.
class ChatUser extends Equatable {
  const ChatUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  /// Ilovadagi foydalanuvchi identifikatori. Xabar kimdan kelganini
  /// aniqlashda shu qiymat solishtiriladi.
  final String id;

  /// Ekranda ko'rsatiladigan ism.
  final String name;

  /// To'liq avatar manzili. `null` bo'lsa ismning bosh harfi chiziladi.
  final String? avatarUrl;

  final bool isOnline;

  /// Oxirgi faollik vaqti - `isOnline` false bo'lganda ko'rsatiladi.
  final DateTime? lastSeen;

  ChatUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
  }) => ChatUser(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isOnline: isOnline ?? this.isOnline,
    lastSeen: lastSeen ?? this.lastSeen,
  );

  /// Avatar bo'lmaganda ishlatiladigan bosh harf(lar).
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.elementAt(1).characters.first)
        .toUpperCase();
  }

  @override
  List<Object?> get props => [id, name, avatarUrl, isOnline, lastSeen];
}
