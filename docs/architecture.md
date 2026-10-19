# Архитектура и разработка

## Стек

| Что | Чем |
|---|---|
| Фреймворк | Flutter 3.47.7, Dart 3.13 |
| Состояние | `provider` + `ChangeNotifier` (`AppState`) |
| Даты, форматы | `intl`, `flutter_localizations` |
| Медиа | `image_picker` (камера/галерея), `video_player` |
| Погода | `geolocator` + `http` → Open-Meteo |
| Уведомления | `flutter_local_notifications` + `timezone` |
| Настройки | `shared_preferences` |
| Идентификаторы | `uuid` |
| Сервер | `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in` |
| Медиа в облаке | Cloudinary через `http` |

## Структура

```
lib/
  main.dart                 запуск: форматы дат, настройки, Firebase, напоминания
  config.dart               ключи Firebase, Cloudinary, Google
  l10n.dart                 строки RU/EN, форматы дат, склонения
  data/
    models.dart             модели (Story, Plan, DiaryPost, Comment, Chat…)
    app_state.dart          всё состояние и правила приложения
    backend.dart            интерфейс сервера
    firebase_backend.dart   Firebase: вход, синхронизация, документы
  services/
    cloudinary.dart         загрузка фото/видео, уменьшенные копии
    weather_service.dart    текущая погода (Open-Meteo)
    reminder_service.dart   напоминание о дневнике и планы
    media_picker.dart       выбор фото/видео
  ui/
    theme.dart              цвета и тема (см. design.md)
    screens/                экраны: auth, home_shell, calendar, feed, diary,
                            note_editor, story_editor, story_viewer, profile,
                            edit_profile, settings, chats, chat, notifications,
                            search, tag, create_sheet
    widgets/                month_calendar, day_panel, media_view,
                            story_overlays, post_actions, common
test/
  app_state_test.dart       правила (вход, сторис, приватность, лента, дневник…)
  widget_test.dart          сценарии экранов + проверка переводов
  demo_data.dart            тестовые пользователи, записи, чаты (только для тестов)
docs/                       эта документация
.github/workflows/build-apk.yml   сборка APK на GitHub
```

## Как устроено состояние

- `AppState` — единственный источник данных: пользователи, записи, подписки,
  блокировки, чаты, уведомления, настройки. Экраны читают его через
  `context.watch<AppState>()` и вызывают методы (`addDiaryPost`, `follow`,
  `toggleLike`…), после которых `notifyListeners()` перерисовывает UI.
- Время берётся из `AppState.now` (инъекция часов `clock`), поэтому тесты
  работают с фиксированной датой.
- Сервисы (`WeatherService`, `ReminderService`) передаются через `Provider`
  и подменяются в тестах.
- Медиа: ссылка в Cloudinary (`Media.url`), байты выбранного файла (`Media.bytes`), путь к видео
  (`Media.path`) или градиент-заглушка (`Media.placeholder`).
  Видеоплеер выбирается условным импортом: `video_source_io.dart` /
  `video_source_web.dart`.

## Локализация

Свой словарь в `lib/l10n.dart`: `context.t('ключ', {'n': '3'})`.
Язык — из `Localizations` (системный или выбранный в настройках).
Русские склонения — `plural(context, n, 'followers')`
(`followers_one/_few/_many`). Тест проверяет, что у каждого используемого
ключа есть RU и EN.

## Android

- `applicationId`: `com.dmitriy.calendar_app`, название — «Calendar».
- Разрешения: INTERNET, CAMERA, RECORD_AUDIO, ACCESS_COARSE_LOCATION,
  POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE.
- Включён core library desugaring (нужен для уведомлений).
- Release пока подписывается debug-ключом (для установки вручную).
  Для Google Play понадобится свой ключ.

## Тесты

```bash
flutter analyze   # без замечаний
flutter test      # 40 тестов
```

Покрыто: чистый старт без данных, вход и регистрация, разбиение видео, 24 часа и «оставить в
календаре», отметки, все правила приватности и блокировки, порядок ленты,
дневник-канал (несколько постов, теги, прошлые дни, чужие дни), текстовые
сторис, планы, серия, опубликованные дни, комментарии и лайки, чаты; виджет-
тесты экранов на ширине 360 dp; полнота переводов.

## Сборка и CI

`.github/workflows/build-apk.yml` на каждый push в `main` (и вручную):

- `android` (Ubuntu): `flutter test` → `flutter build apk --release` → `Calendar.apk`;
- `ios` (macOS Intel): `flutter build ios --release --no-codesign` → папка
  `Payload/Runner.app` в zip → `Calendar-unsigned.ipa`;
- `release`: релиз `build-N` с обоими файлами (последний —
  `releases/latest`). APK выпускается, даже если iOS-сборка не удалась
  (у GitHub бывает очередь на Mac).

## iOS

- Bundle ID `com.dmitriy.calendarApp`, минимум iOS 15, название «Calendar».
- Тексты разрешений в `ios/Runner/Info.plist`: камера, микрофон, фото,
  геопозиция (для погоды). Уведомления запрашиваются при первом запуске.
- IPA собирается без подписи. Для TestFlight/App Store нужен аккаунт
  Apple Developer и сертификат с профилем в секретах GitHub.

Веб-превью: `flutter build web --release --no-web-resources-cdn`
(в `index.html` для публикации в подпапке `<base href>` меняется на `./`).

## Сервер

Firebase (Auth + Firestore) и Cloudinary — подробно в [backend.md](backend.md):
коллекции, правила доступа, лимиты, подпись APK, настройка с нуля.
