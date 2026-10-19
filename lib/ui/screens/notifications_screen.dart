import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';
import 'story_viewer.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
  }

  @override
  void dispose() {
    // Всё, что пользователь увидел, отмечаем прочитанным при выходе.
    _state.markNotificationsRead();
    super.dispose();
  }

  String _text(BuildContext context, AppNotification n) => switch (n.kind) {
    NotificationKind.like => context.t('nLike'),
    NotificationKind.comment => context.t('nComment', {'text': n.text}),
    NotificationKind.reply => context.t('nReply', {'text': n.text}),
    NotificationKind.follow => context.t('nFollow'),
    NotificationKind.followRequest => context.t('nFollowRequest'),
    NotificationKind.mention => context.t('nMention'),
    NotificationKind.commentLike => context.t('nCommentLike', {'text': n.text}),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.notifications
        .where((n) => !s.isBlockedBetween(s.currentUserId!, n.fromUserId))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('notifications'))),
      body: list.isEmpty
          ? Center(child: Text(context.t('noNotifications')))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final n = list[i];
                final u = s.user(n.fromUserId);
                final post = n.postId == null ? null : s.postById(n.postId!);
                return Container(
                  color: n.read
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: 0.35),
                  child: ListTile(
                    onTap: () {
                      if (post is Story) {
                        openStories(context, [post]);
                      } else {
                        openProfile(context, u.id);
                      }
                    },
                    leading: GestureDetector(
                      onTap: () => openProfile(context, u.id),
                      child: Avatar(user: u, size: 44),
                    ),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: u.nick,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' ${_text(context, n)}'),
                        ],
                      ),
                    ),
                    subtitle: Text(timeAgo(context, n.createdAt)),
                    trailing: n.kind == NotificationKind.followRequest
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton(
                                onPressed: () =>
                                    s.answerFollowRequest(u.id, true),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 34),
                                ),
                                child: Text(context.t('accept')),
                              ),
                              IconButton(
                                tooltip: context.t('decline'),
                                onPressed: () =>
                                    s.answerFollowRequest(u.id, false),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          )
                        : post is Story
                        ? MediaThumb(media: post.media, size: 44, radius: 8)
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
