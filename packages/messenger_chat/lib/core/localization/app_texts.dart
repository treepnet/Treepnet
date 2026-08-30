part of messenger_chat;

mixin _AppTexts {
  static String _translate(String key) =>
      _ChatLocalizations.instance.getText(key);

  static String get online => _translate('online');

  static String get connecting => _translate('connecting');

  static String get today => _translate('today');

  static String get yesterday => _translate('yesterday');



  static String get recordCancel => _translate('recordCancel');

  static String get swipToLeft => _translate('swipToLeft');

  static String get toSendAudio => _translate('toSendAudio');

  static String get cantDownloadImage => _translate('cantDownloadImage');

  static String get cancel => _translate('cancel');

  static String get takePhoto => _translate('takePhoto');

  static String get uploadFile => _translate('uploadFile');

  static String get uploadWitGallery => _translate('uploadWitGallery');

  static String get socketConnectionNot => _translate('socketConnectionNot');


  static String get writeHere => _translate('writeHere');

  static String get cancelRecording => _translate('cancelRecording');

  static String get noAppFound => _translate('noAppFound');

  static String get fileOpenError => _translate('fileOpenError');
  static String get noMessages => _translate('noMessages');
  static String get somethingWentWrong => _translate('somethingWentWrong');
  static String get retry => _translate('retry');
  static String get photo => _translate('photo');
  static String get video => _translate('video');
  static String get voiceMessage => _translate('voiceMessage');
  static String get file => _translate('file');
  static String get typingVoice => _translate('typingVoice');
  static String get typingPhoto => _translate('typingPhoto');
  static String get typingVideo => _translate('typingVideo');
  static String get typingFile => _translate('typingFile');
  static String get typing => _translate('typing');
  static String get offline => _translate('offline');
  static String get lastSeen => _translate('lastSeen');
}
