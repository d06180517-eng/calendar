import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';

const demoGradients = <List<Color>>[
  [Color(0xFF9FE0D9), Color(0xFF3FA9A0)],
  [Color(0xFFF4C38B), Color(0xFFD98C5F)],
  [Color(0xFF9AB8E8), Color(0xFF5B7FC4)],
  [Color(0xFFE8A0BF), Color(0xFFB55D8A)],
  [Color(0xFFB8E0A0), Color(0xFF5FA85B)],
  [Color(0xFFD7C4F2), Color(0xFF8A6FC4)],
  [Color(0xFFFFE29A), Color(0xFFE0A030)],
];

Media demoMedia(int i, {MediaType type = MediaType.image}) =>
    Media(type: type, placeholder: demoGradients[i % demoGradients.length]);

/// Наполняет приложение демо-данными, чтобы все экраны можно было потрогать
/// до подключения сервера.
void seedDemo(AppState s) {
  final now = s.now;
  DateTime ago(int days, [int hour = 12, int minute = 0]) =>
      DateTime(now.year, now.month, now.day - days, hour, minute);

  void addUser(AppUser u) => s.users[u.id] = u;
  addUser(
    AppUser(
      id: 'me',
      name: 'Дмитрий',
      nick: 'dima',
      bio: 'Пишу день за днём',
      city: 'Москва',
      avatarColor: const Color(0xFF3FA9A0),
    ),
  );
  addUser(
    AppUser(
      id: 'masha',
      name: 'Маша',
      nick: 'masha',
      bio: 'Море, книги, кофе',
      city: 'Сочи',
      avatarColor: const Color(0xFFD98C5F),
    ),
  );
  addUser(
    AppUser(
      id: 'oleg',
      name: 'Олег',
      nick: 'oleg',
      bio: 'Гитара и походы',
      avatarColor: const Color(0xFF5B7FC4),
    ),
  );
  addUser(
    AppUser(
      id: 'olya',
      name: 'Оля',
      nick: 'olya',
      bio: 'Учусь замечать хорошее',
      city: 'Казань',
      avatarColor: const Color(0xFFB55D8A),
      isPrivate: true,
    ),
  );
  addUser(
    AppUser(
      id: 'ivan',
      name: 'Иван',
      nick: 'ivan.run',
      bio: 'Бегаю каждое утро',
      avatarColor: const Color(0xFF5FA85B),
    ),
  );
  addUser(
    AppUser(
      id: 'kate',
      name: 'Катя',
      nick: 'kate',
      bio: 'Фотографирую город',
      city: 'Санкт-Петербург',
      avatarColor: const Color(0xFF8A6FC4),
    ),
  );

  s.following['me'] = {'masha', 'oleg'};
  s.following['masha'] = {'me', 'olya'};
  s.following['oleg'] = {'me', 'masha'};
  s.following['ivan'] = {'me'};
  s.following['kate'] = {};
  s.following['olya'] = {'masha', 'oleg'};

  var g = 0;
  Story story(
    String author,
    DateTime at, {
    Audience v = Audience.everyone,
    String? caption,
    bool keep = true,
  }) {
    final st = Story(
      id: newId(),
      authorId: author,
      createdAt: at,
      visibility: v,
      media: demoMedia(g++),
      keepInCalendar: keep,
      overlays: [if (caption != null) StoryOverlay(text: caption, dy: 0.75)],
    );
    s.posts.add(st);
    return st;
  }

  Story textStory(String author, DateTime at, String text, int color) {
    final st = Story(
      id: newId(),
      authorId: author,
      createdAt: at,
      visibility: Audience.everyone,
      media: Media(
        type: MediaType.image,
        placeholder: [textStoryColors[color], textStoryColors[color]],
      ),
      text: text,
    );
    s.posts.add(st);
    return st;
  }

  Plan plan(String author, DateTime at, String text) {
    final pl = Plan(
      id: newId(),
      authorId: author,
      createdAt: now,
      visibility: Audience.onlyMe,
      text: text,
      planAt: at,
    );
    s.posts.add(pl);
    return pl;
  }

  DiaryPost diary(
    String author,
    DateTime at,
    String text, {
    Audience v = Audience.everyone,
    Weather? w,
    int photos = 0,
  }) {
    final e = DiaryPost(
      id: newId(),
      authorId: author,
      createdAt: at,
      visibility: v,
      date: dateOnly(at),
      text: text,
      photos: [for (var i = 0; i < photos; i++) demoMedia(g++)],
      weather: w,
    );
    s.posts.add(e);
    return e;
  }

  // Мои записи за последний месяц.
  final myCaptions = [
    'Утренний кофе',
    'Прогулка',
    'Закат',
    null,
    'Новый проект',
    null,
    'Выходные',
  ];
  for (var d = 1; d < 30; d++) {
    if (d % 3 == 0) continue;
    story('me', ago(d, 9 + d % 10), caption: myCaptions[d % myCaptions.length]);
    if (d % 4 == 1) {
      textStory('me', ago(d, 14, 30), 'День получился хорошим', d % 7);
    }
    if (d % 5 == 2) {
      diary(
        'me',
        ago(d, 9, 15),
        'Утро началось с пробежки, 5 км',
        w: Weather(8 + (d % 7).toDouble(), d % 3 == 0 ? 61 : 1),
      );
      diary('me', ago(d, 13, 40), 'Обед с коллегами', photos: 1);
      diary(
        'me',
        ago(d, 21, 5),
        'Спокойный день. Работал, вечером гулял по парку. #работа',
        v: Audience.onlyMe,
      );
    }
  }
  diary(
    'me',
    ago(4, 22),
    'Тяжёлый день, много задач и мало сна. #работа',
    v: Audience.onlyMe,
    w: const Weather(6, 3),
  );
  textStory(
    'me',
    now.subtract(const Duration(hours: 1)),
    'Первый макет приложения готов',
    0,
  );
  diary(
    'me',
    now.subtract(const Duration(hours: 4)),
    'Утро началось с пробежки 🏃',
    w: const Weather(12, 1),
  );
  diary(
    'me',
    now.subtract(const Duration(hours: 2)),
    'Обед с Машей',
    photos: 1,
  );
  plan('me', ago(-7, 9), 'День рождения мамы, купить цветы');
  plan('me', ago(-3, 18, 30), 'Встреча с Олегом');

  // Записи других людей.
  final mashaSea = story(
    'masha',
    now.subtract(const Duration(hours: 2)),
    caption: 'Утро на море',
  );
  story('masha', now.subtract(const Duration(hours: 5)));
  final olegNote = textStory(
    'oleg',
    now.subtract(const Duration(hours: 3)),
    'Чем проще план, тем больше шансов, что он сработает',
    4,
  );
  story('oleg', now.subtract(const Duration(hours: 7)), caption: 'Концерт');
  final olegDiary = diary(
    'oleg',
    ago(1, 21),
    'Сходили в поход на два дня. Ноги гудят, но это того стоило. Ночью было видно Млечный Путь. #походы',
    w: const Weather(4, 0),
    photos: 2,
  );
  diary('oleg', ago(1, 8, 30), 'Выходим на маршрут, погода отличная');
  textStory(
    'olya',
    now.subtract(const Duration(hours: 4)),
    'Наконец-то дочитала книгу, которую начала летом',
    6,
  );
  diary(
    'olya',
    now.subtract(const Duration(hours: 3)),
    'Учусь замечать хорошее: солнце, кофе, тишина',
  );
  story(
    'olya',
    now.subtract(const Duration(hours: 6)),
    caption: 'Казань вечером',
  );
  story(
    'ivan',
    now.subtract(const Duration(hours: 1)),
    caption: '10 км до завтрака',
  );
  textStory(
    'ivan',
    now.subtract(const Duration(hours: 9)),
    '«Дорогу осилит идущий»',
    3,
  );
  story(
    'kate',
    now.subtract(const Duration(hours: 8)),
    caption: 'Невский в тумане',
  );
  diary(
    'kate',
    now.subtract(const Duration(days: 2)),
    'Нашла дворик, где никогда не была',
    photos: 1,
  );
  for (var d = 1; d < 25; d += 2) {
    story('masha', ago(d, 10), caption: d % 4 == 1 ? 'Море' : null);
    story('oleg', ago(d + 1, 17));
  }

  // Комментарии и лайки.
  mashaSea.likes.addAll({'oleg', 'ivan', 'kate'});
  mashaSea.comments.add(
    Comment(
      id: newId(),
      authorId: 'oleg',
      text: 'Красота! Завидую',
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
  );
  final root = mashaSea.comments.first;
  mashaSea.comments.add(
    Comment(
      id: newId(),
      authorId: 'masha',
      text: '@oleg приезжай!',
      createdAt: now.subtract(const Duration(minutes: 40)),
      replyToId: root.id,
    ),
  );
  olegNote.likes.addAll({'masha', 'me'});
  olegDiary.likes.add('masha');
  olegDiary.comments.add(
    Comment(
      id: newId(),
      authorId: 'masha',
      text: 'Покажи фото с Млечным Путём!',
      createdAt: now.subtract(const Duration(hours: 10)),
    ),
  );

  final myLast = s.posts
      .whereType<Story>()
      .where((p) => p.authorId == 'me')
      .first;
  myLast.likes.addAll({'masha', 'oleg'});
  myLast.viewers.addAll({'masha', 'oleg', 'ivan'});

  // Чаты.
  final c1 = Chat(id: newId(), userIds: ['me', 'masha']);
  c1.messages.addAll([
    ChatMessage(
      id: newId(),
      senderId: 'me',
      createdAt: now.subtract(const Duration(hours: 3)),
      text: 'Привет! Как отдых?',
    )..read = true,
    ChatMessage(
      id: newId(),
      senderId: 'masha',
      createdAt: now.subtract(const Duration(minutes: 50)),
      text: 'Отлично, вода ещё тёплая',
      replyToStoryId: mashaSea.id,
    ),
    ChatMessage(
      id: newId(),
      senderId: 'masha',
      createdAt: now.subtract(const Duration(minutes: 49)),
      text: '😍',
    ),
  ]);
  final c2 = Chat(id: newId(), userIds: ['me', 'oleg']);
  c2.messages.addAll([
    ChatMessage(
      id: newId(),
      senderId: 'oleg',
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      text: 'В субботу в силе?',
    )..read = true,
    ChatMessage(
      id: newId(),
      senderId: 'me',
      createdAt: now.subtract(const Duration(days: 1, hours: 1)),
      text: 'Да, увидимся в субботу',
    )..read = true,
  ]);
  s.chats.addAll([c1, c2]);

  // Уведомления.
  s.notifications.addAll([
    AppNotification(
      id: newId(),
      kind: NotificationKind.like,
      fromUserId: 'masha',
      createdAt: now.subtract(const Duration(minutes: 30)),
      postId: myLast.id,
    ),
    AppNotification(
      id: newId(),
      kind: NotificationKind.follow,
      fromUserId: 'ivan',
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: newId(),
      kind: NotificationKind.like,
      fromUserId: 'oleg',
      createdAt: now.subtract(const Duration(hours: 6)),
      postId: myLast.id,
    )..read = true,
  ]);
}
