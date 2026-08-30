part of messenger_chat;

/// Chatda qaysi xabar turlariga ruxsat berilishini belgilaydi.
///
/// Ilgari bu sozlama serverdan yuklanardi (CRM loyihada operator uni
/// boshqarardi). Messenger'da bunday markazlashgan cheklov kerak emas -
/// ilova o'zi qaror qiladi va [MessengerChat.init] ga uzatadi.
class ChatFeatures {
  const ChatFeatures({
    this.text = true,
    this.photo = true,
    this.video = true,
    this.voice = true,
    this.file = true,
    this.blurEffects = true,
  });

  /// Faqat matn yozish mumkin bo'lgan chat.
  const ChatFeatures.textOnly()
    : text = true,
      photo = false,
      video = false,
      voice = false,
      file = false,
      blurEffects = true;

  final bool text;
  final bool photo;
  final bool video;
  final bool voice;
  final bool file;

  /// Fon xiralashtirish (`BackdropFilter`) effektlari.
  ///
  /// Chiroyli, lekin qimmat: eski GPU larda har bir kadrda save-layer + blur
  /// o'tishi bajariladi. O'lchovda tinch turgan ekranda ham raster 43 ms edi,
  /// o'chirilganda 16 ms ga tushdi. Zaif qurilmalarda `false` qiling.
  final bool blurEffects;

  ChatFeatures copyWith({
    bool? text,
    bool? photo,
    bool? video,
    bool? voice,
    bool? file,
    bool? blurEffects,
  }) => ChatFeatures(
    text: text ?? this.text,
    photo: photo ?? this.photo,
    video: video ?? this.video,
    voice: voice ?? this.voice,
    file: file ?? this.file,
    blurEffects: blurEffects ?? this.blurEffects,
  );

  /// Ichki modelga o'tkazish - UI cheklovlarni shu ko'rinishda o'qiydi.
  _ConfigModel get _config => _ConfigModel(
    textIsBlock: !text,
    photoIsBlock: !photo,
    videoIsBlock: !video,
    voiceIsBlock: !voice,
    documentIsBlock: !file,
  );
}
