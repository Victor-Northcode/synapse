import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/ads.dart';
import '../core/audio.dart';
import '../core/haptics.dart';
import '../core/notifications.dart';
import '../core/storage.dart';
import '../data/game_data.dart';
import '../data/story_data.dart';
import '../data/strings.dart';
import '../data/task_data.dart';
import '../game/level.dart' show hash32;

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
  Map<String, int> inv = {'cut': 0, 'stab': 0, 'auto': 0};
  int adShards = 0;
  int adItems = 0; // предметы за ролик, до 3 в день
  int theme = 0;
  List<int> owned = [1, 0, 0, 0];
  List<bool> done = [];
  int hintBought = 0;
  bool soundOn = true;
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
      theme = ((sv['th'] as num?)?.toInt() ?? 0).clamp(0, kThemes.length - 1);
      if (sv['ow'] is List) {
        owned = [for (final v in sv['ow'] as List) (v as num).toInt()];
        while (owned.length < kThemes.length) {
          owned.add(0);
        }
      }
      soundOn = sv['so'] != false;
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
    GameAudio.instance.enabled = soundOn;
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
      'inv': inv,
      'ads': adShards,
      'adb': adItems,
      'th': theme,
      'ow': owned,
      'ch': chapter,
      'dn': done,
      'hbq': hintBought,
      'so': soundOn,
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

  void checkDay() {
    final td = _today();
    if (dayKey == td) return;
    final prev = dayKey;
    dayKey = td;
    gp = [0, 0, 0];
    gDone = [false, false, false];
    adShards = 0;
    adItems = 0;
    if (prev.isNotEmpty) {
      final y = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final yk = '${y.year}-${y.month}-${y.day}';
      if (prev != yk) streak = 0;
    }
    save();
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
        final bonus = streak % 14 == 0 ? 8 : (streak % 7 == 0 ? 5 : (streak % 3 == 0 ? 2 : 1));
        shards += bonus;
        if (streak % 7 == 0) inv['stab'] = inv['stab']! + 1;
        Future.delayed(const Duration(milliseconds: 900), () {
          onEvent?.call(GameEvent(GameEventType.toast,
              text: t('streakUp')
                  .replaceAll('{d}', '$streak')
                  .replaceAll('{n}', '$bonus')));
          GameAudio.instance.chord([659, 880, 1175]);
        });
      }
      save();
      notifyListeners();
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
  int hintPrice() => 5 + math.min(15, hintBought);

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

  /// Предмет за ролик, когда осколков не хватает: бустер или подсказка.
  /// До трёх предметов в день — тем же принципом, что и +2✦.
  bool get canAdItem => adItems < 3 && Ads.instance.hasAds;

  /// Предложение «за ролик» появляется РЕДКО: примерно у одного предмета
  /// в день, состав меняется ежедневно. Детерминировано от даты, чтобы
  /// кнопка не мигала между перерисовками и не исчезала в течение дня.
  bool adOfferFor(String kind) {
    if (!canAdItem) return false;
    final idx = const ['cut', 'stab', 'auto', 'hint'].indexOf(kind);
    if (idx < 0) return false;
    var seed = 0;
    for (final c in dayKey.codeUnits) {
      seed = (seed * 31 + c) & 0x7FFFFFFF;
    }
    return hash32(seed + idx * 977 + 5) < 0.28;
  }

  Future<void> watchAdForItem(String kind) async {
    if (!canAdItem) return;
    onEvent?.call(GameEvent(GameEventType.toast, text: t('adWatch')));
    final ok = await Ads.instance.rewarded();
    if (!ok) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: Ads.instance.hasAds ? t('adFail') : t('adOff')));
      return;
    }
    adItems++;
    String label;
    if (kind == 'hint') {
      hintStock++;
      label = t('hintBought');
    } else {
      inv[kind] = (inv[kind] ?? 0) + 1;
      final bi = kBoosters.indexWhere((b) => b.key == kind);
      label = t('bBought').replaceAll('{n}', tl('bn')[bi]);
    }
    save();
    onEvent?.call(GameEvent(GameEventType.toast, text: label));
    GameAudio.instance.tone(1000, .12, 'sine', .06);
    Haptics.instance.success();
    notifyListeners();
  }

  /// +2✦ за ролик, до трёх в день.
  Future<void> watchAdForShards() async {
    if (adShards >= 3) return;
    onEvent?.call(GameEvent(GameEventType.toast, text: t('adWatch')));
    final ok = await Ads.instance.rewarded();
    if (!ok) {
      onEvent?.call(GameEvent(GameEventType.toast,
          text: Ads.instance.hasAds ? t('adFail') : t('adOff')));
      return;
    }
    shards += 2;
    adShards++;
    save();
    onEvent?.call(const GameEvent(GameEventType.toast, text: '+2✦'));
    GameAudio.instance.tone(1000, .12, 'sine', .06);
    Haptics.instance.success();
    notifyListeners();
  }

  // ---------- настройки ----------
  void setSound(bool v) {
    soundOn = v;
    GameAudio.instance.enabled = v;
    save();
    if (v) GameAudio.instance.tone(880, .1, 'square', .05);
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
    done = [];
    hintBought = 0;
    streak = 0;
    gp = [0, 0, 0];
    gDone = [false, false, false];
    theme = 0;
    owned = [1, 0, 0, 0];
    introSeen = false;
    buildChapter();
    notifyListeners();
    onEvent?.call(const GameEvent(GameEventType.storyIntro));
  }

  // ---------- напоминания ----------
  /// План уведомлений — порт PUSH.plan(): задача дня → цели → стрик.
  void reschedulePush() {
    if (!pushOn) return;
    final entries = <(String, String)>[];
    final title = t('nudgeT');
    String? body;
    final cd = curDay;
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].day == cd && !done[i] && free >= tasks[i].cost) {
        body = t('nudgeTask').replaceAll('{name}', taskNames[i]);
        break;
      }
    }
    if (body == null) {
      final doneN = gDone.where((x) => x).length;
      if (doneN < 3) {
        body = t('nudgeGoals').replaceAll('{v}', '$doneN/3');
      } else if (streak > 0) {
        body = t('nudgeStreak').replaceAll('{d}', '$streak');
      }
    }
    if (body == null) return;
    entries.add((title, body));
    if (streak > 0) {
      entries.add((title, t('nudgeStreak').replaceAll('{d}', '$streak')));
    }
    entries.add((title, t('nudgeGoals').replaceAll('{v}', '0/3')));
    Push.instance.reschedule(entries);
  }

  void markIntroSeen() {
    introSeen = true;
    save();
  }

  void notify() => notifyListeners();
}
