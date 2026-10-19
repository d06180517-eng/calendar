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
import 'tag_screen.dart';

Future<void> openDiary(
  BuildContext context,
  DateTime day, {
  DiaryEntry? entry,
}) {
  final s = context.read<AppState>();
  final e = entry ?? s.diaryOf(s.currentUserId!, day);
  final own = e == null || e.authorId == s.currentUserId;
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: own,
      builder: (_) =>
          own ? DiaryEditor(day: day, entry: e) : DiaryView(entry: e),
    ),
  );
}

class DiaryEditor extends StatefulWidget {
  const DiaryEditor({super.key, required this.day, this.entry});
  final DateTime day;
  final DiaryEntry? entry;

  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> {
  late final TextEditingController _text;
  final _tagInput = TextEditingController();
  Mood? _mood;
  late List<Media> _photos;
  late List<String> _tags;
  Weather? _weather;
  bool _loadingWeather = false;
  late Audience _audience;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _text = TextEditingController(text: e?.text ?? '');
    _mood = e?.mood;
    _photos = [...?e?.photos];
    _tags = [...?e?.tags];
    _weather = e?.weather;
    _audience = e?.visibility ?? Audience.onlyMe;
    final isToday = sameDay(widget.day, context.read<AppState>().now);
    if (e == null && isToday) _loadWeather();
  }

  @override
  void dispose() {
    _text.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final service = context.read<WeatherService>();
    setState(() => _loadingWeather = true);
    final w = await service.current();
    if (!mounted) return;
    setState(() {
      _loadingWeather = false;
      _weather = w ?? _weather;
    });
    if (w == null) showSnack(context, context.t('weatherUnknown'));
  }

  Future<void> _addPhotos() async {
    try {
      final list = await MediaPicker().images();
      if (list.isNotEmpty) setState(() => _photos.addAll(list));
    } catch (_) {
      if (mounted) showSnack(context, context.t('pickFailed'));
    }
  }

  void _addTag() {
    final t = normalizeTag(_tagInput.text);
    if (t.length > 1 && !_tags.contains(t)) setState(() => _tags.add(t));
    _tagInput.clear();
  }

  void _save() {
    if (_tagInput.text.trim().isNotEmpty) _addTag();
    final s = context.read<AppState>();
    if (_text.text.trim().isEmpty && _photos.isEmpty && _mood == null) {
      showSnack(context, context.t('emptyText'));
      return;
    }
    s.saveDiary(
      date: widget.day,
      text: _text.text.trim(),
      mood: _mood,
      photos: _photos,
      tags: _tags,
      weather: _weather,
      visibility: _audience,
    );
    showSnack(context, context.t('diarySaved'));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = context.read<AppState>();
    if (!await confirm(
      context,
      context.t('deleteDiaryQ'),
      ok: context.t('delete'),
    )) {
      return;
    }
    s.deletePost(widget.entry!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isToday = sameDay(widget.day, context.read<AppState>().now);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: _DiaryTitle(day: widget.day),
        actions: [
          if (widget.entry != null)
            IconButton(
              tooltip: context.t('delete'),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              key: const Key('saveDiary'),
              onPressed: _save,
              child: Text(context.t('save')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.t('mood'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final m in Mood.values)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _MoodSquare(
                    mood: m,
                    selected: _mood == m,
                    onTap: () => setState(() => _mood = _mood == m ? null : m),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('diaryText'),
            controller: _text,
            minLines: 6,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: context.t('diaryHint')),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.t('photos'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(context.t('addPhoto')),
              ),
            ],
          ),
          if (_photos.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    children: [
                      MediaThumb(media: _photos[i], size: 84, radius: 12),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            context.t('tags'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _tags)
                InputChip(
                  label: Text(t),
                  onDeleted: () => setState(() => _tags.remove(t)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _tagInput,
            decoration: InputDecoration(
              hintText: context.t('addTag'),
              prefixText: '#',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addTag,
              ),
            ),
            onSubmitted: (_) => _addTag(),
          ),
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.t('weather'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              if (_loadingWeather)
                Text(context.t('weatherLoading'))
              else if (_weather != null) ...[
                Text(
                  formatWeather(_weather!),
                  style: const TextStyle(fontSize: 16),
                ),
                TextButton(
                  onPressed: () => setState(() => _weather = null),
                  child: Text(context.t('removeWeather')),
                ),
              ] else if (isToday)
                TextButton(
                  onPressed: _loadWeather,
                  child: Text(context.t('getWeather')),
                )
              else
                Text('—', style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          AudiencePicker(
            value: _audience,
            onChanged: (a) => setState(() => _audience = a),
          ),
        ],
      ),
    );
  }
}

class _MoodSquare extends StatelessWidget {
  const _MoodSquare({
    required this.mood,
    required this.selected,
    required this.onTap,
  });
  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.t(switch (mood) {
      Mood.good => 'moodGood',
      Mood.neutral => 'moodNeutral',
      Mood.bad => 'moodBad',
    });
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: moodColor(mood),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Чужая запись дневника — только чтение.
class DiaryView extends StatelessWidget {
  const DiaryView({super.key, required this.entry});
  final DiaryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final e = entry!;
    final author = context.read<AppState>().user(e.authorId);
    return Scaffold(
      appBar: AppBar(title: _DiaryTitle(day: e.date)),
      body: DiaryBody(entry: e, author: author),
    );
  }
}

class DiaryBody extends StatelessWidget {
  const DiaryBody({super.key, required this.entry, required this.author});
  final DiaryEntry entry;
  final AppUser author;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Avatar(user: author, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '@${author.nick}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (entry.weather != null) Text(formatWeather(entry.weather!)),
            if (entry.mood != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: moodColor(entry.mood!),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(entry.text, style: const TextStyle(fontSize: 16, height: 1.4)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final t in entry.tags)
              ActionChip(
                label: Text(
                  t,
                  style: const TextStyle(color: AppColors.turquoise),
                ),
                onPressed:
                    entry.authorId == context.read<AppState>().currentUserId
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TagScreen(tag: t)),
                      )
                    : null,
              ),
          ],
        ),
        for (final p in entry.photos)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(aspectRatio: 1, child: MediaView(media: p)),
            ),
          ),
      ],
    );
  }
}

class _DiaryTitle extends StatelessWidget {
  const _DiaryTitle({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.t('diary')),
      Text(
        formatDate(context, day),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
