import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse/core/lb_cache.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/game/rivals.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
  });

  test('кэш топа: сохранить и прочитать без потерь', () {
    final rows = [
      const RivalRow(1, 'neon_fox', 120, false),
      const RivalRow(2, 'Ты', 90, true),
      const RivalRow(3, 'wire_ghost', 70, false),
    ];
    LbCache.save(weekly: false, week: 0, rows: rows, me: rows[1]);
    final got = LbCache.load(weekly: false, week: 0, youLabel: 'Ты');
    expect(got, isNotNull);
    expect(got!.$1.length, 3);
    expect(got.$1[0].name, 'neon_fox');
    expect(got.$1[0].score, 120);
    expect(got.$1[1].me, true);
    expect(got.$1[1].name, 'Ты'); // своё имя подписывается заново
    expect(got.$2!.score, 90);
  });

  test('недельный кэш другой недели не действует', () {
    LbCache.save(weekly: true, week: 100, rows: const [
      RivalRow(1, 'a', 5, false),
    ]);
    expect(LbCache.load(weekly: true, week: 101, youLabel: 'You'), isNull);
    expect(LbCache.load(weekly: true, week: 100, youLabel: 'You'), isNotNull);
  });

  test('вкладки кэшируются независимо', () {
    LbCache.save(weekly: true, week: 5, rows: const [
      RivalRow(1, 'week_player', 3, false),
    ]);
    LbCache.save(weekly: false, week: 5, rows: const [
      RivalRow(1, 'all_player', 300, false),
    ]);
    expect(LbCache.load(weekly: true, week: 5, youLabel: 'x')!.$1[0].name,
        'week_player');
    expect(LbCache.load(weekly: false, week: 5, youLabel: 'x')!.$1[0].name,
        'all_player');
  });

  test('своя строка платформенного топа переживает кэш отдельно', () {
    LbCache.save(
      weekly: false,
      week: 0,
      rows: const [RivalRow(1, 'leader', 999, false)],
      me: const RivalRow(42, 'Ты', 17, true),
    );
    final got = LbCache.load(weekly: false, week: 0, youLabel: 'Du');
    expect(got!.$2, isNotNull);
    expect(got.$2!.rank, 42);
    expect(got.$2!.score, 17);
    expect(got.$2!.name, 'Du');
  });

  test('clear стирает кэш', () {
    LbCache.save(weekly: false, week: 0, rows: const [
      RivalRow(1, 'a', 5, false),
    ]);
    LbCache.clear();
    expect(LbCache.load(weekly: false, week: 0, youLabel: 'x'), isNull);
  });
}
