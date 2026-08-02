import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/game_data.dart';

/// Сюжетная сцена — порт sceneHTML()/setScene().
/// Виды: net · noise · zoom · console · line · net-ok · new.
class SceneWidget extends StatefulWidget {
  final String scene;
  final double lit; // для net-ok: доля «оживших» узлов
  final bool assemble; // финал главы: кабели втягиваются, ядро вспыхивает
  const SceneWidget(this.scene, {super.key, this.lit = .5, this.assemble = false});

  @override
  State<SceneWidget> createState() => _SceneWidgetState();
}

class _SceneWidgetState extends State<SceneWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 386 / 300,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => CustomPaint(
          painter: _ScenePainter(widget.scene, widget.lit, widget.assemble, _t.value),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final String scene;
  final double lit;
  final bool assemble;
  final double t;
  _ScenePainter(this.scene, this.lit, this.assemble, this.t);

  Offset _pt(List<double> p, Size s) => Offset(p[0] / 100 * s.width, p[1] / 100 * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    // Мягкое гало в центре — цвет зависит от сцены.
    final glow = switch (scene) {
      'noise' => const Color(0x33FF2ED1),
      'net-ok' => const Color(0x2900E676),
      'new' => const Color(0x38C9A227),
      'line' => const Color(0x29FFD400),
      'zoom' => const Color(0x1478A0FF),
      _ => const Color(0x2400E5FF),
    };
    canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide * .45,
        Paint()
          ..color = glow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));

    switch (scene) {
      case 'net':
      case 'noise':
      case 'net-ok':
        _paintNet(canvas, size);
      case 'zoom':
        _paintZoom(canvas, size);
      case 'console':
        _paintConsole(canvas, size);
      case 'line':
        _paintLine(canvas, size);
      default:
        _paintCore(canvas, size); // 'new' и запасная композиция
    }
  }

  void _paintNet(Canvas canvas, Size size) {
    final noise = scene == 'noise';
    final ok = scene == 'net-ok';
    final litN = ok ? math.max(2, (kScenePts.length * lit).round()) : kScenePts.length;
    final edges = [...kSceneEdges, if (noise) ...kSceneBadEdges];
    final rnd = math.Random(7);
    for (var i = 0; i < edges.length; i++) {
      final a = kScenePts[edges[i][0]], b = kScenePts[edges[i][1]];
      Color col;
      if (noise) {
        col = const Color(0x99FF2ED1);
      } else if (ok) {
        col = (edges[i][0] < litN && edges[i][1] < litN)
            ? const Color(0x8000E676)
            : const Color(0x3878A0FF);
      } else {
        col = const Color(0x8000E5FF);
      }
      final pulse = .6 + .4 * math.sin((t * 2 * math.pi) + i * .7);
      canvas.drawLine(
        _pt(a, size),
        _pt(b, size),
        Paint()
          ..strokeWidth = noise ? 2.4 : 1.8
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: col.a * pulse),
      );
    }
    for (var i = 0; i < kScenePts.length; i++) {
      var p = _pt(kScenePts[i], size);
      if (noise) {
        p += Offset(((i * 37) % 9) - 4, ((i * 53) % 9) - 4);
      }
      final hub = i == 0;
      Color col;
      if (noise) {
        col = Pal.mag;
      } else if (ok) {
        col = i < litN ? Pal.green : const Color(0xFF3E4B5E);
      } else {
        col = Pal.cyan;
      }
      final r = hub ? 9.0 : 4.5;
      canvas.drawCircle(p, r + 4,
          Paint()..color = col.withValues(alpha: .3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(p, r, Paint()..color = col);
      if (hub) {
        canvas.drawCircle(
            p,
            r + 5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = col.withValues(alpha: .6));
      }
      if (noise && rnd.nextDouble() < .3) {
        canvas.drawCircle(p, r * 1.8,
            Paint()..color = col.withValues(alpha: .18 * math.sin(t * 12 + i).abs()));
      }
    }
    if (noise) {
      // Полоса помех.
      final y = size.height * ((t * 1.4) % 1);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 7),
          Paint()..color = const Color(0x22FF2ED1));
    }
  }

  void _paintZoom(Canvas canvas, Size size) {
    // Сетка ячеек — «взгляд внутрь узла».
    final c = size.center(Offset.zero);
    const gap = 34.0;
    for (var gx = -1; gx <= 1; gx++) {
      for (var gy = -1; gy <= 1; gy++) {
        final i = (gx + 1) * 3 + (gy + 1);
        final k = .5 + .5 * math.sin(t * 2 * math.pi + i * .22 * 2 * math.pi);
        final p = c + Offset(gx * gap, gy * gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 24, height: 24),
              const Radius.circular(6)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Color.lerp(const Color(0xFF2E3652), Pal.cyan, k * .7)!,
        );
      }
    }
    canvas.drawCircle(
        c,
        72,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0x5978A0FF));
    canvas.drawLine(c + const Offset(51, 51), c + const Offset(86, 86),
        Paint()..strokeWidth = 1.6..color = const Color(0x5978A0FF));
  }

  void _paintConsole(Canvas canvas, Size size) {
    const cp = [[32.0, 38.0], [62.0, 30.0], [34.0, 68.0], [70.0, 66.0]];
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .12, size.height * .1, size.width * .76,
              size.height * .8),
          const Radius.circular(14)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x4D00E5FF),
    );
    canvas.drawLine(_pt(cp[0], size), _pt(cp[1], size),
        Paint()..strokeWidth = 2..strokeCap = StrokeCap.round..color = const Color(0x8000E5FF));
    canvas.drawLine(_pt(cp[2], size), _pt(cp[0], size),
        Paint()..strokeWidth = 2..strokeCap = StrokeCap.round..color = const Color(0x8000E5FF));
    for (var i = 0; i < 4; i++) {
      final p = _pt(cp[i], size);
      final socket = i == 3;
      canvas.drawCircle(p, 6, Paint()..color = socket ? const Color(0xFF0C1420) : Pal.cyan);
      if (socket) {
        canvas.drawCircle(
            p,
            8,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = const Color(0x8CFFD400));
      }
    }
    // Курсор-палец обводит поле.
    final ang = t * 2 * math.pi;
    final cur = size.center(Offset.zero) +
        Offset(math.cos(ang) * size.width * .22, math.sin(ang) * size.height * .18);
    canvas.drawCircle(cur, 7, Paint()..color = const Color(0x66FFFFFF));
  }

  void _paintLine(Canvas canvas, Size size) {
    final y = size.height / 2;
    final rail = Rect.fromLTWH(size.width * .12, y - 2, size.width * .76, 4);
    canvas.drawRRect(RRect.fromRectAndRadius(rail, const Radius.circular(2)),
        Paint()..color = const Color(0x2978A0FF));
    final k = (math.sin(t * 2 * math.pi - math.pi / 2) + 1) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(rail.left, rail.top, rail.width * k, 4), const Radius.circular(2)),
      Paint()..color = Pal.yellow,
    );
    for (final (x, col) in [(.12, Pal.cyan), (.88, Pal.yellow)]) {
      final p = Offset(size.width * x, y);
      canvas.drawCircle(p, 12,
          Paint()..color = col.withValues(alpha: .3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(p, 8, Paint()..color = col);
    }
  }

  void _paintCore(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final gold = scene == 'new';
    final coreCol = gold ? const Color(0xFFE8CE7A) : Pal.cyan;
    final wireCol = gold ? const Color(0xFF5FD996) : const Color(0xFF1FAE63);
    // Четыре провода тянутся к ядру.
    final pull = assemble ? (1.0 - math.min(1.0, t * 4)) : 1.0;
    for (var i = 0; i < 4; i++) {
      final ang = math.pi / 4 + i * math.pi / 2;
      final from = c + Offset(math.cos(ang), math.sin(ang)) * size.shortestSide * .42 * pull;
      canvas.drawLine(
          from,
          c,
          Paint()
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..color = wireCol.withValues(alpha: .85));
    }
    final k = .5 + .5 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(c, 34.0 + (assemble ? 10.0 : 4.0) * k,
        Paint()..color = coreCol.withValues(alpha: .25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    final grad = RadialGradient(
      center: const Alignment(-.2, -.3),
      colors: gold
          ? const [Color(0xFFFFF3CE), Color(0xFFE8CE7A), Color(0xFF5A4A1C)]
          : const [Color(0xFFEAFDFF), Color(0xFF4FE6FF), Color(0xFF00697E)],
      stops: const [0, .4, 1],
    );
    canvas.drawCircle(
        c, 26, Paint()..shader = grad.createShader(Rect.fromCircle(center: c, radius: 26)));
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}
