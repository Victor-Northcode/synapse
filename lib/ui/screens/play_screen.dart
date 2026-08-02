import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../game/geometry.dart';
import '../../state/app_state.dart';
import '../../state/play_state.dart';
import '../widgets/common.dart';
import '../widgets/field_widget.dart';

/// Игровой экран: HUD, поле, бустеры.
class PlayScreen extends StatefulWidget {
  final PlayState play;
  final VoidCallback onQuit;
  final Future<void> Function() onHintAd; // подсказка за ролик
  const PlayScreen(
      {super.key, required this.play, required this.onQuit, required this.onHintAd});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _hand =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();
  bool _boomShake = false;
  bool _adBusy = false;

  @override
  void initState() {
    super.initState();
    widget.play.addListener(_onPlay);
  }

  void _onPlay() {
    if (widget.play.result != null && !widget.play.result!.win && !_boomShake) {
      setState(() => _boomShake = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _boomShake = false);
      });
    }
  }

  @override
  void dispose() {
    widget.play.removeListener(_onPlay);
    _hand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final play = widget.play;
    return AnimatedBuilder(
      animation: play,
      builder: (context, _) {
        final kd = play.kind;
        return Container(
          color: Pal.bg,
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(children: [
                  Text(app.t('lvl').replaceAll('{n}', '${play.level}'),
                      style: const TextStyle(
                          fontFamily: Fonts.disp,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .6,
                          color: Pal.text)),
                  if (kd != 0) ...[
                    const SizedBox(width: 6),
                    KindBadge(
                        kd,
                        kd == 2
                            ? app.t('kSuper')
                            : (kd == 1 ? app.t('kHard') : app.t('kEasy'))),
                  ],
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${play.crossings}',
                        style: TextStyle(
                          fontFamily: Fonts.disp,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1,
                          color: play.crossings == 0 ? Pal.green : app.gameTheme.mag,
                          shadows: [
                            Shadow(
                                color: (play.crossings == 0 ? Pal.green : app.gameTheme.mag)
                                    .withValues(alpha: .55),
                                blurRadius: 14),
                          ],
                        )),
                    Text(app.t('cross'),
                        style: const TextStyle(
                            fontFamily: Fonts.mono,
                            fontSize: 7.5,
                            letterSpacing: .5,
                            color: Pal.dim)),
                  ]),
                ]),
              ),
              // Счётчик ходов.
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(app.t('moves'),
                          style: const TextStyle(
                              fontFamily: Fonts.mono, fontSize: 10, color: Pal.dim)),
                      const SizedBox(width: 8),
                      Text('${play.moves}',
                          style: const TextStyle(
                              fontFamily: Fonts.disp,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Pal.text)),
                    ]),
              ),
              // Полоса запаса ходов.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Pal.panel,
                    border: Border.all(color: Pal.line),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: (play.moves / play.movesMax).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: play.moves <= 2
                            ? Pal.red
                            : (play.moves <= (play.movesMax * .35).ceil()
                                ? Pal.yellow
                                : Pal.green),
                        boxShadow: play.moves <= 2
                            ? const [BoxShadow(color: Pal.red, blurRadius: 10)]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              // Поле.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    transform: _boomShake
                        ? (Matrix4.identity()..translateByDouble(3, -3, 0, 1))
                        : Matrix4.identity(),
                    decoration: BoxDecoration(
                      gradient: Pal.fieldGradient,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: play.kind == 2
                            ? const Color(0x80E8564B)
                            : (play.kind == 1
                                ? const Color(0x6B00E5FF)
                                : Pal.fieldBorder),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Stack(children: [
                        Positioned.fill(
                          child: FieldWidget(play: play, themeIndex: app.theme),
                        ),
                        if (_showFirstHint(play)) ..._firstHint(play),
                        if (play.level == 1 && play.snapSeq == 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: IgnorePointer(
                              child: IconText(app.t('tip'),
                                  style: const TextStyle(
                                      fontFamily: Fonts.mono,
                                      fontSize: 9.5,
                                      letterSpacing: .4,
                                      color: Pal.dim)),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              // Бустеры и сервис.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(children: [
                  _boost(app, play, 0, 'cut'),
                  const SizedBox(width: 9),
                  _boost(app, play, 1, 'stab'),
                  const SizedBox(width: 9),
                  _boost(app, play, 2, 'auto'),
                  const SizedBox(width: 9),
                  Expanded(flex: 5, child: _hintBtn(app, play)),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 4,
                    child: _mini(
                      onTap: () {
                        play.quit();
                        widget.onQuit();
                      },
                      child: const Glyph(GlyphKind.close, size: 17, color: Pal.text),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  bool _showFirstHint(PlayState play) =>
      play.level == 1 && play.snapSeq == 0 && play.alive;

  List<Widget> _firstHint(PlayState play) {
    var from = -1;
    for (var i = 0; i < play.nodes.length; i++) {
      if (play.ntype[i] != 3) {
        from = i;
        break;
      }
    }
    if (from < 0) return const [];
    var best = -1;
    var bd = 1e9;
    for (var k = 0; k < play.sockets.length; k++) {
      if (play.slotOf.contains(k)) continue;
      final dd = dist(play.nodes[from], play.sockets[k]);
      if (dd < bd) {
        bd = dd;
        best = k;
      }
    }
    if (best < 0) return const [];
    final a = play.nodes[from], b = play.sockets[best];
    return [
      AnimatedBuilder(
        animation: _hand,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(
              _hand.value < .7 ? _hand.value / .7 : 1 - (_hand.value - .7) / .3);
          final x = a[0] + (b[0] - a[0]) * t;
          final y = a[1] + (b[1] - a[1]) * t - math.sin(t * math.pi) * 18;
          return Positioned(
            left: x - 13,
            top: y - 13,
            child: IgnorePointer(
              child: Opacity(
                opacity: .9,
                child: GameIcon('hand', size: 26, color: Pal.yellow),
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _mini({required Widget child, VoidCallback? onTap, bool disabled = false, Color? border}) {
    return Pressable(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? .35 : 1,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Pal.panel,
            border: Border.all(color: border ?? Pal.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _boost(AppState app, PlayState play, int bi, String key) {
    final count = app.inv[key] ?? 0;
    final noTarget = count > 0 && play.alive && !play.boostHasTarget(key);
    final disabled = count <= 0 || !play.alive || noTarget;
    const icons = ['cut', 'timer', 'target'];
    return Expanded(
      flex: 4,
      child: _mini(
        disabled: disabled,
        onTap: () => play.useBoost(key),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GameIcon(icons[bi], size: 14, color: Pal.text),
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Pal.cyan)),
        ]),
      ),
    );
  }

  Widget _hintBtn(AppState app, PlayState play) {
    final hasStock = app.hintStock > 0;
    if (hasStock) {
      return _mini(
        onTap: () => play.useHint(),
        child: IconText(app.t('hint').replaceAll('{n}', '${app.hintStock}'),
            style: const TextStyle(fontFamily: Fonts.mono, fontSize: 10, color: Pal.text)),
      );
    }
    return _mini(
      border: Pal.yellow,
      disabled: _adBusy,
      onTap: () async {
        setState(() => _adBusy = true);
        await widget.onHintAd();
        if (mounted) setState(() => _adBusy = false);
      },
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        GameIcon('tv', size: 14, color: Pal.yellow),
        SizedBox(width: 3),
        GameIcon('bulb', size: 14, color: Pal.yellow),
      ]),
    );
  }
}
