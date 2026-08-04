import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../game/geometry.dart';
import '../../state/app_state.dart';
import '../../state/play_state.dart';
import '../layout.dart';
import '../widgets/common.dart';
import '../widgets/field_widget.dart';

/// Игровой экран: HUD, поле, бустеры.
class PlayScreen extends StatefulWidget {
  final PlayState play;
  final VoidCallback onQuit;
  final Future<void> Function() onHintAd; // подсказка за ролик
  final void Function(String) onInfo; // тост-пояснение
  const PlayScreen(
      {super.key,
      required this.play,
      required this.onQuit,
      required this.onHintAd,
      required this.onInfo});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  // Создаётся в initState, а не лениво: ленивый контроллер мог впервые
  // инициализироваться в dispose() и падать на поиске vsync.
  late final AnimationController _hand;
  bool _boomShake = false;
  bool _adBusy = false;

  @override
  void initState() {
    super.initState();
    _hand = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
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
    final l = Layout.of(context);
    return AnimatedBuilder(
      animation: play,
      builder: (context, _) {
        return Container(
          color: Pal.bg,
          child: SafeArea(
            child: l.twoColumn ? _landscape(app, play, l) : _portrait(app, play, l),
          ),
        );
      },
    );
  }

  /// Портрет: HUD сверху, поле, ряд бустеров снизу.
  Widget _portrait(AppState app, PlayState play, Layout l) {
    return ContentColumn(
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(l.gutter, l.isShort ? 8 : 12, l.gutter, 8),
          child: _statusRow(app, play),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _movesRow(app, play),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: l.gutter),
          child: _movesBar(play),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(l.isShort ? 10 : 12),
            child: _field(app, play),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(l.gutter, 0, l.gutter, l.isShort ? 10 : 14),
          child: Row(children: [
            // На планшете кнопки на шаг выше — попадать пальцем проще.
            _boost(app, play, 0, 'cut', height: l.isTablet ? 54 : 46),
            const SizedBox(width: 9),
            _boost(app, play, 1, 'stab', height: l.isTablet ? 54 : 46),
            const SizedBox(width: 9),
            _boost(app, play, 2, 'auto', height: l.isTablet ? 54 : 46),
            const SizedBox(width: 9),
            Expanded(
                flex: 5,
                child: _hintBtn(app, play, height: l.isTablet ? 54 : 46)),
            const SizedBox(width: 9),
            Expanded(
                flex: 4, child: _quitBtn(play, height: l.isTablet ? 54 : 46)),
          ]),
        ),
      ]),
    );
  }

  /// Альбом (планшет): поле во всю высоту, управление колонкой справа.
  /// Панель собрана, а не рассыпана: статус и ходы — карточкой по
  /// центру, бустеры — широкими кнопками с названиями (на планшете
  /// есть место, чтобы не заставлять игрока угадывать по значку).
  Widget _landscape(AppState app, PlayState play, Layout l) {
    return Padding(
      padding: EdgeInsets.all(l.gutter * .75),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Поле не должно расплываться в широкую полосу: держим его
        // около 4:3, остаток ширины отдаём панели.
        Expanded(
          child: Center(
            child: AspectRatio(aspectRatio: 1.15, child: _field(app, play)),
          ),
        ),
        SizedBox(width: l.gutter),
        // На коротком альбоме (телефон боком, сплит-скрин) панель
        // ужимается до компактной, иначе не влезает по высоте.
        l.isShort
            ? SizedBox(
                width: 230,
                child: Column(children: [
                  const Spacer(flex: 2),
                  _statusRow(app, play, stacked: true),
                  const SizedBox(height: 14),
                  _movesRow(app, play),
                  const SizedBox(height: 8),
                  _movesBar(play),
                  const Spacer(flex: 5),
                  Row(children: [
                    _boost(app, play, 0, 'cut'),
                    const SizedBox(width: 8),
                    _boost(app, play, 1, 'stab'),
                    const SizedBox(width: 8),
                    _boost(app, play, 2, 'auto'),
                  ]),
                  const SizedBox(height: 9),
                  SizedBox(width: double.infinity, child: _hintBtn(app, play)),
                  const SizedBox(height: 9),
                  SizedBox(width: double.infinity, child: _quitBtn(play)),
                ]),
              )
            : SizedBox(
                width: 300,
                child: Column(children: [
                  const Spacer(flex: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    decoration: BoxDecoration(
                      color: Pal.panel.withValues(alpha: .6),
                      border: Border.all(color: Pal.line),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _statusRow(app, play, stacked: true),
                      const SizedBox(height: 20),
                      _movesRow(app, play),
                      const SizedBox(height: 10),
                      _movesBar(play),
                    ]),
                  ),
                  const Spacer(flex: 3),
                  _boostWide(app, play, 0, 'cut'),
                  const SizedBox(height: 9),
                  _boostWide(app, play, 1, 'stab'),
                  const SizedBox(height: 9),
                  _boostWide(app, play, 2, 'auto'),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: _hintBtn(app, play, height: 54)),
                  const SizedBox(height: 9),
                  SizedBox(
                      width: double.infinity,
                      child: _quitBtn(play, height: 54)),
                ]),
              ),
      ]),
    );
  }

  /// Широкая кнопка бустера для планшетной панели: значок, название и
  /// запас — видно, что это и сколько осталось, без угадывания.
  Widget _boostWide(AppState app, PlayState play, int bi, String key) {
    final count = app.inv[key] ?? 0;
    final noTarget = count > 0 && play.alive && !play.boostHasTarget(key);
    final dimmed = count <= 0 || !play.alive || noTarget;
    const icons = ['cut', 'timer', 'target'];
    return GestureDetector(
      onLongPress: () =>
          widget.onInfo('${app.tl('bn')[bi]} — ${app.tl('bd')[bi]}'),
      child: Opacity(
        opacity: dimmed ? .45 : 1,
        child: Pressable(
          onTap: () => play.useBoost(key),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Pal.panel,
              border: Border.all(color: Pal.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(children: [
              GameIcon(icons[bi], size: 16, color: Pal.text),
              const SizedBox(width: 11),
              Expanded(
                child: Text(app.tl('bn')[bi],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: Fonts.mono,
                        fontSize: 11.5,
                        color: Pal.text)),
              ),
              Text('×$count',
                  style: const TextStyle(
                      fontFamily: Fonts.mono,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Pal.cyan)),
            ]),
          ),
        ),
      ),
    );
  }

  /// Номер связи, бейдж сложности и счётчик пересечений.
  Widget _statusRow(AppState app, PlayState play, {bool stacked = false}) {
    final kd = play.kind;
    final title = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(app.t('lvl').replaceAll('{n}', '${play.level}'),
          style: const TextStyle(
              fontFamily: Fonts.disp,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .6,
              color: Pal.text)),
      if (kd != 0) ...[
        const SizedBox(width: 6),
        KindBadge(kd,
            kd == 2 ? app.t('kSuper') : (kd == 1 ? app.t('kHard') : app.t('kEasy'))),
      ],
    ]);
    final counter = Column(
      crossAxisAlignment:
          stacked ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      children: [
        Text('${play.crossings}',
            style: TextStyle(
              fontFamily: Fonts.disp,
              fontWeight: FontWeight.w900,
              fontSize: stacked ? 34 : 20,
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
                fontFamily: Fonts.mono, fontSize: 8, letterSpacing: .5, color: Pal.dim)),
      ],
    );
    if (stacked) {
      return Column(children: [
        FittedBox(fit: BoxFit.scaleDown, child: title),
        const SizedBox(height: 14),
        counter,
      ]);
    }
    // Узкий экран + длинный язык: обе половины ужимаются, ничего не
    // режется, но счётчик остаётся прижат к правому краю.
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(
        child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: title),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: counter),
      ),
    ]);
  }

  Widget _movesRow(AppState app, PlayState play) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(app.t('moves'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: Fonts.mono, fontSize: 10, color: Pal.dim)),
          ),
          const SizedBox(width: 8),
          Text('${play.moves}',
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Pal.text)),
        ]);
  }

  Widget _movesBar(PlayState play) {
    return Container(
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
            boxShadow:
                play.moves <= 2 ? const [BoxShadow(color: Pal.red, blurRadius: 10)] : null,
          ),
        ),
      ),
    );
  }

  Widget _field(AppState app, PlayState play) {
    return AnimatedContainer(
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
              : (play.kind == 1 ? const Color(0x6B00E5FF) : Pal.fieldBorder),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(children: [
          Positioned.fill(child: FieldWidget(play: play, themeIndex: app.theme)),
          if (_showFirstHint(play)) ..._firstHint(play),
          if (play.level == 1 && play.snapSeq == 0)
            Positioned(
              left: 8,
              right: 8,
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
    );
  }

  Widget _quitBtn(PlayState play, {double height = 46}) {
    return _mini(
      height: height,
      onTap: () {
        play.quit();
        widget.onQuit();
      },
      child: const Glyph(GlyphKind.close, size: 17, color: Pal.text),
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

  Widget _mini(
      {required Widget child,
      VoidCallback? onTap,
      bool disabled = false,
      Color? border,
      double height = 46}) {
    return Pressable(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? .35 : 1,
        child: Container(
          height: height,
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

  Widget _boost(AppState app, PlayState play, int bi, String key,
      {double height = 46}) {
    final count = app.inv[key] ?? 0;
    final noTarget = count > 0 && play.alive && !play.boostHasTarget(key);
    final dimmed = count <= 0 || !play.alive || noTarget;
    const icons = ['cut', 'timer', 'target'];
    // Кнопка остаётся живой даже «пустой»: тап объясняет тостом, чего
    // не хватает, долгое нажатие — что бустер делает.
    return Expanded(
      flex: 4,
      child: GestureDetector(
        onLongPress: () =>
            widget.onInfo('${app.tl('bn')[bi]} — ${app.tl('bd')[bi]}'),
        child: Opacity(
          opacity: dimmed ? .45 : 1,
          child: _mini(
            height: height,
            onTap: () => play.useBoost(key),
            // Узкая колонка на планшете: даём содержимому сжиматься,
            // иначе иконка со счётчиком не влезает в треть панели.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
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
          ),
        ),
      ),
    );
  }

  Widget _hintBtn(AppState app, PlayState play, {double height = 46}) {
    final hasStock = app.hintStock > 0;
    if (hasStock) {
      return GestureDetector(
        onLongPress: () => widget.onInfo(app.t('hintBuyD')),
        child: _mini(
          height: height,
          onTap: () => play.useHint(),
          // «Hinweis 2» и подобные длинные подписи ужимаются, а не режутся.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: IconText(app.t('hint').replaceAll('{n}', '${app.hintStock}'),
                style: const TextStyle(
                    fontFamily: Fonts.mono, fontSize: 10, color: Pal.text)),
          ),
        ),
      );
    }
    // Подсказки кончились — предлагаем ролик; долгое нажатие поясняет.
    return GestureDetector(
      onLongPress: () => widget.onInfo(app.t('hintAd')),
      child: _mini(
        height: height,
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
      ),
    );
  }
}
