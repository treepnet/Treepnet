import 'package:authentication_client/authentication_client.dart';
import 'package:database_client/database_client.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

/// {@template user_repository}
/// A package that manages user flow.
/// {@endtemplate}
class UserRepository implements UserBaseRepository {
  /// {@macro user_repository}
  const UserRepository({
    required DatabaseClient databaseClient,
    required AuthenticationClient authenticationClient,
  })  : _databaseClient = databaseClient,
        _authenticationClient = authenticationClient;

  final DatabaseClient _databaseClient;
  final AuthenticationClient _authenticationClient;

  /// Stream of [User] which will emit the current user when the authentication
  /// state changes.
  ///
  /// The identity provider only knows who someone is (id, email, display
  /// name) — their handle, bio, links and avatar live on the `profiles` row.
  /// So the auth user is emitted first (so the app can route immediately) and
  /// then replaced by the profile as soon as it is available.
  ///
  /// `switchMap`, not `asyncExpand`: the profile is a `watch()` that never
  /// completes, and `asyncExpand` waits for each inner stream to finish before
  /// handling the next auth event — which swallowed the sign-out and left the
  /// app stuck as the signed-in user.
  Stream<User> get user => _authenticationClient.user
      .switchMap<User>((AuthenticationUser authUser) {
        final base = User.fromAuthenticationUser(authenticationUser: authUser);
        if (authUser.isAnonymous) return Stream.value(base);
        // Until the row syncs, keep showing the identity we already have.
        return _databaseClient
            .profile(id: authUser.id)
            .map((profile) => profile.isAnonymous ? base : profile)
            .startWith(base);
      })
      .asBroadcastStream();

