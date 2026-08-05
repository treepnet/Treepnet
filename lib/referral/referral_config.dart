/// One place for the invite domain and link shapes, so a new domain (or a
/// change from `treepnet.com`) is a single edit that flows to the app-link
/// filter comment, the share text and the parser.
abstract class ReferralConfig {
  /// The domain that will host the smart invite page + assetlinks.json /
  /// apple-app-site-association. **Update here once the real domain is bought.**
  static const domain = 'treepnet.com';

  /// Custom scheme that always opens an already-installed app.
  static const scheme = 'treepnet';

  /// The shareable HTTPS invite for [handle], e.g.
  /// `https://treepnet.com/invite/aziz`.
  static String inviteUrl(String handle) => 'https://$domain/invite/$handle';

  /// Pulls `<handle>` out of any invite form:
  ///   * `https://<domain>/invite/<handle>`
  ///   * `treepnet://invite/<handle>`
  ///   * an install-referrer string like `treepnet_invite=<handle>` or
  ///     `utm_content=<handle>` (Play Store passes these through verbatim).
  static String? handleFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final inviteIndex = segments.indexOf('invite');
    if (inviteIndex != -1 && inviteIndex + 1 < segments.length) {
      return _clean(segments[inviteIndex + 1]);
    }
    if (uri.host == 'invite' && segments.isNotEmpty) {
      return _clean(segments.first);
    }
    return null;
  }

  /// Pulls a handle from a raw Play Store install-referrer query string.
  static String? handleFromReferrer(String? referrer) {
    if (referrer == null || referrer.isEmpty) return null;
    // The referrer is url-encoded key=value pairs joined by '&'.
    final params = Uri.splitQueryString(referrer);
    final value = params['treepnet_invite'] ?? params['utm_content'];
    return _clean(value);
  }

  static String? _clean(String? v) {
    final trimmed = v?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
