part of messenger_chat;

enum _ContentType {
  text,
  photo,
  voice,
  video,
  document;

  String get name {
    switch (this) {
      case _ContentType.text:
        return 'text';
      case _ContentType.photo:
        return 'photo';
      case _ContentType.voice:
        return 'voice';
      case _ContentType.video:
        return 'video';
      case _ContentType.document:
        return 'document';
    }
  }

  static _ContentType fromName(String name) {
    switch (name) {
      case 'text':
        return _ContentType.text;
      case 'photo':
        return _ContentType.photo;
      case 'voice':
        return _ContentType.voice;
      case 'video':
        return _ContentType.video;
      case 'document':
        return _ContentType.document;
      default:
        return _ContentType.text;
    }
  }

  /// Ochiq API dagi [ChatMessageKind] ni ichki turga aylantiradi.
  static _ContentType fromKind(ChatMessageKind kind) {
    switch (kind) {
      case ChatMessageKind.text:
        return _ContentType.text;
      case ChatMessageKind.photo:
        return _ContentType.photo;
      case ChatMessageKind.voice:
        return _ContentType.voice;
      case ChatMessageKind.video:
        return _ContentType.video;
      case ChatMessageKind.file:
        return _ContentType.document;
    }
  }

  /// Ichki turni ochiq API turiga aylantiradi.
  ChatMessageKind get kind {
    switch (this) {
      case _ContentType.text:
        return ChatMessageKind.text;
      case _ContentType.photo:
        return ChatMessageKind.photo;
      case _ContentType.voice:
        return ChatMessageKind.voice;
      case _ContentType.video:
        return ChatMessageKind.video;
      case _ContentType.document:
        return ChatMessageKind.file;
    }
  }

  static _ContentType fromPath(String path) {
    final ext = _MimetypeDetector.getMimeType(path);
    final parts = ext.split('/');
    switch (parts[0]) {
      case 'image':
        return _ContentType.photo;
      case 'audio':
        return _ContentType.voice;
      case 'video':
        return _ContentType.video;
      case 'application':
        return _ContentType.document;
      default:
        return _ContentType.text;
    }
  }

  bool get isText => this == _ContentType.text;

  bool get isVoice => this == _ContentType.voice;

  bool get isVideo => this == _ContentType.video;

  bool get isDocument => this == _ContentType.document;

  bool get isPhoto => this == _ContentType.photo;
}
