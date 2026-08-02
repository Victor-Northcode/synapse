import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/audio.dart';
import '../core/haptics.dart';
import '../core/notifications.dart';
import '../data/game_data.dart';
import '../game/geometry.dart';
import '../game/level.dart';
import 'app_state.dart';

/// Разовые визуальные эффекты поля.
enum PlayFx { snap, boom, flashRed }

class PlayFxEvent {
  final PlayFx fx;
  final int node;
  const PlayFxEvent(this.fx, [this.node = -1]);
}

/// Карточка-объяснение, показываемая перед стартом уровня.
class MechCard {
  /// 'obstacle' (введена механика узла), 'fill' (pick/zone/bomb), 'bridge'.
  final String kind;
  final int index;
  const MechCard(this.kind, this.index);
}

class LevelResult {
  final bool win;
  final int got;
  final int shardGain;
  final int level; // номер пройденного/проваленного уровня
  final int crossings;
  final int nodesCount;
  final int edgesCount;
  final int nextSpecN;
  const LevelResult(this.win, this.got, this.shardGain, this.level, this.crossings,
      this.nodesCount, this.edgesCount, this.nextSpecN);
}

/// Движок одного уровня — порт игровой части index.html.
class PlayState extends ChangeNotifier {
  final AppState app;
  double w, h;

  late List<Pt> nodes;
  late List<List<int>> edges;
  late List<Pt> sockets;
  late List<int> slotOf;
  late List<int> ntype;
  late Map<int, int> twin;
  late List<Zone> zones;
  int liveEdge = -1, ghostEdge = -1;
  int pickIdx = -1, bombIdx = -1, bombLeft = 0;
  int maxBridges = 0;
  final Set<int> bridges = {};

  int moves = 0, movesMax = 1;
  int crossings = 0;
  bool alive = false;
  int dragIdx = -1;
  List<double> _dragOff = [0, 0];
  int hiLite = -1;
  int snapSeq = 0;
  bool noHintRun = true;
  int level = 1;
  int kind = 0;

  MechCard? pendingCard;
  LevelResult? result;

  Timer? _corrTimer, _driftTimer;
  void Function(PlayFxEvent fx)? onFx;
  void Function(String text)? onToast;
  void Function()? onWin;
  void Function()? onBoom;

  /// Механики, уже показанные в этой сессии (мосты — одна на игру,
  /// pick/zone/bomb — по разу на главу, сбрасываются в финале).
  static bool seenBridge = false;
  static final List<bool> seenFill = [false, false, false];
  static void resetSeenFill() {
    for (var i = 0; i < 3; i++) {
      seenFill[i] = false;
    }
  }

  PlayState(this.app, this.w, this.h);

  // ---------- запуск ----------
  void start(int lvl) {
    level = lvl;
    kind = lvlKind(lvl);
    var l = generateLevel(lvl, w, h, chapter: app.chapter, curDay: app.curDay);
    var guard = 0;
    while (countCross(l.nodes, l.edges) == 0 && guard++ < 8) {
      l = generateLevel(lvl, w, h, chapter: app.chapter, curDay: app.curDay);
    }
    nodes = l.nodes;
    edges = l.edges;
    sockets = l.sockets;
    slotOf = l.slotOf;
    ntype = l.ntype;
    twin = l.twin;
    zones = l.zones;
    liveEdge = l.liveEdge;
    ghostEdge = l.ghostEdge;
    pickIdx = l.pickIdx;
    bombIdx = l.bombIdx;
    bombLeft = l.bombLeft;
    maxBridges = l.maxBridges;
    bridges.clear();
    hiLite = -1;
    snapSeq = 0;
    noHintRun = true;
    result = null;

    movesMax = (l.movesMax *
            (kind == 2 ? 0.86 : (kind == 1 ? 0.93 : 1.0)) *
            (1 + (app.timeBonus() - 1) * 0.5))
        .round();
    movesMax = math.max(4, movesMax);
    if (liveEdge >= 0) movesMax = math.max(4, movesMax - 2);
    moves = movesMax;

    _recount();
    _startTimers();
    GameAudio.instance.tone(680, .1, 'square', .04);

    // Карточка механики: мосты → бонус/зона/бомба → введённое препятствие.
    pendingCard = null;
    alive = true;
    if (maxBridges > 0 && !seenBridge) {
      seenBridge = true;
      pendingCard = const MechCard('bridge', 0);
    } else if (pickIdx >= 0 && !seenFill[0]) {
      seenFill[0] = true;
      pendingCard = const MechCard('fill', 0);
    } else if (zones.isNotEmpty && !seenFill[1]) {
      seenFill[1] = true;
      pendingCard = const MechCard('fill', 1);
    } else if (bombIdx >= 0 && !seenFill[2]) {
      seenFill[2] = true;
      pendingCard = const MechCard('fill', 2);
    } else if (l.introObstacle != 0) {
      pendingCard = MechCard('obstacle', l.introObstacle);
    }
    if (pendingCard != null) {
      alive = false;
      GameAudio.instance.tone(900, .16, 'sine', .05);
      Haptics.instance.buzz(33);
    }
    notifyListeners();
  }

