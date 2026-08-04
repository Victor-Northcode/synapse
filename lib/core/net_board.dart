import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Сетевая таблица лидеров на dreamlo — простой облачный сервис счёта
/// без аккаунтов и SDK. Работает у всех игроков сразу: очки уходят на
/// сервер при победе, топ-100 загружается на экране «Топ».
///
/// Всё «падает закрыто»: нет сети или сервис молчит — экран топа тихо
/// переключается на локальный рейтинг, игрока это не касается.
///
/// Недельный срез живёт на второй доске: записи подписываются номером
/// недели (`w123.nick`), клиент читает только текущую неделю и подчищает
/// свою прошлую запись.
class NetBoard {
  NetBoard._();
  static final NetBoard instance = NetBoard._();

  // Приватный код — только для записи своего счёта, публичный — чтение.
  static const _privAll = '7Oq_tpgN8EGoxt4CWTR8XwcFhBghEmikei_3gpxAOElQ';
  static const _pubAll = '6a706edb8f40bb12189b4daa';
  static const _privWeek = '6-evH_gE-kKSCufJGIhQbwm6C0WECcHU6V4X8c4ywzPw';
  static const _pubWeek = '6a706edc8f40bb12189b4daf';
  static const _host = 'dreamlo.com';

  bool get available => !kIsWeb; // в вебе нет dart:io (и упрётся в CORS)

  Future<String?> _get(String path) async {
    if (!available) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client
          .getUrl(Uri.http(_host, path))
          .timeout(const Duration(seconds: 4));
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      return await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Отправить счёт: общий и недельный. true — сервер подтвердил приём
  /// (по этому признаку AppState понимает, что досылать больше нечего).
  Future<bool> submit({
    required String nick,
    required int allTime,
    required int weeklyScore,
    required int week,
  }) async {
    if (nick.isEmpty || allTime <= 0) return false;
    final n = Uri.encodeComponent(nick);
    final okAll = await _get('/lb/$_privAll/add/$n/$allTime') != null;
    var okWeek = true;
    if (weeklyScore > 0) {
      okWeek = await _get(
              '/lb/$_privWeek/add/${Uri.encodeComponent('w$week.$nick')}/$weeklyScore') !=
          null;
      // Своя запись прошлой недели больше не нужна; неуспех не критичен.
      await _get('/lb/$_privWeek/delete/${Uri.encodeComponent('w${week - 1}.$nick')}');
    }
    return okAll && okWeek;
  }

  /// Топ с сервера: (имя, счёт), по убыванию. null — сервер недоступен.
  Future<List<(String, int)>?> top({required bool weekly, required int week}) async {
    final raw = await _get('/lb/${weekly ? _pubWeek : _pubAll}/json');
    if (raw == null) return null;
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      final lb = (root['dreamlo'] as Map<String, dynamic>?)?['leaderboard'];
      if (lb == null) return const []; // доска пуста — это не ошибка
      final entry = (lb as Map<String, dynamic>)['entry'];
      final list = entry is List ? entry : [entry];
      final out = <(String, int)>[];
      final prefix = 'w$week.';
      for (final e in list) {
        if (e is! Map) continue;
        var name = '${e['name'] ?? ''}';
        final score = int.tryParse('${e['score'] ?? ''}') ?? 0;
        if (weekly) {
          if (!name.startsWith(prefix)) continue; // чужая неделя
          name = name.substring(prefix.length);
        }
        if (name.isEmpty || score <= 0) continue;
        out.add((name, score));
      }
      out.sort((a, b) => b.$2 - a.$2);
      return out.take(100).toList();
    } catch (_) {
      return null;
    }
  }
}
