import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/media_picker.dart';
import '../widgets/common.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name, _nick, _bio, _city, _link;
  DateTime? _birthday;
  List<int>? _avatar;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().me!;
    _name = TextEditingController(text: u.name);
    _nick = TextEditingController(text: u.nick);
    _bio = TextEditingController(text: u.bio);
    _city = TextEditingController(text: u.city);
    _link = TextEditingController(text: u.link);
    _birthday = u.birthday;
    _avatar = u.avatarBytes;
  }

  @override
  void dispose() {
    for (final c in [_name, _nick, _bio, _city, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final m = await MediaPicker().image();
      if (m?.bytes != null) setState(() => _avatar = m!.bytes);
    } catch (_) {
      if (mounted) showSnack(context, context.t('pickFailed'));
    }
  }

  void _save() {
    final s = context.read<AppState>();
    final nick = _nick.text.trim().replaceAll('@', '').replaceAll(' ', '');
    if (nick.isEmpty) {
      setState(() => _error = context.t('emptyNick'));
      return;
    }
    if (s.users.values.any((u) => u.id != s.currentUserId && u.nick == nick)) {
      setState(() => _error = context.t('nickTaken'));
      return;
    }
    s.updateProfile((u) {
      u
        ..name = _name.text.trim().isEmpty ? nick : _name.text.trim()
        ..nick = nick
        ..bio = _bio.text.trim()
        ..city = _city.text.trim()
        ..link = _link.text.trim()
        ..birthday = _birthday
        ..avatarBytes = _avatar;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final preview = s.me!;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('editProfile')),
        actions: [TextButton(onPressed: _save, child: Text(context.t('save')))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Avatar(
                  user: AppUser(
                    id: preview.id,
                    name: preview.name,
                    nick: preview.nick,
                    avatarColor: preview.avatarColor,
                    avatarBytes: _avatar,
                  ),
                  size: 88,
                ),
                TextButton(
                  onPressed: _pickAvatar,
                  child: Text(context.t('changePhoto')),
                ),
              ],
            ),
          ),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: context.t('name')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nick,
            decoration: InputDecoration(
              labelText: context.t('nick'),
              prefixText: '@',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLength: 150,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: context.t('bio')),
          ),
          TextField(
            controller: _city,
            decoration: InputDecoration(labelText: context.t('city')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: context.t('link')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.cake_outlined),
            label: Text(
              _birthday == null
                  ? context.t('birthday')
                  : '${context.t('birthday')}: ${formatDate(context, _birthday!)}',
            ),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _birthday ?? DateTime(2000, 1, 1),
                firstDate: DateTime(1920),
                lastDate: s.now,
              );
              if (d != null) setState(() => _birthday = d);
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
