import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Локальные напоминания — порт модуля PUSH, расширенный до недели.
///
/// Правила: не больше одного уведомления в сутки, в 19:00 по местному
/// времени, при каждом запуске всё снимается и ставится заново на 7 дней
/// вперёд с разными текстами. Разрешение спрашивается после первой
/// пройденной связи.
class Push {
  Push._();
  static final Push instance = Push._();

  static const _ids = [9101, 9102, 9103, 9104, 9105, 9106, 9107];
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

  /// [entries] — до семи пар (title, body): по одному уведомлению в день
  /// на неделю вперёд. Тексты разные, чтобы напоминания не приедались;
  /// длинное тело раскрывается на Android в BigTextStyle.
  Future<void> reschedule(List<(String, String)> entries) async {
    try {
      await init();
      if (!await _granted()) return;
      await clear();
      for (var i = 0; i < entries.length && i < _ids.length; i++) {
        final details = NotificationDetails(
          android: AndroidNotificationDetails(
            'synapse_nudge',
            'Daily reminders',
            channelDescription: 'Daily reminder to return to the game',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(entries[i].$2),
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        );
        await _plugin.zonedSchedule(
          _ids[i],
          entries[i].$1,
          entries[i].$2,
          _at(i + 1),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {}
  }
}
