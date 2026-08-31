import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:search_repository/search_repository.dart';
import 'package:user_repository/user_repository.dart';

/// People search to start a new conversation. Pops with the chosen [User];
/// the caller then opens the chat. Uses the app's own user search (so you can
/// message anyone), not just users already present in the chat backend.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  static const _background = Color(0xff191919);
  static const _debounce = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _debounceTimer;
  List<User> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final users = await context.read<SearchRepository>().searchUsers(
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _results = users.where((u) => !u.isAnonymous).toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Yangi suhbat',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ism yoki foydalanuvchi nomi',
              hintStyle: const TextStyle(color: Color(0xff687575)),
              prefixIcon: const Icon(Icons.search, color: Color(0xff687575)),
              filled: true,
              fillColor: const Color(0xff2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    ),
  );

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff728FCE)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty
              ? 'Ism bilan qidiring'
              : 'Foydalanuvchi topilmadi',
          style: const TextStyle(color: Color(0xff687575)),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 76, color: Color(0xff2A2A2A)),
      itemBuilder: (context, index) {
        final user = _results[index];
        return ListTile(
          onTap: () => Navigator.of(context).pop(user),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xff414141),
            backgroundImage: user.hasAvatar
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.hasAvatar
                ? null
                : Text(
                    user.displayFullName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          title: Text(
            user.displayFullName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '@${user.displayUsername}',
            style: const TextStyle(color: Color(0xff687575)),
          ),
        );
      },
    );
  }
}
