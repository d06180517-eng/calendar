import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../l10n.dart';
import '../../services/reminder_service.dart';
import 'calendar_screen.dart';
import 'chats_screen.dart';
import 'create_sheet.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    // Напоминание «Как прошёл день?» ставим при входе в приложение.
    final s = context.read<AppState>();
    context.read<ReminderService>().scheduleDiary(
      s.diaryReminderOn,
      s.diaryReminderTime,
      context.t('diaryReminderTitle'),
      context.t('diaryReminderBody'),
    );
  }

  void _select(int i) {
    if (i == 2) {
      showCreateSheet(context);
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // На ленте, как в инсте, нижнее меню становится тёмным.
    final onFeed = _tab == 1;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const CalendarScreen(),
          FeedScreen(active: onFeed),
          const SizedBox.shrink(),
          const ChatsScreen(),
          ProfileScreen(userId: s.currentUserId!, isTab: true),
        ],
      ),
      bottomNavigationBar: MinimalNavBar(
        index: _tab,
        dark: onFeed,
        chatBadge: s.unreadMessages > 0,
        onTap: _select,
      ),
    );
  }
}

/// Нижнее меню: чёрно-белые контурные значки, активный — залитый.
class MinimalNavBar extends StatelessWidget {
  const MinimalNavBar({
    super.key,
    required this.index,
    required this.onTap,
    this.dark = false,
    this.chatBadge = false,
  });

  final int index;
  final ValueChanged<int> onTap;
  final bool dark;
  final bool chatBadge;

  @override
  Widget build(BuildContext context) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = dark || themeDark;
    final fg = isDark ? Colors.white : Colors.black;
    final bg = dark ? Colors.black : Theme.of(context).colorScheme.surface;
    final items = <(IconData, IconData, String)>[
      (Icons.calendar_today_outlined, Icons.calendar_today, 'tabCalendar'),
      (Icons.play_circle_outline, Icons.play_circle, 'tabFeed'),
      (Icons.add_box_outlined, Icons.add_box, 'tabCreate'),
      (Icons.chat_bubble_outline, Icons.chat_bubble, 'tabChats'),
      (Icons.person_outline, Icons.person, 'tabProfile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    label: context.t(items[i].$3),
                    selected: i == index,
                    button: true,
                    child: InkResponse(
                      key: Key('nav_$i'),
                      onTap: () => onTap(i),
                      radius: 28,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              i == index ? items[i].$2 : items[i].$1,
                              color: fg,
                              size: 27,
                            ),
                            if (i == 3 && chatBadge)
                              Positioned(
                                right: -2,
                                top: -1,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: bg, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
