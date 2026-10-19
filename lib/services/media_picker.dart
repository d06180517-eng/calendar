import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../ui/widgets/video_source_io.dart'
    if (dart.library.js_interop) '../ui/widgets/video_source_web.dart';

/// Выбор фото и видео с камеры или из галереи.
class MediaPicker {
  final _picker = ImagePicker();

  Future<Media?> image({bool camera = false}) async {
    final f = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2160,
      imageQuality: 88,
    );
    if (f == null) return null;
    return Media(
      type: MediaType.image,
      bytes: await f.readAsBytes(),
      path: f.path,
    );
  }

  Future<List<Media>> images() async {
    final fs = await _picker.pickMultiImage(maxWidth: 2160, imageQuality: 88);
    return [
      for (final f in fs)
        Media(
          type: MediaType.image,
          bytes: await f.readAsBytes(),
          path: f.path,
        ),
    ];
  }

  /// Видео и его длительность (нужна, чтобы порезать на части по 60 секунд).
  Future<(Media, Duration?)?> video({bool camera = false}) async {
    final f = await _picker.pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (f == null) return null;
    Duration? len;
    try {
      final c = controllerForPath(f.path);
      await c.initialize();
      len = c.value.duration;
      await c.dispose();
    } catch (e) {
      debugPrint('Не удалось узнать длину видео: $e');
    }
    return (Media(type: MediaType.video, path: f.path), len);
  }
}
