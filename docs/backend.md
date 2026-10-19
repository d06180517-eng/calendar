# Сервер: Firebase и Cloudinary

Приложение хранит данные в **Firebase** (бесплатный план Spark):
Authentication для входа и Firestore для всех записей. Фото и видео
лежат в **Cloudinary** (бесплатный план). Без настроек сервера (веб-превью,
тесты) приложение работает в памяти.

## Как устроено в коде

- `lib/config.dart` — ключи Firebase для Android и iOS, Cloudinary
  (`cloudinaryCloudName`, `cloudinaryUploadPreset`) и client ID для входа
  через Google. Это не секреты: доступ защищают правила Firestore.
- `lib/data/backend.dart` — интерфейс сервера.
- `lib/data/firebase_backend.dart` — реализация: вход, слушатели Firestore
  в реальном времени, запись изменений, преобразование моделей в документы.
- `lib/services/cloudinary.dart` — загрузка медиа (unsigned upload) и ссылки
  на уменьшенные копии (`f_auto,q_auto,w_…`) и кадры из видео.
- `AppState` не изменил интерфейс: экран вызывает метод, состояние сразу
  меняется в памяти, а изменение уходит на сервер. Изменения от других людей
  приходят через `apply…` и обновляют объекты на месте.

## Коллекции Firestore

| Путь | Что | Кто пишет |
|---|---|---|
| `users/{uid}` | профиль: name, nick, bio, city, link, birthday, avatarColor, avatarUrl, isPrivate | владелец |
| `users/{uid}/notifications/{id}` | kind, fromUserId, createdAt, postId, text, read | создаёт автор действия, читает владелец |
| `follows/{from_to}` | from, to, accepted (false — запрос на закрытый профиль) | from; принимает to |
| `blocks/{from_to}` | from, to | from |
| `reports/{id}` | from, userId, postId, reason, createdAt | любой, читать нельзя |
| `posts/{id}` | type (`story`/`plan`/`diary`), authorId, createdAt, visibility, likes, + поля типа | автор; другие — только likes и viewers |
| `posts/{id}/comments/{id}` | authorId, text, createdAt, replyToId, likes | автор; удалить может и автор записи |
| `chats/{a_b}` | members, updatedAt | участники |
| `chats/{a_b}/messages/{id}` | senderId, createdAt, text, photo, sharedPostId, replyToStoryId, read | участники |

Поля записей: сторис — media, text, overlays, keepInCalendar, groupId,
partIndex, partCount, viewers; план — text, planAt, remind; пост дневника —
date, text, photos, weather. Медиа — `{type, url, start, end, placeholder}`.

## Правила доступа

Файл `firestore.rules` вставляется в Firebase Console → Firestore Database →
Rules → Publish. Главное:

- всё только для вошедших;
- писать можно только своё (профиль, записи, подписки, блокировки);
- записи «только я» сервер отдаёт лишь автору; «подписчики» и закрытые
  профили дополнительно фильтруются в приложении;
- чаты и сообщения видят только участники.

## Лимиты бесплатных планов

| Сервис | Лимит | Хватает |
|---|---|---|
| Firestore | 50 000 чтений, 20 000 записей в день, 1 ГБ | на десятки активных людей |
| Authentication | email и Google без ограничений | — |
| Cloudinary | 25 кредитов в месяц (≈25 ГБ хранения + трафика) | фото — надолго, видео — смотреть |

Пуш-уведомления между пользователями не сделаны: нужны Cloud Functions,
а значит план Blaze. Внутри приложения уведомления работают.
Удалённые записи не удаляют файлы из Cloudinary (для этого нужен
подписанный запрос с секретным ключом).

## Подпись APK

Постоянный ключ нужен, чтобы обновления ставились поверх и работал вход
через Google (его SHA-1 добавлен в Firebase). Сборка на GitHub берёт ключ из
секретов репозитория `ANDROID_KEYSTORE_BASE64` и `ANDROID_KEYSTORE_PASSWORD`
(alias `calendar`). Без них APK подписывается временным ключом.

## Настройка с нуля

1. Firebase: проект, приложения Android (`com.dmitriy.calendar_app`) и iOS
   (`com.dmitriy.calendarApp`), Authentication → Email/Password и Google,
   Firestore в production-режиме, правила из `firestore.rules`, SHA-1 ключа
   подписи в настройках Android-приложения.
2. Значения из `google-services.json` и `GoogleService-Info.plist` —
   в `lib/config.dart`; `REVERSED_CLIENT_ID` — в `ios/Runner/Info.plist`.
3. Cloudinary: Settings → Upload → Upload presets → Add, Signing mode
   **Unsigned**, имя `calendar`; Cloud name — в `lib/config.dart`.
