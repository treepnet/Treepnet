/// Configuration for the self-hosted messenger chat backend (Node + Express +
/// Socket.IO on OCI). These are client-side values embedded in the app:
///
/// * [chatBaseUrl]  — REST + Socket.IO origin. `chat.treepnet.com` once the DNS
///   A-record is added; the sslip.io host works meanwhile without DNS.
/// * [chatAppName]  — the `x-app` header. Identifies this app to the backend.
/// * [chatApiKey]   — the `x-app-key` header. A *project* key (public, not a
///   secret): it only scopes requests to the treepnet project.
///
/// All three can be overridden at build time, e.g. for staging:
///   flutter run --dart-define=CHAT_BASE_URL=https://chat.treepnet.com
library;

const String chatBaseUrl = String.fromEnvironment(
  'CHAT_BASE_URL',
  defaultValue: 'https://chat.130-61-138-104.sslip.io',
);

const String chatAppName = String.fromEnvironment(
  'CHAT_APP_NAME',
  defaultValue: 'treepnet',
);

const String chatApiKey = String.fromEnvironment(
  'CHAT_API_KEY',
  defaultValue: 'ee4ba2b2d34f9a1f7896bdf6bbd53b8da94b40b40d3c5c04',
);
