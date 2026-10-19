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

  Note note(
    String author,
    DateTime at,
    NoteTemplate t,
    String text, {
    Audience v = Audience.everyone,
    DateTime? planAt,
  }) {
    final n = Note(
      id: newId(),
      authorId: author,
      createdAt: at,
      visibility: planAt != null ? Audience.onlyMe : v,
      template: t,
      text: text,
      planAt: planAt,
      remind: planAt != null,
    );
    s.posts.add(n);
    return n;
  }

  DiaryEntry diary(
    String author,
    DateTime day,
    String text, {
    Mood? mood,
    List<String> tags = const [],
    Audience v = Audience.onlyMe,
    Weather? w,
  }) {
    final e = DiaryEntry(
      id: newId(),
      authorId: author,
      createdAt: DateTime(day.year, day.month, day.day, 22),
      visibility: v,
      date: day,
      text: text,
      mood: mood,
      tags: tags,
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
      note(
        'me',
        ago(d, 14, 30),
        NoteTemplate.moment,
        'Поймал себя на мысли, что день получился хорошим',
      );
    }
    if (d % 5 == 2) {
      diary(
        'me',
        ago(d),
        'Спокойный день. Работал, вечером гулял по парку.',
        mood: d % 2 == 0 ? Mood.good : Mood.neutral,
        tags: ['#работа'],
        w: Weather(8 + (d % 7).toDouble(), d % 3 == 0 ? 61 : 1),
      );
    }
  }
  diary(
    'me',
    ago(4),
    'Тяжёлый день, много задач и мало сна.',
    mood: Mood.bad,
    tags: ['#работа'],
    w: const Weather(6, 3),
  );
  note(
    'me',
    ago(0, 10, 47),
    NoteTemplate.moment,
    'Первый макет приложения готов',
  );
  note(
    'me',
    ago(1, 19, 5),
    NoteTemplate.gratitude,
    'Спасибо другу, который приехал помочь с переездом',
  );
  note(
    'me',
    ago(-7, 9),
    NoteTemplate.plan,
    'День рождения мамы, купить цветы',
    planAt: ago(-7, 9),
  );
  note(
    'me',
    ago(-3, 18),
    NoteTemplate.plan,
    'Встреча с Олегом',
    planAt: ago(-3, 18, 30),
  );

  // Записи других людей.
  final mashaSea = story(
    'masha',
    now.subtract(const Duration(hours: 2)),
    caption: 'Утро на море',
  );
  story('masha', now.subtract(const Duration(hours: 5)));
  final olegNote = note(
    'oleg',
    now.subtract(const Duration(hours: 3)),
    NoteTemplate.thought,
    'Чем проще план, тем больше шансов, что он сработает',
  );
  story('oleg', now.subtract(const Duration(hours: 7)), caption: 'Концерт');
  final olegDiary = diary(
    'oleg',
    dateOnly(now.subtract(const Duration(days: 1))),
    'Сходили в поход на два дня. Ноги гудят, но это того стоило. Ночью было видно Млечный Путь.',
    mood: Mood.good,
    tags: ['#походы'],
    v: Audience.everyone,
    w: const Weather(4, 0),
  );
  note(
    'olya',
    now.subtract(const Duration(hours: 4)),
    NoteTemplate.joy,
    'Наконец-то дочитала книгу, которую начала летом',
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
  note(
    'ivan',
    now.subtract(const Duration(hours: 9)),
    NoteTemplate.quote,
    '«Дорогу осилит идущий»',
  );
  story(
    'kate',
    now.subtract(const Duration(hours: 8)),
    caption: 'Невский в тумане',
  );
  note(
    'kate',
    now.subtract(const Duration(days: 2)),
    NoteTemplate.moment,
    'Нашла дворик, где никогда не была',
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
