import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/media_picker.dart';
import '../../services/weather_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/media_view.dart';
import '../widgets/post_actions.dart';
import 'tag_screen.dart';

/// Дневник дня — как канал: посты этого дня, свайп влево/вправо
/// переключает соседние дни. Свой дневник можно дописывать снизу.
Future<void> openDiary(BuildContext context, String ownerId, DateTime day) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DiaryScreen(ownerId: ownerId, day: dateOnly(day)),
    ),
  );
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.ownerId, required this.day});
  final String ownerId;
  final DateTime day;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final List<DateTime> _days;
  late final PageController _pages;
  late int _i;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final today = dateOnly(s.now);
    final own = widget.ownerId == s.currentUserId;
    // Список дней фиксируем при открытии, чтобы страницы не прыгали,
    // когда в дне появляется или удаляется пост.
    final set = {...s.diaryDays(widget.ownerId), widget.day, if (own) today}
      ..removeWhere((d) => d.isAfter(today) && d != widget.day);
    _days = set.toList()..sort();
    _i = _days.indexOf(widget.day);
    _pages = PageController(initialPage: _i);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) => _pages.animateToPage(
    _i + delta,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final own = widget.ownerId == s.currentUserId;
    final day = _days[_i];
    final canWrite = own && !day.isAfter(dateOnly(s.now));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              own
                  ? context.t('diary')
                  : '${context.t('diary')} · @${s.user(widget.ownerId).nick}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              capitalize(formatDateFull(context, day)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('prevDay'),
            tooltip: context.t('prevDay'),
            onPressed: _i > 0 ? () => _go(-1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: const Key('nextDay'),
            tooltip: context.t('nextDay'),
            onPressed: _i < _days.length - 1 ? () => _go(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _days.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) =>
                  _DayPosts(ownerId: widget.ownerId, day: _days[i]),
            ),
          ),
          if (canWrite) _Composer(key: ValueKey(day), day: day),
        ],
      ),
    );
  }
}

class _DayPosts extends StatelessWidget {
  const _DayPosts({required this.ownerId, required this.day});
  final String ownerId;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final posts = s.diaryOf(ownerId, day);
    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.t(
              ownerId == s.currentUserId ? 'diaryEmpty' : 'diaryEmptyOther',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    // Как в канале: новое внизу, открываемся на последнем посте.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: posts.length,
      itemBuilder: (context, i) =>
          DiaryPostBubble(post: posts[posts.length - 1 - i]),
    );
  }
}

/// Один пост дневника: фото, текст с #тегами, время, лайки, комментарии.
class DiaryPostBubble extends StatelessWidget {
  const DiaryPostBubble({
    super.key,
    required this.post,
    this.showDate = false,
    this.compact = false,
  });
  final DiaryPost post;
  final bool showDate;

  /// В превью дня фото показываются маленькими.
  final bool compact;

