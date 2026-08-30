part of messenger_chat;

mixin _MimetypeDetector {
  static String getMimeType(String path) {
    return lookupMimeType(path) ?? 'application/octet-stream';
  }
}
