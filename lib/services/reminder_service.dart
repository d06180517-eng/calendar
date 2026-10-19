import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

/// Локальные напоминания: «Как прошёл день?» и планы на будущие даты.
/// Работают на телефоне без сервера, даже когда приложение закрыто.
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  static const _diaryId = 1;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Напоминания',
      channelDescription: 'Дневник и планы',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      // Время напоминаний считаем по смещению устройства.
      final offset = DateTime.now().timeZoneOffset;
      final loc = tz.timeZoneDatabase.locations.values.firstWhere(
        (l) => l.currentTimeZone.offset == offset,
        orElse: () => tz.UTC,
      );
      tz.setLocalLocation(loc);
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Напоминания недоступны: $e');
    }
  }

  Future<void> scheduleDiary(
    bool on,
    TimeOfDay time,
    String title,
    String body,
  ) async {
    if (!_ready) return;
    await _plugin.cancel(id: _diaryId);
    if (!on) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _diaryId,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  int _idFor(Note n) => 1000 + (n.id.hashCode & 0x3fffffff);

  Future<void> schedulePlan(Note n, String title) async {
    if (!_ready || n.planAt == null) return;
    await _plugin.cancel(id: _idFor(n));
    if (!n.remind || !n.planAt!.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _idFor(n),
      scheduledDate: tz.TZDateTime.from(n.planAt!, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: n.text,
    );
  }

  Future<void> cancelPlan(Note n) async {
    if (!_ready) return;
    await _plugin.cancel(id: _idFor(n));
  }
}
