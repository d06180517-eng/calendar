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
import 'story_overlays.dart';

/// Выбранный день: сторис (и текстовые), планы и дневник-канал.
/// Своё можно дописывать, у других — только смотреть открытое.
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
    final plans = s.plansOfDay(ownerId, day);
    final today = dateOnly(s.now);
    final future = dateOnly(day).isAfter(today);
    final text = Theme.of(context).textTheme;
    final weather = diary
        .map((p) => p.weather)
        .whereType<Weather>()
        .firstOrNull;

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
              if (weather != null)
                Text(formatWeather(weather), style: text.titleSmall),
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
                      StoryThumb(story: stories[i], size: 68),
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
          for (final p in plans) PlanTile(plan: p),
          if (own && !dateOnly(day).isBefore(today))
            _AddButton(
              key: const Key('addNote'),
              icon: future ? Icons.event_outlined : Icons.add,
              label: context.t(future ? 'notePlan' : 'addNote'),
              onTap: () => openNoteEditor(context, day: day),
            ),
          if (!future) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.t('diaryDay'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (diary.isNotEmpty)
                  Text(
                    context.t('postsCount', {'n': '${diary.length}'}),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final p
                in diary.length > 3 ? diary.sublist(diary.length - 3) : diary)
              DiaryPostBubble(post: p, compact: true),
            if (own || diary.isNotEmpty)
              _AddButton(
                key: const Key('openDiary'),
                icon: own ? Icons.edit_outlined : Icons.menu_book_outlined,
                label: context.t(own ? 'diaryWrite' : 'openDiary'),
                onTap: () => openDiary(context, ownerId, day),
              ),
          ],
          if (!own && stories.isEmpty && diary.isEmpty && plans.isEmpty)
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

class PlanTile extends StatelessWidget {
  const PlanTile({super.key, required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final own = plan.authorId == s.currentUserId;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: own ? () => openNoteEditor(context, plan: plan) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  plan.remind
                      ? Icons.notifications_active_outlined
                      : Icons.event_outlined,
                  size: 20,
                  color: AppColors.turquoise,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.t('notePlan')} · ${hhmm(plan.planAt)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(plan.text),
                    ],
                  ),
                ),
                if (own)
                  Icon(
                    audienceIcon(plan.visibility),
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
