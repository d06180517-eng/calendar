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

## Структура

```
lib/
  main.dart                 запуск: форматы дат, демо-данные, настройки, напоминания
  l10n.dart                 строки RU/EN, форматы дат, склонения
  data/
    models.dart             модели (Story, Plan, DiaryPost, Comment, Chat…)
    app_state.dart          всё состояние и правила приложения
    demo_data.dart          демо-пользователи, записи, чаты, уведомления
  services/
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
- Медиа в демо: байты выбранного файла (`Media.bytes`), путь к видео
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
flutter test      # 39 тестов
```

Покрыто: вход и регистрация, разбиение видео, 24 часа и «оставить в
календаре», отметки, все правила приватности и блокировки, порядок ленты,
дневник-канал (несколько постов, теги, прошлые дни, чужие дни), текстовые
сторис, планы, серия, опубликованные дни, комментарии и лайки, чаты; виджет-
тесты экранов на ширине 360 dp; полнота переводов.

## Сборка и CI

`.github/workflows/build-apk.yml` на каждый push в `main` (и вручную):
`flutter pub get` → `flutter test` → `flutter build apk --release` →
артефакт `calendar-apk` + релиз `build-N` с файлом `Calendar.apk`
(последний — по ссылке `releases/latest`).

Веб-превью: `flutter build web --release --no-web-resources-cdn`
(в `index.html` для публикации в подпапке `<base href>` меняется на `./`).

## Бэкенд (план)

Сейчас данные живут в памяти и пропадают при закрытии. Решено:

- **Firebase (бесплатный план Spark)**: Authentication (email + Google),
  Firestore для пользователей, записей, комментариев, чатов, уведомлений.
- **Cloudinary (бесплатный план)** для фото и видео — без платного
  Firebase Storage.
- Пуш-уведомления между пользователями — только после перехода на Blaze
  (Cloud Functions + FCM). Локальные напоминания работают уже сейчас.

`AppState` спроектирован так, чтобы методы остались теми же, а внутри
вместо списков в памяти появились запросы к Firestore — экраны менять
не придётся.
