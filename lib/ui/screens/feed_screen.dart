import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/weather_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/media_view.dart';
import '../widgets/post_actions.dart';
import '../widgets/story_overlays.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Лента в формате TikTok: каждая запись на весь экран, листается вверх.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.active});

  /// Видео играет, только когда вкладка открыта.
  final bool active;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _pages = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.feed();
    if (_current >= items.length && items.isNotEmpty) {
      _current = items.length - 1;
    }
    return Theme(
      data: buildTheme(Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    context.t('feedEmpty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              )
            else
              PageView.builder(
                key: const Key('feedPages'),
                controller: _pages,
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => FeedItem(
                  key: ValueKey(items[i].id),
                  post: items[i],
                  playing: widget.active && i == _current,
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
                child: Row(
                  children: [
                    Text(
                      context.t('tabFeed'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('openSearch'),
                      tooltip: context.t('search'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      ),
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    IconButton(
                      key: const Key('openNotifications'),
                      tooltip: context.t('notifications'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                      icon: Badge(
                        isLabelVisible: s.unreadNotifications > 0,
                        label: Text('${s.unreadNotifications}'),
                        child: const Icon(
                          Icons.favorite_border,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedItem extends StatefulWidget {
  const FeedItem({super.key, required this.post, required this.playing});
  final Post post;
  final bool playing;

  @override
  State<FeedItem> createState() => _FeedItemState();
}

class _FeedItemState extends State<FeedItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _viewed();
  }

  @override
  void didUpdateWidget(FeedItem old) {
    super.didUpdateWidget(old);
    if (widget.playing && !old.playing) _viewed();
  }

  void _viewed() {
    final p = widget.post;
    if (p is Story) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppState>().markStoryViewed(p);
      });
    }
  }

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    context.read<AppState>().like(widget.post);
    _heart.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = widget.post;
    final author = s.user(p.authorId);
    final liked = p.likes.contains(s.currentUserId);
    final me = s.currentUserId!;
    final showFollow = !s.isFollowing(me, author.id);
    final kind = switch (p) {
      Story() => context.t('kindStory'),
      Note() => context.t('kindNote'),
      _ => context.t('kindDiary'),
    };

    // Двойной тап ловим только на самом контенте, чтобы кнопки справа
    // срабатывали мгновенно, без ожидания второго тапа.
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTap: _doubleTapLike,
          child: switch (p) {
            Story() => _StoryContent(story: p, playing: widget.playing),
            Note() => _NoteContent(note: p),
            DiaryEntry() => _DiaryContent(entry: p),
            _ => const SizedBox.shrink(),
          },
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _heart, curve: Curves.elasticOut),
              child: FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.0).animate(
                  CurvedAnimation(
                    parent: _heart,
                    curve: const Interval(0.6, 1),
                  ),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 110,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 24,
          child: Column(
            children: [
              _SideButton(
                key: const Key('likeButton'),
                icon: liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? Colors.redAccent : Colors.white,
                label: '${p.likes.length}',
                tooltip: context.t('like'),
                onTap: () => s.toggleLike(p),
              ),
              _SideButton(
                key: const Key('commentsButton'),
                icon: Icons.mode_comment_outlined,
                label: '${p.comments.length}',
                tooltip: context.t('comments'),
                onTap: () => showComments(context, p),
              ),
              _SideButton(
                icon: Icons.send_outlined,
                tooltip: context.t('share'),
                onTap: () => showShare(context, p),
              ),
              _SideButton(
                icon: Icons.more_horiz,
                tooltip: context.t('more'),
                onTap: () => showPostMenu(context, p),
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 76,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: () => openProfile(context, author.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Avatar(user: author, size: 34),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              author.nick,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showFollow) ...[
                    const SizedBox(width: 10),
                    _FollowPill(userId: author.id),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$kind · ${timeAgo(context, p.createdAt)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowPill extends StatelessWidget {
  const _FollowPill({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final requested = s.hasRequested(s.currentUserId!, userId);
    return GestureDetector(
      onTap: requested ? null : () => s.follow(userId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          context.t(requested ? 'requested' : 'follow'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.label,
    this.color = Colors.white,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(
            icon,
            color: color,
            size: 32,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
          ),
        ),
        if (label != null)
          Text(
            label!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({required this.story, required this.playing});
  final Story story;
  final bool playing;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      MediaView(media: story.media, playing: playing),
      StoryOverlays(
        overlays: story.overlays,
        onMentionTap: (id) => openProfile(context, id),
      ),
      if (story.partCount > 1)
        Positioned(
          top: 100,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              context.t('part', {
                'i': '${story.partIndex + 1}',
                'n': '${story.partCount}',
              }),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
    ],
  );
}

class _NoteContent extends StatelessWidget {
  const _NoteContent({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final st = noteStyle(note.template);
    return Container(
      color: st.color,
      padding: const EdgeInsets.fromLTRB(28, 120, 84, 120),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(st.icon, size: 16, color: AppColors.text),
                const SizedBox(width: 4),
                Text(
                  templateLabel(context, note.template),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hhmm(note.createdAt),
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            note.text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (note.photo != null) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 200,
                height: 200,
                child: MediaView(media: note.photo!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiaryContent extends StatelessWidget {
  const _DiaryContent({required this.entry});
  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final bg = switch (entry.mood) {
      Mood.good => const Color(0xFFDDF4E6),
      Mood.bad => const Color(0xFFF8DEDE),
      _ => AppColors.turquoiseLight,
    };
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(28, 110, 84, 110),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: AppColors.text),
                const SizedBox(width: 6),
                Text(
                  capitalize(formatDate(context, entry.date)),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.weather != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    formatWeather(entry.weather!),
                    style: const TextStyle(color: AppColors.text),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              entry.text,
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 19,
                height: 1.4,
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                entry.tags.join(' '),
                style: const TextStyle(
                  color: Color(0xFF2B7F78),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (entry.photos.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final ph in entry.photos)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: MediaThumb(media: ph, size: 110, radius: 14),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
