import 'dart:math' as math;

import 'geometry.dart';

/// Радиус узла (px поля) — константа R исходника.
const double kNodeR = 19;

/// Детерминированный хэш → [0,1) — порт hash32()/rnd32().
double hash32(int n) {
  n &= 0xFFFFFFFF;
  n = ((n ^ (n >> 15)) * 0x2c1b3c6d) & 0xFFFFFFFF;
  n = ((n ^ (n >> 12)) * 0x297a2d39) & 0xFFFFFFFF;
  n = n ^ (n >> 15);
  return n / 4294967296;
}

class LevelSpec {
  final int n;
  final double dens;
  const LevelSpec(this.n, this.dens);
}

LevelSpec spec(int level) {
  var base = math.min(16, 4 + (level * 0.55).floor());
  // На передышке уменьшаем и число узлов, а не только запутанность.
  if (lvlKind(level) == -1) base = math.max(4, base - 3);
  return LevelSpec(base, math.min(2.0, 1.12 + level * 0.032));
}

/// -1 передышка · 0 обычный · 1 сложный · 2 очень сложный (≈ раз в 10).
int lvlKind(int level) {
  if (level <= 4) return 0;
  final band = level ~/ 10;
  final superAt = band * 10 + 5 + (hash32(band * 7717 + 13) * 4).floor();
  if (level == superAt) return 2;
  final h = hash32(level * 13 + 7);
  if (h < 0.24) return 1;
  if (h > 0.88) return -1;
  return 0;
}

const _kMul = {-1: 0.78, 0: 1.0, 1: 1.28, 2: 1.55};

int targetCross(int level, int edgeCount) {
  var base = math.max(
    2 + (level * 0.7).floor(),
    (edgeCount * (0.5 + math.min(0.55, level * 0.02))).round(),
  );
  base = math.min(base, (edgeCount * 1.15).round());
  return math.max(1, (base * _kMul[lvlKind(level)]!).round());
}

/// Зона протечки.
class Zone {
  double x, y, w, h;
  Zone(this.x, this.y, this.w, this.h);
  bool contains(Pt p) => p[0] > x && p[0] < x + w && p[1] > y && p[1] < y + h;
}

/// Сгенерированный уровень — всё состояние поля до первого хода.
class Level {
  final List<Pt> nodes;
  final List<List<int>> edges;
  final List<Pt> sockets;
  final List<int> slotOf;
  final List<int> ntype;
  final int liveEdge;
  final int ghostEdge;
  final Map<int, int> twin;
  final List<Zone> zones;
  final int pickIdx;
  final int bombIdx;
  final int bombLeft;
  final int maxBridges;
  final int movesMax;
  final int introObstacle;

  Level({
    required this.nodes,
    required this.edges,
    required this.sockets,
    required this.slotOf,
    required this.ntype,
    required this.liveEdge,
    required this.ghostEdge,
    required this.twin,
    required this.zones,
    required this.pickIdx,
    required this.bombIdx,
    required this.bombLeft,
    required this.maxBridges,
    required this.movesMax,
    required this.introObstacle,
  });
}

