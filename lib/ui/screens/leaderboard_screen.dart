import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';

import '../../core/leaderboard.dart';
import '../../core/net_board.dart';
import '../../core/palette.dart';
import '../../game/rivals.dart';
import '../../state/app_state.dart';
import '../layout.dart';
import '../widgets/common.dart';

/// Топ игроков.
///
/// Сверху — уровень оператора и личные рекорды (локальные, работают
/// всегда). Ниже — рейтинг: если настроен и доступен онлайн (Game
/// Center / Play Игры) — берём его; в любом другом случае показывается
/// локальный рейтинг операторов сети, который генерируется на
/// устройстве и масштабируется под прогресс игрока. Ошибок «не удалось
/// загрузить» больше не существует: таблица есть ВСЕГДА.
class LeaderboardScreen extends StatefulWidget {
  final AppState app;
  final VoidCallback onClose;

  /// true — экран живёт во вкладке нижнего меню (без кнопки «назад»).
  final bool embedded;

  /// Данные для превью в тестах/скриншотах: список и своя строка.
  final (List<LeaderboardScoreData>, LeaderboardScoreData?)? previewData;

  const LeaderboardScreen(
      {super.key,
      required this.app,
      required this.onClose,
      this.embedded = false,
      this.previewData});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool weekly = true;
  bool loading = true;
  List<RivalRow> rows = [];
  RivalRow? me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  RivalRow _fromScore(LeaderboardScoreData r, {bool mine = false}) => RivalRow(
      r.rank, mine ? widget.app.lt('lbYou') : r.scoreHolder.displayName,
      r.rawScore, mine);

