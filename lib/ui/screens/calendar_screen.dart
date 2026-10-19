import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../widgets/day_panel.dart';
import '../widgets/month_calendar.dart';
import 'story_viewer.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selected;
  Key _calendarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(context.read<AppState>().now);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final today = dateOnly(s.now);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('appName')),
        actions: [
          if (!sameDay(_selected, today))
            TextButton(
              onPressed: () => setState(() {
                _selected = today;
                _calendarKey =
                    UniqueKey(); // вернуть календарь на текущий месяц
              }),
              child: Text(context.t('today')),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MonthCalendar(
            key: _calendarKey,
            ownerId: s.currentUserId!,
            selected: _selected,
            onSelect: (d) => setState(() => _selected = d),
            onOpenStories: (day, stories) => openStories(context, stories),
          ),
          const SizedBox(height: 8),
          DayPanel(ownerId: s.currentUserId!, day: _selected),
        ],
      ),
    );
  }
}
