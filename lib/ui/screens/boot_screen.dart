import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// Экран загрузки: штекер защёлкивается, из него растут кабели,
/// проявляется имя. Хронометраж — 1.7 с, как в патче 10.2.
class BootScreen extends StatefulWidget {
  final VoidCallback onDone;
  const BootScreen({super.key, required this.onDone});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1960));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 1960; // мс
        final drop = Curves.easeOutBack.transform(_seg(t, 300, 900));
        final ring = _seg(t, 920, 1420);
        final wire = _seg(t, 1200, 1800);
        final nameA = _seg(t, 1400, 1800);
        final tagA = _seg(t, 1550, 1950);
        final load = _seg(t, 300, 1800);
        final leave = _seg(t, 1700, 1960);
        return Opacity(
          opacity: 1 - leave,
          child: Container(
            decoration: const BoxDecoration(gradient: Pal.fieldGradient),
            // Stack по умолчанию прижимает нецентрированных детей к левому
            // верхнему углу — колонка обязана растягиваться на весь экран,
            // иначе вся анимация «уезжает влево».
            child: Stack(children: [
              // Мягкое дыхание фона за штекером.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.12),
                        radius: .9,
                        colors: [
                          Pal.mag.withValues(alpha: .06 + .05 * drop),
                          const Color(0x00000000),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 80,
                    child: Stack(alignment: Alignment.center, children: [
                      // Кабели растут из разъёма.
                      for (final dir in [-1.0, 1.0])
                        Positioned(
                          left: dir < 0 ? 120 - 26 - 85.0 * wire : null,
                          right: dir > 0 ? 120 - 26 - 85.0 * wire : null,
                          child: Container(
                            width: 85 * wire,
                            height: 11,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF1FAE63), Color(0xFF0E6E42), Color(0xFF04241A)],
                                stops: [0, .62, 1],
                              ),
                            ),
                          ),
                        ),
                      // Волна защёлкивания.
                      if (ring > 0 && ring < 1)
                        Container(
                          width: 44 + 48 * ring,
                          height: 44 + 48 * ring,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Pal.mag.withValues(alpha: (1 - ring) * .8), width: 1.5),
                          ),
                        ),
                      // Штекер.
                      Transform.translate(
                        offset: Offset(0, -56 * (1 - drop)),
                        child: Transform.scale(
                          scale: 1 + .35 * (1 - drop),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFDCE6F2), Color(0xFF93A2B6), Color(0xFF4C596B), Color(0xFF7C8A9C)],
                                stops: [0, .34, .62, 1],
                              ),
                              boxShadow: [BoxShadow(color: Color(0xA6000000), blurRadius: 18, offset: Offset(0, 8))],
                            ),
                            child: Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: Alignment(0, -.36),
                                    colors: [Color(0xFF101A26), Color(0xFF03060B)],
                                  ),
                                ),
                                child: Center(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    opacity: t > 900 ? 1 : 0,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          center: Alignment(-.16, -.32),
                                          colors: [Color(0xFFFFE6F8), Pal.mag, Color(0xFF6B0C55)],
                                          stops: [0, .38, 1],
                                        ),
                                        boxShadow: [BoxShadow(color: Color(0x80FF2ED1), blurRadius: 14)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 44),
                  Opacity(
                    opacity: nameA,
                    child: Transform.translate(
                      offset: Offset(0, 6 * (1 - nameA)),
                      child: const Text('SYNAPSE',
                          style: TextStyle(
                              fontFamily: Fonts.disp,
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                              letterSpacing: 12,
                              color: Pal.text)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: tagA,
                    child: const Text('OBEN AI · LINK LAB',
                        style: TextStyle(
                            fontFamily: Fonts.mono,
                            fontSize: 10.5,
                            letterSpacing: 4.8,
                            color: Pal.dim)),
                  ),
                ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: Column(children: [
                  SizedBox(
                    width: 140,
                    height: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: load,
                        backgroundColor: const Color(0x2978A0FF),
                        valueColor: const AlwaysStoppedAnimation(Pal.cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('${(load * 100).round()}%',
                      style: const TextStyle(
                          fontFamily: Fonts.mono,
                          fontSize: 9.5,
                          letterSpacing: 2.4,
                          color: Pal.ghost)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
