import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/models.dart';
import 'video_source_io.dart'
    if (dart.library.js_interop) 'video_source_web.dart';

/// Показывает фото, видео (с учётом отрезка части) или градиент-заглушку.
class MediaView extends StatefulWidget {
  const MediaView({
    super.key,
    required this.media,
    this.thumbnail = false,
    this.playing = true,
    this.fit = BoxFit.cover,
    this.onFinished,
    this.onProgress,
  });

  final Media media;
  final bool thumbnail;
  final bool playing;
  final BoxFit fit;
  final VoidCallback? onFinished;

  /// 0..1 — сколько отрезка видео уже проиграно.
  final ValueChanged<double>? onProgress;

  @override
  State<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<MediaView> {
  VideoPlayerController? _ctrl;
  bool _finished = false;
  bool _failed = false;

  bool get _isVideo =>
      widget.media.type == MediaType.video && widget.media.path != null;

  @override
  void initState() {
    super.initState();
    if (_isVideo && !widget.thumbnail) _initVideo();
  }

  Future<void> _initVideo() async {
    final c = controllerForPath(widget.media.path!);
    _ctrl = c;
    try {
      await c.initialize();
      await c.seekTo(widget.media.start);
      c.addListener(_tick);
      if (widget.playing) await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Duration get _end => widget.media.end ?? _ctrl!.value.duration;

  void _tick() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final len = _end - widget.media.start;
    if (len.inMilliseconds > 0) {
      widget.onProgress?.call(
        ((pos - widget.media.start).inMilliseconds / len.inMilliseconds).clamp(
          0.0,
          1.0,
        ),
      );
    }
    final ended =
        pos >= _end - const Duration(milliseconds: 150) ||
        (!c.value.isPlaying &&
            pos >= c.value.duration &&
            c.value.duration > Duration.zero);
    if (ended && !_finished) {
      _finished = true;
      if (widget.onFinished != null) {
        c.pause();
        scheduleMicrotask(() => widget.onFinished?.call());
      } else {
        // Без обработчика крутим отрезок по кругу.
        _finished = false;
        c.seekTo(widget.media.start);
      }
    }
  }

  @override
  void didUpdateWidget(MediaView old) {
    super.didUpdateWidget(old);
    final c = _ctrl;
    if (c != null && c.value.isInitialized && old.playing != widget.playing) {
      widget.playing ? c.play() : c.pause();
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_tick);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    if (m.type == MediaType.image && m.bytes != null) {
      return Image.memory(
        Uint8List.fromList(m.bytes!),
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }
    if (_isVideo && !widget.thumbnail) {
      final c = _ctrl;
      if (_failed) return _placeholder(icon: Icons.videocam_off_outlined);
      if (c == null || !c.value.isInitialized) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }
      return ColoredBox(
        color: Colors.black,
        child: FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    }
    return _placeholder(
      icon: m.type == MediaType.video && widget.thumbnail
          ? Icons.play_arrow_rounded
          : null,
    );
  }

  Widget _placeholder({IconData? icon}) {
    final colors =
        widget.media.placeholder ??
        (widget.media.type == MediaType.video
            ? const [Color(0xFF3A4A48), Color(0xFF1F2D2C)]
            : const [Color(0xFF9FE0D9), Color(0xFF3FA9A0)]);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: icon == null
          ? null
          : Center(child: Icon(icon, color: Colors.white)),
    );
  }
}
