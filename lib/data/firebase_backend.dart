import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../services/cloudinary.dart';
import 'app_state.dart';
import 'backend.dart';
import 'models.dart';

/// Firebase (Auth + Firestore) и Cloudinary для медиа.
///
/// Коллекции:
/// - `users/{uid}` — профиль; `users/{uid}/notifications/{id}`;
/// - `follows/{from_to}` — подписка или запрос (`accepted`);
/// - `blocks/{from_to}`, `reports/{id}`;
/// - `posts/{id}` — сторис, план или пост дневника (`type`);
///   `posts/{id}/comments/{id}`;
/// - `chats/{a_b}` с `members`; `chats/{a_b}/messages/{id}`.
class FirebaseBackend implements Backend {
  FirebaseBackend(this.state);

  final AppState state;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _media = Cloudinary();
  final _subs = <StreamSubscription<Object?>>[];
  final _chatSubs = <String, StreamSubscription<Object?>>{};
  bool _googleReady = false;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  // ---------- Вход ----------

  /// Вход, сохранённый с прошлого запуска.
  Future<void> restoreSession() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await _startSession(u).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Сессия не восстановлена: $e');
    }
  }

  @override
  Future<String?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _startSession(cred.user!);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      debugPrint('Вход: $e');
      return 'networkError';
    }
  }

  @override
  Future<String?> register(
    String email,
    String password,
    String name,
    String nick,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;
      if (await _nickTaken(nick, user.uid)) {
        await user.delete();
        return 'nickTaken';
      }
      await _startSession(user, name: name, nick: nick);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      debugPrint('Регистрация: $e');
      return 'networkError';
    }
  }

  @override
  Future<String?> signInWithGoogle() async {
    try {
      final g = GoogleSignIn.instance;
      if (!_googleReady) {
        await g.initialize(
          clientId: AppConfig.googleIosClientId.isEmpty
              ? null
              : AppConfig.googleIosClientId,
          serverClientId: AppConfig.googleServerClientId.isEmpty
              ? null
              : AppConfig.googleServerClientId,
        );
        _googleReady = true;
      }
      final account = await g.authenticate();
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
      await _startSession(
        cred.user!,
        name: account.displayName,
        nick: nickFromEmail(account.email.split('@').first),
      );
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Google: $e');
      return 'googleFailed';
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      debugPrint('Google: $e');
      return 'googleFailed';
    }
  }

  @override
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    }
  }

  @override
  Future<void> signOut() async {
    _stopSync();
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  String _authError(FirebaseAuthException e) {
    debugPrint('FirebaseAuth: ${e.code}');
    return switch (e.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' => 'wrongCredentials',
      'email-already-in-use' => 'emailInUse',
      'invalid-email' => 'badEmail',
      'weak-password' => 'shortPassword',
      'network-request-failed' => 'networkError',
      'too-many-requests' => 'tooManyRequests',
      _ => 'authError',
    };
  }

  Future<bool> _nickTaken(String nick, String uid) async {
    final q = await _users.where('nick', isEqualTo: nick).limit(2).get();
    return q.docs.any((d) => d.id != uid);
  }

  /// Создаёт профиль при первом входе, загружает данные и открывает
  /// приложение, когда свой профиль уже в памяти.
  Future<void> _startSession(User u, {String? name, String? nick}) async {
    final ref = _users.doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      var n = nick ?? nickFromEmail((u.email ?? 'user').split('@').first);
      if (await _nickTaken(n, u.uid)) {
        n = '${n}_${u.uid.substring(0, 4).toLowerCase()}';
      }
      final me = AppUser(
        id: u.uid,
        name: (name ?? u.displayName ?? '').trim().isEmpty
            ? n
            : (name ?? u.displayName)!.trim(),
        nick: n,
        avatarColor: _avatarColors[u.uid.hashCode % _avatarColors.length],
      );
      await ref.set(_userToMap(me));
      state.applyUser(me);
    } else {
      state.applyUser(_userFromDoc(snap));
    }
    _startSync(u.uid);
    state.signedIn(u.uid);
  }

  // ---------- Слушатели ----------

  void _startSync(String uid) {
    _stopSync();
    void listen<T>(Stream<T> s, void Function(T) onData) =>
        _subs.add(s.listen(onData, onError: (Object e) => debugPrint('$e')));

    listen(_users.snapshots(), (q) {
      for (final c in q.docChanges) {
        if (c.type != DocumentChangeType.removed) {
          state.applyUser(_userFromDoc(c.doc));
        }
      }
    });
    listen(
      _db.collection('follows').snapshots(),
      (q) => state.applyFollows([
        for (final d in q.docs)
          (
            d.data()['from'] as String,
            d.data()['to'] as String,
            d.data()['accepted'] == true,
          ),
      ]),
    );
    listen(
      _db.collection('blocks').snapshots(),
      (q) => state.applyBlocks([
        for (final d in q.docs)
          (d.data()['from'] as String, d.data()['to'] as String),
      ]),
    );
    void onPosts(QuerySnapshot<Map<String, dynamic>> q, {required bool own}) {
      for (final c in q.docChanges) {
        if (c.type == DocumentChangeType.removed) {
          // Чужая запись стала «только для автора» или удалена.
          final p = state.postById(c.doc.id);
          if (own || p == null || p.authorId != uid) state.removePost(c.doc.id);
        } else {
          final p = _postFromDoc(c.doc);
          if (p != null) state.applyPost(p);
        }
      }
    }

    listen(
      _posts
          .where('visibility', whereIn: ['everyone', 'followers'])
          .snapshots(),
      (q) => onPosts(q, own: false),
    );
    listen(
      _posts.where('authorId', isEqualTo: uid).snapshots(),
      (q) => onPosts(q, own: true),
    );
    listen(_db.collectionGroup('comments').snapshots(), (q) {
      final changed = <(String, Comment)>[];
      final removed = <(String, String)>[];
      for (final c in q.docChanges) {
        final postId = c.doc.reference.parent.parent!.id;
        if (c.type == DocumentChangeType.removed) {
          removed.add((postId, c.doc.id));
        } else {
          changed.add((postId, _commentFromDoc(c.doc)));
        }
      }
      state.applyComments(changed, removed);
    });
    listen(
      _users
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      (q) => state.applyNotifications([
        for (final d in q.docs) _notificationFromDoc(d),
      ]),
    );
    listen(
      _db.collection('chats').where('members', arrayContains: uid).snapshots(),
      (q) {
        for (final d in q.docs) {
          final chat = state.applyChat(
            d.id,
            List<String>.from(d.data()['members'] as List),
          );
          _chatSubs[d.id] ??= d.reference
              .collection('messages')
              .orderBy('createdAt')
              .snapshots()
              .listen(
                (m) => state.applyMessages(chat, [
                  for (final x in m.docs) _messageFromDoc(x),
                ]),
                onError: (Object e) => debugPrint('$e'),
              );
        }
      },
    );
  }

  void _stopSync() {
    for (final s in [..._subs, ..._chatSubs.values]) {
      s.cancel();
    }
    _subs.clear();
    _chatSubs.clear();
  }

  // ---------- Запись ----------

  /// Запись в фоне: интерфейс уже обновлён, ошибку только логируем.
  void _run(String what, Future<void> Function() f) {
    f().catchError((Object e) => debugPrint('$what: $e'));
  }

  Future<void> _upload(Media m) async {
    if (m.url != null || (m.bytes == null && m.path == null)) return;
    m.url = await _media.upload(m);
  }

  @override
  void saveUser(AppUser u) => _run('Профиль', () async {
    if (u.avatarUrl == null && u.avatarBytes != null) {
      u.avatarUrl = await _media.upload(
        Media(type: MediaType.image, bytes: u.avatarBytes),
      );
    }
    await _users.doc(u.id).set(_userToMap(u), SetOptions(merge: true));
  });

  @override
  void setFollow(String from, String to, {required bool accepted}) =>
      _run('Подписка', () async {
        await _db.collection('follows').doc('${from}_$to').set({
          'from': from,
          'to': to,
          'accepted': accepted,
        });
      });

  @override
  void removeFollow(String from, String to) => _run(
    'Отписка',
    () => _db.collection('follows').doc('${from}_$to').delete(),
  );

  @override
  void setBlock(String from, String to, bool on) => _run('Блокировка', () {
    final ref = _db.collection('blocks').doc('${from}_$to');
    return on ? ref.set({'from': from, 'to': to}) : ref.delete();
  });

  @override
  void report(String from, {String? userId, String? postId, String? reason}) =>
      _run('Жалоба', () async {
        await _db.collection('reports').add({
          'from': from,
          'userId': userId,
          'postId': postId,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  void savePost(Post p) => _run('Запись', () async {
    if (p is Story) await _upload(p.media);
    if (p is DiaryPost) await Future.wait(p.photos.map(_upload));
    await _posts.doc(p.id).set(_postToMap(p), SetOptions(merge: true));
  });

  @override
  void deletePost(Post p) => _run('Удаление', () async {
    final batch = _db.batch();
    for (final c in p.comments) {
      batch.delete(_posts.doc(p.id).collection('comments').doc(c.id));
    }
    batch.delete(_posts.doc(p.id));
    await batch.commit();
  });

  @override
  void setLike(Post p, String uid, bool on) => _run(
    'Лайк',
    () => _posts.doc(p.id).update({
      'likes': on
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    }),
  );

  @override
  void addViewer(Story s, String uid) => _run(
    'Просмотр',
    () => _posts.doc(s.id).update({
      'viewers': FieldValue.arrayUnion([uid]),
    }),
  );

  @override
  void addComment(Post p, Comment c) => _run(
    'Комментарий',
    () => _posts.doc(p.id).collection('comments').doc(c.id).set({
      'authorId': c.authorId,
      'text': c.text,
      'createdAt': Timestamp.fromDate(c.createdAt),
      'replyToId': c.replyToId,
      'likes': <String>[],
    }),
  );

  @override
  void deleteComments(Post p, List<Comment> cs) => _run('Комментарий', () {
    final batch = _db.batch();
    for (final c in cs) {
      batch.delete(_posts.doc(p.id).collection('comments').doc(c.id));
    }
    return batch.commit();
  });

  @override
  void setCommentLike(Post p, Comment c, String uid, bool on) => _run(
    'Лайк комментария',
    () => _posts.doc(p.id).collection('comments').doc(c.id).update({
      'likes': on
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    }),
  );

  @override
  void notify(String to, AppNotification n) => _run(
    'Уведомление',
    () => _users.doc(to).collection('notifications').doc(n.id).set({
      'kind': n.kind.name,
      'fromUserId': n.fromUserId,
      'createdAt': Timestamp.fromDate(n.createdAt),
      'postId': n.postId,
      'text': n.text,
      'read': false,
    }),
  );

  @override
  void markNotificationsRead(List<AppNotification> ns) =>
      _run('Уведомления', () {
        final uid = state.currentUserId!;
        final batch = _db.batch();
        for (final n in ns) {
          batch.update(_users.doc(uid).collection('notifications').doc(n.id), {
            'read': true,
          });
        }
        return batch.commit();
      });

  @override
  void deleteNotifications(List<AppNotification> ns) => _run('Уведомления', () {
    final uid = state.currentUserId!;
    final batch = _db.batch();
    for (final n in ns) {
      batch.delete(_users.doc(uid).collection('notifications').doc(n.id));
    }
    return batch.commit();
  });

  @override
  void sendMessage(Chat c, ChatMessage m) => _run('Сообщение', () async {
    if (m.photo != null) await _upload(m.photo!);
    final chat = _db.collection('chats').doc(c.id);
    await chat.set({
      'members': c.userIds,
      'updatedAt': Timestamp.fromDate(m.createdAt),
    }, SetOptions(merge: true));
    await chat.collection('messages').doc(m.id).set({
      'senderId': m.senderId,
      'createdAt': Timestamp.fromDate(m.createdAt),
      'text': m.text,
      'photo': m.photo == null ? null : _mediaToMap(m.photo!),
      'sharedPostId': m.sharedPostId,
      'replyToStoryId': m.replyToStoryId,
      'read': false,
    });
  });

  @override
  void markMessagesRead(Chat c, List<ChatMessage> ms) => _run('Прочитано', () {
    final batch = _db.batch();
    for (final m in ms) {
      batch.update(
        _db.collection('chats').doc(c.id).collection('messages').doc(m.id),
        {'read': true},
      );
    }
    return batch.commit();
  });
}

// ---------- Преобразование в документы и обратно ----------

const _avatarColors = [
  Color(0xFF7FD6CF),
  Color(0xFF9AB8E8),
  Color(0xFFF4C38B),
  Color(0xFFE8A0BF),
  Color(0xFFB8E0A0),
  Color(0xFFD7C4F2),
];

DateTime _date(Object? v) =>
    v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

Map<String, dynamic> _userToMap(AppUser u) => {
  'name': u.name,
  'nick': u.nick,
  'bio': u.bio,
  'city': u.city,
  'link': u.link,
  'birthday': u.birthday == null ? null : Timestamp.fromDate(u.birthday!),
  'avatarColor': u.avatarColor.toARGB32(),
  'avatarUrl': u.avatarUrl,
  'isPrivate': u.isPrivate,
};

AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? {};
  return AppUser(
    id: d.id,
    name: m['name'] as String? ?? '',
    nick: m['nick'] as String? ?? 'user',
    bio: m['bio'] as String? ?? '',
    city: m['city'] as String? ?? '',
    link: m['link'] as String? ?? '',
    birthday: m['birthday'] == null ? null : _date(m['birthday']),
    avatarColor: Color(m['avatarColor'] as int? ?? 0xFF7FD6CF),
    avatarUrl: m['avatarUrl'] as String?,
    isPrivate: m['isPrivate'] == true,
  );
}

Map<String, dynamic> _mediaToMap(Media m) => {
  'type': m.type.name,
  'url': m.url,
  'start': m.start.inMilliseconds,
  'end': m.end?.inMilliseconds,
  'placeholder': m.placeholder?.map((c) => c.toARGB32()).toList(),
};

Media _mediaFromMap(Map<String, dynamic> m) => Media(
  type: m['type'] == 'video' ? MediaType.video : MediaType.image,
  url: m['url'] as String?,
  start: Duration(milliseconds: m['start'] as int? ?? 0),
  end: m['end'] == null ? null : Duration(milliseconds: m['end'] as int),
  placeholder: (m['placeholder'] as List?)
      ?.map((c) => Color(c as int))
      .toList(),
);

Map<String, dynamic> _postToMap(Post p) {
  final m = <String, dynamic>{
    'authorId': p.authorId,
    'createdAt': Timestamp.fromDate(p.createdAt),
    'visibility': p.visibility.name,
  };
  switch (p) {
    case Story():
      m.addAll({
        'type': 'story',
        'media': _mediaToMap(p.media),
        'text': p.text,
        'overlays': [
          for (final o in p.overlays)
            {
              'text': o.text,
              'dx': o.dx,
              'dy': o.dy,
              'color': o.color.toARGB32(),
              'fontIndex': o.fontIndex,
              'isSticker': o.isSticker,
              'mentionUserId': o.mentionUserId,
            },
        ],
        'keepInCalendar': p.keepInCalendar,
        'groupId': p.groupId,
        'partIndex': p.partIndex,
        'partCount': p.partCount,
      });
    case Plan():
      m.addAll({
        'type': 'plan',
        'text': p.text,
        'planAt': Timestamp.fromDate(p.planAt),
        'remind': p.remind,
      });
    case DiaryPost():
      m.addAll({
        'type': 'diary',
        'date': Timestamp.fromDate(p.date),
        'text': p.text,
        'photos': p.photos.map(_mediaToMap).toList(),
        'weather': p.weather == null
            ? null
            : {'t': p.weather!.temperature, 'c': p.weather!.code},
      });
  }
  return m;
}

Post? _postFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data();
  if (m == null) return null;
  final authorId = m['authorId'] as String;
  final createdAt = _date(m['createdAt']);
  final visibility = Audience.values.firstWhere(
    (a) => a.name == m['visibility'],
    orElse: () => Audience.onlyMe,
  );
  final Post p;
  switch (m['type']) {
    case 'story':
      p = Story(
        id: d.id,
        authorId: authorId,
        createdAt: createdAt,
        visibility: visibility,
        media: _mediaFromMap(Map<String, dynamic>.from(m['media'] as Map)),
        text: m['text'] as String?,
        overlays: [
          for (final o in (m['overlays'] as List? ?? []).cast<Map>())
            StoryOverlay(
              text: o['text'] as String? ?? '',
              dx: (o['dx'] as num? ?? 0.5).toDouble(),
              dy: (o['dy'] as num? ?? 0.5).toDouble(),
              color: Color(o['color'] as int? ?? 0xFFFFFFFF),
              fontIndex: o['fontIndex'] as int? ?? 0,
              isSticker: o['isSticker'] == true,
              mentionUserId: o['mentionUserId'] as String?,
            ),
        ],
        keepInCalendar: m['keepInCalendar'] != false,
        groupId: m['groupId'] as String?,
        partIndex: m['partIndex'] as int? ?? 0,
        partCount: m['partCount'] as int? ?? 1,
      )..viewers.addAll(List<String>.from(m['viewers'] as List? ?? []));
    case 'plan':
      p = Plan(
        id: d.id,
        authorId: authorId,
        createdAt: createdAt,
        visibility: visibility,
        text: m['text'] as String? ?? '',
        planAt: _date(m['planAt']),
        remind: m['remind'] != false,
      );
    case 'diary':
      final w = m['weather'] as Map?;
      p = DiaryPost(
        id: d.id,
        authorId: authorId,
        createdAt: createdAt,
        visibility: visibility,
        date: dateOnly(_date(m['date'])),
        text: m['text'] as String? ?? '',
        photos: [
          for (final x in (m['photos'] as List? ?? []).cast<Map>())
            _mediaFromMap(Map<String, dynamic>.from(x)),
        ],
        weather: w == null
            ? null
            : Weather((w['t'] as num).toDouble(), w['c'] as int),
      );
    default:
      return null;
  }
  p.likes.addAll(List<String>.from(m['likes'] as List? ?? []));
  return p;
}

Comment _commentFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data()!;
  return Comment(
    id: d.id,
    authorId: m['authorId'] as String,
    text: m['text'] as String? ?? '',
    createdAt: _date(m['createdAt']),
    replyToId: m['replyToId'] as String?,
  )..likes.addAll(List<String>.from(m['likes'] as List? ?? []));
}

AppNotification _notificationFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data()!;
  return AppNotification(
    id: d.id,
    kind: NotificationKind.values.firstWhere(
      (k) => k.name == m['kind'],
      orElse: () => NotificationKind.like,
    ),
    fromUserId: m['fromUserId'] as String,
    createdAt: _date(m['createdAt']),
    postId: m['postId'] as String?,
    text: m['text'] as String? ?? '',
  )..read = m['read'] == true;
}

ChatMessage _messageFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data()!;
  final photo = m['photo'] as Map?;
  return ChatMessage(
    id: d.id,
    senderId: m['senderId'] as String,
    createdAt: _date(m['createdAt']),
    text: m['text'] as String? ?? '',
    photo: photo == null ? null : _mediaFromMap(Map.from(photo)),
    sharedPostId: m['sharedPostId'] as String?,
    replyToStoryId: m['replyToStoryId'] as String?,
  )..read = m['read'] == true;
}
