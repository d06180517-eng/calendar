import 'package:flutter/material.dart';

/// Кому видна запись.
enum Audience { onlyMe, followers, everyone }

/// Настроение дня в дневнике (цветом, по желанию).
enum Mood { good, neutral, bad }

/// Шаблоны пометок.
enum NoteTemplate { moment, thought, gratitude, joy, quote, plan, free }

enum MediaType { image, video }

/// Максимальная длина одной сторис с видео.
const Duration maxStoryDuration = Duration(seconds: 60);
const int maxNoteLength = 300;

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.nick,
    this.bio = '',
    this.city = '',
    this.link = '',
    this.birthday,
    this.avatarColor = const Color(0xFF7FD6CF),
    this.avatarBytes,
    this.isPrivate = false,
  });

  final String id;
  String name;
  String nick;
  String bio;
  String city;
  String link;
  DateTime? birthday;
  Color avatarColor;
  List<int>? avatarBytes;
  bool isPrivate;
}

/// Медиа-файл. В демо — либо байты выбранного файла, либо градиент-заглушка.
class Media {
  Media({
    required this.type,
    this.bytes,
    this.path,
    this.placeholder,
    this.start = Duration.zero,
    this.end,
  });

  final MediaType type;
  final List<int>? bytes;
  final String? path;
  final List<Color>? placeholder;

  /// Для видео, разбитого на части: отрезок исходного файла.
  final Duration start;
  final Duration? end;
}

/// Наложение поверх сторис: текст, стикер или отметка человека.
class StoryOverlay {
  StoryOverlay({
    required this.text,
    this.dx = 0.5,
    this.dy = 0.5,
    this.color = Colors.white,
    this.fontIndex = 0,
    this.isSticker = false,
    this.mentionUserId,
  });

  String text;
  double dx;
  double dy;
  Color color;
  int fontIndex;
  bool isSticker;
  String? mentionUserId;
}

abstract class Post {
  Post({
    required this.id,
    required this.authorId,
    required this.createdAt,
    required this.visibility,
  });

  final String id;
  final String authorId;
  DateTime createdAt;
  Audience visibility;
  final Set<String> likes = {};
  final List<Comment> comments = [];

  /// Дата, к которой запись относится в календаре.
  DateTime get day;
}

class Story extends Post {
  Story({
    required super.id,
    required super.authorId,
    required super.createdAt,
    required super.visibility,
    required this.media,
    this.overlays = const [],
    this.keepInCalendar = true,
    this.groupId,
    this.partIndex = 0,
    this.partCount = 1,
  });

  final Media media;
  final List<StoryOverlay> overlays;
  bool keepInCalendar;

  /// Части одного длинного видео имеют общий groupId.
  final String? groupId;
  final int partIndex;
  final int partCount;
  final Set<String> viewers = {};

  @override
  DateTime get day => dateOnly(createdAt);

  bool isActiveAt(DateTime now) =>
      now.difference(createdAt) < const Duration(hours: 24);
}

class Note extends Post {
  Note({
    required super.id,
    required super.authorId,
    required super.createdAt,
    required super.visibility,
    required this.template,
    required this.text,
    this.photo,
    this.planAt,
    this.remind = false,
  });

  NoteTemplate template;
  String text;
  Media? photo;

  /// Для шаблона «План»: на когда запланировано.
  DateTime? planAt;
  bool remind;

  @override
  DateTime get day => dateOnly(planAt ?? createdAt);
}

class Weather {
  const Weather(this.temperature, this.code);
  final double temperature;
  final int code;
}

class DiaryEntry extends Post {
  DiaryEntry({
    required super.id,
    required super.authorId,
    required super.createdAt,
    required super.visibility,
    required this.date,
    this.text = '',
    this.mood,
    List<Media>? photos,
    List<String>? tags,
    this.weather,
  }) : photos = photos ?? [],
       tags = tags ?? [];

  final DateTime date;
  String text;
  Mood? mood;
  final List<Media> photos;
  final List<String> tags;
  Weather? weather;

  @override
  DateTime get day => dateOnly(date);
}

class Comment {
  Comment({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.replyToId,
  });

  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;

  /// Если это ответ — id корневого комментария ветки.
  final String? replyToId;
  final Set<String> likes = {};
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.text = '',
    this.photo,
    this.sharedPostId,
    this.replyToStoryId,
  });

  final String id;
  final String senderId;
  final DateTime createdAt;
  final String text;
  final Media? photo;
  final String? sharedPostId;
  final String? replyToStoryId;
  bool read = false;
}

class Chat {
  Chat({required this.id, required this.userIds});
  final String id;
  final List<String> userIds;
  final List<ChatMessage> messages = [];

  String other(String me) => userIds.firstWhere((u) => u != me);
}

enum NotificationKind {
  like,
  comment,
  reply,
  follow,
  followRequest,
  mention,
  commentLike,
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.fromUserId,
    required this.createdAt,
    this.postId,
    this.text = '',
  });

  final String id;
  final NotificationKind kind;
  final String fromUserId;
  final DateTime createdAt;
  final String? postId;
  final String text;
  bool read = false;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
