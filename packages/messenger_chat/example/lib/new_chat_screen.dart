import 'dart:async';

import 'package:flutter/material.dart';
import 'package:messenger_chat/messenger_chat.dart';

import 'dm_api.dart';

/// Yangi suhbat boshlash ekrani.
///
/// Bu **ilova darajasidagi** ekran, plaginning bir qismi emas: kim bilan
/// yozishish mumkinligini ilova biladi (kontaktlar, do'stlar, qidiruv), plagin
/// esa faqat ochilgan suhbatni chizadi.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({required this.api, super.key});

  final DmApi api;

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();

  List<ChatUser> _users = const [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  /// Qidiruv navbati - har bir harfda so'rov yubormaslik uchun.
  static const _debounceDelay = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String query = ''}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await widget.api.dio.get<Map<String, dynamic>>(
        '/chat/dm/users',
        queryParameters: query.isEmpty ? null : {'q': query},
      );

      final items = (response.data?['data'] as List?) ?? const [];
      if (!mounted) return;

      setState(() {
        _users = items
            .whereType<Map>()
            .map(
              (json) => ChatUser(
                id: json['id']?.toString() ?? '',
                name: (json['name'] ?? '').toString(),
                avatarUrl: (json['avatar'] as String?)?.isEmpty ?? true
                    ? null
                    : json['avatar'] as String,
              ),
            )
            .where((u) => u.id.isNotEmpty)
            .toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _load(query: value.trim()));
  }

  /// Suhbat yaratadi (yoki mavjudini oladi) va uni chaqiruvchiga qaytaradi.
  Future<void> _startChat(ChatUser user) async {
    try {
      final response = await widget.api.dio.post<Map<String, dynamic>>(
        '/chat/dm/conversations',
        data: {'peerId': user.id},
      );

      final id = response.data?['id']?.toString();
      if (id == null || !mounted) return;

      Navigator.of(context).pop((id: id, peer: user));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Suhbat ochilmadi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Yangi suhbat'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    backgroundColor: Colors.white,
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Ism yoki telefon bo\'yicha qidirish',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xffF3F4F6),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(query: _searchController.text.trim()),
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(child: Text('Foydalanuvchi topilmadi'));
    }

    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          onTap: () => _startChat(user),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xff1064FF),
            backgroundImage: user.avatarUrl == null
                ? null
                : NetworkImage(user.avatarUrl!),
            child: user.avatarUrl != null
                ? null
                : Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          title: Text(
            user.name.isEmpty ? user.id : user.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}