  /// Starts the Sign In with Google Flow.
  ///
  /// Throws a [LogInWithGoogleCanceled] if the flow is canceled by the user.
  /// Throws a [LogInWithGoogleFailure] if an exception occurs.
  Future<void> logInWithGoogle() async {
    try {
      await _authenticationClient.logInWithGoogle();
    } on LogInWithGoogleFailure {
      rethrow;
    } on LogInWithGoogleCanceled {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogInWithGoogleFailure(error), stackTrace);
    }
  }

  /// Starts the Sign In with Github Flow.
  ///
  /// Throws a [LogInWithGithubCanceled] if the flow is canceled by the user.
  /// Throws a [LogInWithGithubFailure] if an exception occurs.
  Future<void> logInWithGithub() async {
    try {
      await _authenticationClient.logInWithGithub();
    } on LogInWithGithubFailure {
      rethrow;
    } on LogInWithGithubCanceled {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogInWithGithubFailure(error), stackTrace);
    }
  }

  /// Signs out the current user which will emit
  /// [User.anonymous] from the [user] Stream.
  ///
  /// Throws a [LogOutFailure] if an exception occurs.
  Future<void> logOut() async {
    try {
      await _authenticationClient.logOut();
    } on LogOutFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogOutFailure(error), stackTrace);
    }
  }

  /// Logins in with the provided [password].
  Future<void> logInWithPassword({
    required String password,
    String? email,
    String? phone,
  }) async {
    try {
      await _authenticationClient.logInWithPassword(
        email: email,
        phone: phone,
        password: password,
      );
    } on LogInWithPasswordFailure {
      rethrow;
    } on LogInWithPasswordCanceled {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogInWithPasswordFailure(error), stackTrace);
    }
  }

  /// Sign up with the provided [password].
  Future<void> signUpWithPassword({
    required String password,
    required String fullName,
    required String username,
    String? avatarUrl,
    String? email,
    String? phone,
    String? pushToken,
  }) async {
    try {
      await _authenticationClient.signUpWithPassword(
        email: email,
        phone: phone,
        password: password,
        fullName: fullName,
        username: username,
        avatarUrl: avatarUrl,
        pushToken: pushToken,
      );
    } on SignUpWithPasswordFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SignUpWithPasswordFailure(error), stackTrace);
    }
  }

  /// Whether [username] is still free to claim.
  Future<bool> isUsernameAvailable(String username) =>
      _authenticationClient.isUsernameAvailable(username);

  /// Starts the code-based sign-up: registers the pending account and emails a
  /// one-time code. Returns the continuation token and expected code length.
  Future<({String continuationToken, int codeLength})> signUpSendCode({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      return await _authenticationClient.signUpSendCode(
        email: email,
        password: password,
        fullName: fullName,
      );
    } on SignUpWithPasswordFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SignUpWithPasswordFailure(error), stackTrace);
    }
  }

  /// Completes the code-based sign-up: verifies the emailed [code], signs in
  /// and provisions the profile.
  Future<void> signUpVerifyCode({
    required String continuationToken,
    required String code,
    required String email,
    required String password,
    required String username,
    required String fullName,
    String? birthday,
  }) async {
    try {
      await _authenticationClient.signUpVerifyCode(
        continuationToken: continuationToken,
        code: code,
        email: email,
        password: password,
        username: username,
        fullName: fullName,
        birthday: birthday,
      );
    } on SignUpWithPasswordFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SignUpWithPasswordFailure(error), stackTrace);
    }
  }

  /// Sends a password reset email to the provided [email].
  /// Optionally allows specifying a [redirectTo] url to redirect
  /// the user to after resetting their password.
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _authenticationClient.sendPasswordResetEmail(
        email: email,
        redirectTo: redirectTo,
      );
    } on SendPasswordResetEmailFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SendPasswordResetEmailFailure(error),
        stackTrace,
      );
    }
  }

  /// Starts a password reset for [usernameOrEmail] and emails a one-time code.
  Future<({String continuationToken, int codeLength})> resetPasswordSendCode({
    required String usernameOrEmail,
  }) async {
    try {
      return await _authenticationClient.resetPasswordSendCode(
        usernameOrEmail: usernameOrEmail,
      );
    } on ResetPasswordFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(ResetPasswordFailure(error), stackTrace);
    }
  }

  /// Verifies the emailed [code] and sets [newPassword].
  Future<void> resetPasswordSubmit({
    required String continuationToken,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _authenticationClient.resetPasswordSubmit(
        continuationToken: continuationToken,
        code: code,
        newPassword: newPassword,
      );
    } on ResetPasswordFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(ResetPasswordFailure(error), stackTrace);
    }
  }

  /// Resets the password for the user with the given [email]
  /// using the provided [token]. Updates the password to
  /// the new [newPassword].
  Future<void> resetPassword({
    required String token,
    required String email,
    required String newPassword,
  }) async {
    try {
      await _authenticationClient.resetPassword(
        token: token,
        email: email,
        newPassword: newPassword,
      );
    } on ResetPasswordFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(ResetPasswordFailure, stackTrace);
    }
  }

  @override
  String? get currentUserId => _databaseClient.currentUserId;

  @override
  Stream<User> profile({required String id}) => _databaseClient.profile(id: id);

  /// Presence heartbeat for [userId] (stamps `last_seen_at` = now).
  Future<void> updatePresence({required String userId}) =>
      _databaseClient.updatePresence(userId: userId);

  /// Realtime `last_seen_at` of [userId].
  Stream<DateTime?> lastSeenOf({required String userId}) =>
      _databaseClient.lastSeenOf(userId: userId);

  /// Profiles [userId] has saved (bookmarked), newest first.
  Stream<List<User>> savedProfilesOf({required String userId}) =>
      _databaseClient.savedProfilesOf(userId: userId);

  /// Whether [userId] has saved [profileId].
  Stream<bool> isProfileSaved({
    required String userId,
    required String profileId,
  }) =>
      _databaseClient.isProfileSaved(userId: userId, profileId: profileId);

  /// Saves [profileId] to [userId]'s saved profiles.
  Future<void> saveProfile({
    required String userId,
    required String profileId,
  }) =>
      _databaseClient.saveProfile(userId: userId, profileId: profileId);

  /// Removes [profileId] from [userId]'s saved profiles.
  Future<void> unsaveProfile({
    required String userId,
    required String profileId,
  }) =>
      _databaseClient.unsaveProfile(userId: userId, profileId: profileId);

  @override
  Stream<int> followersCountOf({required String userId}) =>
      _databaseClient.followersCountOf(userId: userId);

  @override
  Stream<int> followingsCountOf({required String userId}) =>
      _databaseClient.followingsCountOf(userId: userId);

  @override
  Stream<int> referralCountOf({required String userId}) =>
      _databaseClient.referralCountOf(userId: userId);

  @override
  Stream<int> referralTierOf({required String userId}) =>
      _databaseClient.referralTierOf(userId: userId);

  /// The user's verification badge tier (0-6), earned by inviting people.
  Stream<int> travelTierOf({required String userId}) =>
      _databaseClient.travelTierOf(userId: userId);

  /// Live badge state — invites, tier, expiry and the next rung.
  Stream<InviteBadgeStatus> inviteBadgeStatusOf({required String userId}) =>
      _databaseClient.inviteBadgeStatusOf(userId: userId);

  @override
  Stream<Set<String>> markedRegionsOf({required String userId}) =>
      _databaseClient.markedRegionsOf(userId: userId);

  @override
  Stream<List<StoryHighlight>> storyHighlightsOf({required String userId}) =>
      _databaseClient.storyHighlightsOf(userId: userId);

  @override
  Stream<List<Story>> highlightStoriesOf({required String highlightId}) =>
      _databaseClient.highlightStoriesOf(highlightId: highlightId);

  @override
  Future<void> createStoryHighlight({
    required String userId,
    required String name,
    required List<String> storyIds,
    String? coverUrl,
  }) => _databaseClient.createStoryHighlight(
    userId: userId,
    name: name,
    storyIds: storyIds,
    coverUrl: coverUrl,
  );

  @override
  Future<void> deleteStoryHighlight({required String highlightId}) =>
      _databaseClient.deleteStoryHighlight(highlightId: highlightId);

  @override
  Future<void> addStoryToHighlight({
    required String highlightId,
    required String storyId,
  }) => _databaseClient.addStoryToHighlight(
    highlightId: highlightId,
    storyId: storyId,
  );

  @override
  Future<void> setStoryLocation({
    required String storyId,
    required double lat,
    required double lng,
    String? name,
  }) => _databaseClient.setStoryLocation(
    storyId: storyId,
    lat: lat,
    lng: lng,
    name: name,
  );

  @override
  Future<bool> isStoryPinned({required String storyId}) =>
      _databaseClient.isStoryPinned(storyId: storyId);

  @override
  Future<void> unpinStoryEverywhere({required String storyId}) =>
      _databaseClient.unpinStoryEverywhere(storyId: storyId);

  @override
  Future<void> setVisitedRegions({
    required String userId,
    required Set<String> regionIsos,
  }) => _databaseClient.setVisitedRegions(
    userId: userId,
    regionIsos: regionIsos,
  );

  @override
  Future<String> redeemReferral({required String handle}) =>
      _databaseClient.redeemReferral(handle: handle);

  /// Permanently deletes the signed-in account.
  ///
  /// [password] is re-checked against the identity provider first: a stolen,
  /// unlocked phone must not be able to erase an account without the password.
  /// A wrong password throws [LogInWithPasswordFailure] and nothing is deleted.
  /// On success every owned row is removed server-side and the session is
  /// signed out, dropping the app back to the login screen.
  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    // Verify the password by re-authenticating; this throws on a wrong one.
    await logInWithPassword(email: email, password: password);
    await _databaseClient.deleteAccount();
    // Remove the auth-provider user too (and sign out), not just sign out.
    await _authenticationClient.deleteAuthUser();
  }

  @override
  Stream<List<NotificationItem>> notificationsOf({required String userId}) =>
      _databaseClient.notificationsOf(userId: userId);

  @override
  Stream<int> unreadNotificationsCount({required String userId}) =>
      _databaseClient.unreadNotificationsCount(userId: userId);

  @override
  Future<void> markNotificationsSeen({required String userId}) =>
      _databaseClient.markNotificationsSeen(userId: userId);

  @override
  Future<List<User>> getFollowers({String? userId}) =>
      _databaseClient.getFollowers(userId: userId);

  @override
  Future<List<User>> getFollowings({String? userId}) =>
      _databaseClient.getFollowings(userId: userId);

  @override
  Future<void> follow({
    required String followToId,
    String? followerId,
  }) =>
      _databaseClient.follow(
        followToId: followToId,
        followerId: followerId,
      );

  @override
  Future<void> removeFollower({required String id}) =>
      _databaseClient.removeFollower(id: id);

  @override
  Future<void> unfollow({required String unfollowId, String? unfollowerId}) =>
      _databaseClient.unfollow(
        unfollowId: unfollowId,
        unfollowerId: unfollowerId,
      );

  @override
  Future<bool> isFollowed({
    required String userId,
    String? followerId,
  }) =>
      _databaseClient.isFollowed(followerId: followerId, userId: userId);

  @override
  Stream<bool> followingStatus({
    required String userId,
    String? followerId,
  }) =>
      _databaseClient.followingStatus(followerId: followerId, userId: userId);

  @override
  Stream<String> followState({required String userId, String? followerId}) =>
      _databaseClient.followState(userId: userId, followerId: followerId);

  @override
  Future<void> acceptFollowRequest({required String requesterId}) =>
      _databaseClient.acceptFollowRequest(requesterId: requesterId);

  @override
  Future<void> declineFollowRequest({required String requesterId}) =>
      _databaseClient.declineFollowRequest(requesterId: requesterId);

  @override
  Future<void> updateUser({
    String? fullName,
    String? email,
    String? username,
    String? avatarUrl,
    String? pushToken,
    String? bio,
    String? birthday,
    String? telegram,
    String? website,
    String? instagram,
    String? gender,
    bool clearAvatar = false,
  }) =>
      _databaseClient.updateUser(
        fullName: fullName,
        email: email,
        username: username,
        avatarUrl: avatarUrl,
        pushToken: pushToken,
        bio: bio,
        birthday: birthday,
        telegram: telegram,
        website: website,
        instagram: instagram,
        gender: gender,
        clearAvatar: clearAvatar,
      );

  @override
  Future<void> updateUserBio({required String userId, required String bio}) =>
      _databaseClient.updateUserBio(userId: userId, bio: bio);

  @override
  Future<void> completeOnboarding() => _databaseClient.completeOnboarding();

  @override
  Future<void> blockUser({
    required String userId,
    required String blockedId,
  }) =>
      _databaseClient.blockUser(userId: userId, blockedId: blockedId);

  @override
  Future<void> unblockUser({
    required String userId,
    required String blockedId,
  }) =>
      _databaseClient.unblockUser(userId: userId, blockedId: blockedId);

  @override
  Stream<bool> isBlocked({
    required String userId,
    required String otherUserId,
  }) =>
      _databaseClient.isBlocked(userId: userId, otherUserId: otherUserId);

  @override
  Stream<List<User>> blockedUsers({required String userId}) =>
      _databaseClient.blockedUsers(userId: userId);

  @override
  Future<void> changePassword({required String newPassword}) =>
      _databaseClient.changePassword(newPassword: newPassword);

  @override
  Future<void> updatePrivacy({
    required String userId,
    required bool isPrivate,
  }) =>
      _databaseClient.updatePrivacy(userId: userId, isPrivate: isPrivate);

  @override
  Future<List<User>> searchUsers({
    required int limit,
    required int offset,
    required String? query,
    String? userId,
    String? excludeUserIds,
  }) =>
      _databaseClient.searchUsers(
        userId: userId,
        limit: limit,
        offset: offset,
        query: query,
        excludeUserIds: excludeUserIds,
      );

  @override
  Future<List<User>> suggestedUsers({int limit = 50}) =>
      _databaseClient.suggestedUsers(limit: limit);

  @override
  Stream<List<User>> followers({required String userId}) =>
      _databaseClient.followers(userId: userId);
}
