import 'package:flutter/widgets.dart';

/// Статические данные игры, перенесённые из www/index.html.
class GameTheme {
  final String nameRu;
  final String nameEn;
  final int cost;
  final Color mag;
  final Color cyan;
  final Color green;
  final Color yellow;
  const GameTheme(this.nameRu, this.nameEn, this.cost, this.mag, this.cyan, this.green, this.yellow);
}

const kThemes = [
  GameTheme('Неон', 'Neon', 0, Color(0xFFFF2ED1), Color(0xFF00E5FF), Color(0xFF00E676), Color(0xFFFFD400)),
  GameTheme('Плазма', 'Plasma', 8, Color(0xFFB06CFF), Color(0xFFFF6BD6), Color(0xFF7CE0FF), Color(0xFFFFB86B)),
  GameTheme('Изумруд', 'Emerald', 12, Color(0xFFFF7A59), Color(0xFF39E0B0), Color(0xFF9BE870), Color(0xFFFFE066)),
  GameTheme('Янтарь', 'Amber', 16, Color(0xFFFF5E5B), Color(0xFFFFC24D), Color(0xFF8FD96B), Color(0xFFFFE9A8)),
];

/// Палитры кабеля: [base, mid, top, highlight].
class CablePal {
  final Color l0, l1, l2, l3;
  const CablePal(this.l0, this.l1, this.l2, this.l3);
}

const kCableOk = CablePal(Color(0xFF04241A), Color(0xFF0E6E42), Color(0xFF1FAE63), Color(0xFF5FD996));
const kCableBad = CablePal(Color(0xFF3A0A2D), Color(0xFFA31878), Color(0xFFDD3AAC), Color(0xFFFF8AD9));
const kCableLive = CablePal(Color(0xFF3A0808), Color(0xFF8E1410), Color(0xFFE03127), Color(0xFFFF8A80));
const kCableHint = CablePal(Color(0xFF3A2C05), Color(0xFF8A6A0A), Color(0xFFE0B400), Color(0xFFFFE680));
const kCableBridge = CablePal(Color(0xFF08303A), Color(0xFF0E5F72), Color(0xFF22A8C4), Color(0xFF8FE9FF));

/// Толщины слоёв кабеля.
abstract final class CableW {
  static const shadow = 14.0, base = 13.5, mid = 11.5, top = 7.0, hi = 3.0;
}

/// Материал кабеля — задаётся темой (патч 9.0): сечение, блик, фактура.
class CableMat {
  final double w; // множитель толщины
  final double hi; // прозрачность блика
  final String? texMode; // core | weave | twist
  final double texWidth;
  final List<double>? texDash;
  final double texOpacity;
  const CableMat(this.w, this.hi,
      {this.texMode, this.texWidth = 0, this.texDash, this.texOpacity = 0});
}

const kCableMats = [
  CableMat(1, .55), // Неон — глянцевый пластик
  CableMat(1.20, 0, texMode: 'core', texWidth: .30, texOpacity: 1), // Плазма — жила в шланге
  CableMat(.94, .12, texMode: 'weave', texWidth: .9, texDash: [2.5, 5.5], texOpacity: .34), // Изумруд — оплётка
  CableMat(1.08, .85, texMode: 'twist', texWidth: .66, texDash: [6, 10], texOpacity: .5), // Янтарь — витой шнур
];

/// Бустеры: ключ, иконка, цена в осколках.
class Booster {
  final String key;
  final String icon;
  final int cost;
  const Booster(this.key, this.icon, this.cost);
}

const kBoosters = [
  Booster('cut', 'cut', 4),
  Booster('stab', 'timer', 3),
  Booster('auto', 'target', 6),
];

/// Уровень первого появления каждой механики: level → тип препятствия.
const kIntroLevels = {4: 1, 9: 2, 15: 3, 20: 6, 26: 7, 32: 8, 38: 4, 44: 9, 50: 5};

/// Кадры сюжетных сцен: точки (в % поля), рёбра и «плохие» рёбра ШУМА.
const kScenePts = [
  [50.0, 50.0], [26.0, 30.0], [74.0, 28.0], [18.0, 62.0], [82.0, 60.0],
  [38.0, 15.0], [62.0, 85.0], [11.0, 41.0], [89.0, 43.0], [44.0, 73.0],
  [58.0, 33.0], [30.0, 86.0], [70.0, 13.0], [50.0, 92.0],
];
const kSceneEdges = [
  [0, 1], [0, 2], [0, 3], [0, 4], [1, 5], [2, 12], [3, 7],
  [4, 8], [0, 9], [9, 11], [9, 6], [6, 13], [1, 10], [10, 2],
];
const kSceneBadEdges = [
  [5, 12], [7, 8],
];

/// Дневные цели: победы, победы без подсказок, задачи.
const kGoals = [10, 3, 2];
