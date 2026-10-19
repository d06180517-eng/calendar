import 'dart:io';

import 'package:calendar_app/data/app_state.dart';
import 'package:calendar_app/data/demo_data.dart';
import 'package:calendar_app/data/models.dart';
import 'package:calendar_app/l10n.dart';
import 'package:calendar_app/main.dart';
import 'package:calendar_app/services/reminder_service.dart';
import 'package:calendar_app/services/weather_service.dart';
import 'package:calendar_app/ui/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// В тестах нет геолокации — погоду не запрашиваем.
class _NoWeather extends WeatherService {
  @override
  Future<Weather?> current() async => null;
}

Finder inCalendar(Finder f) =>
    find.descendant(of: find.byType(CalendarScreen), matching: f);
Finder calendarList() => inCalendar(find.byType(Scrollable)).first;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
  });

  Future<AppState> pumpApp(
    WidgetTester tester, {
    bool loggedIn = true,
    String lang = 'ru',
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final s = AppState(clock: () => DateTime(2026, 10, 19, 15));
    seedDemo(s);
    s.languageCode = lang;
    if (loggedIn) s.currentUserId = 'me';
    await tester.pumpWidget(
      CalendarApp(
        state: s,
        reminders: ReminderService(),
        weather: _NoWeather(),
      ),
    );
    await tester.pumpAndSettle();
    return s;
  }

  testWidgets('вход по email открывает календарь', (tester) async {
    await pumpApp(tester, loggedIn: false);
    expect(find.text('Войти'), findsWidgets);
    await tester.enterText(find.byKey(const Key('email')), 'dima@mail.ru');
    await tester.enterText(find.byKey(const Key('password')), '123');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Пароль — минимум 6 символов'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('password')), '123456');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Октябрь 2026'), findsOneWidget);
  });

  testWidgets('добавление пометки на сегодня', (tester) async {
    final s = await pumpApp(tester);
    await tester.scrollUntilVisible(
      inCalendar(find.byKey(const Key('addNote'))),
      200,
      scrollable: calendarList(),
    );
    await tester.tap(inCalendar(find.byKey(const Key('addNote'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Радость'));
    await tester.enterText(find.byKey(const Key('noteText')), 'Солнце вышло');
    await tester.tap(find.byKey(const Key('saveNote')));
    await tester.pumpAndSettle();
    expect(
      s.posts.whereType<Note>().any((n) => n.text == 'Солнце вышло'),
      isTrue,
    );
    await tester.scrollUntilVisible(
      inCalendar(find.text('Солнце вышло')),
      200,
      scrollable: calendarList(),
    );
    expect(find.text('Солнце вышло'), findsOneWidget);
  });

  testWidgets('пустую пометку сохранить нельзя', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(
      inCalendar(find.byKey(const Key('addNote'))),
      200,
      scrollable: calendarList(),
    );
    await tester.tap(inCalendar(find.byKey(const Key('addNote'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveNote')));
    await tester.pumpAndSettle();
    expect(find.text('Напишите хоть пару слов'), findsOneWidget);
  });

  testWidgets('дневник: настроение, текст, тег', (tester) async {
    final s = await pumpApp(tester);
    await tester.scrollUntilVisible(
      inCalendar(find.byKey(const Key('writeDiary'))),
      200,
      scrollable: calendarList(),
    );
    await tester.tap(inCalendar(find.byKey(const Key('writeDiary'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хорошо'));
    await tester.enterText(find.byKey(const Key('diaryText')), 'Хороший день');
    await tester.enterText(
      find.widgetWithText(TextField, 'Добавить тег'),
      'прогулка',
    );
    await tester.tap(find.byKey(const Key('saveDiary')));
    await tester.pumpAndSettle();
    final e = s.diaryOf('me', DateTime(2026, 10, 19))!;
    expect(e.text, 'Хороший день');
    expect(e.mood, Mood.good);
    expect(e.tags, ['#прогулка']);
    expect(e.visibility, Audience.onlyMe);
  });

  testWidgets('лента: лайк и комментарий', (tester) async {
    final s = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('nav_1')));
    await tester.pumpAndSettle();
    final first = s.feed().first;
    final likes = first.likes.length;
    await tester.tap(find.byKey(const Key('likeButton')).first);
    await tester.pumpAndSettle();
    expect(first.likes.length, likes + 1);

    await tester.tap(find.byKey(const Key('commentsButton')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('commentInput')), 'Отлично!');
    await tester.tap(find.byKey(const Key('sendComment')));
    await tester.pumpAndSettle();
    expect(first.comments.any((c) => c.text == 'Отлично!'), isTrue);
    expect(find.text('Отлично!'), findsOneWidget);
  });

  testWidgets('чаты: отправка сообщения', (tester) async {
    final s = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('nav_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('oleg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chatInput')), 'Во сколько?');
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();
    expect(find.text('Во сколько?'), findsOneWidget);
    expect(s.chatWith('oleg').messages.last.text, 'Во сколько?');
  });

  testWidgets('профиль и настройки: тёмная тема и закрытый профиль', (
    tester,
  ) async {
    final s = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('nav_4')));
    await tester.pumpAndSettle();
    expect(find.text('Дмитрий'), findsOneWidget);
    await tester.tap(find.byKey(const Key('openSettings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(s.themeMode, ThemeMode.dark);
    await tester.tap(find.byKey(const Key('privateSwitch')));
    await tester.pumpAndSettle();
    expect(s.me!.isPrivate, isTrue);
  });

  testWidgets('чужой профиль: подписка и календарь', (tester) async {
    final s = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('nav_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openSearch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchField')), 'kat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Катя'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('followButton')));
    await tester.pumpAndSettle();
    expect(s.isFollowing('me', 'kate'), isTrue);
    expect(find.text('Октябрь 2026'), findsOneWidget);
  });

  testWidgets('английский интерфейс', (tester) async {
    await pumpApp(tester, lang: 'en');
    expect(find.text('October 2026'), findsOneWidget);
    expect(inCalendar(find.text('Add a note')), findsOneWidget);
  });

  test('у всех ключей перевода есть русский и английский текст', () {
    final used = <String>{};
    final re = RegExp(r"""\.t\(\s*'([A-Za-z_]+)'""");
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    // Ключи, собранные динамически.
    for (final t in NoteTemplate.values) {
      used
        ..add('tpl_${t.name}')
        ..add('tplHint_${t.name}');
    }
    used.addAll([
      'reportSpam',
      'reportAbuse',
      'reportNudity',
      'reportOther',
      'moodGood',
      'moodNeutral',
      'moodBad',
      'followers_one',
      'followers_many',
      'days_one',
      'days_many',
      'badEmail',
      'shortPassword',
      'emptyNick',
      'nickTaken',
      'tabCalendar',
      'tabFeed',
      'tabCreate',
      'tabChats',
      'tabProfile',
    ]);
    final missingRu = used.where((k) => !ru.containsKey(k)).toList();
    final missingEn = used.where((k) => !en.containsKey(k)).toList();
    expect(missingRu, isEmpty, reason: 'нет в ru');
    expect(missingEn, isEmpty, reason: 'нет в en');
    expect(
      ru.containsKey('followers_few') && ru.containsKey('days_few'),
      isTrue,
    );
  });
}
