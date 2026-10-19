import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../l10n.dart';
import '../../services/reminder_service.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _reschedule(BuildContext context) {
    final s = context.read<AppState>();
    return context.read<ReminderService>().scheduleDiary(
      s.diaryReminderOn,
      s.diaryReminderTime,
      context.t('diaryReminderTitle'),
      context.t('diaryReminderBody'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final blocked = (s.blocked[s.currentUserId] ?? <String>{}).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('settings'))),
      body: ListView(
        children: [
          _Section(context.t('theme')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(context.t('themeSystem')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(context.t('themeLight')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(context.t('themeDark')),
                ),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ),
          _Section(context.t('language')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: '', label: Text(context.t('langSystem'))),
                const ButtonSegment(value: 'ru', label: Text('Русский')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {s.languageCode ?? ''},
              onSelectionChanged: (v) =>
                  s.setLanguage(v.first.isEmpty ? null : v.first),
            ),
          ),
          _Section(context.t('diary')),
          SwitchListTile(
            value: s.diaryReminderOn,
            title: Text(context.t('diaryReminder')),
            subtitle: Text(s.diaryReminderTime.format(context)),
            onChanged: (v) {
              s.setDiaryReminder(on: v);
              _reschedule(context);
            },
          ),
          ListTile(
            enabled: s.diaryReminderOn,
            leading: const Icon(Icons.schedule),
            title: Text(context.t('planTime')),
            trailing: Text(s.diaryReminderTime.format(context)),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: s.diaryReminderTime,
              );
              if (t != null && context.mounted) {
                s.setDiaryReminder(time: t);
                _reschedule(context);
              }
            },
          ),
          _Section(context.t('privateProfile')),
          SwitchListTile(
            key: const Key('privateSwitch'),
            value: s.me!.isPrivate,
            title: Text(context.t('privateProfile')),
            subtitle: Text(context.t('privateToggleText')),
            onChanged: s.setPrivate,
          ),
          if (blocked.isNotEmpty) ...[
            _Section(context.t('blockedList')),
            for (final id in blocked)
              UserTile(
                user: s.user(id),
                onTap: () => openProfile(context, id),
                trailing: TextButton(
                  onPressed: () => s.unblock(id),
                  child: Text(context.t('unblock')),
                ),
              ),
          ],
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(
              context.t('logout'),
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              if (await confirm(
                context,
                context.t('logoutQ'),
                ok: context.t('logout'),
              )) {
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
                s.logout();
              }
            },
          ),
          if (s.backend == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.t('demoNote'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