  void dismissCard() {
    pendingCard = null;
    alive = true;
    GameAudio.instance.tone(680, .1, 'square', .04);
    notifyListeners();
  }

  void _startTimers() {
    _corrTimer?.cancel();
    _corrTimer = Timer.periodic(const Duration(seconds: 12), (_) => _spreadCorr());
    _driftTimer?.cancel();
    _driftTimer = Timer.periodic(const Duration(milliseconds: 700), (_) => _drift());
  }

  void _stopTimers() {
    _corrTimer?.cancel();
    _driftTimer?.cancel();
  }

  /// Поле изменило размер — пересчитываем координаты пропорционально.
  void resize(double nw, double nh) {
    if (nw <= 0 || nh <= 0 || (nw == w && nh == h)) return;
    final kx = nw / w, ky = nh / h;
    w = nw;
    h = nh;
    for (final p in nodes) {
      p[0] *= kx;
      p[1] *= ky;
    }
    for (final p in sockets) {
      p[0] *= kx;
      p[1] *= ky;
    }
    for (final z in zones) {
      z.x *= kx;
      z.y *= ky;
      z.w *= kx;
      z.h *= ky;
    }
    _recount();
    notifyListeners();
  }

  void _recount() => crossings = countCross(nodes, edges, bridges);

  /// Рёбра, участвующие в пересечениях (для окраски «bad»).
  Set<int> badEdges() {
    final bad = <int>{};
    for (var a = 0; a < edges.length; a++) {
      for (var b = a + 1; b < edges.length; b++) {
        if (shares(edges[a], edges[b])) continue;
        if (bridges.contains(a) != bridges.contains(b)) continue;
        if (segX(nodes[edges[a][0]], nodes[edges[a][1]], nodes[edges[b][0]],
            nodes[edges[b][1]])) {
          bad.add(a);
          bad.add(b);
        }
      }
    }
    return bad;
  }

  // ---------- препятствия-таймеры ----------
  void _spreadCorr() {
    if (!alive) return;
    var src = -1;
    for (var i = 0; i < ntype.length; i++) {
      if (ntype[i] == 2) {
        src = i;
        break;
      }
    }
    if (src < 0) return;
    final nb = <int>[];
    for (final e in edges) {
      if (e[0] == src && ntype[e[1]] == 0) nb.add(e[1]);
      if (e[1] == src && ntype[e[0]] == 0) nb.add(e[0]);
    }
    if (nb.isEmpty) return;
    ntype[nb[math.Random().nextInt(nb.length)]] = 2;
    GameAudio.instance.tone(160, .2, 'sawtooth', .05);
    Haptics.instance.warning();
    notifyListeners();
  }

  void _drift() {
    if (!alive) return;
    final rnd = math.Random();
    var moved = false;
    for (var i = 0; i < ntype.length; i++) {
      if (ntype[i] != 6 || i == dragIdx) continue;
      nodes[i] = [
        (nodes[i][0] + rnd.nextDouble() * 10 - 5).clamp(kNodeR, w - kNodeR),
        (nodes[i][1] + rnd.nextDouble() * 10 - 5).clamp(kNodeR, h - kNodeR),
      ];
      moved = true;
    }
    if (moved) {
      _recount();
      notifyListeners();
    }
  }

