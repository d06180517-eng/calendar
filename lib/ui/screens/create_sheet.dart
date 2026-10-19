import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../l10n.dart';
import '../../services/media_picker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'diary_screen.dart';
import 'note_editor.dart';
import 'story_editor.dart';

Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('createWhat'),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _CreateOption(
              key: const Key('createStory'),
              icon: Icons.photo_camera_outlined,
              title: context.t('createStory'),
              subtitle: context.t('createStoryHint'),
              onTap: () {
                Navigator.pop(sheet);
                startStory(context);
              },
            ),
            _CreateOption(
              key: const Key('createNote'),
              icon: Icons.edit_note_outlined,
              title: context.t('createNote'),
              subtitle: context.t('createNoteHint'),
              onTap: () {
                Navigator.pop(sheet);
                openNoteEditor(context);
              },
            ),
            _CreateOption(
              key: const Key('createDiary'),
              icon: Icons.menu_book_outlined,
              title: context.t('createDiary'),
              subtitle: context.t('createDiaryHint'),
              onTap: () {
                Navigator.pop(sheet);
                openDiary(context, context.read<AppState>().now);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.turquoise),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    ),
  );
}

/// Выбор источника сторис, затем редактор.
Future<void> startStory(BuildContext context) async {
  final choice = await showModalBottomSheet<int>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(context.t('photoCamera')),
            onTap: () => Navigator.pop(c, 0),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text(context.t('videoCamera')),
            onTap: () => Navigator.pop(c, 1),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.t('galleryPhoto')),
            onTap: () => Navigator.pop(c, 2),
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: Text(context.t('galleryVideo')),
            onTap: () => Navigator.pop(c, 3),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final picker = MediaPicker();
  try {
    if (choice == 0 || choice == 2) {
      final m = await picker.image(camera: choice == 0);
      if (m == null || !context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => StoryEditor(media: m),
        ),
      );
    } else {
      final r = await picker.video(camera: choice == 1);
      if (r == null || !context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => StoryEditor(media: r.$1, videoDuration: r.$2),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) showSnack(context, context.t('pickFailed'));
  }
}
