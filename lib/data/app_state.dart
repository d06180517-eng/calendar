import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'backend.dart';
import 'models.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Всё состояние приложения. Экраны читают его синхронно, а изменения
/// сразу применяются в памяти и уходят на сервер ([backend]). Сервер
/// присылает изменения других людей через методы `apply…` ниже.
/// Без сервера (тесты, веб-превью) данные живут только в памяти.
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  Backend? backend;

  final DateTime Function() _clock;
  DateTime get now => _clock();

  // ---------- Настройки ----------
  ThemeMode themeMode = ThemeMode.system;
  String? languageCode; // null = как в системе
  bool diaryReminderOn = true;
  TimeOfDay diaryReminderTime = const TimeOfDay(hour: 21, minute: 0);

  Future<void> loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      themeMode = ThemeMode.values[p.getInt('theme') ?? ThemeMode.system.index];
      languageCode = p.getString('lang');
      diaryReminderOn = p.getBool('remOn') ?? true;
      final m = p.getInt('remMin') ?? 21 * 60;
      diaryReminderTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    } catch (_) {
      // Настройки не критичны: остаёмся на значениях по умолчанию.
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('theme', themeMode.index);
      if (languageCode == null) {
        await p.remove('lang');
      } else {
        await p.setString('lang', languageCode!);
      }
      await p.setBool('remOn', diaryReminderOn);
      await p.setInt(
        'remMin',
        diaryReminderTime.hour * 60 + diaryReminderTime.minute,
      );
    } catch (_) {}
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _saveSettings();
    notifyListeners();
  }

  void setLanguage(String? code) {
    languageCode = code;
    _saveSettings();
    notifyListeners();
  }

  void setDiaryReminder({bool? on, TimeOfDay? time}) {
    if (on != null) diaryReminderOn = on;
    if (time != null) diaryReminderTime = time;
    _saveSettings();
    notifyListeners();
  }

  // ---------- Данные ----------
  final Map<String, AppUser> users = {};
  final List<Post> posts = [];
  final List<Chat> chats = [];
  final List<AppNotification> notifications = [];

  /// following[a] — на кого подписан a.
  final Map<String, Set<String>> following = {};

  /// followRequests[a] — кто просится подписаться на закрытый профиль a.
  final Map<String, Set<String>> followRequests = {};
  final Map<String, Set<String>> blocked = {};
  final Set<String> hiddenPostIds = {};
  final List<String> reports = [];

  String? currentUserId;
  AppUser? get me => currentUserId == null ? null : users[currentUserId];
  bool get isLoggedIn => currentUserId != null;

  /// Пользователь по id. Пока профиль не загрузился с сервера — заглушка.
  AppUser user(String id) =>
      users[id] ?? AppUser(id: id, name: '…', nick: 'user');

  // ---------- Вход ----------
  String? _checkCredentials(String email, String password) {
    if (!email.contains('@') || email.trim().length < 5) return 'badEmail';
    if (password.length < 6) return 'shortPassword';
    return null;
  }

  Future<String?> login(String email, String password) async {
    final err = _checkCredentials(email, password);
    if (err != null) return err;
    if (backend != null) return backend!.signIn(email.trim(), password);
    _ensureLocalUser(email.trim().split('@').first);
    currentUserId = localUserId;
    notifyListeners();
    return null;
  }

  /// Без сервера на телефоне один локальный аккаунт.
  static const localUserId = 'me';

  void _ensureLocalUser(String nick) {
    if (users.containsKey(localUserId)) return;
    users[localUserId] = AppUser(
      id: localUserId,
      name: nick,
      nick: nickFromEmail(nick),
    );
  }

  Future<String?> register(
    String email,
    String password,
    String name,
    String nick,
  ) async {
    final err = _checkCredentials(email, password);
    if (err != null) return err;
    final cleanNick = nick.trim().replaceAll('@', '').replaceAll(' ', '');
    if (cleanNick.isEmpty) return 'emptyNick';
    final cleanName = name.trim().isEmpty ? cleanNick : name.trim();
    if (backend != null) {
      return backend!.register(email.trim(), password, cleanName, cleanNick);
    }
    if (users.values.any((u) => u.id != localUserId && u.nick == cleanNick)) {
      return 'nickTaken';
    }
    _ensureLocalUser(cleanNick);
    users[localUserId]!
      ..name = cleanName
      ..nick = cleanNick;
    currentUserId = localUserId;
    notifyListeners();
    return null;
  }

  Future<String?> loginWithGoogle() async {
    if (backend != null) return backend!.signInWithGoogle();
    _ensureLocalUser('user');
    currentUserId = localUserId;
    notifyListeners();
    return null;
  }

  Future<String?> resetPassword(String email) async {
    if (!email.contains('@')) return 'badEmail';
    return backend?.resetPassword(email.trim());
  }

  void logout() {
    final b = backend;
    currentUserId = null;
    if (b != null) {
      b.signOut();
      clearData();
    }
    notifyListeners();
  }

  void updateProfile(void Function(AppUser u) change) {
    final u = me!;
    final oldAvatar = u.avatarBytes;
    change(u);
    if (!identical(oldAvatar, u.avatarBytes)) u.avatarUrl = null;
    backend?.saveUser(u);
    notifyListeners();
  }

  // ---------- Подписки и приватность ----------
  bool isFollowing(String a, String b) => following[a]?.contains(b) ?? false;
  bool hasRequested(String a, String b) =>
      followRequests[b]?.contains(a) ?? false;
  bool isBlockedBetween(String a, String b) =>
      (blocked[a]?.contains(b) ?? false) || (blocked[b]?.contains(a) ?? false);

  Set<String> followersOf(String id) => {
    for (final e in following.entries)
      if (e.value.contains(id)) e.key,
  };

  Set<String> followingOf(String id) => following[id] ?? {};

  /// Подписаться. Для закрытого профиля отправляется запрос.
  void follow(String target) {
    final me = currentUserId!;
    if (me == target || isBlockedBetween(me, target)) return;
    if (user(target).isPrivate) {
      followRequests.putIfAbsent(target, () => {}).add(me);
      backend?.setFollow(me, target, accepted: false);
      _notify(target, NotificationKind.followRequest, me);
    } else {
      following.putIfAbsent(me, () => {}).add(target);
      backend?.setFollow(me, target, accepted: true);
      _notify(target, NotificationKind.follow, me);
    }
    notifyListeners();
  }

  void unfollow(String target) {
    following[currentUserId!]?.remove(target);
    followRequests[target]?.remove(currentUserId!);
    backend?.removeFollow(currentUserId!, target);
    notifyListeners();
  }

  void answerFollowRequest(String from, bool accept) {
    followRequests[currentUserId!]?.remove(from);
    if (accept) {
      following.putIfAbsent(from, () => {}).add(currentUserId!);
      backend?.setFollow(from, currentUserId!, accepted: true);
    } else {
      backend?.removeFollow(from, currentUserId!);
    }
    bool isRequest(AppNotification n) =>
        n.kind == NotificationKind.followRequest && n.fromUserId == from;
    backend?.deleteNotifications(notifications.where(isRequest).toList());
    notifications.removeWhere(isRequest);
    notifyListeners();
  }

  void setPrivate(bool v) {
    me!.isPrivate = v;
    backend?.saveUser(me!);
    if (!v) {
      // Открыли профиль — все ожидающие запросы принимаются.
      for (final f in followRequests[currentUserId!] ?? <String>{}) {
        following.putIfAbsent(f, () => {}).add(currentUserId!);
        backend?.setFollow(f, currentUserId!, accepted: true);
      }
      followRequests[currentUserId!]?.clear();
    }
    notifyListeners();
  }

  void block(String target) {
    final me = currentUserId!;
    blocked.putIfAbsent(me, () => {}).add(target);
    following[me]?.remove(target);
    following[target]?.remove(me);
    backend
      ?..setBlock(me, target, true)
      ..removeFollow(me, target)
      ..removeFollow(target, me);
    notifyListeners();
  }

  void unblock(String target) {
    blocked[currentUserId!]?.remove(target);
    backend?.setBlock(currentUserId!, target, false);
    notifyListeners();
  }

  void report({String? userId, String? postId, required String reason}) {
    reports.add('${userId ?? ''}|${postId ?? ''}|$reason');
    backend?.report(
      currentUserId!,
      userId: userId,
      postId: postId,
      reason: reason,
    );
    if (postId != null) hiddenPostIds.add(postId);
    notifyListeners();
  }

  void hidePost(String postId) {
    hiddenPostIds.add(postId);
    notifyListeners();
  }

  /// Может ли viewer увидеть запись.
  bool canSee(Post p, String viewer) {
    if (p.authorId == viewer) return true;
    if (isBlockedBetween(viewer, p.authorId)) return false;
    switch (p.visibility) {
      case Audience.onlyMe:
        return false;
      case Audience.followers:
        return isFollowing(viewer, p.authorId);
      case Audience.everyone:
        return !user(p.authorId).isPrivate || isFollowing(viewer, p.authorId);
    }
  }

  /// Попадает ли запись в календарь (сторис старше суток — только если
  /// автор решил её оставить).
  bool inCalendar(Post p) =>
      p is! Story || p.keepInCalendar || p.isActiveAt(now);

  // ---------- Выборки для экранов ----------
  List<Post> postsOfDay(String owner, DateTime day, {String? viewer}) {
    final v = viewer ?? currentUserId!;
    final list =
        posts
            .where(
              (p) =>
                  p.authorId == owner &&
                  sameDay(p.day, day) &&
                  inCalendar(p) &&
                  canSee(p, v),
            )
            .toList()
          ..sort((a, b) => _sortTime(a).compareTo(_sortTime(b)));
    return list;
  }

  DateTime _sortTime(Post p) => p is Plan ? p.planAt : p.createdAt;

  List<Story> storiesOfDay(String owner, DateTime day, {String? viewer}) =>
      postsOfDay(owner, day, viewer: viewer).whereType<Story>().toList();

  /// Посты дневника за день, по времени.
  List<DiaryPost> diaryOf(String owner, DateTime day, {String? viewer}) =>
      postsOfDay(owner, day, viewer: viewer).whereType<DiaryPost>().toList();

  List<Plan> plansOfDay(String owner, DateTime day, {String? viewer}) =>
      postsOfDay(owner, day, viewer: viewer).whereType<Plan>().toList();

  /// Дни, в которые в дневнике пользователя есть видимые посты.
  List<DateTime> diaryDays(String owner, {String? viewer}) {
    final v = viewer ?? currentUserId!;
    return {
      for (final p in posts)
        if (p is DiaryPost && p.authorId == owner && canSee(p, v)) p.day,
    }.toList()..sort();
  }

  /// Лента: сначала свежее от подписок и подписчиков, потом от остальных.
  List<Post> feed() {
    final me = currentUserId!;
    final close = {...followingOf(me), ...followersOf(me)};
    final t = now;
    final items = posts.where((p) {
      if (p.authorId == me) return false;
      if (hiddenPostIds.contains(p.id)) return false;
      if (!canSee(p, me)) return false;
      if (p is Story) return p.isActiveAt(t);
      if (p is Plan) return false;
      return t.difference(p.createdAt) < const Duration(days: 7) &&
          !p.createdAt.isAfter(t);
    }).toList();
    int rank(Post p) => close.contains(p.authorId) ? 0 : 1;
    items.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      // Части одного видео идут подряд и по порядку.
      if (a is Story &&
          b is Story &&
          a.groupId != null &&
          a.groupId == b.groupId) {
        return a.partIndex.compareTo(b.partIndex);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }

  /// Пользователи со свежими сторис — для календаря друзей и профиля.
  List<Story> activeStoriesOf(String owner) {
    final me = currentUserId!;
    return posts
        .whereType<Story>()
        .where((s) => s.authorId == owner && s.isActiveAt(now) && canSee(s, me))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Дни, в которые у пользователя есть опубликованные (не «только я») записи.
  Set<DateTime> publishedDays(String owner) => {
    for (final p in posts)
      if (p.authorId == owner &&
          p.visibility != Audience.onlyMe &&
          inCalendar(p) &&
          !p.day.isAfter(dateOnly(now)))
        p.day,
  };

  /// Серия: сколько дней подряд (до сегодня или вчера) есть записи.
  int streak(String owner) {
    final days = {
      for (final p in posts)
        if (p.authorId == owner && p is! Plan) p.day,
    };
    var d = dateOnly(now);
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  Post? postById(String id) {
    for (final p in posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<AppUser> searchUsers(String q) {
    final s = q.trim().toLowerCase().replaceAll('@', '');
    if (s.isEmpty) return [];
    return users.values
        .where(
          (u) =>
              u.id != currentUserId &&
              !isBlockedBetween(currentUserId!, u.id) &&
              (u.name.toLowerCase().contains(s) ||
                  u.nick.toLowerCase().contains(s)),
        )
        .toList();
  }

  // ---------- Создание записей ----------
  /// Публикует сторис. Видео длиннее 60 секунд режется на части,
  /// которые идут подряд.
  List<Story> createStory({
    required Media media,
    Duration? videoDuration,
    List<StoryOverlay> overlays = const [],
    Audience visibility = Audience.everyone,
    bool keepInCalendar = true,
  }) {
    final created = <Story>[];
    final t = now;
    final mentions = overlays.map((o) => o.mentionUserId).whereType<String>();
    if (media.type == MediaType.video &&
        videoDuration != null &&
        videoDuration > maxStoryDuration) {
      final parts =
          (videoDuration.inMilliseconds / maxStoryDuration.inMilliseconds)
              .ceil();
      final group = newId();
      for (var i = 0; i < parts; i++) {
        final start = maxStoryDuration * i;
        var end = maxStoryDuration * (i + 1);
        if (end > videoDuration) end = videoDuration;
        created.add(
          Story(
            id: newId(),
            authorId: currentUserId!,
            // Чуть разносим время, чтобы порядок частей был однозначным.
            createdAt: t.add(Duration(milliseconds: i)),
            visibility: visibility,
            media: Media(
              type: MediaType.video,
              bytes: media.bytes,
              path: media.path,
              start: start,
              end: end,
            ),
            overlays: i == 0 ? overlays : const [],
            keepInCalendar: keepInCalendar,
            groupId: group,
            partIndex: i,
            partCount: parts,
          ),
        );
      }
    } else {
      created.add(
        Story(
          id: newId(),
          authorId: currentUserId!,
          createdAt: t,
          visibility: visibility,
          media: media,
          overlays: overlays,
          keepInCalendar: keepInCalendar,
        ),
      );
    }
    posts.addAll(created);
    created.forEach(_save);
    for (final m in mentions.toSet()) {
      _notify(
        m,
        NotificationKind.mention,
        currentUserId!,
        postId: created.first.id,
      );
    }
    notifyListeners();
    return created;
  }

  void setKeepInCalendar(Story s, bool keep) {
    final ids = s.groupId == null
        ? [s]
        : posts.whereType<Story>().where((x) => x.groupId == s.groupId);
    for (final x in ids) {
      x.keepInCalendar = keep;
      _save(x);
    }
    notifyListeners();
  }

  /// «Свободная» пометка — текстовая сторис на цветном фоне.
  Story createTextStory({
    required String text,
    required Color background,
    Audience visibility = Audience.everyone,
    bool keepInCalendar = true,
  }) {
    final st = Story(
      id: newId(),
      authorId: currentUserId!,
      createdAt: now,
      visibility: visibility,
      media: Media(
        type: MediaType.image,
        placeholder: [background, background],
      ),
      text: _clip(text.trim()),
      keepInCalendar: keepInCalendar,
    );
    posts.add(st);
    _save(st);
    notifyListeners();
    return st;
  }

  Plan createPlan({
    required String text,
    required DateTime planAt,
    bool remind = true,
    Audience visibility = Audience.onlyMe,
  }) {
    final pl = Plan(
      id: newId(),
      authorId: currentUserId!,
      createdAt: now,
      visibility: visibility,
      text: _clip(text.trim()),
      planAt: planAt,
      remind: remind,
    );
    posts.add(pl);
    _save(pl);
    notifyListeners();
    return pl;
  }

  void updatePlan(Plan pl, void Function(Plan) change) {
    change(pl);
    pl.text = _clip(pl.text);
    _save(pl);
    notifyListeners();
  }

  String _clip(String t) =>
      t.length > maxNoteLength ? t.substring(0, maxNoteLength) : t;

  /// Новый пост в дневник дня.
  DiaryPost? addDiaryPost({
    required DateTime date,
    String text = '',
    List<Media> photos = const [],
    Weather? weather,
    Audience visibility = Audience.everyone,
  }) {
    if (text.trim().isEmpty && photos.isEmpty) return null;
    final d = dateOnly(date);
    final t = now;
    // В прошлый день пишем «задним числом», но с текущим временем суток.
    final at = sameDay(d, t)
        ? t
        : DateTime(d.year, d.month, d.day, t.hour, t.minute, t.second);
    final p = DiaryPost(
      id: newId(),
      authorId: currentUserId!,
      createdAt: at,
      visibility: visibility,
      date: d,
      text: text.trim(),
      photos: [...photos],
      weather: weather,
    );
    posts.add(p);
    _save(p);
    notifyListeners();
    return p;
  }

  void editDiaryPost(DiaryPost p, String text) {
    p.text = text.trim();
    _save(p);
    notifyListeners();
  }

  void deletePost(Post p) {
    final gone = p is Story && p.groupId != null
        ? posts.where((x) => x is Story && x.groupId == p.groupId).toList()
        : [p];
    posts.removeWhere(gone.contains);
    gone.forEach(backend?.deletePost ?? (_) {});
    notifyListeners();
  }

  void setVisibility(Post p, Audience v) {
    p.visibility = v;
    _save(p);
    notifyListeners();
  }

  void _save(Post p) => backend?.savePost(p);

  List<DiaryPost> searchDiaryByTag(String tag) {
    final t = normalizeTag(tag);
    return posts
        .whereType<DiaryPost>()
        .where((e) => e.authorId == currentUserId && e.tags.contains(t))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ---------- Реакции ----------
  void markStoryViewed(Story s) {
    if (s.authorId != currentUserId && s.viewers.add(currentUserId!)) {
      backend?.addViewer(s, currentUserId!);
      notifyListeners();
    }
  }

  void toggleLike(Post p) {
    final me = currentUserId!;
    final on = !p.likes.remove(me);
    if (on) {
      p.likes.add(me);
      _notify(p.authorId, NotificationKind.like, me, postId: p.id);
    }
    backend?.setLike(p, me, on);
    notifyListeners();
  }

  void like(Post p) {
    if (!p.likes.contains(currentUserId)) toggleLike(p);
  }

  Comment addComment(Post p, String text, {Comment? replyTo}) {
    final me = currentUserId!;
    final rootId = replyTo == null ? null : (replyTo.replyToId ?? replyTo.id);
    final c = Comment(
      id: newId(),
      authorId: me,
      text: text.trim(),
      createdAt: now,
      replyToId: rootId,
    );
    p.comments.add(c);
    backend?.addComment(p, c);
    _notify(
      p.authorId,
      NotificationKind.comment,
      me,
      postId: p.id,
      text: c.text,
    );
    if (replyTo != null && replyTo.authorId != p.authorId) {
      _notify(
        replyTo.authorId,
        NotificationKind.reply,
        me,
        postId: p.id,
        text: c.text,
      );
    }
    notifyListeners();
    return c;
  }

  void toggleCommentLike(Post p, Comment c) {
    final me = currentUserId!;
    final on = !c.likes.remove(me);
    if (on) {
      c.likes.add(me);
      _notify(
        c.authorId,
        NotificationKind.commentLike,
        me,
        postId: p.id,
        text: c.text,
      );
    }
    backend?.setCommentLike(p, c, me, on);
    notifyListeners();
  }

  void deleteComment(Post p, Comment c) {
    bool gone(Comment x) => x.id == c.id || x.replyToId == c.id;
    backend?.deleteComments(p, p.comments.where(gone).toList());
    p.comments.removeWhere(gone);
    notifyListeners();
  }

  /// Корневые комментарии и ответы на них.
  List<Comment> rootComments(Post p) => p.comments
      .where(
        (c) =>
            c.replyToId == null &&
            !isBlockedBetween(currentUserId!, c.authorId),
      )
      .toList();

  List<Comment> repliesTo(Post p, Comment root) => p.comments
      .where(
        (c) =>
            c.replyToId == root.id &&
            !isBlockedBetween(currentUserId!, c.authorId),
      )
      .toList();

  // ---------- Уведомления ----------
  void _notify(
    String to,
    NotificationKind kind,
    String from, {
    String? postId,
    String text = '',
  }) {
    if (to == from) return;
    final n = AppNotification(
      id: newId(),
      kind: kind,
      fromUserId: from,
      createdAt: now,
      postId: postId,
      text: text,
    );
    if (backend != null) {
      backend!.notify(to, n);
      return;
    }
    // Без сервера уведомления храним только для текущего пользователя.
    if (to != currentUserId && to != localUserId) return;
    notifications.insert(0, n);
  }

  int get unreadNotifications => notifications.where((n) => !n.read).length;

  void markNotificationsRead() {
    final unread = notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    for (final n in unread) {
      n.read = true;
    }
    backend?.markNotificationsRead(unread);
    notifyListeners();
  }

  // ---------- Чаты ----------
  Chat chatWith(String other) {
    final me = currentUserId!;
    for (final c in chats) {
      if (c.userIds.contains(me) && c.userIds.contains(other)) return c;
    }
    final c = Chat(id: chatIdFor(me, other), userIds: [me, other]);
    chats.add(c);
    return c;
  }

  List<Chat> myChats() {
    final me = currentUserId!;
    return chats
        .where(
          (c) =>
              c.userIds.contains(me) &&
              c.messages.isNotEmpty &&
              !isBlockedBetween(me, c.other(me)),
        )
        .toList()
      ..sort(
        (a, b) =>
            b.messages.last.createdAt.compareTo(a.messages.last.createdAt),
      );
  }

  bool canMessage(String other) =>
      other != currentUserId && !isBlockedBetween(currentUserId!, other);

  ChatMessage? sendMessage(
    Chat chat, {
    String text = '',
    Media? photo,
    String? sharedPostId,
    String? replyToStoryId,
  }) {
    if (!canMessage(chat.other(currentUserId!))) return null;
    if (text.trim().isEmpty && photo == null && sharedPostId == null) {
      return null;
    }
    final m = ChatMessage(
      id: newId(),
      senderId: currentUserId!,
      createdAt: now,
      text: text.trim(),
      photo: photo,
      sharedPostId: sharedPostId,
      replyToStoryId: replyToStoryId,
    );
    chat.messages.add(m);
    backend?.sendMessage(chat, m);
    notifyListeners();
    return m;
  }

  int unreadIn(Chat c) =>
      c.messages.where((m) => m.senderId != currentUserId && !m.read).length;

  int get unreadMessages => myChats().fold(0, (s, c) => s + unreadIn(c));

  void markChatRead(Chat c) {
    final unread = c.messages
        .where((m) => m.senderId != currentUserId && !m.read)
        .toList();
    if (unread.isEmpty) return;
    for (final m in unread) {
      m.read = true;
    }
    backend?.markMessagesRead(c, unread);
    notifyListeners();
  }

  // ---------- Синхронизация с сервером ----------
  // Сервер присылает актуальные данные; объекты обновляются на месте,
  // чтобы открытые экраны, держащие ссылку на запись, увидели изменения.

  void signedIn(String uid) {
    currentUserId = uid;
    notifyListeners();
  }

  void clearData() {
    users.clear();
    posts.clear();
    chats.clear();
    notifications.clear();
    following.clear();
    followRequests.clear();
    blocked.clear();
    hiddenPostIds.clear();
    _comments.clear();
  }

  void applyUser(AppUser u) {
    final old = users[u.id];
    if (old == null) {
      users[u.id] = u;
    } else {
      if (old.avatarUrl != u.avatarUrl && u.avatarUrl != null) {
        old.avatarBytes = null;
      }
      old
        ..name = u.name
        ..nick = u.nick
        ..bio = u.bio
        ..city = u.city
        ..link = u.link
        ..birthday = u.birthday
        ..avatarColor = u.avatarColor
        ..avatarUrl = u.avatarUrl ?? old.avatarUrl
        ..isPrivate = u.isPrivate;
    }
    notifyListeners();
  }

  /// Все подписки разом: (кто, на кого, принята ли).
  void applyFollows(Iterable<(String, String, bool)> all) {
    following.clear();
    followRequests.clear();
    for (final (from, to, accepted) in all) {
      if (accepted) {
        following.putIfAbsent(from, () => {}).add(to);
      } else {
        followRequests.putIfAbsent(to, () => {}).add(from);
      }
    }
    notifyListeners();
  }

  void applyBlocks(Iterable<(String, String)> all) {
    blocked.clear();
    for (final (from, to) in all) {
      blocked.putIfAbsent(from, () => {}).add(to);
    }
    notifyListeners();
  }

  void applyPost(Post incoming) {
    final old = postById(incoming.id);
    if (old == null) {
      incoming.comments.addAll(_sortedComments(incoming.id));
      posts.add(incoming);
    } else {
      _mergePost(old, incoming);
    }
    notifyListeners();
  }

  void _mergePost(Post old, Post n) {
    old
      ..createdAt = n.createdAt
      ..visibility = n.visibility;
    old.likes
      ..clear()
      ..addAll(n.likes);
    if (old is Story && n is Story) {
      old.keepInCalendar = n.keepInCalendar;
      old.media.url ??= n.media.url;
      old.viewers.addAll(n.viewers);
    } else if (old is Plan && n is Plan) {
      old
        ..text = n.text
        ..planAt = n.planAt
        ..remind = n.remind;
    } else if (old is DiaryPost && n is DiaryPost) {
      old
        ..text = n.text
        ..weather = n.weather;
      for (var i = 0; i < old.photos.length && i < n.photos.length; i++) {
        old.photos[i].url ??= n.photos[i].url;
      }
    }
  }

  void removePost(String id) {
    posts.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  /// Комментарии по id записи — приходят независимо от самих записей.
  final Map<String, Map<String, Comment>> _comments = {};

  List<Comment> _sortedComments(String postId) =>
      (_comments[postId]?.values.toList() ?? [])
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  void applyComments(
    Iterable<(String postId, Comment c)> changed,
    Iterable<(String postId, String id)> removed,
  ) {
    final touched = <String>{};
    for (final (postId, c) in changed) {
      final old = _comments[postId]?[c.id];
      if (old != null) {
        old.likes
          ..clear()
          ..addAll(c.likes);
      } else {
        _comments.putIfAbsent(postId, () => {})[c.id] = c;
      }
      touched.add(postId);
    }
    for (final (postId, id) in removed) {
      _comments[postId]?.remove(id);
      touched.add(postId);
    }
    for (final id in touched) {
      final p = postById(id);
      if (p == null) continue;
      p.comments
        ..clear()
        ..addAll(_sortedComments(id));
    }
    notifyListeners();
  }

  void applyNotifications(List<AppNotification> list) {
    notifications
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  /// Чат с сервера; возвращает объект, куда складывать сообщения.
  Chat applyChat(String id, List<String> members) {
    for (final c in chats) {
      if (c.id == id) return c;
    }
    final c = Chat(id: id, userIds: members);
    chats.add(c);
    notifyListeners();
    return c;
  }

  void applyMessages(Chat c, List<ChatMessage> list) {
    // Своё сообщение с фото может ещё загружаться — его оставляем.
    final fresh = {for (final m in list) m.id: m};
    final merged = <ChatMessage>[
      for (final old in c.messages)
        if (fresh.remove(old.id) case final m?)
          old..read = old.read || m.read
        else
          old,
      ...fresh.values,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    c.messages
      ..clear()
      ..addAll(merged);
    notifyListeners();
  }
}

String chatIdFor(String a, String b) =>
    (a.compareTo(b) < 0 ? [a, b] : [b, a]).join('_');

/// Ник по умолчанию из email: латиница, цифры, точка и подчёркивание.
String nickFromEmail(String s) {
  final clean = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
  return clean.isEmpty ? 'user' : clean;
}

String normalizeTag(String t) {
  var s = t.trim().toLowerCase();
  if (!s.startsWith('#')) s = '#$s';
  return s.replaceAll(RegExp(r'\s+'), '');
}
