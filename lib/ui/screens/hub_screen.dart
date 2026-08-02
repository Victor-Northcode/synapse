import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../data/game_data.dart';
import '../../game/level.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Хаб: карточка модели, вкладки «стойка»/«склад».
class HubScreen extends StatefulWidget {
  final VoidCallback onPlay;
  const HubScreen({super.key, required this.onPlay});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HubCard(app: app),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _tabButton(app.t('tab0'), 0)),
          const SizedBox(width: 10),
          Expanded(child: _tabButton(app.t('tab2'), 1)),
        ]),
        const SizedBox(height: 14),
        if (tab == 0) ..._pane0(app) else ..._pane1(app),
      ],
    );
  }

  Widget _tabButton(String label, int i) {
    final on = tab == i;
    return Pressable(
      onTap: () => setState(() => tab = i),
      child: Container(
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Pal.mag : const Color(0x1200E5FF),
          border: Border.all(color: on ? Colors.transparent : const Color(0x5200E5FF)),
          borderRadius: BorderRadius.circular(999),
          boxShadow: on
              ? const [BoxShadow(color: Color(0x6BFF2ED1), blurRadius: 46)]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: Fonts.disp,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 2.2,
            color: on ? const Color(0xFF1A0512) : Pal.cyan,
          ),
        ),
      ),
    );
  }

  // ---------- вкладка «стойка» ----------
  List<Widget> _pane0(AppState app) {
    final pk = lvlKind(app.level);
    final btnColor = pk == 2 ? Pal.superRed : (pk == 1 ? Pal.hardTeal : Pal.mag);
    final btnText = pk == 2
        ? const Color(0xFF2A0D0A)
        : (pk == 1 ? const Color(0xFF0C2320) : const Color(0xFF1A0512));
    return [
      PillButton(
        onTap: widget.onPlay,
        color: btnColor,
        textColor: btnText,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(app.t('play').replaceAll('{n}', '${app.level}'),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (pk != 0)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                pk == 2 ? app.t('kSuper') : (pk == 1 ? app.t('kHard') : app.t('kEasy')),
                style: TextStyle(
                    fontFamily: Fonts.mono,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: btnText.withValues(alpha: .65)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 11),
      IconText(app.nextGoalLine(),
          style: const TextStyle(
              fontFamily: Fonts.mono, fontSize: 11.5, height: 1.45, color: Pal.yellow)),
      const SizedBox(height: 18),
      GamePanel(
        child: Column(children: [
          Text(
            app.curDay < app.days
                ? '${app.t('dc')} · ${app.t('day').replaceAll('{n}', '${app.curDay + 1}')} — ${app.dayNames[app.curDay]}'
                : app.t('dc'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: Fonts.disp,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: .6,
                color: Pal.text),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < app.tasks.length; i++)
            if (app.tasks[i].day == app.curDay) _TaskRow(app: app, index: i),
          const SizedBox(height: 11),
          Text(app.t('dcHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: Fonts.mono, fontSize: 10, height: 1.4, color: Pal.dim)),
        ]),
      ),
    ];
  }

  // ---------- вкладка «склад» ----------
  List<Widget> _pane1(AppState app) {
    return [
      GamePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(app.t('shopT').replaceAll('{n}', '${app.shards}')),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var bi = 0; bi < kBoosters.length; bi++) ...[
              if (bi > 0) const SizedBox(width: 7),
              Expanded(child: _shopBooster(app, bi)),
            ],
            const SizedBox(width: 7),
            Expanded(child: _shopHint(app)),
          ]),
          const SizedBox(height: 14),
          SectionTitle(app.t('themesT')),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            childAspectRatio: 1.9,
            children: [for (var ti = 0; ti < kThemes.length; ti++) _themeCard(app, ti)],
          ),
          if (app.adShards < 3) ...[
            const SizedBox(height: 12),
            Pressable(
              onTap: app.watchAdForShards,
              child: Container(
                constraints: const BoxConstraints(minHeight: 62),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0x17FFD400),
                  border: Border.all(color: const Color(0x61FFD400)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: IconText(
                  app.t('adShard').replaceAll('{n}', '${3 - app.adShards}'),
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontSize: 12,
                      letterSpacing: 1.8,
                      color: Pal.yellow),
                ),
              ),
            ),
          ],
        ]),
      ),
    ];
  }

  Widget _shopCard({
    required bool can,
    required VoidCallback onTap,
    required String count,
    required Widget icon,
    required String name,
    required String desc,
    required String price,
  }) {
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: can ? 1 : .5,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
          decoration: BoxDecoration(
            color: const Color(0x0D78A0FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(children: [
            Positioned(
              right: 2,
              top: -4,
              child: Text(count,
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: Pal.cyan)),
            ),
            Column(children: [
              icon,
              const SizedBox(height: 8),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 10, color: Pal.text)),
              const SizedBox(height: 3),
              SizedBox(
                height: 26,
                child: Text(desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: Fonts.mono, fontSize: 8, height: 1.3, color: Pal.faint)),
              ),
              const SizedBox(height: 6),
              IconText(price,
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Pal.cyan)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _shopBooster(AppState app, int bi) {
    final b = kBoosters[bi];
    return _shopCard(
      can: app.shards >= b.cost,
      onTap: () => app.buyBooster(bi),
      count: '${app.inv[b.key]}',
      icon: GameIcon(b.icon, size: 19, color: Pal.text),
      name: app.tl('bn')[bi],
      desc: app.tl('bd')[bi],
      price: '${b.cost}✦',
    );
  }

  Widget _shopHint(AppState app) {
    return _shopCard(
      can: app.shards >= app.hintPrice(),
      onTap: app.buyHint,
      count: '${app.hintStock}',
      icon: const GameIcon('bulb', size: 19, color: Pal.text),
      name: app.t('hintBuy'),
      desc: app.t('hintBuyD'),
      price: '${app.hintPrice()}✦',
    );
  }

  Widget _themeCard(AppState app, int ti) {
    final th = kThemes[ti];
    final own = app.owned[ti] == 1;
    final cur = app.theme == ti;
    return Pressable(
      onTap: () => app.selectTheme(ti),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0x0D78A0FF),
          borderRadius: BorderRadius.circular(18),
          border: cur ? Border.all(color: const Color(0x8000E676)) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Превью тянется по высоте ячейки — фикс-высота ломала узкие экраны.
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [th.mag, th.cyan, th.green],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
              child: Text(app.lang == 'ru' ? th.nameRu : th.nameEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 10.5, color: Pal.text)),
            ),
            if (own && cur)
              const Glyph(GlyphKind.check, size: 15, color: Pal.green)
            else
              IconText(
                own ? app.t('thUse') : '${th.cost}✦',
                style: TextStyle(
                  fontFamily: Fonts.disp,
                  fontSize: own ? 9 : 11,
                  fontWeight: FontWeight.w700,
                  color: Pal.cyan,
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final AppState app;
  const _HubCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final pct = app.donePct;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        gradient: Pal.hubCardGradient,
        border: Border.all(color: Pal.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        Text('OBEN AI ${app.modelName(app.chapter)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: Fonts.disp,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 1.3,
              color: Pal.text,
              shadows: [Shadow(color: Color(0x59FFD400), blurRadius: 18, offset: Offset(0, 2))],
            )),
        const SizedBox(height: 5),
        Text(app.t('state'),
            style: const TextStyle(fontFamily: Fonts.mono, fontSize: 9, color: Pal.dim)),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(end: pct.toDouble()),
          duration: const Duration(milliseconds: 900),
          builder: (context, v, _) => Text('${v.round()}%',
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w900,
                  fontSize: 42,
                  height: 1,
                  color: Pal.green)),
        ),
        const SizedBox(height: 10),
        Container(
          height: 9,
          decoration: BoxDecoration(
            color: Pal.bg,
            border: Border.all(color: Pal.line),
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: pct / 100,
            child: Container(
              decoration: const BoxDecoration(
                color: Pal.green,
                boxShadow: [BoxShadow(color: Color(0x8000E676), blurRadius: 10)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${app.t('sub')} '),
            TextSpan(
                text: '${app.done.where((x) => x).length}/${app.tasks.length}',
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: Fonts.mono, fontSize: 10, letterSpacing: .6, color: Pal.dim),
        ),
      ]),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final AppState app;
  final int index;
  const _TaskRow({required this.app, required this.index});

  @override
  Widget build(BuildContext context) {
    final t = app.tasks[index];
    final isDone = app.done[index];
    final can = !isDone && app.free >= t.cost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: can ? () => app.doTask(index) : null,
        child: Opacity(
          opacity: isDone ? .75 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Pal.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isDone ? Pal.green : (can ? Pal.yellow : Pal.line)),
              boxShadow: can
                  ? const [BoxShadow(color: Color(0x40FFD400), blurRadius: 10)]
                  : null,
            ),
            child: Row(children: [
              GameIcon(t.icon,
                  size: 22, color: isDone ? Pal.green : (can ? Pal.text : Pal.dim)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.taskNames[index],
                      style: const TextStyle(
                          fontFamily: Fonts.mono, fontSize: 12, color: Pal.text)),
                  if (t.fx != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(t.fx == 't' ? app.t('fxT') : app.t('fxH'),
                          style: const TextStyle(
                              fontFamily: Fonts.mono, fontSize: 9, color: Pal.dim)),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              isDone
                  ? const Glyph(GlyphKind.check, size: 16, color: Pal.green)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${t.cost}',
                          style: TextStyle(
                              fontFamily: Fonts.disp,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: can ? Pal.yellow : Pal.dim)),
                      const SizedBox(width: 2),
                      GameIcon('bolt',
                          size: 12, solid: true, color: can ? Pal.yellow : Pal.dim),
                    ]),
            ]),
          ),
        ),
      ),
    );
  }
}
