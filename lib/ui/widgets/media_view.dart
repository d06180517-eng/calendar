import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/models.dart';
import '../../services/cloudinary.dart';
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
  String? _error;

  bool get _isVideo =>
      widget.media.type == MediaType.video &&
      (widget.media.path != null || widget.media.url != null);

  @override
  void initState() {
    super.initState();
    if (_isVideo && !widget.thumbnail) _initVideo();
  }

  Future<void> _initVideo() async {
    // Только что снятое видео играем с телефона, остальное — из облака.
    // Если один источник не открылся, пробуем другой.
    final m = widget.media;
    final sources = <VideoPlayerController Function()>[
      if (m.path != null) () => controllerForPath(m.path!),
      if (m.url != null)
        () => VideoPlayerController.networkUrl(Uri.parse(m.url!)),
    ];
    for (final make in sources) {
      final c = make();
      _ctrl = c;
      try {
        await c.initialize();
        if (!mounted) return;
        await c.seekTo(m.start);
        c.addListener(_tick);
        if (widget.playing) await c.play();
        if (mounted) setState(() {});
        return;
      } catch (e) {
        debugPrint('Видео не открылось: $e');
        _error = '$e';
        await c.dispose();
        if (identical(_ctrl, c)) _ctrl = null;
      }
    }
    if (mounted) setState(() => _failed = true);
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
    if (m.type == MediaType.image && m.url != null) {
      return _network(sizedImageUrl(m.url!, widget.thumbnail ? 400 : 1080));
    }
    if (m.type == MediaType.video && widget.thumbnail && m.url != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _network(videoPosterUrl(m.url!, at: m.start)),
          const Center(
            child: Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),
        ],
      );
    }
    if (_isVideo && !widget.thumbnail) {
      final c = _ctrl;
      if (_failed) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _placeholder(icon: Icons.videocam_off_outlined),
            // Текст ошибки помогает понять, почему видео не открылось.
            if (_error != null && !widget.thumbnail)
              Positioned(
                left: 16,
                right: 16,
                bottom: 120,
                child: Text(
                  _error!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
          ],
        );
      }
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

  Widget _network(String url) => Image.network(
    url,
    fit: widget.fit,
    width: double.infinity,
    height: double.infinity,
    gaplessPlayback: true,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : _placeholder(),
    errorBuilder: (context, error, stack) =>
        _placeholder(icon: Icons.image_not_supported_outlined),
  );

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
