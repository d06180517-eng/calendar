import 'package:calendar_app/data/app_state.dart';

import 'demo_data.dart';

import 'package:calendar_app/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 19, 15, 0);
  late AppState s;

  setUp(() {
    s = AppState(clock: () => fixedNow);
    seedDemo(s);
    s.currentUserId = 'me';
  });

  Media img() => Media(type: MediaType.image, placeholder: demoGradients[0]);

  group('Вход', () {
    test('проверяет email и пароль', () {
      s.logout();
      expect(s.login('bad', '123456'), 'badEmail');
      expect(s.login('a@b.ru', '123'), 'shortPassword');
      expect(s.login('a@b.ru', '123456'), isNull);
      expect(s.isLoggedIn, isTrue);
    });

    test('регистрация не даёт занять чужой ник', () {
      s.logout();
      expect(s.register('a@b.ru', '123456', 'Дима', 'masha'), 'nickTaken');
      expect(s.isLoggedIn, isFalse);
      expect(s.register('a@b.ru', '123456', 'Дима', '@dimas'), isNull);
      expect(s.me!.nick, 'dimas');
    });
  });

  group('Сторис', () {
    test('видео длиннее минуты режется на части по 60 секунд', () {
      final media = Media(type: MediaType.video, path: '/tmp/v.mp4');
      final parts = s.createStory(
        media: media,
        videoDuration: const Duration(seconds: 150),
      );
      expect(parts.length, 3);
      expect(parts.map((p) => p.media.start.inSeconds), [0, 60, 120]);
      expect(parts.map((p) => p.media.end!.inSeconds), [60, 120, 150]);
      expect(parts.every((p) => p.groupId == parts.first.groupId), isTrue);
      expect(parts.map((p) => p.partIndex), [0, 1, 2]);
    });

    test('ровно 60 секунд — одна сторис', () {
      final media = Media(type: MediaType.video, path: '/tmp/v.mp4');
      expect(
        s
            .createStory(
              media: media,
              videoDuration: const Duration(seconds: 60),
            )
            .length,
        1,
      );
    });

    test(
      'после 24 часов сторис остаётся в календаре, только если так выбрано',
      () {
        final old = Story(
          id: 'old',
          authorId: 'me',
          createdAt: fixedNow.subtract(const Duration(days: 2)),
          visibility: Audience.everyone,
          media: img(),
          keepInCalendar: false,
        );
        s.posts.add(old);
        expect(s.storiesOfDay('me', old.day).contains(old), isFalse);
        s.setKeepInCalendar(old, true);
        expect(s.storiesOfDay('me', old.day).contains(old), isTrue);
      },
    );

    test(
      'отметка человека создаёт ему уведомление (для текущего пользователя)',
      () {
        s.currentUserId = 'masha';
        final before = s.notifications.length;
        s.createStory(
          media: img(),
          overlays: [StoryOverlay(text: '@dima', mentionUserId: 'me')],
        );
        expect(s.notifications.length, before + 1);
        expect(s.notifications.first.kind, NotificationKind.mention);
      },
    );
  });

  group('Приватность', () {
    test('«только я» не видит никто, кроме автора', () {
      final n = s.addDiaryPost(
        date: fixedNow,
        text: 'секрет',
        visibility: Audience.onlyMe,
      )!;
      expect(s.canSee(n, 'me'), isTrue);
      expect(s.canSee(n, 'masha'), isFalse);
    });

    test('«подписчики» видят только подписанные на автора', () {
      final n = s.createTextStory(
        text: 'для своих',
        background: textStoryColors.first,
        visibility: Audience.followers,
      );
      expect(s.canSee(n, 'masha'), isTrue); // masha подписана на me
      expect(s.canSee(n, 'kate'), isFalse);
    });

    test('закрытый профиль: «все» значит только подписчики', () {
      final olyaNote = s.posts.whereType<DiaryPost>().firstWhere(
        (n) => n.authorId == 'olya',
      );
      expect(s.canSee(olyaNote, 'me'), isFalse);
      expect(s.canSee(olyaNote, 'masha'), isTrue);
    });

    test('подписка на закрытый профиль — через запрос', () {
      s.follow('olya');
      expect(s.isFollowing('me', 'olya'), isFalse);
      expect(s.hasRequested('me', 'olya'), isTrue);
      s.currentUserId = 'olya';
      s.answerFollowRequest('me', true);
      expect(s.isFollowing('me', 'olya'), isTrue);
    });

    test('открытие профиля принимает все ожидающие запросы', () {
      s.setPrivate(true);
      s.currentUserId = 'kate';
      s.follow('me');
      s.currentUserId = 'me';
      expect(s.isFollowing('kate', 'me'), isFalse);
      s.setPrivate(false);
      expect(s.isFollowing('kate', 'me'), isTrue);
    });

    test('блокировка скрывает записи, отписывает и запрещает чат', () {
      final mashaPost = s.posts.firstWhere((p) => p.authorId == 'masha');
      s.block('masha');
      expect(s.canSee(mashaPost, 'me'), isFalse);
      expect(s.isFollowing('me', 'masha'), isFalse);
      expect(s.isFollowing('masha', 'me'), isFalse);
      expect(s.sendMessage(s.chatWith('masha'), text: 'привет'), isNull);
      expect(s.feed().any((p) => p.authorId == 'masha'), isFalse);
      s.unblock('masha');
      expect(s.canSee(mashaPost, 'me'), isTrue);
    });
  });

  group('Лента', () {
    test('сначала подписки и подписчики, потом остальные', () {
      final feed = s.feed();
      expect(feed, isNotEmpty);
      final close = {...s.followingOf('me'), ...s.followersOf('me')};
      var seenOther = false;
      for (final p in feed) {
        final isClose = close.contains(p.authorId);
        if (!isClose) seenOther = true;
        if (seenOther) {
          expect(isClose, isFalse, reason: 'близкие должны идти раньше');
        }
      }
      expect(feed.any((p) => !close.contains(p.authorId)), isTrue);
    });

    test('в ленте нет своих записей, старых сторис, планов и скрытого', () {
      final feed = s.feed();
      expect(feed.any((p) => p.authorId == 'me'), isFalse);
      expect(
        feed.whereType<Story>().every((st) => st.isActiveAt(fixedNow)),
        isTrue,
      );
      expect(feed.whereType<Plan>(), isEmpty);
      expect(feed.whereType<DiaryPost>(), isNotEmpty);
      final first = feed.first;
      s.hidePost(first.id);
      expect(s.feed().contains(first), isFalse);
    });

    test('части одного видео идут подряд и по порядку', () {
      s.currentUserId = 'masha';
      s.createStory(
        media: Media(type: MediaType.video, path: '/v.mp4'),
        videoDuration: const Duration(seconds: 130),
      );
      s.currentUserId = 'me';
      final parts = s
          .feed()
          .whereType<Story>()
          .where((p) => p.partCount == 3)
          .toList();
      expect(parts.map((p) => p.partIndex), [0, 1, 2]);
      final feed = s.feed();
      final i = feed.indexOf(parts.first);
      expect(feed.sublist(i, i + 3), parts);
    });
  });

  group('Дневник и пометки', () {
    test('в дневник дня можно писать сколько угодно постов', () {
      final day = DateTime(2026, 10, 19);
      s.posts.removeWhere((p) => p is DiaryPost && p.authorId == 'me');
      s.addDiaryPost(date: day, text: 'утро');
      s.addDiaryPost(date: day, text: 'обед', photos: [img()]);
      s.addDiaryPost(date: day, text: 'вечер #Работа и #спорт');
      final posts = s.diaryOf('me', day);
      expect(posts.map((p) => p.text.split(' ').first), [
        'утро',
        'обед',
        'вечер',
      ]);
      expect(posts.last.tags, ['#работа', '#спорт']);
      expect(s.searchDiaryByTag('спорт').single, posts.last);
      expect(posts.every((p) => p.visibility == Audience.everyone), isTrue);
    });

    test('пустой пост не публикуется', () {
      expect(s.addDiaryPost(date: fixedNow, text: '   '), isNull);
    });

    test('пост в прошлый день остаётся в том дне', () {
      final past = DateTime(2026, 10, 10);
      final p = s.addDiaryPost(date: past, text: 'вспомнил')!;
      expect(sameDay(p.createdAt, past), isTrue);
      expect(s.diaryOf('me', past).contains(p), isTrue);
      expect(s.diaryDays('me').contains(past), isTrue);
    });

    test('чужие дни дневника — только с видимыми постами', () {
      s.currentUserId = 'olya';
      s.posts.removeWhere((p) => p is DiaryPost && p.authorId == 'olya');
      s.addDiaryPost(
        date: DateTime(2026, 10, 1),
        text: 'личное',
        visibility: Audience.onlyMe,
      );
      s.addDiaryPost(date: DateTime(2026, 10, 2), text: 'для всех');
      expect(s.diaryDays('olya', viewer: 'masha'), [DateTime(2026, 10, 2)]);
      expect(s.diaryDays('olya', viewer: 'me'), isEmpty); // закрытый профиль
    });

    test('свободная пометка — это текстовая сторис дня', () {
      final st = s.createTextStory(
        text: 'а' * 400,
        background: textStoryColors[2],
      );
      expect(st.isText, isTrue);
      expect(st.text!.length, maxNoteLength);
      expect(st.background, textStoryColors[2]);
      expect(s.storiesOfDay('me', fixedNow).contains(st), isTrue);
    });

    test('план попадает в будущий день и по умолчанию виден только мне', () {
      final at = DateTime(2026, 11, 5, 9);
      final n = s.createPlan(text: 'ДР мамы', planAt: at);
      expect(n.visibility, Audience.onlyMe);
      expect(s.plansOfDay('me', DateTime(2026, 11, 5)).contains(n), isTrue);
      expect(s.plansOfDay('me', dateOnly(fixedNow)).contains(n), isFalse);
    });

    test('серия считает дни подряд до сегодня', () {
      s.posts.removeWhere((p) => p.authorId == 'me');
      for (var d = 0; d < 4; d++) {
        s.posts.add(
          DiaryPost(
            id: 'n$d',
            authorId: 'me',
            createdAt: fixedNow.subtract(Duration(days: d)),
            visibility: Audience.everyone,
            date: dateOnly(fixedNow.subtract(Duration(days: d))),
            text: 'x',
          ),
        );
      }
      s.createPlan(text: 'p', planAt: fixedNow.add(const Duration(days: 1)));
      expect(s.streak('me'), 4);
      s.posts.removeWhere(
        (p) => p.id == 'n0',
      ); // сегодня ещё не писал — серия жива
      expect(s.streak('me'), 3);
      s.posts.removeWhere((p) => p.id == 'n1');
      expect(s.streak('me'), 0);
    });

    test('опубликованные дни не считают «только я» и будущие планы', () {
      s.posts.removeWhere((p) => p.authorId == 'me');
      s.addDiaryPost(date: fixedNow, text: 'a');
      s.addDiaryPost(
        date: fixedNow.subtract(const Duration(days: 1)),
        text: 'b',
        visibility: Audience.onlyMe,
      );
      s.createPlan(
        text: 'c',
        planAt: fixedNow.add(const Duration(days: 3)),
        visibility: Audience.everyone,
      );
      expect(s.publishedDays('me'), {dateOnly(fixedNow)});
    });
  });

  group('Комментарии и лайки', () {
    test('ответы собираются в ветку под корневым комментарием', () {
      final post = s.posts.firstWhere((p) => p.authorId == 'oleg');
      final root = s.addComment(post, 'круто');
      final r1 = s.addComment(post, '@dima спасибо', replyTo: root);
      final r2 = s.addComment(post, 'ответ на ответ', replyTo: r1);
      expect(r1.replyToId, root.id);
      expect(r2.replyToId, root.id);
      expect(s.repliesTo(post, root), [r1, r2]);
      s.deleteComment(post, root);
      expect(post.comments.where((c) => c.id == r1.id), isEmpty);
    });

    test('лайк переключается, двойной тап лайкает только один раз', () {
      final post = s.posts.firstWhere((p) => p.authorId == 'kate');
      s.toggleLike(post);
      expect(post.likes.contains('me'), isTrue);
      s.like(post);
      expect(post.likes.length, 1);
      s.toggleLike(post);
      expect(post.likes.contains('me'), isFalse);
    });

    test('лайк комментария', () {
      final post = s.posts.firstWhere((p) => p.authorId == 'oleg');
      final c = s.addComment(post, 'привет');
      s.toggleCommentLike(post, c);
      expect(c.likes, {'me'});
    });
  });

  group('Чаты', () {
    test('ответ на сторис уходит в личный чат и считается непрочитанным у получателя', () {
      final story = s.posts.whereType<Story>().firstWhere(
        (p) => p.authorId == 'ivan',
      );
      final chat = s.chatWith('ivan');
      s.sendMessage(chat, text: 'класс!', replyToStoryId: story.id);
      expect(s.myChats().first, chat);
      s.currentUserId = 'ivan';
      expect(s.unreadIn(chat), 1);
      s.markChatRead(chat);
      expect(s.unreadIn(chat), 0);
    });

    test('пустое сообщение не отправляется', () {
      expect(s.sendMessage(s.chatWith('oleg'), text: '   '), isNull);
    });
  });
}
