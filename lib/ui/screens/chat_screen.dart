import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/media_picker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/media_view.dart';
import 'diary_screen.dart';
import 'profile_screen.dart';
import 'story_viewer.dart';

Future<void> openChat(BuildContext context, Chat chat) {
  return Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat});
  final Chat chat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().markChatRead(widget.chat);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final s = context.read<AppState>();
    if (s.sendMessage(widget.chat, text: _input.text) == null &&
        _input.text.trim().isNotEmpty) {
      showSnack(context, context.t('cantMessage'));
      return;
    }
    _input.clear();
  }

  Future<void> _sendPhoto() async {
    final s = context.read<AppState>();
    try {
      final m = await MediaPicker().image();
      if (m != null) s.sendMessage(widget.chat, photo: m);
    } catch (_) {
      if (mounted) showSnack(context, context.t('pickFailed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.currentUserId!;
    final other = s.user(widget.chat.other(me));
    final msgs = widget.chat.messages.reversed.toList();
    final canWrite = s.canMessage(other.id);
    // Новые входящие, пришедшие при открытом чате, сразу прочитаны.
    if (s.unreadIn(widget.chat) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) s.markChatRead(widget.chat);
      });
    }
    final lastMine = widget.chat.messages.lastIndexWhere(
      (m) => m.senderId == me,
    );
    final lastMineRead =
        lastMine >= 0 &&
        widget.chat.messages.length - 1 == lastMine &&
        widget.chat.messages[lastMine].read;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => openProfile(context, other.id),
          child: Row(
            children: [
              Avatar(user: other, size: 34),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    other.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${other.nick}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (context, i) =>
                  _Bubble(message: msgs[i], mine: msgs[i].senderId == me),
            ),
          ),
          if (lastMineRead)
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  context.t('read'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
              child: canWrite
                  ? Row(
                      children: [
                        IconButton(
                          tooltip: context.t('addPhoto'),
                          onPressed: _sendPhoto,
                          icon: const Icon(Icons.image_outlined),
                        ),
                        Expanded(
                          child: TextField(
                            key: const Key('chatInput'),
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: context.t('messageHint'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('sendMessage'),
                          tooltip: context.t('send'),
                          onPressed: _send,
                          icon: const Icon(
                            Icons.send_outlined,
                            color: AppColors.turquoise,
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        context.t('cantMessage'),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? AppColors.turquoise : scheme.surfaceContainerHighest;
    final fg = mine ? Colors.white : scheme.onSurface;
    final story = message.replyToStoryId == null
        ? null
        : s.postById(message.replyToStoryId!);
    final shared = message.sharedPostId == null
        ? null
        : s.postById(message.sharedPostId!);
    final sharedVisible = shared != null && s.canSee(shared, s.currentUserId!);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (story is Story)
              GestureDetector(
                onTap: () => openStories(context, [story]),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('storyReply'),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      MediaThumb(media: story.media, size: 72, radius: 10),
                    ],
                  ),
                ),
              ),
            if (message.sharedPostId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: sharedVisible
                    ? _SharedPost(post: shared)
                    : Text(
                        context.t('postUnavailable'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
              ),
            if (message.photo != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: MediaView(media: message.photo!),
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(color: fg, fontSize: 15),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                hhmm(message.createdAt),
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedPost extends StatelessWidget {
  const _SharedPost({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final author = s.user(post.authorId);
    final p = post;
    final preview = switch (p) {
      Story() => MediaThumb(media: p.media, size: 120, radius: 12),
      Note() => Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: noteStyle(p.template).color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          p.text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.text),
        ),
      ),
      DiaryEntry() => Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.turquoiseLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          p.text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.text),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
    return GestureDetector(
      onTap: () {
        if (p is Story) {
          openStories(context, [p]);
        } else if (p is DiaryEntry) {
          openDiary(context, p.date, entry: p);
        } else {
          openProfile(context, p.authorId);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(user: author, size: 20),
              const SizedBox(width: 6),
              Text(
                author.nick,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          preview,
        ],
      ),
    );
  }
}
