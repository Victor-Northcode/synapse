import 'dart:math' as math;

import 'level.dart' show hash32;

/// Строка локального рейтинга.
class RivalRow {
  final int rank;
  final String name;
  final int score;
  final bool me;
  const RivalRow(this.rank, this.name, this.score, this.me);
}

const _prefixes = [
  'neon', 'wire', 'volt', 'echo', 'flux', 'nova', 'zero', 'lumen',
  'pulse', 'cyber', 'glitch', 'shard', 'nano', 'hex', 'core', 'drift',
];
const _suffixes = [
  'kid', 'fox', 'witch', 'runner', 'wave', 'byte', 'node', 'ghost',
  'link', 'smith', 'ray', 'jack', 'mora', 'ops', 'dex', 'zen',
];

/// Псевдоним игрока для сетевого топа: слово+слово+номер, без личных
/// данных. Генерируется один раз и хранится в сейве.
String makeNick(math.Random rnd) {
  final p = _prefixes[rnd.nextInt(_prefixes.length)];
  final s = _suffixes[rnd.nextInt(_suffixes.length)];
  return '${p}_$s${100 + rnd.nextInt(900)}';
}

/// Детерминированный ник от сида: цензура подменяет грязное имя одним
/// и тем же псевдонимом при каждом показе, а не новым на каждый кадр.
String nickFromSeed(int seed) {
  final p = _prefixes[(hash32(seed * 3 + 1) * _prefixes.length).floor()];
  final s = _suffixes[(hash32(seed * 7 + 5) * _suffixes.length).floor()];
  return '${p}_$s${100 + (hash32(seed * 11 + 9) * 900).floor()}';
}

/// Локальный «общий рейтинг» операторов сети: соперники генерируются
/// детерминированно и масштабируются под прогресс игрока, поэтому топ
/// работает всегда — без сети, аккаунтов и настройки сторов. Игрок
/// вставляется на своё место по реальному счёту; сид меняет состав
/// (для недельного среза — каждый понедельник новый).
List<RivalRow> buildRivals({
  required int myScore,
  required String myName,
  required int seed,
  int count = 24,
}) {
  double r(int i) => hash32(seed * 7919 + i * 613 + 29);

  // Вершина таблицы растёт вместе с игроком: новичку не показывают
  // недостижимые тысячи, ветерану — смешные единицы.
  final top = math.max(30, (myScore * 1.9 + 25 * (0.9 + r(1) * .2)).round());

  final scores = <int>[];
  for (var i = 0; i < count; i++) {
    final k = math.pow(.86, i).toDouble() * (0.92 + r(i * 3 + 5) * .16);
    scores.add(math.max(1, (top * k).round()));
  }
  scores.sort((a, b) => b - a);

  // Имена без повторов: пары префикс+суффикс, иногда с номером.
  final names = <String>{};
  while (names.length < count) {
    final i = names.length;
    final p = _prefixes[(r(i * 11 + 3) * _prefixes.length).floor()];
    final s = _suffixes[(r(i * 13 + 7) * _suffixes.length).floor()];
    final num_ = r(i * 17 + 9) < .3 ? '_${2 + (r(i * 19) * 97).floor()}' : '';
    final sep = r(i * 23 + 1) < .5 ? '_' : '';
    names.add('$p$sep$s$num_');
  }
  final nameList = names.toList();

  // Вставляем игрока по его счёту.
  final rows = <RivalRow>[];
  var placed = false;
  var rank = 1;
  for (var i = 0; i < scores.length; i++) {
    if (!placed && myScore >= scores[i]) {
      rows.add(RivalRow(rank++, myName, myScore, true));
      placed = true;
    }
    rows.add(RivalRow(rank++, nameList[i], scores[i], false));
  }
  if (!placed) rows.add(RivalRow(rank, myName, myScore, true));
  return rows;
}
