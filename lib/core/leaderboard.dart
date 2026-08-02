import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:games_services/games_services.dart';

/// Таблицы лидеров: Game Center (iOS) и Google Play Игры (Android).
///
/// Метрика одна — «распутано связей» (пройденный уровень). Вкладка
/// «неделя» на iOS живёт отдельной повторяющейся таблицей Game Center,
/// на Android — недельным срезом той же таблицы Play Games.
class Lb {
  Lb._();
  static final Lb instance = Lb._();

  // ---- идентификаторы таблиц ----
  // iOS: создаются в App Store Connect → Game Center → Leaderboards.
  //   iosAllTime — классическая, iosWeekly — recurring с недельным сбросом.
  // Android: создаётся в Play Console → Play Games Services → Лидерборды,
  //   id выглядит как «CgkI…». Пока пусто — на Android раздел скрыт.
  static const iosAllTime = 'synapse.links';
  static const iosWeekly = 'synapse.links.week';
  static const androidBoard = '';

  bool get _platformOk => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Раздел показывается только там, где таблицы настроены.
  bool get available => _platformOk &&
      (Platform.isIOS ? iosAllTime.isNotEmpty : androidBoard.isNotEmpty);

  String get serviceName =>
      !_platformOk || Platform.isIOS ? 'Game Center' : 'Google Play Games';

  bool signedIn = false;

  /// Вход в одно касание; на Android Play Games входит сам.
  Future<bool> ensureSignedIn() async {
    if (!available) return false;
    try {
      if (await GameAuth.isSignedIn) {
        signedIn = true;
        return true;
      }
      await GameAuth.signIn();
      signedIn = await GameAuth.isSignedIn;
      return signedIn;
    } catch (_) {
      signedIn = false;
      return false;
    }
  }

  /// Отправить общий счёт «распутано связей». Падает молча: очки
  /// досылаются при следующей победе, игрока это не касается.
  Future<void> submit(int links) async {
    if (!available || links <= 0) return;
    try {
      if (!signedIn && !await ensureSignedIn()) return;
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: androidBoard,
          iOSLeaderboardID: iosAllTime,
          value: links,
        ),
      );
      if (Platform.isIOS && iosWeekly.isNotEmpty) {
        await Leaderboards.submitScore(
          score: Score(iOSLeaderboardID: iosWeekly, value: links),
        );
      }
    } catch (_) {}
  }

  String _iosBoard(bool weekly) => weekly ? iosWeekly : iosAllTime;
  TimeScope _scope(bool weekly) {
    // На iOS недельная таблица — отдельная recurring, срез там не нужен.
    if (_platformOk && Platform.isIOS) return TimeScope.allTime;
    return weekly ? TimeScope.week : TimeScope.allTime;
  }

  /// Топ до 100 записей (платформа может отдать меньше).
  Future<List<LeaderboardScoreData>?> top({required bool weekly}) async {
    if (!available) return null;
    try {
      if (!signedIn && !await ensureSignedIn()) return null;
      return await Leaderboards.loadLeaderboardScores(
        iOSLeaderboardID: _iosBoard(weekly),
        androidLeaderboardID: androidBoard,
        scope: PlayerScope.global,
        timeScope: _scope(weekly),
        forceRefresh: true,
        maxResults: 100,
      );
    } catch (_) {
      return null;
    }
  }

  /// Строка самого игрока (ранг и счёт).
  Future<LeaderboardScoreData?> myScore({required bool weekly}) async {
    if (!available || !signedIn) return null;
    try {
      return await Leaderboards.getPlayerScoreObject(
        iOSLeaderboardID: _iosBoard(weekly),
        androidLeaderboardID: androidBoard,
        scope: PlayerScope.global,
        timeScope: _scope(weekly),
      );
    } catch (_) {
      return null;
    }
  }

  /// Системная таблица (полный список, друзья, профили).
  Future<void> openNative({required bool weekly}) async {
    if (!available) return;
    try {
      await Leaderboards.showLeaderboards(
        iOSLeaderboardID: _iosBoard(weekly),
        androidLeaderboardID: androidBoard,
        timeScope: _scope(weekly),
      );
    } catch (_) {}
  }
}
