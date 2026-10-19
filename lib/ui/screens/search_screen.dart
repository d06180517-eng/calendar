import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../l10n.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.onPick});

  /// Если задан — экран работает как выбор человека (например, для нового чата).
  final ValueChanged<String>? onPick;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final results = s.searchUsers(_q.text);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('searchField'),
          controller: _q,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: context.t('searchPeople'),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
        ),
      ),
      body: _q.text.trim().isEmpty
          ? const SizedBox.shrink()
          : results.isEmpty
          ? Center(child: Text(context.t('nothingFound')))
          : ListView(
              children: [
                for (final u in results)
                  UserTile(
                    user: u,
                    onTap: () => widget.onPick != null
                        ? widget.onPick!(u.id)
                        : openProfile(context, u.id),
                  ),
              ],
            ),
    );
  }
}