  // ---------- перетаскивание ----------
  /// Тап/захват узла. Возвращает true, если начат drag.
  bool pointerDown(int i, double px, double py) {
    if (!alive) return false;
    switch (ntype[i]) {
      case 6: // дрейф: тап фиксирует
        ntype[i] = 0;
        _spendMove();
        GameAudio.instance.tone(700, .12, 'sine', .05);
        Haptics.instance.buzz(25);
        notifyListeners();
        return false;
      case 3: // гвоздь
        GameAudio.instance.tone(120, .12, 'square', .06);
        Haptics.instance.reject();
        return false;
      case 4: // двойной липкий
        ntype[i] = 1;
        _spendMove();
        GameAudio.instance.tone(240, .12, 'square', .05);
        Haptics.instance.buzz(40);
        notifyListeners();
        return false;
      case 1: // липкий
        ntype[i] = 0;
        _spendMove();
        GameAudio.instance.tone(300, .12, 'square', .05);
        Haptics.instance.buzz(30);
        notifyListeners();
        return false;
      case 2: // ржавчина: чистится чистым соседом
        var okc = false;
        for (final e in edges) {
          if (e[0] == i && ntype[e[1]] == 0) okc = true;
          if (e[1] == i && ntype[e[0]] == 0) okc = true;
        }
        if (okc) {
          ntype[i] = 0;
          _spendMove();
          GameAudio.instance.tone(420, .14, 'sine', .05);
          Haptics.instance.buzz(30);
          notifyListeners();
        } else {
          GameAudio.instance.tone(120, .12, 'square', .05);
          Haptics.instance.reject();
        }
        return false;
    }
    dragIdx = i;
    _dragOff = [nodes[i][0] - px, nodes[i][1] - py];
    GameAudio.instance.tone(420, .05, 'sine', .03);
    Haptics.instance.grab();
    notifyListeners();
    return true;
  }

  void pointerMove(double px, double py) {
    if (dragIdx < 0 || !alive) return;
    var nx = px + _dragOff[0], ny = py + _dragOff[1];
    if (ntype[dragIdx] == 7) {
      // инверсия: узел движется против пальца
      nx = nodes[dragIdx][0] - (nx - nodes[dragIdx][0]);
      ny = nodes[dragIdx][1] - (ny - nodes[dragIdx][1]);
    }
    final ox = nodes[dragIdx][0], oy = nodes[dragIdx][1];
    nodes[dragIdx] = [nx.clamp(kNodeR, w - kNodeR), ny.clamp(kNodeR, h - kNodeR)];
    final tw = twin[dragIdx];
    if (tw != null) {
      nodes[tw] = [
        (nodes[tw][0] + (nodes[dragIdx][0] - ox)).clamp(kNodeR, w - kNodeR),
        (nodes[tw][1] + (nodes[dragIdx][1] - oy)).clamp(kNodeR, h - kNodeR),
      ];
    }
    _recount();
    notifyListeners();
  }

  void pointerUp() {
    if (dragIdx < 0) return;
    Haptics.instance.light();
    final i = dragIdx;
    final from = slotOf[i];
    var bi = -1;
    var bd = 1e9;
    for (var k = 0; k < sockets.length; k++) {
      if (slotOf.contains(k) && k != from) continue;
      final dd = dist(nodes[i], sockets[k]);
      if (dd < bd) {
        bd = dd;
        bi = k;
      }
    }
    final wet = bi >= 0 && bi != from && _inZone(sockets[bi]);
    if (bi < 0 || bd > kNodeR * 4.2) bi = from;
    nodes[i] = [sockets[bi][0], sockets[bi][1]];
    final tw = twin[i];
    if (tw != null) {
      var bj = -1;
      var bjd = 1e9;
      for (var k3 = 0; k3 < sockets.length; k3++) {
        if (slotOf.contains(k3) && k3 != slotOf[tw]) continue;
        final d3 = dist(nodes[tw], sockets[k3]);
        if (d3 < bjd) {
          bjd = d3;
          bj = k3;
        }
      }
      if (bj >= 0 && bjd <= kNodeR * 4.2) {
        slotOf[tw] = bj;
        nodes[tw] = [sockets[bj][0], sockets[bj][1]];
      } else {
        nodes[tw] = [sockets[slotOf[tw]][0], sockets[slotOf[tw]][1]];
      }
    }
    final changed = bi != from;
    slotOf[i] = bi;
    dragIdx = -1;
    _recount();
    if (changed) {
      moves -= wet ? 2 : 1;
      if (wet) {
        onToast?.call(app.t('zoneNo'));
        GameAudio.instance.tone(150, .14, 'square', .05);
        Haptics.instance.warning();
      }
      if (pickIdx >= 0 && bi == pickIdx) {
        pickIdx = -1;
        final rk = kBoosters[math.Random().nextInt(kBoosters.length)].key;
        app.inv[rk] = app.inv[rk]! + 1;
        app.save();
        onToast?.call(app.t('pickGot'));
        GameAudio.instance.tone(1100, .14, 'sine', .06);
        Haptics.instance.success();
      }
      if (bombIdx >= 0) {
        bombLeft--;
        var bad2 = false;
        for (var q2 = 0; q2 < edges.length && !bad2; q2++) {
          if (edges[q2][0] != bombIdx && edges[q2][1] != bombIdx) continue;
          for (var q3 = 0; q3 < edges.length; q3++) {
            if (q3 == q2 || shares(edges[q2], edges[q3])) continue;
            if (segX(nodes[edges[q2][0]], nodes[edges[q2][1]], nodes[edges[q3][0]],
                nodes[edges[q3][1]])) {
              bad2 = true;
              break;
            }
          }
        }
        if (!bad2) {
          bombIdx = -1;
          onToast?.call(app.t('bombOk'));
          GameAudio.instance.tone(950, .16, 'sine', .06);
        } else if (bombLeft <= 0) {
          notifyListeners();
          boom();
          return;
        }
      }
      snapSeq++;
      GameAudio.instance.snapTone(snapSeq);
      Haptics.instance.snap();
      onFx?.call(PlayFxEvent(PlayFx.snap, i));
    }
    notifyListeners();
    if (alive && crossings == 0) {
      win();
      return;
    }
    if (alive && moves <= 0) boom();
  }

