import '../game/rivals.dart';
import 'storage.dart';

/// Кэш последнего успешно загруженного НАСТОЯЩЕГО топа (Game Center /
/// Play Игры / сетевая доска).
///
/// При перебоях интернета экран топа показывает кэш мгновенно, а свежие
/// данные подъезжают фоном. Без кэша обрыв сети «выкидывал» игрока на
/// локальных сгенерированных соперников — рейтинг выглядел нестабильным,
/// будто список каждый раз другой.
///
/// Недельный кэш действителен только внутри своей недели; своя строка
/// хранится без имени (подписывается локализованным «Ты» при чтении).
class LbCache {
  static const _key = 'synapse_lb1';

  /// null — кэша нет (или недельный кэш от прошлой недели).
  static (List<RivalRow>, RivalRow?)? load({
    required bool weekly,
    required int week,
    required String youLabel,
  }) {
    final root = Storage.instance.loadAux(_key);
    final m = root?[weekly ? 'week' : 'all'];
    if (m is! Map) return null;
    if (weekly && (m['wk'] as num?)?.toInt() != week) return null;
    final raw = m['rows'];
    if (raw is! List || raw.isEmpty) return null;
    try {
      final rows = <RivalRow>[];
      RivalRow? me;
      for (final e in raw) {
        final l = e as List;
        final isMe = l[3] == true;
        final row = RivalRow((l[2] as num).toInt(),
            isMe ? youLabel : '${l[0]}', (l[1] as num).toInt(), isMe);
        rows.add(row);
        if (isMe) me = row;
      }
      final mr = m['me'];
      if (me == null && mr is List) {
        me = RivalRow(
            (mr[2] as num).toInt(), youLabel, (mr[1] as num).toInt(), true);
      }
      return (rows, me);
    } catch (_) {
      return null;
    }
  }

  static void save({
    required bool weekly,
    required int week,
    required List<RivalRow> rows,
    RivalRow? me,
  }) {
    final root = Storage.instance.loadAux(_key) ?? <String, dynamic>{};
    root[weekly ? 'week' : 'all'] = {
      'wk': week,
      'rows': [
        for (final r in rows.take(100))
          [r.me ? '' : r.name, r.score, r.rank, r.me],
      ],
      // Своя строка платформенного топа живёт отдельно от списка.
      if (me != null && !rows.any((r) => r.me))
        'me': ['', me.score, me.rank, true],
    };
    Storage.instance.saveAux(_key, root);
  }

  static void clear() => Storage.instance.removeAux(_key);
}
