import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/weather_service.dart';
import '../screens/diary_screen.dart';
import '../screens/note_editor.dart';
import '../screens/story_viewer.dart';
import '../theme.dart';
import 'common.dart';

/// Выбранный день: сторис, дневник и пометки. Своё можно править,
/// у других — только смотреть открытое.
class DayPanel extends StatelessWidget {
  const DayPanel({super.key, required this.ownerId, required this.day});
  final String ownerId;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final own = ownerId == s.currentUserId;
    final stories = s.storiesOfDay(ownerId, day);
    final diary = s.diaryOf(ownerId, day);
    final notes = s.notesOfDay(ownerId, day);
    final future = dateOnly(day).isAfter(dateOnly(s.now));
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  capitalize(formatDateFull(context, day)),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (diary?.weather != null)
                Text(formatWeather(diary!.weather!), style: text.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          if (stories.isNotEmpty) ...[
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => openStories(context, stories, start: i),
                  child: Stack(
                    children: [
                      MediaThumb(media: stories[i].media, size: 68, radius: 14),
                      if (own && stories[i].visibility != Audience.everyone)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Icon(
                            audienceIcon(stories[i].visibility),
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (diary != null)
            DiaryCard(entry: diary)
          else if (own && !future)
            _AddButton(
              key: const Key('writeDiary'),
              icon: Icons.menu_book_outlined,
              label: context.t('writeAboutDay'),
              onTap: () => openDiary(context, day),
            ),
          const SizedBox(height: 8),
          for (final n in notes) NoteTile(note: n),
          if (own)
            _AddButton(
              key: const Key('addNote'),
              icon: Icons.add,
              label: context.t('addNote'),
              onTap: () => openNoteEditor(context, day: day),
            ),
          if (!own && stories.isEmpty && diary == null && notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.t('nothingVisible'),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.turquoise),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiaryCard extends StatelessWidget {
  const DiaryCard({super.key, required this.entry});
  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moodC = entry.mood == null ? null : moodColor(entry.mood!);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openDiary(context, entry.date, entry: entry),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: moodC == null || entry.mood == Mood.neutral
                      ? scheme.outlineVariant
                      : moodC,
                  width: 5,
                ),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      context.t('diary'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      audienceIcon(entry.visibility),
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.tags.join(' '),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.turquoise,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (entry.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (entry.photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in entry.photos)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: MediaThumb(media: p, size: 48, radius: 8),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final own = note.authorId == s.currentUserId;
    final scheme = Theme.of(context).colorScheme;
    final time = note.planAt ?? note.createdAt;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: own ? () => openNoteEditor(context, note: note) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          NoteChip(template: note.template),
                          const SizedBox(width: 8),
                          Text(
                            hhmm(time),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          if (note.remind) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.notifications_active_outlined,
                              size: 14,
                              color: AppColors.turquoise,
                            ),
                          ],
                          if (own) ...[
                            const SizedBox(width: 6),
                            Icon(
                              audienceIcon(note.visibility),
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(note.text),
                    ],
                  ),
                ),
                if (note.photo != null) ...[
                  const SizedBox(width: 10),
                  MediaThumb(media: note.photo!, size: 52),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
