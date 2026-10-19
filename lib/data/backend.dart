import 'models.dart';

/// Сервер, с которым синхронизируется [AppState]. Состояние сначала меняется
/// в памяти (интерфейс отвечает сразу), а затем изменение уходит сюда.
/// Без сервера (тесты, веб-превью) `AppState.backend == null`.
abstract class Backend {
  /// Возвращают ключ ошибки для перевода или null при успехе.
  Future<String?> signIn(String email, String password);
  Future<String?> register(
    String email,
    String password,
    String name,
    String nick,
  );
  Future<String?> signInWithGoogle();
  Future<String?> resetPassword(String email);
  Future<void> signOut();

  void saveUser(AppUser u);

  void setFollow(String from, String to, {required bool accepted});
  void removeFollow(String from, String to);
  void setBlock(String from, String to, bool on);
  void report(String from, {String? userId, String? postId, String reason});

  void savePost(Post p);
  void deletePost(Post p);
  void setLike(Post p, String uid, bool on);
  void addViewer(Story s, String uid);

  void addComment(Post p, Comment c);
  void deleteComments(Post p, List<Comment> cs);
  void setCommentLike(Post p, Comment c, String uid, bool on);

  void notify(String to, AppNotification n);
  void markNotificationsRead(List<AppNotification> ns);
  void deleteNotifications(List<AppNotification> ns);

  void sendMessage(Chat c, ChatMessage m);
  void markMessagesRead(Chat c, List<ChatMessage> ms);
}
