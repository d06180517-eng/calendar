import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/media_view.dart';
import '../widgets/story_overlays.dart';
import 'profile_screen.dart';

Future<void> openStories(
  BuildContext context,
  List<Story> stories, {
  int start = 0,
}) {
  if (stories.isEmpty) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => StoryViewer(stories: stories, start: start),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Просмотр сторис на весь экран: тап справа — дальше, слева — назад,
/// удержание — пауза.
class StoryViewer extends StatefulWidget {
  const StoryViewer({super.key, required this.stories, this.start = 0});
  final List<Story> stories;
  final int start;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  static const _photoDuration = Duration(seconds: 5);
  late int _i;
  late final AnimationController _timer;
  double _videoProgress = 0;
  bool _paused = false;
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();

  Story get _story => widget.stories[_i];
  bool get _isVideo =>
      _story.media.type == MediaType.video && _story.media.path != null;

  @override
  void initState() {
    super.initState();
    _i = widget.start.clamp(0, widget.stories.length - 1);
    _timer = AnimationController(vsync: this, duration: _photoDuration)
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed) _next();
      });
    _replyFocus.addListener(() => _setPaused(_replyFocus.hasFocus));
    _startCurrent();
  }

  void _startCurrent() {
    context.read<AppState>().markStoryViewed(_story);
    _videoProgress = 0;
    _timer.stop();
    _timer.value = 0;
    if (!_isVideo && !_paused) _timer.forward();
  }

  void _next() {
    if (_i < widget.stories.length - 1) {
      setState(() => _i++);
      _startCurrent();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
    }
    _startCurrent();
  }

  void _setPaused(bool p) {
    if (_paused == p) return;
    setState(() => _paused = p);
    if (!_isVideo) {
      p ? _timer.stop() : _timer.forward();
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _sendReply() {
    final s = context.read<AppState>();
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final chat = s.chatWith(_story.authorId);
    if (s.sendMessage(chat, text: text, replyToStoryId: _story.id) != null) {
      showSnack(context, context.t('replySent'));
    } else {
      showSnack(context, context.t('cantMessage'));
    }
    _reply.clear();
    _replyFocus.unfocus();
  }

  Future<void> _showViewers() async {
    _setPaused(true);
    final s = context.read<AppState>();
    await showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: _story.viewers.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.t('noViewers')),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final id in _story.viewers)
                    UserTile(
                      user: s.user(id),
                      trailing: _story.likes.contains(id)
                          ? const Icon(
                              Icons.favorite,
                              color: Colors.redAccent,
                              size: 18,
                            )
                          : null,
                    ),
                ],
              ),
      ),
    );
    if (mounted) _setPaused(false);
  }

  Future<void> _ownMenu() async {
    _setPaused(true);
    final s = context.read<AppState>();
    final story = _story;
    await showModalBottomSheet(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AudiencePicker(
                  value: story.visibility,
                  onChanged: (a) {
                    s.setVisibility(story, a);
                    set(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: story.keepInCalendar,
                  onChanged: (v) {
                    s.setKeepInCalendar(story, v);
                    set(() {});
                  },
                  title: Text(context.t('keepInCalendar')),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    context.t('delete'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    s.deletePost(story);
                    Navigator.pop(c);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) _setPaused(false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final story = _story;
    final author = s.user(story.authorId);
    final own = story.authorId == s.currentUserId;
    final liked = story.likes.contains(s.currentUserId);

    return Theme(
      data: buildTheme(Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final w = MediaQuery.sizeOf(context).width;
                      d.localPosition.dx < w / 3 ? _prev() : _next();
                    },
                    onLongPressStart: (_) => _setPaused(true),
                    onLongPressEnd: (_) => _setPaused(false),
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) > 300) {
                        Navigator.maybePop(context);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaView(
                          key: ValueKey(story.id),
                          media: story.media,
                          playing: !_paused,
                          onProgress: (p) => setState(() => _videoProgress = p),
                          onFinished: _next,
                        ),
                        StoryOverlays(
                          overlays: story.overlays,
                          onMentionTap: (id) => openProfile(context, id),
                        ),
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 110,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black54, Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: _ProgressBars(
                            count: widget.stories.length,
                            index: _i,
                            timer: _timer,
                            videoProgress: _isVideo ? _videoProgress : null,
                          ),
                        ),
                        Positioned(
                          top: 18,
                          left: 4,
                          right: 4,
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => openProfile(context, author.id),
                                child: Avatar(user: author, size: 32),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      author.nick,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      [
                                        timeAgo(context, story.createdAt),
                                        if (story.partCount > 1)
                                          context.t('part', {
                                            'i': '${story.partIndex + 1}',
                                            'n': '${story.partCount}',
                                          }),
                                      ].join(' · '),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (own)
                                IconButton(
                                  tooltip: context.t('more'),
                                  onPressed: _ownMenu,
                                  icon: const Icon(
                                    Icons.more_horiz,
                                    color: Colors.white,
                                  ),
                                ),
                              IconButton(
                                tooltip: context.t('cancel'),
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: own
                    ? Row(
                        children: [
                          TextButton.icon(
                            onPressed: _showViewers,
                            icon: const Icon(
                              Icons.visibility_outlined,
                              color: Colors.white,
                            ),
                            label: Text(
                              '${context.t('viewers')}: ${story.viewers.length}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.favorite_border,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${story.likes.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reply,
                              focusNode: _replyFocus,
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendReply(),
                              decoration: InputDecoration(
                                hintText: context.t('replyToStory'),
                                hintStyle: const TextStyle(
                                  color: Colors.white60,
                                ),
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: context.t('like'),
                            onPressed: () => s.toggleLike(story),
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: liked ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          IconButton(
                            tooltip: context.t('send'),
                            onPressed: _sendReply,
                            icon: const Icon(
                              Icons.send_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({
    required this.count,
    required this.index,
    required this.timer,
    this.videoProgress,
  });

  final int count;
  final int index;
  final AnimationController timer;
  final double? videoProgress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timer,
      builder: (context, _) => Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: i < index
                      ? 1
                      : i > index
                      ? 0
                      : (videoProgress ?? timer.value),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
