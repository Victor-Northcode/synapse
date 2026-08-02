import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../state/app_state.dart';
import '../../state/play_state.dart';
import '../widgets/common.dart';

/// Карточка новой механики перед стартом уровня (ovMech).
class MechOverlay extends StatefulWidget {
  final AppState app;
  final MechCard card;
  final int maxBridges;
  final VoidCallback onOk;
  const MechOverlay(
      {super.key,
      required this.app,
      required this.card,
      required this.maxBridges,
      required this.onOk});

  @override
  State<MechOverlay> createState() => _MechOverlayState();
}

class _MechOverlayState extends State<MechOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  (String, String) _texts() {
    final app = widget.app;
    switch (widget.card.kind) {
      case 'bridge':
        return (app.t('brT'), app.t('brB').replaceAll('{n}', '${widget.maxBridges}'));
      case 'fill':
        return (app.tl('fn')[widget.card.index], app.tl('fb')[widget.card.index]);
      default: // obstacle
        final i = widget.card.index - 1;
        return (app.tl('obn')[i], app.tl('ob')[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final (title, body) = _texts();
    return Container(
      color: const Color(0xB804060E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(26),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
          decoration: BoxDecoration(
            color: Pal.ovCard,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0x47FFD400)),
            boxShadow: const [
              BoxShadow(color: Color(0x9A000000), blurRadius: 70, offset: Offset(0, 30)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Демо: узел механики и палец.
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: Pal.fieldGradient,
                border: Border.all(color: Pal.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(alignment: Alignment.center, children: [
                AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) => Transform.translate(
                    offset: _demoOffset(),
                    child: _demoNode(),
                  ),
                ),
                AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) {
                    final k = Curves.easeInOut.transform(
                        _t.value < .45 ? _t.value / .45 : 1 - (_t.value - .45) / .55);
                    return Positioned(
                      right: 22 + 14 * k,
                      bottom: 14 + 16 * k,
                      child: Opacity(
                        opacity: .5 + .5 * k,
                        child: const GameIcon('hand', size: 26, color: Pal.text),
                      ),
                    );
                  },
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.disp,
                    fontSize: 19,
                    letterSpacing: 1.8,
                    height: 1.4,
                    color: Color(0xFFFFB300))),
            const SizedBox(height: 12),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.mono,
                    fontSize: 13.5,
                    height: 1.7,
                    color: Pal.bodyDim)),
            const SizedBox(height: 20),
            PillButton(
              onTap: widget.onOk,
              color: Pal.yellow,
              textColor: const Color(0xFF241C00),
              minHeight: 72,
              glow: .35,
              child: Text(app.t('mechOk')),
            ),
          ]),
        ),
      ),
    );
  }

  Offset _demoOffset() {
    if (widget.card.kind != 'obstacle') return Offset.zero;
    final v = _t.value;
    switch (widget.card.index) {
      case 6: // дрейф
        return Offset(16 * math.sin(v * 2 * math.pi), -8 * math.sin(v * 2 * math.pi));
      case 7: // инверсия
        return Offset(18 * math.cos(v * 2 * math.pi), 0);
      case 3: // гвоздь: мелкая тряска
        return Offset(3 * math.sin(v * 24 * math.pi), -2 * math.sin(v * 16 * math.pi));
    }
    return Offset.zero;
  }

  Widget _demoNode() {
    // Узел 44px в стиле поля; цвет ядра — по механике.
    final (mid, ring) = switch (widget.card.kind) {
      'bridge' => (const Color(0xFF7CE0FF), const Color(0xFF7CE0FF)),
      'fill' => switch (widget.card.index) {
          0 => (Pal.yellow, Pal.yellow),
          1 => (const Color(0xFF2979FF), const Color(0xFF2979FF)),
          _ => (Pal.red, Pal.red),
        },
      _ => switch (widget.card.index) {
          1 || 4 => (const Color(0xFFF0C14B), const Color(0xFFC9A227)),
          2 => (const Color(0xFF9FD16B), const Color(0xFF7FA05A)),
          3 => (const Color(0xFFB9B9C4), const Color(0xFF8A8A96)),
          5 => (const Color(0xFFE03127), const Color(0xFFE03127)),
          6 => (const Color(0xFFB06CFF), const Color(0xFFB06CFF)),
          7 => (const Color(0xFFFF6BD6), const Color(0xFFFF6BD6)),
          8 => (Pal.yellow, Pal.yellow),
          _ => (const Color(0xFF4FE6FF), const Color(0xFF00E5FF)),
        },
    };
    final ghost = widget.card.kind == 'obstacle' && widget.card.index == 9;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: ghost ? (.12 + .88 * math.sin(_t.value * math.pi)) : 1,
        child: child,
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDCE6F2), Color(0xFF93A2B6), Color(0xFF4C596B), Color(0xFF7C8A9C)],
            stops: [0, .34, .62, 1],
          ),
          boxShadow: [
            BoxShadow(color: ring.withValues(alpha: .5), blurRadius: 16),
            const BoxShadow(color: Color(0x9E000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -.36),
                colors: [Color(0xFF101A26), Color(0xFF03060B)],
              ),
            ),
            child: Center(
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mid,
                  boxShadow: [BoxShadow(color: mid.withValues(alpha: .8), blurRadius: 8)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
