import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../widgets/common.dart';
import '../widgets/media_view.dart';
import '../theme.dart';
import '../widgets/story_overlays.dart';

const storyStickers = [
  '😀',
  '😍',
  '🥳',
  '😎',
  '🤔',
  '😴',
  '❤️',
  '🔥',
  '✨',
  '🌊',
  '☀️',
  '🌙',
  '☕',
  '🍕',
  '🎉',
  '🎸',
  '📚',
  '🏃',
  '✈️',
  '🌿',
  '🐱',
  '👍',
  '💪',
  '🙏',
];

class StoryEditor extends StatefulWidget {
  const StoryEditor({super.key, required this.media, this.videoDuration});
  final Media media;
  final Duration? videoDuration;

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<StoryEditor> {
  final List<StoryOverlay> _overlays = [];
  Audience _audience = Audience.everyone;
  bool _keep = true;

  int get _parts {
    final d = widget.videoDuration;
    if (widget.media.type != MediaType.video ||
        d == null ||
        d <= maxStoryDuration) {
      return 1;
    }
    return (d.inMilliseconds / maxStoryDuration.inMilliseconds).ceil();
  }

  Future<void> _editText([StoryOverlay? existing]) async {
    final ctrl = TextEditingController(text: existing?.text ?? '');
    var color = existing?.color ?? Colors.white;
    var font = existing?.fontIndex ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                textAlign: TextAlign.center,
                maxLines: null,
                style: storyFonts[font].copyWith(color: color, fontSize: 26),
                decoration: InputDecoration(
                  hintText: context.t('typeText'),
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < storyFonts.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('Aa', style: storyFonts[i]),
                        selected: font == i,
                        onSelected: (_) => set(() => font = i),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  for (final col in storyTextColors)
                    GestureDetector(
                      onTap: () => set(() => color = col),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: col,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white,
                            width: color == col ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(context.t('done')),
              ),
            ],
          ),
        ),
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    setState(() {
      if (existing != null) {
        if (text.isEmpty) {
          _overlays.remove(existing);
        } else {
          existing
            ..text = text
            ..color = color
            ..fontIndex = font;
        }
      } else if (text.isNotEmpty) {
        _overlays.add(
          StoryOverlay(text: text, color: color, fontIndex: font, dy: 0.4),
        );
      }
    });
  }

  Future<void> _addSticker() async {
    final e = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => GridView.count(
        crossAxisCount: 6,
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        children: [
          for (final s in storyStickers)
            InkWell(
              onTap: () => Navigator.pop(c, s),
              child: Center(
                child: Text(s, style: const TextStyle(fontSize: 34)),
              ),
            ),
        ],
      ),
    );
    if (e != null) {
      setState(
        () => _overlays.add(StoryOverlay(text: e, isSticker: true, dy: 0.3)),
      );
    }
  }

  Future<void> _addMention() async {
    final s = context.read<AppState>();
    final me = s.currentUserId!;
    final candidates = {
      ...s.followingOf(me),
      ...s.followersOf(me),
    }.where((id) => !s.isBlockedBetween(me, id)).map(s.user).toList();
    final u = await showModalBottomSheet<AppUser>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.t('mentionWho'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            for (final u in candidates)
              UserTile(user: u, onTap: () => Navigator.pop(c, u)),
          ],
        ),
      ),
    );
    if (u != null) {
      setState(
        () => _overlays.add(
          StoryOverlay(text: '@${u.nick}', mentionUserId: u.id, dy: 0.6),
        ),
      );
    }
  }

  void _publish() {
    final s = context.read<AppState>();
    final list = s.createStory(
      media: widget.media,
      videoDuration: widget.videoDuration,
      overlays: _overlays,
      visibility: _audience,
      keepInCalendar: _keep,
    );
    showSnack(
      context,
      list.length == 1
          ? context.t('storyPublished')
          : context.t('storiesPublished', {'n': '${list.length}'}),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MediaView(media: widget.media),
                      StoryOverlays(
                        overlays: _overlays,
                        editable: true,
                        onChanged: () => setState(() {}),
                        onEdit: (o) {
                          if (!o.isSticker && o.mentionUserId == null) {
                            _editText(o);
                          }
                        },
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        right: 4,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: context.t('cancel'),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            _ToolButton(
                              icon: Icons.text_fields,
                              label: context.t('addText'),
                              onTap: _editText,
                            ),
                            _ToolButton(
                              icon: Icons.emoji_emotions_outlined,
                              label: context.t('addSticker'),
                              onTap: _addSticker,
                            ),
                            _ToolButton(
                              icon: Icons.alternate_email,
                              label: context.t('addMention'),
                              onTap: _addMention,
                            ),
                          ],
                        ),
                      ),
                      if (_overlays.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Text(
                            context.t('dragHint'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_parts > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          context.t('videoSplit', {'n': '$_parts'}),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    AudiencePicker(
                      value: _audience,
                      onChanged: (a) => setState(() => _audience = a),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _keep,
                      onChanged: (v) => setState(() => _keep = v),
                      title: Text(context.t('keepInCalendar')),
                    ),
                    FilledButton(
                      key: const Key('publishStory'),
                      onPressed: _publish,
                      child: Text(context.t('publish')),
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );
}
