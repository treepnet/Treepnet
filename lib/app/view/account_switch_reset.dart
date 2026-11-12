import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:search_repository/search_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/feed.dart';

/// Invisible: when another account is signed in (or no one), forgets what the
/// last one saw. The feed's bloc lives above the router for the whole run, so
/// after A signed out and B signed in here, B first got A's feed (private
/// accounts A follows included), and search answered from A's cached results.
class AccountSwitchReset extends StatelessWidget {
  const AccountSwitchReset({super.key});

  @override
  Widget build(BuildContext context) => BlocListener<AppBloc, AppState>(
    listenWhen: (previous, current) => previous.user.id != current.user.id,
    listener: (context, _) {
      context.read<FeedBloc>().add(const FeedResetRequested());
      context.read<SearchRepository>().clearCache();
    },
    child: const SizedBox.shrink(),
  );
}
