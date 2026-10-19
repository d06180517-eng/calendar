import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../theme.dart';
import 'media_view.dart';

/// Месяц с квадратиками дней. Дни со сторис показывают превью.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.ownerId,
    required this.selected,
    required this.onSelect,
    this.onOpenStories,
  });

  final String ownerId;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final void Function(DateTime day, List<Story> stories)? onOpenStories;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  static const _base = 1200; // индекс страницы «текущий месяц»
  late final PageController _pages;
  late DateTime _origin;
  int _page = _base;

  @override
  void initState() {
    super.initState();
    final n = context.read<AppState>().now;
    _origin = DateTime(n.year, n.month);
    final sel = widget.selected;
    _page = _base + (sel.year - _origin.year) * 12 + sel.month - _origin.month;
    _pages = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime _monthAt(int page) =>
      DateTime(_origin.year, _origin.month + page - _base);

  @override
  Widget build(BuildContext context) {
    final month = _monthAt(_page);
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth - 24 - 6 * 6) / 7;
        final gridHeight = cell * 6 + 5 * 6;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      capitalize(formatMonthYear(context, month)),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('prevMonth'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _pages.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('nextMonth'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _pages.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final w in weekdayShort(context))
                    Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: gridHeight,
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, p) => _MonthGrid(
                  month: _monthAt(p),
                  cell: cell,
                  ownerId: widget.ownerId,
                  selected: widget.selected,
                  onSelect: widget.onSelect,
                  onOpenStories: widget.onOpenStories,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.cell,
    required this.ownerId,
    required this.selected,
    required this.onSelect,
    this.onOpenStories,
  });

  final DateTime month;
  final double cell;
  final String ownerId;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final void Function(DateTime day, List<Story> stories)? onOpenStories;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // неделя с понедельника
    final days = DateTime(month.year, month.month + 1, 0).day;
    final today = dateOnly(s.now);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < lead; i++) SizedBox(width: cell, height: cell),
          for (var d = 1; d <= days; d++)
            _DayCell(
              day: DateTime(month.year, month.month, d),
              size: cell,
              ownerId: ownerId,
              isToday: sameDay(today, DateTime(month.year, month.month, d)),
              isSelected: sameDay(
                selected,
                DateTime(month.year, month.month, d),
              ),
              onTap: () {
                final day = DateTime(month.year, month.month, d);
                final st = s.storiesOfDay(ownerId, day);
                if (sameDay(selected, day) &&
                    st.isNotEmpty &&
                    onOpenStories != null) {
                  onOpenStories!(day, st);
                } else {
                  onSelect(day);
                }
              },
              onLongPress: () {
                final day = DateTime(month.year, month.month, d);
                final st = s.storiesOfDay(ownerId, day);
                if (st.isNotEmpty) onOpenStories?.call(day, st);
              },
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.size,
    required this.ownerId,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime day;
  final double size;
  final String ownerId;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final posts = s.postsOfDay(ownerId, day);
    final stories = posts.whereType<Story>().toList();
    final hasPlan = posts.any((p) => p is Plan);
    final hasOther = posts.isNotEmpty;
    final radius = BorderRadius.circular(size * 0.22);
    final hasStory = stories.isNotEmpty;

    final numberStyle = TextStyle(
      fontSize: size * 0.26,
      fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
      color: hasStory ? Colors.white : scheme.onSurface,
      shadows: hasStory
          ? const [Shadow(blurRadius: 3, color: Colors.black45)]
          : null,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: formatDate(context, day),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: hasStory
                ? null
                : hasOther
                ? scheme.primaryContainer
                : null,
            border: isSelected
                ? Border.all(color: scheme.onSurface, width: 2)
                : isToday
                ? Border.all(color: AppColors.turquoise, width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: isSelected || isToday
                ? BorderRadius.circular(size * 0.22 - 2)
                : radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasStory)
                  MediaView(media: stories.last.media, thumbnail: true),
                Padding(
                  padding: EdgeInsets.all(size * 0.08),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text('${day.day}', style: numberStyle),
                  ),
                ),
                if (hasPlan)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: size * 0.3,
                      color: hasStory ? Colors.white : AppColors.turquoise,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
