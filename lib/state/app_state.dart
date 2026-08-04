import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/ads.dart';
import '../core/audio.dart';
import '../core/haptics.dart';
import '../core/leaderboard.dart';
import '../core/lb_cache.dart';
import '../core/net_board.dart';
import '../core/notifications.dart';
import '../core/storage.dart';
import '../data/game_data.dart';
import '../data/lb_strings.dart';
import '../data/push_data.dart';
import '../data/story_data.dart';
import '../data/upgrade_data.dart';
import '../data/strings.dart';
import '../data/task_data.dart';
import '../game/level.dart' show hash32;
import '../game/rivals.dart' show makeNick;

/// Задача датацентра.
class HubTask {
  final int day;
  final String icon;
  final int cost;
  final String? fx; // 't' — бонус времени, 'h' — подсказка
  const HubTask(this.day, this.icon, this.cost, this.fx);
}

/// События, которые состояние просит показать интерфейс.
enum GameEventType { toast, dayScene, chapterFinale, storyIntro }

class GameEvent {
  final GameEventType type;
  final String? text;
  final int? day;
  const GameEvent(this.type, {this.text, this.day});
}

/// Профиль игрока и логика хаба — порт «глобальной» части index.html.
class AppState extends ChangeNotifier {
  // ---- сохраняемое состояние (поля JSON совпадают с synapse_v1) ----
  int level = 1;
  int tokens = 0;
  int spent = 0;
  int shards = 0;
  int hintStock = 2;
  int chapter = 0;
  String dayKey = '';
  int streak = 0;
  List<int> gp = [0, 0, 0];
  List<bool> gDone = [false, false, false];

  /// Цели недели: номер недели (от эпохи, с понедельника), прогресс
  /// и выполненность. Новые поля сейва — старые сохранения дают нули.
  int weekKey = 0;
  List<int> wgp = [0, 0, 0];
  List<bool> wgDone = [false, false, false];

  /// Псевдоним для сетевого топа (генерируется один раз, без личного).
  String nick = '';

  /// Год рождения из нейтрального возрастного экрана (0 — ещё не указан).
  /// Нужен ТОЛЬКО для настройки рекламы по возрасту (COPPA/GDPR-K),
  /// хранится локально и никуда не отправляется.
  int birthYear = 0;

  /// Обменов энергии на осколки сегодня (лимит 2).
  int convUsed = 0;
  Map<String, int> inv = {'cut': 0, 'stab': 0, 'auto': 0};
  int adShards = 0;
  int adItems = 0; // предметы за ролик в текущем часе (лимит 3)
  int adItemHour = 0; // номер часа от эпохи — окно лимита предметов

  /// Мастерская: ключ апгрейда → купленный уровень.
  Map<String, int> upgrades = {};

  /// Личные рекорды — работают всегда, даже без сети.
  int bestLevel = 0;
  int bestStreak = 0;
  int totalWins = 0;

  /// Очки, ПОДТВЕРЖДЁННЫЕ таблицами лидеров. Если отправка сорвалась
  /// без сети — здесь остаются старые числа, и syncBoards() дошлёт
  /// разницу при первом же удобном случае. Очки не теряются никогда.
  int sentPlatform = 0; // «распутано связей», принятое Game Center/PGS
  int sentAll = 0; // totalWins, принятый сетевой доской
  int sentWeekScore = 0; // недельный счёт, принятый сетевой доской
  int sentWeekKey = -1; // неделя, к которой относится sentWeekScore
  bool musicOn = true;
  int theme = 0;
  List<int> owned = List.generate(kThemes.length, (i) => i == 0 ? 1 : 0);
  List<bool> done = [];
  int hintBought = 0;
  bool soundOn = true;

  /// Громкость звуков: 0.5–2.0 (до 200%).
  double soundVol = 1.0;
  bool vibroOn = true;
  bool pushOn = true;
  bool introSeen = false;
  String lang = 'en';

  // ---- глава ----
  List<HubTask> tasks = [];
  List<String> taskNames = [];
  List<String> taskLogs = [];
  List<String> dayNames = [];
  List<String> dayEnds = [];
  int days = 4;

  void Function(GameEvent event)? onEvent;

  GameTheme get gameTheme => kThemes[theme];
  bool get isRtl => lang == 'ar';