  bool _inZone(Pt p) => zones.any((z) => z.contains(p));

  void _spendMove([int n = 1]) {
    moves -= n;
    if (alive && moves <= 0 && crossings > 0) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (alive) boom();
      });
    }
  }

  // ---------- мосты ----------
  /// Индекс кабеля около точки (портит cableIndexAt: у нас — по дистанции
  /// до квадратичной кривой, с допуском в половину толщины + запас).
  int cableIndexAt(double px, double py) {
    var best = -1;
    var bestD = 16.0; // допуск попадания
    for (var i = 0; i < edges.length; i++) {
      final a = nodes[edges[i][0]], b = nodes[edges[i][1]];
      final mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
      final dx = b[0] - a[0], dy = b[1] - a[1];
      final s = math.min(26.0, math.sqrt(dx * dx + dy * dy) * 0.14);
      final cy = my + s;
      for (var t = 0.0; t <= 1.0; t += 1 / 24) {
        final it = 1 - t;
        final x = it * it * a[0] + 2 * it * t * mx + t * t * b[0];
        final y = it * it * a[1] + 2 * it * t * cy + t * t * b[1];
        final d = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
    }
    return best;
  }

  /// Тап по кабелю: поднять/опустить мост.
  void toggleBridge(double px, double py) {
    if (!alive || maxBridges <= 0) return;
    final idx = cableIndexAt(px, py);
    if (idx < 0) return;
    if (bridges.contains(idx)) {
      bridges.remove(idx);
    } else {
      if (bridges.length >= maxBridges) {
        onToast?.call(app.t('brMax').replaceAll('{n}', '$maxBridges'));
        return;
      }
      bridges.add(idx);
    }
    moves--;
    _recount();
    GameAudio.instance.tone(bridges.contains(idx) ? 900 : 600, .1, 'sine', .05);
    Haptics.instance.buzz(20);
    notifyListeners();
    if (alive && crossings == 0) {
      win();
      return;
    }
    if (alive && moves <= 0) boom();
  }

  // ---------- бустеры ----------
  bool boostHasTarget(String k) {
    if (!alive) return false;
    if (k == 'stab') return true;
    if (k == 'cut') {
      for (var i = 0; i < ntype.length; i++) {
        if (ntype[i] == 1 || ntype[i] == 3 || ntype[i] == 4 || ntype[i] == 6) return true;
      }
      return false;
    }
    if (k == 'auto') {
      final base = countCross(nodes, edges);
      for (var n2 = 0; n2 < nodes.length; n2++) {
        if (ntype[n2] == 3) continue;
        final old = [...nodes[n2]];
        var hit = false;
        for (var s2 = 0; s2 < sockets.length; s2++) {
          if (slotOf.contains(s2)) continue;
          nodes[n2] = [...sockets[s2]];
          if (countCross(nodes, edges) < base) {
            hit = true;
            break;
          }
        }
        nodes[n2] = old;
        if (hit) return true;
      }
      return false;
    }
    return true;
  }

  void useBoost(String k) {
    if (!alive) return;
    if ((app.inv[k] ?? 0) <= 0) {
      onToast?.call(app.t('needBoost'));
      Haptics.instance.reject();
      return;
    }
    if (!boostHasTarget(k)) {
      onToast?.call(app.t('bNoTarget'));
      Haptics.instance.reject();
      return;
    }
    if (k == 'stab') {
      moves += 3;
      onToast?.call(app.t('bStabOk'));
    }
    if (k == 'cut') {
      var f = -1;
      for (var i = 0; i < ntype.length; i++) {
        if (ntype[i] == 1 || ntype[i] == 3 || ntype[i] == 4 || ntype[i] == 6) {
          f = i;
          break;
        }
      }
      if (f < 0) {
        onToast?.call(app.t('bNoTarget'));
        return;
      }
      ntype[f] = 0;
      onToast?.call(app.t('bCutOk'));
    }
    if (k == 'auto') {
      var bestI = -1, bestS = -1;
      var bestC = countCross(nodes, edges);
      for (var n2 = 0; n2 < nodes.length; n2++) {
        if (ntype[n2] == 3) continue;
        final old = [...nodes[n2]];
        for (var s2 = 0; s2 < sockets.length; s2++) {
          if (slotOf.contains(s2)) continue;
          nodes[n2] = [...sockets[s2]];
          final c2 = countCross(nodes, edges);
          if (c2 < bestC) {
            bestC = c2;
            bestI = n2;
            bestS = s2;
          }
        }
        nodes[n2] = old;
      }
      if (bestI < 0) {
        onToast?.call(app.t('bNoTarget'));
        return;
      }
      slotOf[bestI] = bestS;
      nodes[bestI] = [...sockets[bestS]];
      onToast?.call(app.t('bAutoOk'));
    }
    app.inv[k] = app.inv[k]! - 1;
    app.save();
    _recount();
    GameAudio.instance.tone(1000, .12, 'sine', .06);
    Haptics.instance.success();
    notifyListeners();
    if (alive && crossings == 0) win();
  }

  // ---------- подсказка ----------
  /// true — подсказка показана; false — нет запаса (нужен ролик).
  bool useHint() {
    if (!alive) return true;
    if (app.hintStock <= 0) return false;
    for (var a = 0; a < edges.length && hiLite < 0; a++) {
      for (var b = a + 1; b < edges.length; b++) {
        if (shares(edges[a], edges[b])) continue;
        if (segX(nodes[edges[a][0]], nodes[edges[a][1]], nodes[edges[b][0]],
            nodes[edges[b][1]])) {
          hiLite = a;
          break;
        }
      }
    }
    app.hintStock--;
    noHintRun = false;
    app.save();
    GameAudio.instance.tone(1000, .1, 'sine', .05);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 2200), () {
      hiLite = -1;
      notifyListeners();
    });
    return true;
  }

  // ---------- финалы ----------
  void win() {
    alive = false;
    _stopTimers();
    final left = moves / movesMax;
    var got = left > 0.45 ? 3 : (left > 0.2 ? 2 : 1);
    app.goalHit(0);
    if (noHintRun) app.goalHit(1);
    final kd2 = lvlKind(level);
    if (kd2 == 2) {
      got += 2;
    } else if (kd2 == 1) {
      got += 1;
    }
    app.tokens += got;
    // Осколки: за чистое прохождение и за мастерство.
    final cleanRun = noHintRun;
    final skillBonus = (kd2 == 2 && left > 0.5) || (level % 10 == 0 && left > 0.6);
    if (cleanRun) app.shards++;
    if (skillBonus) app.shards++;
    if (level % 15 == 0) app.hintStock++;
    app.level = level + 1;
    app.save();
    GameAudio.instance.chord([523, 659, 784, 1047], .3);
    Haptics.instance.success();
    if (app.level == 2) {
      Push.instance.askOnce().then((ok) {
        if (ok) app.reschedulePush();
      });
    } else {
      app.reschedulePush();
    }
    result = LevelResult(true, got, (cleanRun ? 1 : 0) + (skillBonus ? 1 : 0), level,
        crossings, nodes.length, edges.length, spec(app.level).n);
    app.notify();
    notifyListeners();
    onWin?.call();
  }

  void boom() {
    if (!alive) return;
    alive = false;
    _stopTimers();
    GameAudio.instance.noiseBurst();
    GameAudio.instance.tone(90, .55, 'sawtooth', .12);
    GameAudio.instance.tone(48, .8, 'square', .1);
    Haptics.instance.error();
    onFx?.call(const PlayFxEvent(PlayFx.boom));
    result = LevelResult(false, 0, 0, level, crossings, nodes.length, edges.length, 0);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 900), () => onBoom?.call());
  }

  /// Продолжение за ролик: +ходы, уровень оживает.
  void continueAfterAd() {
    moves = math.max(3, (movesMax * 0.4).round());
    alive = true;
    result = null;
    _startTimers();
    notifyListeners();
  }

  void quit() {
    alive = false;
    _stopTimers();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