  Future<void> _menu(BuildContext context) async {
    final s = context.read<AppState>();
    if (post.authorId != s.currentUserId) return showPostMenu(context, post);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.t('editPost')),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: Icon(audienceIcon(post.visibility)),
              title: Text(context.t('whoSeesPost')),
              subtitle: Text(audienceLabel(context, post.visibility)),
              onTap: () => Navigator.pop(c, 'audience'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.t('delete')),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'edit':
        final ctrl = TextEditingController(text: post.text);
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(context.t('editPost')),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 8,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(context.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(context.t('save')),
              ),
            ],
          ),
        );
        if (ok == true &&
            (ctrl.text.trim().isNotEmpty || post.photos.isNotEmpty)) {
          s.editDiaryPost(post, ctrl.text);
        }
        ctrl.dispose();
      case 'audience':
        await showModalBottomSheet<void>(
          context: context,
          builder: (c) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AudiencePicker(
                value: post.visibility,
                onChanged: (a) {
                  s.setVisibility(post, a);
                  Navigator.pop(c);
                },
              ),
            ),
          ),
        );
      case 'delete':
        if (await confirm(
          context,
          context.t('deletePostQ'),
          ok: context.t('delete'),
        )) {
          s.deletePost(post);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final own = post.authorId == s.currentUserId;
    final liked = post.likes.contains(s.currentUserId);
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: () => _menu(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (post.photos.isNotEmpty && !compact)
                _Photos(photos: post.photos),
              if (post.photos.isNotEmpty && compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final ph in post.photos)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: MediaThumb(media: ph, size: 56, radius: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TaggedText(
                          text: post.text,
                          onTag: own
                              ? (t) => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TagScreen(tag: t),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    Row(
                      children: [
                        if (post.weather != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              formatWeather(post.weather!),
                              style: muted,
                            ),
                          ),
                        if (own)
                          Icon(
                            audienceIcon(post.visibility),
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        const Spacer(),
                        _Mini(
                          key: Key('diaryLike_${post.id}'),
                          icon: liked ? Icons.favorite : Icons.favorite_border,
                          color: liked ? Colors.redAccent : null,
                          count: post.likes.length,
                          tooltip: context.t('like'),
                          onTap: () => s.toggleLike(post),
                        ),
                        _Mini(
                          icon: Icons.mode_comment_outlined,
                          count: post.comments.length,
                          tooltip: context.t('comments'),
                          onTap: () => showComments(context, post),
                        ),
                        if (own)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: context.t('more'),
                            onPressed: () => _menu(context),
                            icon: const Icon(Icons.more_horiz, size: 20),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 8),
                          child: Text(
                            showDate
                                ? '${formatDate(context, post.date)}, ${hhmm(post.createdAt)}'
                                : hhmm(post.createdAt),
                            style: muted,
                          ),
                        ),
                      ],
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

class _Mini extends StatelessWidget {
  const _Mini({
    super.key,
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text('$count', style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Photos extends StatelessWidget {
  const _Photos({required this.photos});
  final List<Media> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: MediaView(media: photos.first),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final side = (box.maxWidth - 2) / 2;
        return Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            for (final p in photos)
              SizedBox(
                width: side,
                height: side,
                child: MediaView(media: p),
              ),
          ],
        );
      },
    );
  }
}

/// Текст, в котором #теги выделены и нажимаются.
class _TaggedText extends StatelessWidget {
  const _TaggedText({required this.text, this.onTag});
  final String text;
  final ValueChanged<String>? onTag;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style
        .copyWith(fontSize: 15, height: 1.35);
    final re = RegExp(r'#[\p{L}\p{N}_]+', unicode: true);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final tag = m.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: onTag == null ? null : () => onTag!(tag.toLowerCase()),
            child: Text(
              tag,
              style: base.copyWith(
                color: AppColors.turquoise,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// Поле внизу дневника: фото, текст, кто видит, отправить.
class _Composer extends StatefulWidget {
  const _Composer({super.key, required this.day});
  final DateTime day;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  final List<Media> _photos = [];
  Audience _audience = Audience.everyone;
  Weather? _weather;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final isToday = sameDay(widget.day, s.now);
    final hasWeather = s
        .diaryOf(s.currentUserId!, widget.day)
        .any((p) => p.weather != null);
    // Погода дня прикрепляется к первому посту за сегодня.
    if (isToday && !hasWeather) _loadWeather();
  }

  Future<void> _loadWeather() async {
    final w = await context.read<WeatherService>().current();
    if (mounted) setState(() => _weather = w);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    try {
      final list = await MediaPicker().images();
      if (list.isNotEmpty) setState(() => _photos.addAll(list));
    } catch (_) {
      if (mounted) showSnack(context, context.t('pickFailed'));
    }
  }

  Future<void> _pickAudience() async {
    final a = await showModalBottomSheet<Audience>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('whoSeesPost'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final a in Audience.values)
              ListTile(
                leading: Icon(audienceIcon(a)),
                title: Text(audienceLabel(context, a)),
                trailing: a == _audience ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(c, a),
              ),
          ],
        ),
      ),
    );
    if (a != null) setState(() => _audience = a);
  }

  void _send() {
    final s = context.read<AppState>();
    final p = s.addDiaryPost(
      date: widget.day,
      text: _text.text,
      photos: _photos,
      weather: _weather,
      visibility: _audience,
    );
    if (p == null) return;
    _text.clear();
    setState(() {
      _photos.clear();
      _weather = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (var i = 0; i < _photos.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: Stack(
                              children: [
                                MediaThumb(
                                  media: _photos[i],
                                  size: 60,
                                  radius: 10,
                                ),
                                const Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Icon(
                                    Icons.cancel,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: context.t('addPhoto'),
                    onPressed: _addPhotos,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('diaryInput'),
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: context.t('diaryWrite'),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('whoSeesPost'),
                    onPressed: _pickAudience,
                    icon: Icon(audienceIcon(_audience)),
                  ),
                  IconButton(
                    key: const Key('diarySend'),
                    tooltip: context.t('send'),
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: AppColors.turquoise),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