  // ---------- локализация ----------
  Map<String, Object> get _d => kStrings[lang] ?? kStrings['en']!;

  String t(String key) {
    final v = _d[key] ?? kStrings['en']![key];
    return v is String ? v : key;
  }

  List<String> tl(String key) {
    final v = _d[key] ?? kStrings['en']![key];
    return v is List ? List<String>.from(v) : const [];
  }

  /// Строки экрана лидеров (добавлены поверх исходного словаря).
  String lt(String key) =>
      kLbStrings[lang]?[key] ??
      kUpgradeStrings[lang]?[key] ??
      kLbStrings['en']?[key] ??
      kUpgradeStrings['en']![key] ??
      key;

  // ---------- мастерская ----------
  int upLevel(String key) => upgrades[key] ?? 0;

  /// Цена следующего уровня; null — уже максимум.
  int? upPrice(Upgrade u) {
    final next = upLevel(u.key) + 1;
    return next > u.maxLevel ? null : u.priceFor(next);
  }

  bool buyUpgrade(Upgrade u) {
    final price = upPrice(u);
    if (price == null) return false;
    if (shards < price) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: t('needSh').replaceAll('{n}', '${price - shards}')));
      Haptics.instance.reject();
      return false;
    }
    shards -= price;
    upgrades[u.key] = upLevel(u.key) + 1;
    if (u.key == 'hints') hintStock++; // эффект виден сразу
    save();
    GameAudio.instance.chord([523, 784, 1047]);
    Haptics.instance.success();
    onEvent?.call(GameEvent(GameEventType.toast,
        text: lt('upBought').replaceAll('{n}', lt('up_${u.key}'))));
    notifyListeners();
    return true;
  }

  /// Бонусы апгрейдов, которые читает игровой движок.
  int get bonusMoves => upLevel('moves') * 2;
  int get bonusTokens => upLevel('income');
  bool get hasScan => upLevel('scan') > 0;
  int get dailyHintBonus => upLevel('hints');

  // ---------- уровень оператора ----------
  /// Опыт — распутанные связи. Порог уровня растёт линейно:
  /// 1→2 через 5 связей, дальше +5 к шагу.
  int get operatorLevel {
    var lvl = 1, need = 5, left = totalWins;
    while (left >= need && lvl < 99) {
      left -= need;
      lvl++;
      need += 5;
    }
    return lvl;
  }

  int get winsToNextLevel {
    var lvl = 1, need = 5, left = totalWins;
    while (left >= need && lvl < 99) {
      left -= need;
      lvl++;
      need += 5;
    }
    return need - left;
  }

  double get operatorProgress {
    var lvl = 1, need = 5, left = totalWins;
    while (left >= need && lvl < 99) {
      left -= need;
      lvl++;
      need += 5;
    }
    return need == 0 ? 0 : left / need;
  }

  // ---------- загрузка/сохранение ----------
  void loadSaved() {
    final sv = Storage.instance.load();
    if (sv != null) {
      level = (sv['l'] as num?)?.toInt() ?? 1;
      tokens = (sv['t'] as num?)?.toInt() ?? 0;
      spent = (sv['s'] as num?)?.toInt() ?? 0;
      if (sv['dn'] is List) done = [for (final v in sv['dn'] as List) v == true];
      shards = (sv['sh'] as num?)?.toInt() ?? 0;
      hintBought = (sv['hbq'] as num?)?.toInt() ?? 0;
      hintStock = (sv['hs'] as num?)?.toInt() ?? 2;
      chapter = (sv['ch'] as num?)?.toInt() ?? 0;
      dayKey = sv['dk'] as String? ?? '';
      streak = (sv['st'] as num?)?.toInt() ?? 0;
      if (sv['gp'] is List) gp = [for (final v in sv['gp'] as List) (v as num).toInt()];
      if (sv['gd'] is List) gDone = [for (final v in sv['gd'] as List) v == true];
      weekKey = (sv['wkk'] as num?)?.toInt() ?? 0;
      if (sv['wgp'] is List) wgp = [for (final v in sv['wgp'] as List) (v as num).toInt()];
      if (sv['wgd'] is List) wgDone = [for (final v in sv['wgd'] as List) v == true];
      nick = sv['nk'] as String? ?? '';
      convUsed = (sv['cvd'] as num?)?.toInt() ?? 0;
      birthYear = (sv['by'] as num?)?.toInt() ?? 0;
      if (sv['inv'] is Map) {
        final m = sv['inv'] as Map;
        inv = {
          'cut': (m['cut'] as num?)?.toInt() ?? 0,
          'stab': (m['stab'] as num?)?.toInt() ?? 0,
          'auto': (m['auto'] as num?)?.toInt() ?? 0,
        };
      }
      adShards = (sv['ads'] as num?)?.toInt() ?? 0;
      adItems = (sv['adb'] as num?)?.toInt() ?? 0;
      adItemHour = (sv['adbh'] as num?)?.toInt() ?? 0;
      if (sv['up'] is Map) {
        upgrades = {
          for (final e in (sv['up'] as Map).entries)
            e.key.toString(): (e.value as num).toInt()
        };
      }
      bestLevel = (sv['bl'] as num?)?.toInt() ?? 0;
      bestStreak = (sv['bs'] as num?)?.toInt() ?? 0;
      totalWins = (sv['tw'] as num?)?.toInt() ?? 0;
      // Старый сейв без этих полей: прежний код отправлял очки при
      // каждой победе, поэтому считаем их уже подтверждёнными — без
      // внезапного входа в Game Center на первом же запуске обновления.
      sentPlatform = (sv['nsp'] as num?)?.toInt() ?? bestLevel;
      sentAll = (sv['nsa'] as num?)?.toInt() ?? totalWins;
      sentWeekScore = (sv['nsw'] as num?)?.toInt() ?? wgp[0];
      sentWeekKey = (sv['nswk'] as num?)?.toInt() ?? weekKey;
      musicOn = sv['mu'] != false;
      theme = ((sv['th'] as num?)?.toInt() ?? 0).clamp(0, kThemes.length - 1);
      if (sv['ow'] is List) {
        owned = [for (final v in sv['ow'] as List) (v as num).toInt()];
        while (owned.length < kThemes.length) {
          owned.add(0);
        }
      }
      soundOn = sv['so'] != false;
      soundVol = ((sv['vol'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0);
      vibroOn = sv['vi'] != false;
      pushOn = sv['pu'] != false;
      introSeen = sv['i'] == true;
      final lg = sv['lg'] as String?;
      if (lg != null && kStrings.containsKey(lg)) {
        lang = lg;
      } else {
        lang = detectLang();
      }
    } else {
      lang = detectLang();
    }
    if (nick.isEmpty) {
      nick = makeNick(math.Random());
      save();
    }
    Ads.instance.setAge(adAge);
    GameAudio.instance.enabled = soundOn;
    GameAudio.instance.volume = soundVol;
    GameAudio.instance.setMusicEnabled(musicOn);
    Haptics.instance.enabled = vibroOn;
    buildChapter();
    checkDay();
  }

  void save() {
    Storage.instance.save({
      'l': level,
      't': tokens,
      's': spent,
      'sh': shards,
      'hs': hintStock,
      'dk': dayKey,
      'st': streak,
      'gp': gp,
      'gd': gDone,
      'wkk': weekKey,
      'wgp': wgp,
      'wgd': wgDone,
      'nk': nick,
      'cvd': convUsed,
      'by': birthYear,
      'inv': inv,
      'ads': adShards,
      'adb': adItems,
      'adbh': adItemHour,
      'up': upgrades,
      'bl': bestLevel,
      'bs': bestStreak,
      'tw': totalWins,
      'nsp': sentPlatform,
      'nsa': sentAll,
      'nsw': sentWeekScore,
      'nswk': sentWeekKey,
      'mu': musicOn,
      'th': theme,
      'ow': owned,
      'ch': chapter,
      'dn': done,
      'hbq': hintBought,
      'so': soundOn,
      'vol': soundVol,
      'vi': vibroOn,
      'pu': pushOn,
      'i': introSeen,
      'lg': lang,
    });
  }

  /// Язык берём у устройства: первый поддерживаемый из списка локалей.
  String detectLang() {
    for (final loc in PlatformDispatcher.instance.locales) {
      final code = loc.languageCode.toLowerCase();
      if (kStrings.containsKey(code)) return code;
    }
    return 'en';
  }

  void setLang(String l) {
    lang = kStrings.containsKey(l) ? l : 'en';
    buildChapter();
    save();
    notifyListeners();
  }

  // ---------- глава и задачи ----------
  void buildChapter() {
    final loc = lang == 'ru' ? 'ru' : 'en';
    double r(int i) => hash32(chapter * 9173 + i * 577 + 11);
    final cnt = math.min(30, 12 + chapter * 2);
    days = math.min(6, 4 + chapter ~/ 2);
    final per = (cnt / days).ceil();
    tasks = [];
    taskNames = [];
    taskLogs = [];
    final gv = kGenVerbs[loc]!, gpArr = kGenParts[loc]!, gl = kGenLogs[loc]!;
    for (var i = 0; i < cnt; i++) {
      taskNames.add(
          '${gv[(r(i * 3) * gv.length).floor()]} ${gpArr[(r(i * 3 + 1) * gpArr.length).floor()]} ${kGenAddrs[(r(i * 3 + 2) * kGenAddrs.length).floor()]}');
      taskLogs.add(gl[(r(i * 7) * gl.length).floor()]
          .replaceAll('{n}', '${2 + (r(i * 11) * 88).floor()}'));
      tasks.add(HubTask(
        i ~/ per,
        kTaskIcons[i % kTaskIcons.length],
        math.max(2, ((2 + (i * 1.15).round()) * (1 + math.sqrt(chapter) * 0.75)).round()),
        i % 5 == 0 ? 't' : (i % 7 == 3 ? 'h' : null),
      ));
    }
    dayNames = [];
    dayEnds = [];
    final gd = kGenDays[loc]!, gs = kGenDayEnds[loc]!;
    for (var dd = 0; dd < days; dd++) {
      dayNames.add(gd[dd % gd.length]);
      dayEnds.add(gs[dd % gs.length]);
    }
    if (done.length != cnt) done = List.filled(cnt, false);
  }

  int get free => tokens - spent;

  int get curDay {
    for (var dd = 0; dd < days; dd++) {
      for (var i = 0; i < tasks.length; i++) {
        if (tasks[i].day == dd && !done[i]) return dd;
      }
    }
    return days;
  }

  String modelName(int c) {
    final g = c ~/ kModelNames.length;
    return kModelNames[c % kModelNames.length] + (g > 0 ? ' ${g + 1}' : '');
  }

  int get donePct =>
      tasks.isEmpty ? 0 : (done.where((x) => x).length / tasks.length * 100).round();

  /// Бонус ходов от построенных задач с эффектом «t».
  double timeBonus() {
    var m = 1.0;
    for (var i = 0; i < tasks.length; i++) {
      if (i < done.length && done[i] && tasks[i].fx == 't') m *= 1.15;
    }
    return m;
  }

  String nextGoalLine() {
    for (var i = 0; i < tasks.length; i++) {
      if (done[i]) continue;
      final need = math.max(0, tasks[i].cost - free);
      return need > 0
          ? t('goalNeed').replaceAll('{name}', taskNames[i]).replaceAll('{n}', '$need')
          : t('goalBuy').replaceAll('{name}', taskNames[i]);
    }
    return t('goalAll');
  }

  // ---------- день и цели ----------
  String _today() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Номер недели от эпохи (понедельник — первый день).
  int _thisWeek() =>
      ((DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000) + 3) ~/ 7;

  void checkDay() {
    _checkWeek();
    final td = _today();
    if (dayKey == td) return;
    final prev = dayKey;
    dayKey = td;
    gp = [0, 0, 0];
    gDone = [false, false, false];
    adShards = 0;
    convUsed = 0;
    // «Запасная подсказка» из мастерской: +1 в день за каждый уровень.
    hintStock += dailyHintBonus;
    if (prev.isNotEmpty) {
      final y = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final yk = '${y.year}-${y.month}-${y.day}';
      if (prev != yk) streak = 0;
    }
    save();
  }

  void _checkWeek() {
    final wk = _thisWeek();
    if (weekKey == wk) return;
    weekKey = wk;
    wgp = [0, 0, 0];
    wgDone = [false, false, false];
    save();
  }

  /// Прогресс цели недели: 0 — связи, 1 — задачи, 2 — дни с полным
  /// комплектом целей дня. Награды крупнее дневных (kWeekRewards).
  void weekHit(int i, [int n = 1]) {
    // Счёт продолжается и после выполнения (нужен недельному топу),
    // награда выдаётся один раз.
    wgp[i] += n;
    if (!wgDone[i] && wgp[i] >= kWeekGoals[i]) {
      wgDone[i] = true;
      shards += kWeekRewards[i];
      Future.delayed(const Duration(milliseconds: 1800), () {
        onEvent?.call(GameEvent(GameEventType.toast,
            text: lt('wkDone')
                .replaceAll('{n}', lt('wk$i'))
                .replaceAll('{s}', '${kWeekRewards[i]}')));
        GameAudio.instance.chord([659, 880, 1175]);
        Haptics.instance.success();
      });
      save();
      notifyListeners();
    }
  }

  void goalHit(int i, [int n = 1]) {
    if (gDone[i]) return;
    gp[i] += n;
    if (gp[i] >= kGoals[i]) {
      gDone[i] = true;
      shards++;
      onEvent?.call(GameEvent(GameEventType.toast,
          text: t('goalDone').replaceAll('{n}', tl('gn')[i])));
      GameAudio.instance.chord([784, 1047]);
      if (gDone[0] && gDone[1] && gDone[2]) {
        streak++;
        if (streak > bestStreak) bestStreak = streak;
        weekHit(2); // день с полным комплектом целей — шаг цели недели
        // Осколки — редкая валюта: серия платит только на вехах,
        // а не каждый день (иначе они копятся быстрее, чем тратятся).
        final bonus = streak % 14 == 0 ? 4 : (streak % 7 == 0 ? 2 : (streak % 3 == 0 ? 1 : 0));
        shards += bonus;
        if (streak % 7 == 0) inv['stab'] = inv['stab']! + 1;
        Future.delayed(const Duration(milliseconds: 900), () {
          onEvent?.call(GameEvent(GameEventType.toast,
              text: bonus > 0
                  ? t('streakUp')
                      .replaceAll('{d}', '$streak')
                      .replaceAll('{n}', '$bonus')
                  : t('streakN').replaceAll('{d}', '$streak')));
          GameAudio.instance.chord([659, 880, 1175]);
        });
      }
      save();
      notifyListeners();
    }
  }

  // ---------- досылка очков в таблицы ----------
  /// Есть очки, которые таблицы ещё не подтвердили?
  bool get _boardsBehind =>
      bestLevel > sentPlatform ||
      totalWins > sentAll ||
      (wgp[0] > 0 && (sentWeekKey != weekKey || wgp[0] > sentWeekScore));

  bool _syncingBoards = false;

  /// Дослать очки в Game Center/Play Игры и на сетевую доску.
  ///
  /// Безопасно вызывать сколько угодно раз: когда всё подтверждено —
  /// мгновенный выход без сети. Вызывается при победе, при возврате в
  /// приложение и при открытии топа — очки, не ушедшие без интернета,
  /// доедут при первом же его появлении. Ошибки игрока не трогают.
  Future<void> syncBoards() async {
    if (_syncingBoards || !_boardsBehind) return;
    _syncingBoards = true;
    try {
      if (bestLevel > sentPlatform) {
        if (await Lb.instance.submit(bestLevel)) {
          sentPlatform = bestLevel;
          save();
        }
      }
      if (NetBoard.instance.available &&
          (totalWins > sentAll ||
              (wgp[0] > 0 &&
                  (sentWeekKey != weekKey || wgp[0] > sentWeekScore)))) {
        final all = totalWins, ws = wgp[0], wk = weekKey;
        final ok = await NetBoard.instance
            .submit(nick: nick, allTime: all, weeklyScore: ws, week: wk);
        if (ok) {
          sentAll = all;
          sentWeekScore = ws;
          sentWeekKey = wk;
          save();
        }
      }
    } finally {
      _syncingBoards = false;
    }
  }

  // ---------- личные рекорды и уровень оператора ----------
  /// Вызывается движком при каждой победе: ведёт рекорды и уровень
  /// оператора. Повышение уровня — редкое событие, платит осколками.
  void recordWin(int lvl) {
    checkDay();
    final before = operatorLevel;
    totalWins++;
    weekHit(0);
    if (lvl > bestLevel) bestLevel = lvl;
    if (streak > bestStreak) bestStreak = streak;
    // Очки в таблицы — в фоне; без сети дошлются позже (syncBoards).
    syncBoards().ignore();
    final after = operatorLevel;
    if (after > before) {
      shards += 2;
      Future.delayed(const Duration(milliseconds: 1400), () {
        onEvent?.call(GameEvent(GameEventType.toast,
            text: lt('opUp').replaceAll('{n}', '$after').replaceAll('{s}', '2✦')));
        GameAudio.instance.chord([523, 659, 784, 1047]);
        Haptics.instance.fanfare();
      });
    }
  }

  // ---------- задачи датацентра ----------
  void doTask(int i) {
    if (done[i] || free < tasks[i].cost) return;
    final wasDay = curDay;
    spent += tasks[i].cost;
    done[i] = true;
    if (tasks[i].fx == 'h') hintStock++;
    goalHit(2);
    weekHit(1);
    save();
    GameAudio.instance.tone(660, .1, 'square', .06);
    Future.delayed(const Duration(milliseconds: 90),
        () => GameAudio.instance.tone(990, .14, 'square', .06));
    Haptics.instance.success();
    notifyListeners();
    if (done.every((x) => x)) {
      _finaleChapter();
      return;
    }
    if (curDay != wasDay && wasDay < days) {
      onEvent?.call(GameEvent(GameEventType.dayScene, day: wasDay));
    } else {
      onEvent?.call(GameEvent(GameEventType.toast, text: taskLogs[i]));
    }
  }

  void _finaleChapter() {
    GameAudio.instance.tone(880, .2, 'sine', .07);
    Future.delayed(const Duration(milliseconds: 180),
        () => GameAudio.instance.tone(1320, .3, 'sine', .07));
    Haptics.instance.fanfare();
    Future.delayed(const Duration(milliseconds: 1000), () {
      chapter++;
      spent = 0;
      done = [];
      buildChapter();
      shards += 5;
      inv = {
        'cut': inv['cut']! + 1,
        'stab': inv['stab']! + 1,
        'auto': inv['auto']! + 1,
      };
      hintStock += 2;
      save();
      notifyListeners();
      onEvent?.call(const GameEvent(GameEventType.chapterFinale));
    });
  }

  /// Текст финала главы: {a} — собранная модель, {b} — следующая.
  String chapterStoryText() {
    final loc = lang == 'ru' ? 'ru' : 'en';
    final list = kChapterStories[loc]!;
    return list[chapter % list.length]
        .replaceAll('{a}', modelName(chapter - 1))
        .replaceAll('{b}', modelName(chapter));
  }

  // ---------- магазин ----------
  /// Цена подсказки: первые покупки дешёвые, дальше дорожает, но с
  /// потолком 12✦ — вечная эскалация (до 21✦) наказывала игрока за
  /// использование главного инструмента. Потолок сохраняет смысл
  /// апгрейда «+1 подсказка в день», не превращая цену в стену.
  int hintPrice() => 6 + math.min(6, hintBought);

  /// Обмен энергии на осколки: 40{bolt} → 1✦, до двух раз в день.
  /// Сток для избытка энергии: когда задачи дня уже построены, компьют
  /// не копится мёртвым грузом.
  static const convCost = 40;
  static const convLimit = 2;
  bool get canConvert => free >= convCost && convUsed < convLimit;

  void convertEnergy() {
    checkDay();
    if (convUsed >= convLimit) return;
    if (free < convCost) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: t('goalNeed')
              .replaceAll('{name}', lt('cvT'))
              .replaceAll('{n}', '${convCost - free}')));
      Haptics.instance.reject();
      return;
    }
    spent += convCost;
    shards++;
    convUsed++;
    save();
    GameAudio.instance.chord([660, 880]);
    Haptics.instance.success();
    onEvent?.call(const GameEvent(GameEventType.toast, text: '+1✦'));
    notifyListeners();
  }

  bool buyBooster(int bi) {
    final b = kBoosters[bi];
    if (shards < b.cost) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: t('needSh').replaceAll('{n}', '${b.cost - shards}')));
      return false;
    }
    shards -= b.cost;
    inv[b.key] = inv[b.key]! + 1;
    save();
    GameAudio.instance.tone(880, .1, 'square', .05);
    Haptics.instance.buzz(25);
    onEvent?.call(GameEvent(GameEventType.toast,
        text: t('bBought').replaceAll('{n}', tl('bn')[bi])));
    notifyListeners();
    return true;
  }

  bool buyHint() {
    final c = hintPrice();
    if (shards < c) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: t('needSh').replaceAll('{n}', '${c - shards}')));
      return false;
    }
    shards -= c;
    hintStock++;
    hintBought++;
    save();
    GameAudio.instance.tone(940, .1, 'square', .05);
    Haptics.instance.buzz(25);
    onEvent?.call(GameEvent(GameEventType.toast, text: t('hintBought')));
    notifyListeners();
    return true;
  }

  void selectTheme(int ti) {
    final th = kThemes[ti];
    if (owned[ti] == 0) {
      if (shards < th.cost) {
        onEvent?.call(GameEvent(GameEventType.toast,
            text: t('needSh').replaceAll('{n}', '${th.cost - shards}')));
        return;
      }
      shards -= th.cost;
      owned[ti] = 1;
      onEvent?.call(GameEvent(GameEventType.toast,
          text: t('thBought').replaceAll('{n}', lang == 'ru' ? th.nameRu : th.nameEn)));
      GameAudio.instance.chord([660, 880]);
    }
    theme = ti;
    Haptics.instance.snap();
    save();
    notifyListeners();
  }

  bool get canAdShard => adShards < 3 && Ads.instance.hasAds;

  /// Товар за ролик: до [adItemLimit] предметов В ЧАС (осколки — 3 в
  /// день, а предметы восполняются каждый час). Кнопка появляется на
  /// карточке ВМЕСТО цены — только когда осколков не хватает; купить
  /// и за осколки, и за рекламу одновременно нельзя.
  static const adItemLimit = 3;

  int get _thisHour =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 3600000;

  /// Новый час — новый запас предметов за ролик.
  void _checkAdHour() {
    final h = _thisHour;
    if (adItemHour == h) return;
    adItemHour = h;
    adItems = 0;
  }

  bool get canAdItem {
    _checkAdHour();
    return adItems < adItemLimit && Ads.instance.hasAds;
  }

  /// Остаток предметов за ролик в этом часе — показывается на кнопке.
  int get adItemsLeft {
    _checkAdHour();
    return adItemLimit - adItems;
  }

  Future<void> watchAdForItem(String key) async {
    checkDay();
    if (!canAdItem) return;
    onEvent?.call(GameEvent(GameEventType.toast, text: t('adWatch')));
    final ok = await Ads.instance.rewarded();
    if (!ok) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: Ads.instance.hasAds ? t('adFail') : t('adOff')));
      return;
    }
    adItems++;
    if (key == 'hint') {
      hintStock++;
      onEvent?.call(GameEvent(GameEventType.toast, text: t('hintBought')));
    } else {
      inv[key] = (inv[key] ?? 0) + 1;
      final bi = kBoosters.indexWhere((b) => b.key == key);
      onEvent?.call(GameEvent(GameEventType.toast,
          text: t('bBought').replaceAll('{n}', tl('bn')[bi])));
    }
    save();
    GameAudio.instance.tone(880, .1, 'square', .05);
    Haptics.instance.success();
    notifyListeners();
  }

  /// +1✦ за ролик, до трёх в день. Осколки — премиальная валюта,
  /// поэтому награда нарочно маленькая: быстро их не нафармить.
  Future<void> watchAdForShards() async {
    if (adShards >= 3) return;
    onEvent?.call(GameEvent(GameEventType.toast, text: t('adWatch')));
    final ok = await Ads.instance.rewarded();
    if (!ok) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: Ads.instance.hasAds ? t('adFail') : t('adOff')));
      return;
    }
    shards += 1;
    adShards++;
    save();
    onEvent?.call(const GameEvent(GameEventType.toast, text: '+1✦'));
    GameAudio.instance.tone(1000, .12, 'sine', .06);
    Haptics.instance.success();
    notifyListeners();
  }

  // ---------- настройки ----------
  void setMusic(bool v) {
    musicOn = v;
    GameAudio.instance.setMusicEnabled(v);
    save();
    notifyListeners();
  }

  void setSound(bool v) {
    soundOn = v;
    GameAudio.instance.enabled = v;
    save();
    if (v) GameAudio.instance.tone(880, .1, 'square', .05);
    notifyListeners();
  }

  /// Громкость звуков (0.5–2.0). [commit] — конец жеста: сохраняем и
  /// даём услышать результат контрольным щелчком.
  void setSoundVolume(double v, {bool commit = false}) {
    soundVol = v.clamp(0.5, 2.0);
    GameAudio.instance.volume = soundVol;
    if (commit) {
      save();
      GameAudio.instance.tone(660, .1, 'triangle', .09);
    }
    notifyListeners();
  }

  void setVibro(bool v) {
    vibroOn = v;
    Haptics.instance.enabled = v;
    save();
    if (v) Haptics.instance.medium();
    notifyListeners();
  }

  Future<void> setPush(bool v) async {
    pushOn = v;
    save();
    notifyListeners();
    if (v) {
      final ok = await Push.instance.askOnce();
      if (!ok) {
        onEvent?.call(GameEvent(GameEventType.toast, text: t('pushOff')));
      } else {
        reschedulePush();
      }
    } else {
      await Push.instance.clear();
    }
  }

  /// Полное обнуление: прогресс, валюты, улучшения, рекорды и сюжет.
  /// Настройки звука/языка/уведомлений сохраняются — это выбор
  /// устройства, а не прогресс.
  void resetProgress() {
    Storage.instance.reset();
    level = 1;
    tokens = 0;
    spent = 0;
    shards = 0;
    hintStock = 2;
    chapter = 0;
    inv = {'cut': 0, 'stab': 0, 'auto': 0};
    adShards = 0;
    adItems = 0;
    adItemHour = 0;
    upgrades = {};
    bestLevel = 0;
    bestStreak = 0;
    totalWins = 0;
    sentPlatform = 0;
    sentAll = 0;
    sentWeekScore = 0;
    sentWeekKey = -1;
    LbCache.clear();
    done = [];
    hintBought = 0;
    streak = 0;
    dayKey = '';
    gp = [0, 0, 0];
    gDone = [false, false, false];
    weekKey = 0;
    wgp = [0, 0, 0];
    wgDone = [false, false, false];
    theme = 0;
    owned = List.generate(kThemes.length, (i) => i == 0 ? 1 : 0);
    introSeen = false;
    buildChapter();
    checkDay();
    notifyListeners();
    onEvent?.call(const GameEvent(GameEventType.storyIntro));
  }

  // ---------- напоминания ----------
  /// План уведомлений: одно в день на неделю вперёд, тексты не
  /// повторяются. Завтра — контекст (задача дня → цели → серия),
  /// дальше — ротация мягких напоминаний из kPushStrings.
  void reschedulePush() {
    if (!pushOn) return;
    final px = kPushStrings[lang] ?? kPushStrings['en']!;
    final entries = <(String, String)>[];

    // Завтра: самое конкретное, что можно сказать про сохранение.
    String? body;
    final cd = curDay;
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].day == cd && !done[i] && free >= tasks[i].cost) {
        body = t('nudgeTask').replaceAll('{name}', taskNames[i]);
        break;
      }
    }
    body ??= streak > 0
        ? t('nudgeStreak').replaceAll('{d}', '$streak')
        : t('nudgeGoals').replaceAll('{v}', '0/3');
    entries.add((px.titles[0], body));

    // Послезавтра: серия под угрозой или цели дня.
    entries.add((
      px.titles[1],
      streak > 1
          ? t('nudgeStreak').replaceAll('{d}', '$streak')
          : t('nudgeGoals').replaceAll('{v}', '0/3'),
    ));

    // Дни 3–7: спокойная ротация «возвращайся» без повторов подряд.
    for (var d = 2; d < 7; d++) {
      entries.add((
        px.titles[d % px.titles.length],
        px.bodies[(d - 2) % px.bodies.length],
      ));
    }
    Push.instance.reschedule(entries);
  }

  /// Возраст для настройки рекламы. Консервативно: минус один год
  /// (день рождения в этом году мог ещё не наступить). Пока год не
  /// указан — считаем пользователя ребёнком: строже, но безопасно.
  int get adAge {
    if (birthYear <= 0) return 0;
    return math.max(0, DateTime.now().year - birthYear - 1);
  }

  bool get needsAgeGate => birthYear <= 0;

  void setBirthYear(int year) {
    birthYear = year;
    Ads.instance.setAge(adAge);
    save();
    notifyListeners();
  }

  void markIntroSeen() {
    introSeen = true;
    save();
  }

  void notify() => notifyListeners();
}
