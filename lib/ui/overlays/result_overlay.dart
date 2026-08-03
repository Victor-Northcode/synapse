import 'package:flutter/material.dart';

import '../../core/ads.dart';
import '../../core/palette.dart';
import '../../state/app_state.dart';
import '../../state/play_state.dart';
import '../layout.dart';
import '../widgets/common.dart';

/// Экран результата уровня (победа / перегрузка).
class ResultOverlay extends StatefulWidget {
  final AppState app;
  final LevelResult result;
  final VoidCallback onNext; // следующий уровень / повтор
  final VoidCallback onHub;
  final VoidCallback onContinue; // продолжение после ролика (+ходы)
  final void Function(String) onToast;
  const ResultOverlay({
    super.key,
    required this.app,
    required this.result,
    required this.onNext,
    required this.onHub,
    required this.onContinue,
    required this.onToast,
  });

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay> {
  bool _adUsed = false;
  bool _adBusy = false;

  Future<void> _watchAd() async {
    final app = widget.app;
    if (_adBusy || _adUsed) return;
    setState(() => _adBusy = true);
    widget.onToast(app.t('adWatch'));
    final ok = await Ads.instance.rewarded();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (!ok) {
      widget.onToast(Ads.instance.hasAds ? app.t('adFail') : app.t('adOff'));
      return;
    }
    setState(() => _adUsed = true);
    if (widget.result.win) {
      app.tokens += widget.result.got;
      app.save();
      app.notify();
      widget.onToast(app.t('adDone'));
    } else {
      widget.onContinue();
    }
  }

  /// Строка наград победы: компьют и (если есть) осколки.
  Widget _rewards(AppState app, LevelResult r) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('+${r.got}',
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontSize: 40,
                  letterSpacing: 2,
                  color: Pal.yellow,
                  shadows: [Shadow(color: Color(0x66FFD400), blurRadius: 34)])),
          const SizedBox(width: 4),
          const GameIcon('bolt', size: 30, solid: true, color: Pal.yellow),
          if (r.shardGain > 0) ...[
            const SizedBox(width: 12),
            Text('+${r.shardGain}',
                style: const TextStyle(
                    fontFamily: Fonts.disp, fontSize: 22, color: Pal.cyan)),
            const SizedBox(width: 3),
            const ShardIcon(size: 15, color: Pal.cyan),
          ],
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final r = widget.result;
    final win = r.win;
    return Container(
      color: const Color(0xB804060E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(26),
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: Layout.of(context).overlayMaxWidth),
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
          decoration: BoxDecoration(
            color: Pal.ovCard,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: win ? const Color(0x4700E676) : const Color(0x4DFF3B30)),
            boxShadow: const [
              BoxShadow(color: Color(0x9A000000), blurRadius: 70, offset: Offset(0, 30)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            HexIcon(size: 56, color: win ? Pal.green : Pal.red, filled: !win),
            const SizedBox(height: 14),
            Text(
              win ? app.t('winT') : app.t('loseT'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Fonts.disp,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: win ? 1.8 : 2.4,
                height: 1.4,
                color: win ? Pal.green : Pal.red,
              ),
            ),
            const SizedBox(height: 12),
            IconText(
              win
                  ? app
                      .t('winB')
                      .replaceAll('{a}', '${r.nodesCount}')
                      .replaceAll('{b}', '${r.edgesCount}')
                      .replaceAll('{c}', '${r.nextSpecN}')
                  : app
                      .t('loseB')
                      .replaceAll('{n}', '${r.level}')
                      .replaceAll('{c}', '${r.crossings}'),
              style: const TextStyle(
                  fontFamily: Fonts.mono, fontSize: 13.5, height: 1.7, color: Pal.bodyDim),
            ),
            if (win) ...[
              const SizedBox(height: 16),
              // На узком экране (сложенный Fold) строка награды должна
              // сжиматься, а не резаться.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _rewards(app, r),
              ),
              // Тизер следующей вехи: видно, ради чего идти дальше.
              if (r.level % 10 != 0) ...[
                const SizedBox(height: 10),
                IconText(
                  app
                      .lt('mileNext')
                      .replaceAll('{m}', '${(r.level ~/ 10 + 1) * 10}'),
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 10, color: Pal.faint),
                ),
              ],
            ],
            const SizedBox(height: 18),
            PillButton(
              onTap: widget.onNext,
              minHeight: 72,
              child: Text(win ? app.t('next') : app.t('retry'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            if (!_adUsed) ...[
              const SizedBox(height: 10),
              Pressable(
                onTap: _adBusy ? null : _watchAd,
                child: Opacity(
                  opacity: _adBusy ? .5 : 1,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 72),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x1CFFD400),
                      border: Border.all(color: const Color(0x73FFD400)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      win ? app.t('adX2') : app.t('adCont'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: Fonts.disp,
                          fontSize: 13,
                          letterSpacing: 1.8,
                          color: Pal.yellow),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            GhostButton(onTap: widget.onHub, child: Text(app.t('toHub'))),
          ]),
        ),
      ),
    );
  }
}
