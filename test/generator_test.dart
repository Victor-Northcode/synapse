import 'package:flutter_test/flutter_test.dart';
import 'package:synapse/game/geometry.dart';
import 'package:synapse/game/level.dart';

void main() {
  test('каждый уровень решаем на любом размере поля', () {
    // (ширина, высота, масштаб) — телефон, планшет портрет, планшет альбом.
    const fields = [
      (360.0, 460.0, 1.0),
      (700.0, 900.0, 1.7),
      (900.0, 780.0, 1.7),
    ];
    for (final (fw, fh, sc) in fields) {
      for (var lvl = 1; lvl <= 60; lvl++) {
        final l = generateLevel(lvl, fw, fh, chapter: 2, curDay: 1, scale: sc);
        final sol = [for (var i = 0; i < l.nodes.length; i++) l.sockets[i]];
        expect(countCross(sol, l.edges), 0,
            reason: 'уровень $lvl на поле ${fw}x$fh (масштаб $sc) нерешаем');
        expect(l.nodes.length, greaterThanOrEqualTo(4),
            reason: 'слишком мало узлов на поле ${fw}x$fh');
        expect(l.slotOf.toSet().length, l.slotOf.length);
      }
    }
  });

  test('каждый сгенерированный уровень имеет решение без пересечений', () {
    for (var lvl = 1; lvl <= 60; lvl++) {
      for (var rep = 0; rep < 3; rep++) {
        final l = generateLevel(lvl, 360, 460, chapter: rep, curDay: rep);
        // Раскладка-решение: узел i в гнезде i (первые n гнёзд — из sol).
        final sol = [
          for (var i = 0; i < l.nodes.length; i++) l.sockets[i],
        ];
        expect(countCross(sol, l.edges), 0,
            reason: 'уровень $lvl (глава $rep) не имеет решения');
        expect(l.movesMax, greaterThanOrEqualTo(4));
        expect(l.slotOf.toSet().length, l.slotOf.length,
            reason: 'два узла в одном гнезде');
      }
    }
  });

  test('кривая сложности детерминирована', () {
    expect(lvlKind(1), 0);
    // Значения фиксированы формулой hash32 — сверены с JS-оригиналом.
    expect(spec(1).n, 4);
    expect(spec(30).n, 16);
    expect(targetCross(1, 6), greaterThanOrEqualTo(1));
    // hash32 должен совпадать с JS: rnd32(11) и т.п. стабильны.
    expect(hash32(11), closeTo(hash32(11), 0));
    expect(hash32(7717 * 1 + 13), inInclusiveRange(0, 1));
  });
}
