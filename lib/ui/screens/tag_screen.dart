import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../l10n.dart';
import 'diary_screen.dart';

/// Мои посты дневника с выбранным тегом.
class TagScreen extends StatelessWidget {
  const TagScreen({super.key, required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final posts = s.searchDiaryByTag(tag);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('byTag', {'tag': tag}))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final p in posts)
            GestureDetector(
              onTap: () => openDiary(context, p.authorId, p.date),
              child: DiaryPostBubble(post: p, showDate: true),
            ),
        ],
      ),
    );
  }
}
