import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'search_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  String _preview(BuildContext context, AppState s, ChatMessage m) {
    final prefix = m.senderId == s.currentUserId ? '${context.t('you')}: ' : '';
    if (m.replyToStoryId != null) {
      return '$prefix${context.t('storyReply')}: ${m.text}';
    }
    if (m.sharedPostId != null) return '$prefix${context.t('sharedPost')}';
    if (m.photo != null && m.text.isEmpty) return '$prefix📷';
    return '$prefix${m.text}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final chats = s.myChats();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('chats')),
        actions: [
          IconButton(
            tooltip: context.t('newChat'),
            icon: const Icon(Icons.edit_square),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => SearchScreen(
                  onPick: (id) {
                    Navigator.pop(c);
                    openChat(context, s.chatWith(id));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: chats.isEmpty
          ? Center(child: Text(context.t('noChats')))
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final c = chats[i];
                final u = s.user(c.other(s.currentUserId!));
                final last = c.messages.last;
                final unread = s.unreadIn(c);
                return ListTile(
                  onTap: () => openChat(context, c),
                  leading: Avatar(user: u, size: 50),
                  title: Text(
                    u.nick,
                    style: TextStyle(
                      fontWeight: unread > 0
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${_preview(context, s, last)} · ${timeAgo(context, last.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.w700 : null,
                    ),
                  ),
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.turquoise,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
