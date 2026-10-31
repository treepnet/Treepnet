part of messenger_chat;

class _ChatLocalizations {
  _ChatLocalizations._();

  static final _ChatLocalizations _instance = _ChatLocalizations._();

  static _ChatLocalizations get instance => _instance;

  ChatLanguage _language = ChatLanguage.russian;

  /// Locale code of the chat language, for dates (`ru`, `en`, ...).
  String get locale => _language.locale;

  void initialize(ChatLanguage? lan) {
    if (lan != null && lan != _language) _language = lan;
  }

  String getText(String key) {
    final text = switch (_language) {
      ChatLanguage.uzbek => _Uzbek.texts[key],
      ChatLanguage.uzbekCyrillic => _UzbekCyrillic.texts[key],
      ChatLanguage.russian => _Russian.texts[key],
      ChatLanguage.english => _English.texts[key],
    };

    return text ?? key;
  }
}
