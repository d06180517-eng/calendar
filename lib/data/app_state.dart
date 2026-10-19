import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Всё состояние приложения. Сейчас данные живут в памяти (демо-режим);
/// при подключении Firebase этот класс будет читать и писать в Firestore
/// с тем же набором методов, поэтому экраны менять не придётся.
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

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

  AppUser user(String id) => users[id]!;

  // ---------- Вход ----------
  String? login(String email, String password) {
    if (!email.contains('@') || email.trim().length < 5) return 'badEmail';
    if (password.length < 6) return 'shortPassword';
    currentUserId = 'me';
    notifyListeners();
    return null;
  }

  String? register(String email, String password, String name, String nick) {
    final err = login(email, password);
    if (err != null) return err;
    final cleanNick = nick.trim().replaceAll('@', '');
    if (cleanNick.isEmpty) return 'emptyNick';
    if (users.values.any((u) => u.id != 'me' && u.nick == cleanNick)) {
      currentUserId = null;
      return 'nickTaken';
    }
    final m = users['me']!;
    m.name = name.trim().isEmpty ? cleanNick : name.trim();
    m.nick = cleanNick;
    notifyListeners();
    return null;
  }

  void loginWithGoogle() {
    currentUserId = 'me';
    notifyListeners();
  }

  void logout() {
    currentUserId = null;
    notifyListeners();
  }

  void updateProfile(void Function(AppUser u) change) {
    change(me!);
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
    if (users[target]!.isPrivate) {
      followRequests.putIfAbsent(target, () => {}).add(me);
      _notify(target, NotificationKind.followRequest, me);
    } else {
      following.putIfAbsent(me, () => {}).add(target);
      _notify(target, NotificationKind.follow, me);
    }
    notifyListeners();
  }

  void unfollow(String target) {
    following[currentUserId!]?.remove(target);
    followRequests[target]?.remove(currentUserId!);
    notifyListeners();
  }

  void answerFollowRequest(String from, bool accept) {
    followRequests[currentUserId!]?.remove(from);
    if (accept) {
      following.putIfAbsent(from, () => {}).add(currentUserId!);
    }
    notifications.removeWhere(
      (n) => n.kind == NotificationKind.followRequest && n.fromUserId == from,
    );
    notifyListeners();
  }

  void setPrivate(bool v) {
    me!.isPrivate = v;
    if (!v) {
      // Открыли профиль — все ожидающие запросы принимаются.
      for (final f in followRequests[currentUserId!] ?? <String>{}) {
        following.putIfAbsent(f, () => {}).add(currentUserId!);
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
    notifyListeners();
  }

  void unblock(String target) {
    blocked[currentUserId!]?.remove(target);
    notifyListeners();
  }

  void report({String? userId, String? postId, required String reason}) {
    reports.add('${userId ?? ''}|${postId ?? ''}|$reason');
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
        return !users[p.authorId]!.isPrivate || isFollowing(viewer, p.authorId);
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

  DateTime _sortTime(Post p) => p is Note && p.planAt != null
      ? p.planAt!
      : (p is DiaryEntry
            ? DateTime(p.date.year, p.date.month, p.date.day)
            : p.createdAt);

  List<Story> storiesOfDay(String owner, DateTime day, {String? viewer}) =>
      postsOfDay(owner, day, viewer: viewer).whereType<Story>().toList();

  DiaryEntry? diaryOf(String owner, DateTime day, {String? viewer}) {
    for (final p in postsOfDay(owner, day, viewer: viewer)) {
      if (p is DiaryEntry) return p;
    }
    return null;
  }

  List<Note> notesOfDay(String owner, DateTime day, {String? viewer}) =>
      postsOfDay(owner, day, viewer: viewer).whereType<Note>().toList();

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
      if (p is Note && p.template == NoteTemplate.plan) return false;
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
        if (p.authorId == owner && !(p is Note && p.planAt != null)) p.day,
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
    }
    notifyListeners();
  }

  Note createNote({
    required NoteTemplate template,
    required String text,
    Media? photo,
    DateTime? at,
    DateTime? planAt,
    bool remind = false,
    Audience? visibility,
  }) {
    final n = Note(
      id: newId(),
      authorId: currentUserId!,
      createdAt: at ?? now,
      visibility:
          visibility ??
          (template == NoteTemplate.plan ? Audience.onlyMe : Audience.everyone),
      template: template,
      text: text.length > maxNoteLength
          ? text.substring(0, maxNoteLength)
          : text,
      photo: photo,
      planAt: template == NoteTemplate.plan ? planAt : null,
      remind: template == NoteTemplate.plan && remind,
    );
    posts.add(n);
    notifyListeners();
    return n;
  }

  void updateNote(Note n, void Function(Note) change) {
    change(n);
    if (n.text.length > maxNoteLength) {
      n.text = n.text.substring(0, maxNoteLength);
    }
    notifyListeners();
  }

  /// Дневник: одна запись на день. Если запись уже есть — обновляется.
  DiaryEntry saveDiary({
    required DateTime date,
    required String text,
    Mood? mood,
    required List<Media> photos,
    required List<String> tags,
    Weather? weather,
    required Audience visibility,
  }) {
    final d = dateOnly(date);
    DiaryEntry? e;
    for (final p in posts) {
      if (p is DiaryEntry &&
          p.authorId == currentUserId &&
          sameDay(p.date, d)) {
        e = p;
        break;
      }
    }
    if (e == null) {
      e = DiaryEntry(
        id: newId(),
        authorId: currentUserId!,
        createdAt: now,
        visibility: visibility,
        date: d,
      );
      posts.add(e);
    }
    e
      ..text = text
      ..mood = mood
      ..weather = weather ?? e.weather
      ..visibility = visibility;
    e.photos
      ..clear()
      ..addAll(photos);
    e.tags
      ..clear()
      ..addAll(tags.map(normalizeTag).where((t) => t.length > 1).toSet());
    notifyListeners();
    return e;
  }

  void deletePost(Post p) {
    posts.remove(p);
    if (p is Story && p.groupId != null) {
      posts.removeWhere((x) => x is Story && x.groupId == p.groupId);
    }
    notifyListeners();
  }

  void setVisibility(Post p, Audience v) {
    p.visibility = v;
    notifyListeners();
  }

  List<DiaryEntry> searchDiaryByTag(String tag) {
    final t = normalizeTag(tag);
    return posts
        .whereType<DiaryEntry>()
        .where((e) => e.authorId == currentUserId && e.tags.contains(t))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ---------- Реакции ----------
  void markStoryViewed(Story s) {
    if (s.authorId != currentUserId && s.viewers.add(currentUserId!)) {
      notifyListeners();
    }
  }

  void toggleLike(Post p) {
    final me = currentUserId!;
    if (!p.likes.remove(me)) {
      p.likes.add(me);
      _notify(p.authorId, NotificationKind.like, me, postId: p.id);
    }
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
    if (!c.likes.remove(me)) {
      c.likes.add(me);
      _notify(
        c.authorId,
        NotificationKind.commentLike,
        me,
        postId: p.id,
        text: c.text,
      );
    }
    notifyListeners();
  }

  void deleteComment(Post p, Comment c) {
    p.comments.removeWhere((x) => x.id == c.id || x.replyToId == c.id);
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
    // Демо: уведомления храним только для текущего пользователя.
    if (to != currentUserId && to != 'me') return;
    notifications.insert(
      0,
      AppNotification(
        id: newId(),
        kind: kind,
        fromUserId: from,
        createdAt: now,
        postId: postId,
        text: text,
      ),
    );
  }

  int get unreadNotifications => notifications.where((n) => !n.read).length;

  void markNotificationsRead() {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  // ---------- Чаты ----------
  Chat chatWith(String other) {
    final me = currentUserId!;
    for (final c in chats) {
      if (c.userIds.contains(me) && c.userIds.contains(other)) return c;
    }
    final c = Chat(id: newId(), userIds: [me, other]);
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
    notifyListeners();
    return m;
  }

  int unreadIn(Chat c) =>
      c.messages.where((m) => m.senderId != currentUserId && !m.read).length;

  int get unreadMessages => myChats().fold(0, (s, c) => s + unreadIn(c));

  void markChatRead(Chat c) {
    var changed = false;
    for (final m in c.messages) {
      if (m.senderId != currentUserId && !m.read) {
        m.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}

String normalizeTag(String t) {
  var s = t.trim().toLowerCase();
  if (!s.startsWith('#')) s = '#$s';
  return s.replaceAll(RegExp(r'\s+'), '');
}
