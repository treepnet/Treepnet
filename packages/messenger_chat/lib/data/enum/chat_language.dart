enum ChatLanguage {
  russian('ru'),
  english('en');

  const ChatLanguage(this.locale);

  final String locale;

  static ChatLanguage fromName(String name) => ChatLanguage.values.firstWhere(
    (e) => e.name.toLowerCase() == name.toLowerCase(),
    orElse: () => ChatLanguage.russian,
  );

  bool get isExists => ChatLanguage.values.contains(this);

  bool get isRussian => this == ChatLanguage.russian;

  bool get isEnglish => this == ChatLanguage.english;
}
