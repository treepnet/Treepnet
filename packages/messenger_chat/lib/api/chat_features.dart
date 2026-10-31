part of messenger_chat;

/// Chatda qaysi xabar turlariga ruxsat berilishini belgilaydi.
///
/// Ilgari bu sozlama serverdan yuklanardi (CRM loyihada operator uni
/// boshqarardi). Messenger'da bunday markazlashgan cheklov kerak emas -
/// ilova o'zi qaror qiladi va [MessengerChat.init] ga uzatadi.
///
/// Chat faqat matnli: rasm, video, ovoz va fayl xabarlari hech qachon
/// yoqilmagan, ularning kodi olib tashlangan.
class ChatFeatures {
  const ChatFeatures({this.text = true, this.blurEffects = true});

  final bool text;

  /// Fon xiralashtirish (`BackdropFilter`) effektlari.
  ///
  /// Chiroyli, lekin qimmat: eski GPU larda har bir kadrda save-layer + blur
  /// o'tishi bajariladi. O'lchovda tinch turgan ekranda ham raster 43 ms edi,
  /// o'chirilganda 16 ms ga tushdi. Zaif qurilmalarda `false` qiling.
  final bool blurEffects;

  ChatFeatures copyWith({bool? text, bool? blurEffects}) => ChatFeatures(
    text: text ?? this.text,
    blurEffects: blurEffects ?? this.blurEffects,
  );

  /// Ichki modelga o'tkazish - UI cheklovlarni shu ko'rinishda o'qiydi.
  _ConfigModel get _config => _ConfigModel(textIsBlock: !text);
}
