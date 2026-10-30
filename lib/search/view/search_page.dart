import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:go_router/go_router.dart';
import 'package:search_repository/search_repository.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({this.withResult, super.key});

  final bool? withResult;

  @override
  Widget build(BuildContext context) {
    return SearchView(withResult: withResult ?? false);
  }
}

class SearchView extends StatelessWidget {
  const SearchView({required this.withResult, super.key});

  final bool withResult;

  @override
  Widget build(BuildContext context) {
    final search = ValueNotifier(const _SearchResults());

    return AppScaffold(
      appBar: SearcAppBar(
        onQueryChanged: (query) => search.value = _SearchResults(
          query: query,
          users: query.trim().isEmpty ? const [] : search.value.users,
          loading: query.trim().isNotEmpty,
        ),
        onUsersSearch: (query, foundUsers) =>
            search.value = _SearchResults(query: query, users: foundUsers),
      ),
      body: ValueListenableBuilder(
        valueListenable: search,
        builder: (context, search, _) {
          final users = search.users;
          if (users.isEmpty && search.query.trim().isNotEmpty) {
            return Center(
              child: search.loading
                  ? const CircularProgressIndicator.adaptive()
                  : Text(
                      context.l10n.searchNothingFoundText,
                      style: context.bodyMedium?.copyWith(
                        color: AppColors.grey,
                      ),
                    ),
            );
          }
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverList.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return UserListTile(
                    key: ValueKey(user.id),
                    user: user,
                    withResult: withResult,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// What the search screen shows: the latest query, its results so far, and
/// whether they are still loading.
class _SearchResults {
  const _SearchResults({
    this.query = '',
    this.users = const [],
    this.loading = false,
  });

  final String query;
  final List<User> users;
  final bool loading;
}

class UserListTile extends StatelessWidget {
  const UserListTile({required this.user, required this.withResult, super.key});

  final User user;
  final bool withResult;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: UserStoriesAvatar(
        resizeHeight: 156,
        author: user,
        withAdaptiveBorder: false,
        enableInactiveBorder: false,
        radius: 26,
      ),
      title: Text(user.displayUsername),
      subtitle: Text(
        user.displayFullName,
        style: context.labelLarge?.copyWith(
          fontWeight: AppFontWeight.medium,
          color: AppColors.grey,
        ),
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => withResult
          ? context.pop(user.id)
          : context.pushNamed(
              AppRoutes.userProfile.name,
              pathParameters: {'user_id': user.id},
            ),
    );
  }
}

class SearcAppBar extends StatefulWidget implements PreferredSizeWidget {
  const SearcAppBar({
    required this.onQueryChanged,
    required this.onUsersSearch,
    super.key,
  });

  /// The text changed (results for it follow in [onUsersSearch]).
  final ValueSetter<String> onQueryChanged;

  /// Results for the latest query only.
  final void Function(String query, List<User> users) onUsersSearch;

  @override
  State<SearcAppBar> createState() => _SearcAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SearcAppBarState extends State<SearcAppBar> {
  late FocusNode _focusNode;
  late TextEditingController _searchController;

  late Debouncer _debouncer;

  /// Bumped per search; a slower, older search's results are dropped instead
  /// of overwriting the newer ones.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _searchController = TextEditingController();

    _debouncer = Debouncer();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: SearchInputField(
        active: false,
        readOnly: false,
        focusNode: _focusNode,
        textController: _searchController,
        onChanged: (query) {
          // Read the repository NOW (while this element is active), not inside
          // the debounced async callback: by the time that fires the search bar
          // may be gone, and context.read on a deactivated element throws
          // "Looking up a deactivated widget's ancestor is unsafe".
          final searchRepository = context.read<SearchRepository>();
          final request = ++_request;
          widget.onQueryChanged(query);
          _debouncer.run(() async {
            final users = await searchRepository.searchUsers(query: query);
            if (!mounted || request != _request) return;
            widget.onUsersSearch.call(query, users);
          });
        },
      ),
    );
  }
}

class SearchInputField extends StatelessWidget {
  const SearchInputField({
    required this.active,
    required this.readOnly,
    this.textController,
    this.focusNode,
    this.onChanged,
    super.key,
  });

  final TextEditingController? textController;
  final FocusNode? focusNode;
  final ValueSetter<String>? onChanged;
  final bool active;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.adaptiveColor;
    const inactiveColor = AppColors.grey;

    final search = AppTextField(
      filled: true,
      focusNode: focusNode,
      readOnly: readOnly,
      autofocus: !readOnly,
      textController: textController,
      onChanged: textController == null
          ? null
          : (query) {
              onChanged?.call(query);
            },
      constraints: const BoxConstraints.tightFor(height: 40),
      onTap: !readOnly ? null : () => context.pushNamed(AppRoutes.search.name),
      hintText: context.l10n.searchText,
      prefixIcon: Icon(
        Icons.search,
        color: active ? activeColor : inactiveColor,
      ),
      // No clear (X) button — it used to appear once the field held text (e.g.
      // after returning from a profile). The search field has none by design.
      border: outlinedBorder(borderRadius: 14),
    );
    if (textController != null) {
      return ListenableBuilder(
        listenable: textController!,
        builder: (context, child) => search,
      );
    }

    return search;
  }
}
