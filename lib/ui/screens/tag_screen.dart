import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../l10n.dart';
import '../widgets/day_panel.dart';

/// Мои записи дневника с выбранным тегом.
class TagScreen extends StatelessWidget {
  const TagScreen({super.key, required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().searchDiaryByTag(tag);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('byTag', {'tag': tag}))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final e in entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 2),
              child: Text(
                capitalize(formatDateFull(context, e.date)),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DiaryCard(entry: e),
          ],
        ],
      ),
    );
  }
}
