import 'package:authentication_client/authentication_client.dart';
import 'package:shared/shared.dart';

/// {@template user}
/// User model represents the current user.
/// {@endtemplate}
class User extends AuthenticationUser {
  /// {@macro user}
  const User({
    required super.id,
    super.email,
    super.username,
    super.fullName,
    super.avatarUrl,
    super.pushToken,
    super.isNewUser,
    this.bio,
    this.isPrivate = false,
    this.birthday,
    this.telegram,
    this.website,
    this.instagram,
    this.gender,
    this.onboardedAt,
  });

  /// Converts an [AuthenticationUser] instance to [User].
  factory User.fromAuthenticationUser({
    required AuthenticationUser authenticationUser,
  }) =>
      User(
        email: authenticationUser.email,
        id: authenticationUser.id,
        username: authenticationUser.username,
        fullName: authenticationUser.fullName,
        avatarUrl: authenticationUser.avatarUrl,
        pushToken: authenticationUser.pushToken,
        isNewUser: authenticationUser.isNewUser,
      );

  /// Converts a `Map<String, dynamic>` json to a [User] instance.
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['user_id'] as String? ?? json['id'] as String,
        email: json['email'] as String?,
        username: json['username'] as String?,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        pushToken: json['push_token'] as String?,
        bio: json['bio'] as String?,
        isPrivate: json['is_private'] == true || json['is_private'] == 1,
        birthday: json['birthday'] as String?,
        telegram: json['telegram'] as String?,
        website: json['website'] as String?,
        instagram: json['instagram'] as String?,
        gender: json['gender'] as String?,
        onboardedAt: json['onboarded_at'] as String?,
        isNewUser: false,
      );

  /// Converts a `Map<String, dynamic>` to a [User] instance.
  factory User.fromParticipant(Map<String, dynamic> participant) => User(
        id: participant['participant_id'] as String,
        avatarUrl: participant['participant_avatar_url'] as String?,
        fullName: participant['participant_name'] as String?,
        email: participant['participant_email'] as String?,
        username: participant['participant_username'] as String?,
        pushToken: participant['participant_push_token'] as String?,
      );

  /// The user's short profile bio / "About" text.
  final String? bio;

  /// Whether this is a private account (content hidden from non-followers).
  final bool isPrivate;

  /// Date of birth, as an ISO `yyyy-MM-dd` date.
  final String? birthday;

  /// Telegram handle, stored without the `t.me/` prefix.
  final String? telegram;

  /// Personal or company site.
  final String? website;

  /// Instagram handle, stored without the leading `@`.
  final String? instagram;

  /// Self-described gender; free text so it isn't a forced choice.
  final String? gender;

  /// When the user finished onboarding (ISO 8601), or null if they never has.
  ///
  /// Lives on the profile rather than on the device so that reinstalling or
  /// switching phones doesn't show the intro again.
  final String? onboardedAt;

  /// Whether the intro still has to be shown.
  ///
  /// Only meaningful once the profile row has loaded — see [hasProfile]; the
  /// auth-only user this stream emits first has no columns to judge by.
  bool get needsOnboarding => hasProfile && onboardedAt == null;

  /// Whether this user carries its `profiles` row, as opposed to being the
  /// identity-only user emitted while that row is still syncing.
  bool get hasProfile => username != null;

  /// Whether a profile photo is set. An empty string counts as unset — that is
  /// what the avatar widget falls back on.
  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        ...super.props,
        bio,
        isPrivate,
        birthday,
        telegram,
        website,
        instagram,
        gender,
        onboardedAt,
      ];

  /// Whether the current user is anonymous.
  @override
  bool get isAnonymous => this == anonymous;

  /// Anonymous user which represents an unauthenticated user.
  static const User anonymous = User(id: '');

  /// The effective full name display without null aware operators.
  /// Empty strings (the DB default for `full_name`) fall back to the username.
  /// By default no existing name value is `Unknown`.
  String get displayFullName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return 'Unknown';
  }

  /// The effective user name display without null aware operators.
  /// By default no existing name value is `Unknown`.
  String get displayUsername {
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Unknown';
  }

  /// Converts current [User] instance to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (email != null) 'email': email,
      'user_id': id,
      if (username != null) 'username': username,
      if (fullName != null) 'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (pushToken != null) 'push_token': pushToken,
      if (bio != null) 'bio': bio,
      'is_private': isPrivate,
      'is_new_user': isNewUser,
    };
  }
}

/// Extension that converts [PostAuthor] into [User] instance.
extension UserX on PostAuthor {
  /// Converts a [PostAuthor] into a [User] instance.
  User get toUser => User(
        id: id,
        avatarUrl: avatarUrl,
        username: username,
      );
}