  Future<void> _load() async {
    final app = widget.app;
    final preview = widget.previewData;
    if (preview != null) {
      setState(() {
        rows = [for (final r in preview.$1) _fromScore(r)];
        me = preview.$2 == null ? null : _fromScore(preview.$2!, mine: true);
        loading = false;
      });
      return;
    }
    setState(() => loading = true);

    // 1. Платформенные таблицы (Game Center / Play Игры) — если
    //    настроены и реально отвечают.
    if (Lb.instance.available) {
      try {
        if (await Lb.instance.ensureSignedIn()) {
          final list = await Lb.instance.top(weekly: weekly);
          final my = await Lb.instance.myScore(weekly: weekly);
          if (mounted && list != null && list.isNotEmpty) {
            setState(() {
              rows = [for (final r in list) _fromScore(r)];
              me = my == null ? null : _fromScore(my, mine: true);
              loading = false;
            });
            return;
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;

    // 2. Сетевой топ (dreamlo): настоящие игроки со всех устройств.
    //    Свой счёт досылается в фоне; если сервер его ещё не записал,
    //    строка игрока подмешивается локально — ждать не нужно.
    if (NetBoard.instance.available) {
      final myScore = weekly ? app.wgp[0] : app.totalWins;
      NetBoard.instance
          .submit(
              nick: app.nick,
              allTime: app.totalWins,
              weeklyScore: app.wgp[0],
              week: app.weekKey)
          .ignore();
      final net =
          await NetBoard.instance.top(weekly: weekly, week: app.weekKey);
      if (!mounted) return;
      if (net != null) {
        final entries = [...net];
        if (myScore > 0 && !entries.any((e) => e.$1 == app.nick)) {
          entries.add((app.nick, myScore));
          entries.sort((a, b) => b.$2 - a.$2);
        }
        if (entries.isNotEmpty) {
          final rows2 = <RivalRow>[];
          RivalRow? mine;
          for (var i = 0; i < entries.length; i++) {
            final isMe = entries[i].$1 == app.nick;
            final row = RivalRow(i + 1,
                isMe ? app.lt('lbYou') : entries[i].$1, entries[i].$2, isMe);
            rows2.add(row);
            if (isMe) mine = row;
          }
          setState(() {
            rows = rows2;
            me = mine;
            loading = false;
          });
          return;
        }
      }
    }

    // 3. Локальный рейтинг: детерминированный, без сети, всегда есть.
    final localRows = buildRivals(
      myScore: weekly ? app.wgp[0] : app.totalWins,
      myName: app.lt('lbYou'),
      seed: weekly ? 1000 + app.weekKey : 424242,
      count: weekly ? 18 : 24,
    );
    setState(() {
      rows = localRows;
      me = localRows.firstWhere((r) => r.me);
      loading = false;
    });
  }

  void _switch(bool w) {
    if (weekly == w) return;
    setState(() => weekly = w);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    // Один общий скролл: рекорды, вкладки и рейтинг едут вместе —
    // на коротких экранах (телефон в альбоме) ничего не переполняется.
    return Container(
      decoration:
          widget.embedded ? null : const BoxDecoration(gradient: Pal.fieldGradient),
      child: SafeArea(
        top: !widget.embedded,
        bottom: !widget.embedded,
        child: ContentColumn(
          child: Column(children: [
            _header(app),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  StaggerIn(index: 1, child: _recordsPanel(app)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(children: [
                      Expanded(child: _tab(app.lt('lbWeek'), true)),
                      const SizedBox(width: 8),
                      Expanded(child: _tab(app.lt('lbAll'), false)),
                    ]),
                  ),
                  ..._body(app),
                ],
              ),
            ),
            if (!loading && me != null) _meRow(app),
          ]),
        ),
      ),
    );
  }

  Widget _header(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(children: [
        if (!widget.embedded)
          Pressable(
            onTap: widget.onClose,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Pal.panel,
                border: Border.all(color: Pal.line),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Glyph(GlyphKind.chevronLeft, size: 20, color: Pal.text),
            ),
          )
        else
          const SizedBox(width: 36),
        Expanded(
          child: Column(children: [
            const GameIcon('trophy', size: 22, color: Pal.yellow),
            const SizedBox(height: 4),
            Text(app.lt('lbTitle'),
                style: const TextStyle(
                    fontFamily: Fonts.disp,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 2.2,
                    color: Pal.text)),
          ]),
        ),
        if (Lb.instance.available)
          Pressable(
            onTap: () => Lb.instance.openNative(weekly: weekly),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Pal.panel,
                border: Border.all(color: Pal.line),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const GameIcon('screen', size: 16, color: Pal.dim),
            ),
          )
        else
          const SizedBox(width: 36),
      ]),
    );
  }

  /// Уровень оператора + личные рекорды: работают всегда, без сети.
  Widget _recordsPanel(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GamePanel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            // Значок уровня оператора.
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF26314F), Color(0xFF0B1020)],
                ),
                border: Border.all(color: const Color(0x8000E5FF), width: 1.4),
                boxShadow: const [BoxShadow(color: Color(0x2E00E5FF), blurRadius: 14)],
              ),
              child: Text('${app.operatorLevel}',
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Pal.cyan)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.lt('opLvl').replaceAll('{n}', '${app.operatorLevel}'),
                    style: const TextStyle(
                        fontFamily: Fonts.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Pal.text)),
                const SizedBox(height: 3),
                Text(
                  app
                      .lt('opNext')
                      .replaceAll('{n}', '${app.winsToNextLevel}')
                      .replaceAll('{l}', '${app.operatorLevel + 1}'),
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 9, color: Pal.dim),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 4,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: app.operatorProgress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        backgroundColor: Pal.bg,
                        valueColor: const AlwaysStoppedAnimation(Pal.cyan),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          SectionTitle(app.lt('lbLocal')),
          const SizedBox(height: 9),
          Row(children: [
            _stat(app.lt('lbBest'), '${app.bestLevel}', Pal.yellow),
            const SizedBox(width: 7),
            _stat(app.lt('lbStreak'), '${app.bestStreak}', Pal.mag),
            const SizedBox(width: 7),
            _stat(app.lt('lbTotal'), '${app.totalWins}', Pal.green),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: Pal.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pal.line),
        ),
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: double.tryParse(value) ?? 0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text('${v.round()}',
                style: TextStyle(
                    fontFamily: Fonts.disp,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: color)),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1,
                style: const TextStyle(
                    fontFamily: Fonts.mono, fontSize: 8, letterSpacing: .4, color: Pal.dim)),
          ),
        ]),
      ),
    );
  }

  Widget _tab(String label, bool w) {
    final on = weekly == w;
    return Pressable(
      onTap: () => _switch(w),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? const Color(0x2400E5FF) : Colors.transparent,
          border: Border.all(color: on ? const Color(0x8000E5FF) : Pal.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: Fonts.mono,
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                color: on ? Pal.cyan : Pal.dim)),
      ),
    );
  }

  /// Список рейтинга — элементы общего скролла.
  List<Widget> _body(AppState app) {
    if (loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Pal.cyan),
            ),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('$weekly-$i'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 240 + (i.clamp(0, 14)) * 40),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
            ),
            child: _row(rows[i]),
          ),
        ),
    ];
  }

  static const _medal = [Color(0xFFFFD400), Color(0xFFC9D3E0), Color(0xFFD8935B)];

  Widget _row(RivalRow r) {
    final top3 = r.rank >= 1 && r.rank <= 3;
    final medal = top3 ? _medal[r.rank - 1] : null;
    final mine = r.me;
    final name = r.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? const Color(0x1A00E5FF) : Pal.panel.withValues(alpha: .55),
        border: Border.all(
            color: mine
                ? const Color(0x8000E5FF)
                : (medal?.withValues(alpha: .45) ?? Pal.line)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: medal != null
            ? [BoxShadow(color: medal.withValues(alpha: .16), blurRadius: 16)]
            : null,
      ),
      child: Row(children: [
        // Ранг: медаль для топ-3, номер для остальных.
        SizedBox(
          width: 34,
          child: Text('${r.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w900,
                  fontSize: top3 ? 16 : 12,
                  color: medal ?? Pal.dim)),
        ),
        const SizedBox(width: 8),
        // Аватар-инициал в стиле узла.
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF26314F), Color(0xFF0B1020)],
            ),
            border: Border.all(color: medal ?? const Color(0x4D00E5FF), width: 1.4),
          ),
          child: Text(
            name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: TextStyle(
                fontFamily: Fonts.disp,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: medal ?? Pal.cyan),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 12.5,
                  fontWeight: mine || top3 ? FontWeight.w700 : FontWeight.w400,
                  color: mine ? Pal.cyan : Pal.text)),
        ),
        const SizedBox(width: 10),
        // «Verbindungen» на узком экране длиннее самой строки — счёт
        // ужимается, но никогда не режется.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${r.score}',
                    style: TextStyle(
                        fontFamily: Fonts.disp,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: medal ?? Pal.cyan)),
                TextSpan(
                    text: ' ${widget.app.lt('lbScore')}',
                    style: const TextStyle(
                        fontFamily: Fonts.mono, fontSize: 8.5, color: Pal.faint)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  /// Своя строка — закреплена под списком.
  Widget _meRow(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: _row(me!),
    );
  }
}
