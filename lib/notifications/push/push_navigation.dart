import 'package:go_router/go_router.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chat/open_chat.dart';

/// Opens what a tapped push notification is about: the chat for a message,
/// the post for a like or a comment, the person for a follow. Call it once
/// the user is signed in; anything it doesn't recognise just leaves the app
/// open where it is.
Future<void> openFromNotification(Map<String, String> data) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  String? id(String key) {
    final value = data[key];
    return value == null || value.isEmpty ? null : value;
  }

  switch (data['type']) {
    case 'dm':
      final peer = id('peerUuid');
      if (peer == null) return;
      await openChat(
        context,
        peerUuid: peer,
        peerName: id('peerName') ?? id('title') ?? '',
      );
    case 'like' || 'comment':
      final post = id('post_id');
      if (post == null) return;
      await context.pushNamed(
        AppRoutes.post.name,
        pathParameters: {'id': post},
      );
    case 'follow' || 'follow_request':
      final actor = id('actor_id');
      if (actor == null) return;
      await context.pushNamed(
        AppRoutes.userProfile.name,
        pathParameters: {'user_id': actor},
      );
  }
}
