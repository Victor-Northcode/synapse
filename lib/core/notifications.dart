import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Локальные напоминания — порт модуля PUSH.
///
/// Правила сохранены: не больше одного уведомления в сутки, только в 19:00
/// по местному времени, при каждом запуске всё снимается и ставится заново,
/// разрешение спрашивается после первой пройденной связи.
class Push {
  Push._();
  static final Push instance = Push._();

  static const _ids = [9101, 9102, 9103];
  static const _hour = 19;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;
  bool _askedOnce = false;

  Future<void> init() async {
    if (_inited || kIsWeb) return; // в браузере локальных уведомлений нет
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _inited = true;
    } catch (_) {
      // Среда без уведомлений (тесты, десктоп) — напоминания недоступны.
    }
  }

  Future<bool> _granted() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final s = await ios.checkPermissions();
      return s?.isEnabled ?? false;
    }
    return false;
  }

  /// Спрашиваем один раз и в подходящий момент (после победы на уровне 1).
  Future<bool> askOnce() async {
    if (_askedOnce) return _granted();
    _askedOnce = true;
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: false, sound: true) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> clear() async {
    if (!_inited) return;
    for (final id in _ids) {
      await _plugin.cancel(id);
    }
  }

  tz.TZDateTime _at(int daysAhead) {
    var t = DateTime.now().add(Duration(days: daysAhead));
    t = DateTime(t.year, t.month, t.day, _hour);
    if (t.millisecondsSinceEpoch < DateTime.now().millisecondsSinceEpoch + 60000) {
      t = t.add(const Duration(days: 1));
    }
    // Абсолютный момент времени: локальную стену переводим в UTC-инстант.
    return tz.TZDateTime.from(t.toUtc(), tz.UTC);
  }

  /// [entries] — до трёх пар (title, body) с шагом 1/3/7 дней.
  Future<void> reschedule(List<(String, String)> entries) async {
    try {
      await init();
      if (!await _granted()) return;
      await clear();
      const days = [1, 3, 7];
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'synapse_nudge',
          'Reminders',
          channelDescription: 'Daily reminder to return to the game',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );
      for (var i = 0; i < entries.length && i < 3; i++) {
        await _plugin.zonedSchedule(
          _ids[i],
          entries[i].$1,
          entries[i].$2,
          _at(days[i]),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {}
  }
}
