import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../screens/profile_screen.dart';
import '../theme.dart';
import 'common.dart';

/// Комментарии: ветки с ответами (@автор) и лайки комментариев.
Future<void> showComments(BuildContext context, Post post) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: CommentsSheet(post: post),
    ),
  );
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.post});
  final Post post;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final s = context.read<AppState>();
    final c = s.addComment(widget.post, text, replyTo: _replyTo);
    if (c.replyToId != null) _expanded.add(c.replyToId!);
    _input.clear();
    setState(() => _replyTo = null);
  }

  void _startReply(Comment c) {
    final nick = context.read<AppState>().user(c.authorId).nick;
    setState(() => _replyTo = c);
    _input.text = '@$nick ';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final roots = s.rootComments(widget.post);
    return Column(
      children: [
        Text(
          context.t('comments'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const Divider(height: 20),
        Expanded(
          child: roots.isEmpty
              ? Center(child: Text(context.t('noComments')))
              : ListView(
                  children: [
                    for (final c in roots) ...[
                      _CommentTile(
                        post: widget.post,
                        comment: c,
                        onReply: () => _startReply(c),
                      ),
                      if (s.repliesTo(widget.post, c).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 68),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setState(
                                () => _expanded.contains(c.id)
                                    ? _expanded.remove(c.id)
                                    : _expanded.add(c.id),
                              ),
                              child: Text(
                                _expanded.contains(c.id)
                                    ? context.t('hideReplies')
                                    : context.t('showReplies', {
                                        'n':
                                            '${s.repliesTo(widget.post, c).length}',
                                      }),
                              ),
                            ),
                          ),
                        ),
                      if (_expanded.contains(c.id))
                        for (final r in s.repliesTo(widget.post, c))
                          Padding(
                            padding: const EdgeInsets.only(left: 48),
                            child: _CommentTile(
                              post: widget.post,
                              comment: r,
                              onReply: () => _startReply(r),
                            ),
                          ),
                    ],
                  ],
                ),
        ),
        if (_replyTo != null)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('replyTo', {
                      'nick': s.user(_replyTo!.authorId).nick,
                    }),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _replyTo = null;
                    _input.clear();
                  }),
                  child: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 4,
              top: 8,
              bottom: 8 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: [
                Avatar(user: s.me!, size: 34),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('commentInput'),
                    controller: _input,
                    focusNode: _focus,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: context.t('addComment'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('sendComment'),
                  tooltip: context.t('send'),
                  onPressed: _send,
                  icon: const Icon(
                    Icons.send_outlined,
                    color: AppColors.turquoise,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.post,
    required this.comment,
    required this.onReply,
  });
  final Post post;
  final Comment comment;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user(comment.authorId);
    final liked = comment.likes.contains(s.currentUserId);
    final mine =
        comment.authorId == s.currentUserId || post.authorId == s.currentUserId;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onLongPress: mine
          ? () async {
              if (await confirm(
                context,
                '${context.t('delete')}?',
                ok: context.t('delete'),
              )) {
                s.deleteComment(post, comment);
              }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => openProfile(context, u.id),
              child: Avatar(user: u, size: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: u.nick,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: '  ${timeAgo(context, comment.createdAt)}',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  _MentionText(comment.text),
                  GestureDetector(
                    onTap: onReply,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        context.t('reply'),
                        style: TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.t('like'),
                  onPressed: () => s.toggleCommentLike(post, comment),
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: liked ? Colors.redAccent : muted,
                  ),
                ),
                if (comment.likes.isNotEmpty)
                  Text(
                    '${comment.likes.length}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Подсвечивает @упоминания.
class _MentionText extends StatelessWidget {
  const _MentionText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp(r'@[\w.]+');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: const TextStyle(
            color: AppColors.turquoise,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans));
  }
}

/// «Поделиться»: в чат другу или ссылкой.
Future<void> showShare(BuildContext context, Post post) {
  final s = context.read<AppState>();
  final me = s.currentUserId!;
  final people = <String>{
    ...s.myChats().map((c) => c.other(me)),
    ...s.followingOf(me),
    ...s.followersOf(me),
  }.where((id) => s.canMessage(id)).map(s.user).toList();
  return showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('sendToChat'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final u in people)
                  GestureDetector(
                    onTap: () {
                      s.sendMessage(s.chatWith(u.id), sharedPostId: post.id);
                      Navigator.pop(c);
                      showSnack(context, context.t('sentTo', {'name': u.name}));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Avatar(user: u, size: 56),
                          const SizedBox(height: 4),
                          Text(u.nick, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(context.t('copyLink')),
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: 'https://calendar.app/p/${post.id}'),
              );
              Navigator.pop(c);
              showSnack(context, context.t('linkCopied'));
            },
          ),
        ],
      ),
    ),
  );
}

/// «Ещё»: пожаловаться, скрыть, заблокировать.
Future<void> showPostMenu(BuildContext context, Post post) {
  final s = context.read<AppState>();
  final author = s.user(post.authorId);
  return showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            title: Text(
              context.t('report'),
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              Navigator.pop(c);
              await showReport(context, postId: post.id, userId: post.authorId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: Text(context.t('hide')),
            onTap: () {
              s.hidePost(post.id);
              Navigator.pop(c);
              showSnack(context, context.t('hidden'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text('${context.t('block')} @${author.nick}'),
            onTap: () async {
              Navigator.pop(c);
              await blockUser(context, author);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showReport(
  BuildContext context, {
  String? postId,
  String? userId,
}) async {
  final s = context.read<AppState>();
  final reason = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('reportWhy'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          for (final r in [
            'reportSpam',
            'reportAbuse',
            'reportNudity',
            'reportOther',
          ])
            ListTile(
              title: Text(context.t(r)),
              onTap: () => Navigator.pop(c, r),
            ),
        ],
      ),
    ),
  );
  if (reason == null) return;
  s.report(userId: userId, postId: postId, reason: reason);
  if (context.mounted) showSnack(context, context.t('reported'));
}

Future<void> blockUser(BuildContext context, AppUser u) async {
  final s = context.read<AppState>();
  if (await confirm(
    context,
    context.t('blockQ', {'nick': u.nick}),
    ok: context.t('block'),
  )) {
    s.block(u.id);
    if (context.mounted) showSnack(context, context.t('blockedUser'));
  }
}
