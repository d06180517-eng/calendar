import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Ключи сервера. Это не секреты: доступ к данным защищают правила
/// Firestore (firestore.rules), а загрузку в Cloudinary — unsigned-пресет.
class AppConfig {
  static const cloudinaryCloudName = '';
  static const cloudinaryUploadPreset = 'calendar';

  /// Web client ID из google-services.json (client_type 3) — нужен для
  /// входа через Google на Android.
  static const googleServerClientId =
      '796050138013-rf1ovdpj77orfi0v4df48qpaa83vmlsb.apps.googleusercontent.com';

  /// CLIENT_ID из GoogleService-Info.plist — вход через Google на iOS.
  static const googleIosClientId =
      '796050138013-grqc404li0rm7gavduhtntgsn95nqlvf.apps.googleusercontent.com';

  static const _android = FirebaseOptions(
    apiKey: 'AIzaSyAiJb_9o_jF3oOPvQPdIS4PhcBSYHuIaJ8',
    appId: '1:796050138013:android:d2e8535502285899018574',
    messagingSenderId: '796050138013',
    projectId: 'calendar-3fdd3',
    storageBucket: 'calendar-3fdd3.firebasestorage.app',
  );

  static const _ios = FirebaseOptions(
    apiKey: 'AIzaSyB9lM3sOe2s2TO3BaeNgJMgLI1x57InA_8',
    appId: '1:796050138013:ios:a503b2f07c17db70018574',
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
