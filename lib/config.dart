import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Ключи сервера. Это не секреты: доступ к данным защищают правила
/// Firestore (firestore.rules), а загрузку в Cloudinary — unsigned-пресет.
class AppConfig {
  static const cloudinaryCloudName = '';
  static const cloudinaryUploadPreset = 'calendar';

  /// Web client ID из google-services.json (client_type 3) — нужен для
  /// входа через Google на Android.
  static const googleServerClientId = '';

  /// CLIENT_ID из GoogleService-Info.plist — вход через Google на iOS.
  static const googleIosClientId = '';

  static const _android = FirebaseOptions(
    apiKey: 'AIzaSyAiJb_9o_jF3oOPvQPdIS4PhcBSYHuIaJ8',
    appId: '1:796050138013:android:d2e8535502285899018574',
    messagingSenderId: '796050138013',
    projectId: 'calendar-3fdd3',
    storageBucket: 'calendar-3fdd3.firebasestorage.app',
  );

  static const _ios = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '796050138013',
    projectId: 'calendar-3fdd3',
    storageBucket: 'calendar-3fdd3.firebasestorage.app',
    iosBundleId: 'com.dmitriy.calendarApp',
  );

  /// Настройки Firebase для текущей платформы или null — тогда приложение
  /// работает без сервера, данные в памяти (веб-превью, тесты).
  static FirebaseOptions? get firebase {
    if (kIsWeb) return null;
    final o = switch (defaultTargetPlatform) {
      TargetPlatform.android => _android,
      TargetPlatform.iOS => _ios,
      _ => null,
    };
    return o == null || o.appId.isEmpty ? null : o;
  }

  static bool get mediaUploadReady => cloudinaryCloudName.isNotEmpty;
}
