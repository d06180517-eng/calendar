import 'package:flutter/material.dart';

import '../../data/models.dart';

const storyFonts = <TextStyle>[
  TextStyle(fontWeight: FontWeight.w700),
  TextStyle(
    fontFamily: 'serif',
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
  ),
  TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
];

const storyTextColors = <Color>[
  Colors.white,
  Colors.black,
  Color(0xFF3FA9A0),
  Color(0xFFFFD54F),
  Color(0xFFE06B6B),
  Color(0xFF9AB8E8),
];

/// Надписи, стикеры и отметки поверх сторис. В редакторе их можно двигать.
class StoryOverlays extends StatelessWidget {
  const StoryOverlays({
    super.key,
    required this.overlays,
    this.editable = false,
    this.onChanged,
    this.onEdit,
    this.onMentionTap,
  });

  final List<StoryOverlay> overlays;
  final bool editable;
  final VoidCallback? onChanged;
  final ValueChanged<StoryOverlay>? onEdit;
  final ValueChanged<String>? onMentionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            for (final o in overlays)
              Positioned(
                left: o.dx * box.maxWidth,
                top: o.dy * box.maxHeight,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: GestureDetector(
                    onPanUpdate: editable
                        ? (d) {
                            o.dx = (o.dx + d.delta.dx / box.maxWidth).clamp(
                              0.05,
                              0.95,
                            );
                            o.dy = (o.dy + d.delta.dy / box.maxHeight).clamp(
                              0.05,
                              0.95,
                            );
                            onChanged?.call();
                          }
                        : null,
                    onTap: editable
                        ? () => onEdit?.call(o)
                        : (o.mentionUserId != null
                              ? () => onMentionTap?.call(o.mentionUserId!)
                              : null),
                    onLongPress: editable
                        ? () {
                            overlays.remove(o);
                            onChanged?.call();
                          }
                        : null,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: box.maxWidth * 0.85,
                      ),
                      child: _OverlayLabel(o),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel(this.o);
  final StoryOverlay o;

  @override
  Widget build(BuildContext context) {
    if (o.isSticker) {
      return Text(o.text, style: const TextStyle(fontSize: 64));
    }
    if (o.mentionUserId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          o.text,
          style: const TextStyle(
            color: Color(0xFF3FA9A0),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      );
    }
    final style = storyFonts[o.fontIndex % storyFonts.length].copyWith(
      color: o.color,
      fontSize: 26,
      shadows: o.color == Colors.black
          ? null
          : const [Shadow(blurRadius: 6, color: Colors.black54)],
    );
    return Text(o.text, textAlign: TextAlign.center, style: style);
  }
}
