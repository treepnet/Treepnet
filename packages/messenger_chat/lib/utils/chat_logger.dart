part of messenger_chat;

mixin _ChatLogger {
  static void failure(String message) {
    if (kReleaseMode) return;
    log('⛔️ Failure $message', name: 'MilliyChat Failure');
  }

  static void success(String message) {
    if (kReleaseMode) return;

    log('✅ Success $message', name: 'MilliyChat Success');
  }

  static void warning(String message) {
    if (kReleaseMode) return;
    log('⚠️ Warning $message', name: 'MilliyChat Warning');
  }

  static void print(String message) {
    if (kReleaseMode) return;
    log(message, name: 'MilliyChat');
  }
}