/// Генератор уровня — построчный порт gen(L) из index.html.
///
/// [w]/[h] — размер поля, [chapter] и [curDay] задают темп появления
/// протечек, бомб и мостов, как в исходнике.
Level generateLevel(int level, double w, double h, {required int chapter, required int curDay}) {
  final rnd = math.Random();
  double r() => rnd.nextDouble();

  final sp = spec(level);
  final pad = kNodeR + 14;

  // Раскладка-решение: узлы без пересечений.
  final sol = <Pt>[];
  var tries = 0;
  while (sol.length < sp.n && tries < 3000) {
    tries++;
    final p = [pad + r() * (w - 2 * pad), pad + r() * (h - 2 * pad)];
    var ok = true;
    for (final q in sol) {
      if (dist(p, q) < kNodeR * 2.6) {
        ok = false;
        break;
      }
    }
    if (ok) sol.add(p);
  }
  final n = sol.length;

  // Рёбра: ближайшие пары без пересечений в раскладке-решении.
  final cand = <(int, int, double)>[];
  for (var a = 0; a < n; a++) {
    for (var b = a + 1; b < n; b++) {
      cand.add((a, b, dist(sol[a], sol[b])));
    }
  }
  cand.sort((x, y) => x.$3.compareTo(y.$3));
  final edges = <List<int>>[];
  final deg = List.filled(n, 0);
  final target = (n * sp.dens).round();
  for (var c = 0; c < cand.length && edges.length < target; c++) {
    final e = [cand[c].$1, cand[c].$2];
    var bad = false;
    for (final k in edges) {
      if (shares(e, k)) continue;
      if (segX(sol[e[0]], sol[e[1]], sol[k[0]], sol[k[1]])) {
        bad = true;
        break;
      }
    }
    if (bad || deg[e[0]] > 4 || deg[e[1]] > 4) continue;
    edges.add(e);
    deg[e[0]]++;
    deg[e[1]]++;
  }

  // Изолированный узел подключаем к ближайшему соседу — ребро обязано
  // не пересекать уже построенные, иначе уровень может стать непроходимым.
  for (var s = 0; s < n; s++) {
    if (deg[s] > 0) continue;
    final order = <(int, double)>[];
    for (var q = 0; q < n; q++) {
      if (q != s) order.add((q, dist(sol[s], sol[q])));
    }
    order.sort((x, y) => x.$2.compareTo(y.$2));
    var picked = -1;
    for (final o in order) {
      final candE = [s, o.$1];
      var clash = false;
      for (final k in edges) {
        if (shares(candE, k)) continue;
        if (segX(sol[candE[0]], sol[candE[1]], sol[k[0]], sol[k[1]])) {
          clash = true;
          break;
        }
      }
      if (!clash) {
        picked = o.$1;
        break;
      }
    }
    if (picked < 0) continue; // чистого ребра нет — узел остаётся сам по себе
    edges.add([s, picked]);
    deg[s]++;
    deg[picked]++;
  }

  // Страховка: раскладка-решение обязана быть решением.
  for (var gi = edges.length - 1; gi >= 0; gi--) {
    var crosses = false;
    for (var gj = 0; gj < edges.length; gj++) {
      if (gj == gi || shares(edges[gi], edges[gj])) continue;
      if (segX(sol[edges[gi][0]], sol[edges[gi][1]], sol[edges[gj][0]], sol[edges[gj][1]])) {
        crosses = true;
        break;
      }
    }
    if (crosses) edges.removeAt(gi);
  }

  // Подбираем стартовую раскладку под целевую запутанность.
  final tgt = targetCross(level, edges.length);
  List<Pt>? best;
  var bestD = 1e9;
  for (var t = 0; t < 140; t++) {
    final pos = <Pt>[];
    for (var m = 0; m < n; m++) {
      pos.add([pad + r() * (w - 2 * pad), pad + r() * (h - 2 * pad)]);
    }
    final c = countCross(pos, edges);
    final dd = (c - tgt).abs().toDouble();
    if (c < 1) continue;
    if (dd < bestD) {
      bestD = dd;
      best = pos;
      if (dd == 0) break;
    }
  }
  best ??= [for (var m = 0; m < n; m++) [pad + r() * (w - 2 * pad), pad + r() * (h - 2 * pad)]];

  // Головоломка не должна открываться уже решённой.
  var gg = 0;
  final minStart = math.max(1, math.min(3, (tgt * 0.5).round()));
  while (countCross(best, edges) < minStart && gg++ < 300) {
    final a1 = rnd.nextInt(best.length), b1 = rnd.nextInt(best.length);
    if (a1 == b1) continue;
    final tp = best[a1];
    best[a1] = best[b1];
    best[b1] = tp;
  }

  final nodes = best;
  final sockets = [for (final q in sol) [q[0], q[1]]];
  final freeN = 3 + level ~/ 12;
  for (var f = 0; f < freeN; f++) {
    var g = 0;
    Pt c;
    do {
      c = [pad + r() * (w - 2 * pad), pad + r() * (h - 2 * pad)];
      g++;
    } while (g < 60 && sockets.any((q) => dist(q, c) < kNodeR * 2.6));
    sockets.add(c);
  }

  // Привязка узлов к ближайшим гнёздам.
  final slotOf = List.filled(nodes.length, -1);
  final used = <int>{};
  for (var i = 0; i < nodes.length; i++) {
    var bi = -1;
    var bd = 1e9;
    for (var k = 0; k < sockets.length; k++) {
      if (used.contains(k)) continue;
      final dd = dist(nodes[i], sockets[k]);
      if (dd < bd) {
        bd = dd;
        bi = k;
      }
    }
    used.add(bi);
    slotOf[i] = bi;
    nodes[i] = [sockets[bi][0], sockets[bi][1]];
  }

  // Протечки, бонус и бомба — по темпу главы.
  final zones = <Zone>[];
  var bombIdx = -1, bombLeft = 0, pickIdx = -1;
  final maxBr = (chapter >= 3) ? (2 + (chapter - 3) ~/ 3) : 0;
  final ch = curDay + math.min(3, chapter ~/ 2);
  if (ch >= 1 && level > 2 && r() < 0.55) {
    var cx = 0.0, cy = 0.0;
    for (final nn in nodes) {
      cx += nn[0];
      cy += nn[1];
    }
    cx /= nodes.length;
    cy /= nodes.length;
    var bestF = -1;
    var bestDist = -1.0;
    for (var q1 = 0; q1 < sockets.length; q1++) {
      if (slotOf.contains(q1)) continue;
      final dq = dist(sockets[q1], [cx, cy]);
      if (dq > bestDist) {
        bestDist = dq;
        bestF = q1;
      }
    }
    if (bestF >= 0 && bestDist > kNodeR * 3.2) pickIdx = bestF;
  }
  if (ch >= 2 && level > 3) {
    for (var z = 0; z < 1 + (ch >= 3 ? 1 : 0); z++) {
      zones.add(Zone(
        pad + r() * (w - 2 * pad - 90),
        pad + r() * (h - 2 * pad - 90),
        70 + r() * 50,
        60 + r() * 50,
      ));
    }
  }
  if (ch >= 3 && level > 4) {
    bombIdx = rnd.nextInt(nodes.length);
    bombLeft = math.max(4, (nodes.length * 0.9).round());
  }

  // После привязки к гнёздам ещё раз гарантируем запутанность.
  var g3 = 0;
  while (countCross(nodes, edges) < minStart && g3++ < 400) {
    final x1 = rnd.nextInt(nodes.length), x2 = rnd.nextInt(nodes.length);
    if (x1 == x2) continue;
    final ts = slotOf[x1];
    slotOf[x1] = slotOf[x2];
    slotOf[x2] = ts;
    final tn = nodes[x1];
    nodes[x1] = nodes[x2];
    nodes[x2] = tn;
  }

  final movesMax =
      math.max(4, (nodes.length * 1.1 + countCross(nodes, edges) * 0.78).round());

  // Препятствия появляются постепенно и не на каждом уровне.
  final ntype = List.filled(nodes.length, 0);
  var liveEdge = -1, ghostE = -1;
  final twin = <int, int>{};
  final kd = lvlKind(level);
  var pool = <int>[];
  final forced = const {4: 1, 9: 2, 15: 3, 20: 6, 26: 7, 32: 8, 38: 4, 44: 9, 50: 5}[level];
  if (forced != null) {
    pool = [forced];
  } else {
    if (level > 4 && r() < 0.5) pool.add(1);
    if (level > 9 && r() < 0.45) pool.add(2);
    if (level > 15 && r() < 0.4) pool.add(3);
    if (level > 20 && r() < 0.4) pool.add(6);
    if (level > 26 && r() < 0.4) pool.add(7);
    if (level > 32 && r() < 0.35) pool.add(8);
    if (level > 38 && r() < 0.35) pool.add(4);
    if (level > 44 && r() < 0.35) pool.add(9);
    if (level > 50 && r() < 0.35) pool.add(5);
    pool.shuffle(rnd);
    if (kd == 2 && pool.isEmpty && level > 4) {
      pool.add(1 + rnd.nextInt(math.min(3, 1 + level ~/ 9)));
    }
    if (kd == -1) pool = [];
    pool = pool.take(kd == 2 ? 2 : 2).toList();
  }
  for (final t in pool) {
    if (t == 5) {
      if (edges.isNotEmpty) liveEdge = rnd.nextInt(edges.length);
      continue;
    }
    if (t == 9) {
      if (edges.isNotEmpty) ghostE = rnd.nextInt(edges.length);
      continue;
    }
    if (t == 8) {
      final a1 = rnd.nextInt(nodes.length);
      var b1 = -1;
      for (final e in edges) {
        if (b1 < 0) {
          if (e[0] == a1) {
            b1 = e[1];
          } else if (e[1] == a1) {
            b1 = e[0];
          }
        }
      }
      if (b1 >= 0) {
        twin[a1] = b1;
        twin[b1] = a1;
        ntype[a1] = 8;
        ntype[b1] = 8;
      }
      continue;
    }
    final cnt = (t == 3)
        ? 1
        : (forced != null ? 1 : 1 + rnd.nextInt(math.min(2, 1 + level ~/ 14)));
    for (var i = 0; i < cnt; i++) {
      var idx = rnd.nextInt(nodes.length);
      var g = 0;
      while (ntype[idx] != 0 && g++ < 20) {
        idx = rnd.nextInt(nodes.length);
      }
      if (ntype[idx] == 0) ntype[idx] = t;
    }
  }

  return Level(
    nodes: nodes,
    edges: edges,
    sockets: sockets,
    slotOf: slotOf,
    ntype: ntype,
    liveEdge: liveEdge,
    ghostEdge: ghostE,
    twin: twin,
    zones: zones,
    pickIdx: pickIdx,
    bombIdx: bombIdx,
    bombLeft: bombLeft,
    maxBridges: maxBr,
    movesMax: movesMax,
    introObstacle: forced ?? 0,
  );
}
