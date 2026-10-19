import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/models.dart';

/// Загрузка фото и видео в Cloudinary (бесплатный план, unsigned-пресет).
class Cloudinary {
  /// Одно видео, порезанное на части, загружаем один раз.
  final _inFlight = <Object, Future<String>>{};

  Future<String> upload(Media m) {
    final key = m.path ?? m.bytes!;
    return _inFlight[key] ??= _upload(m)
        .whenComplete(() => _inFlight.remove(key));
  }

  Future<String> _upload(Media m) async {
    if (!AppConfig.mediaUploadReady) {
      throw StateError('Cloudinary не настроен');
    }
    final kind = m.type == MediaType.video ? 'video' : 'image';
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '${AppConfig.cloudinaryCloudName}/$kind/upload',
      ),
    )..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
    if (m.bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes('file', m.bytes!, filename: 'upload'),
      );
    } else {
      req.files.add(await http.MultipartFile.fromPath('file', m.path!));
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw http.ClientException('Cloudinary ${res.statusCode}: ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['secure_url']
        as String;
  }
}

/// Ссылка на уменьшенную копию: Cloudinary сам сжимает и подбирает формат.
String sizedImageUrl(String url, int width) => url.contains('/image/upload/')
    ? url.replaceFirst(
        '/image/upload/',
        '/image/upload/f_auto,q_auto,c_limit,w_$width/',
      )
    : url;

/// Кадр из видео как картинка — для превью в календаре и ленте.
String videoPosterUrl(String url, {Duration at = Duration.zero, int w = 480}) {
  final i = url.lastIndexOf('.');
  final base = i > url.lastIndexOf('/') ? url.substring(0, i) : url;
  return '${base.replaceFirst('/video/upload/', '/video/upload/so_${at.inSeconds},w_$w,c_limit/')}.jpg';
}
