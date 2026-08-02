import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/game_data.dart';
import '../../game/geometry.dart';
import '../../state/play_state.dart';

/// Игровое поле: гнёзда, пятислойные кабели, узлы, эффекты.
/// Порт buildDom()/render()/paintCable() на CustomPainter.
class FieldWidget extends StatefulWidget {
  final PlayState play;
  final int themeIndex;
  const FieldWidget({super.key, required this.play, required this.themeIndex});

  @override
  State<FieldWidget> createState() => _FieldWidgetState();
}

class _Particle {
  double x, y, vx, vy, life;
  final Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.color) : life = 1;
}

class _FieldWidgetState extends State<FieldWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  final List<_Particle> _particles = [];
  final List<(Pt, int)> _snapRings = []; // позиция, момент запуска (мс)
  final Map<int, int> _edgeFlash = {}; // ребро → погасить в (мс)
  Set<int> _prevBad = {};
  bool _boomTint = false;
  int _buildTime = 0;
  int _tapPointer = -1;
  Offset _tapPos = Offset.zero;
  bool _dragging = false;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _buildTime = _now;
    widget.play.onFx = _onFx;
    widget.play.addListener(_onPlayChanged);
  }

  @override
  void didUpdateWidget(covariant FieldWidget old) {
    super.didUpdateWidget(old);
    if (old.play != widget.play) {
      old.play.removeListener(_onPlayChanged);
      old.play.onFx = null;
      widget.play.onFx = _onFx;
      widget.play.addListener(_onPlayChanged);
      _reset();
    }
  }

  void _reset() {
    _particles.clear();
    _snapRings.clear();
    _edgeFlash.clear();
    _prevBad = {};
    _boomTint = false;
    _buildTime = _now;
  }

  void _onPlayChanged() {
    // Вспышка кабеля при появлении нового пересечения (бренд-бук: 300 мс).
    final bad = widget.play.badEdges();
    for (final e in bad) {
      if (!_prevBad.contains(e)) _edgeFlash[e] = _now + 310;
    }
    _prevBad = bad;
  }

  void _onFx(PlayFxEvent e) {
    switch (e.fx) {
      case PlayFx.snap:
        if (e.node >= 0 && e.node < widget.play.nodes.length) {
          _snapRings.add(([...widget.play.nodes[e.node]], _now));
        }
      case PlayFx.boom:
        _boomTint = true;
        _spawnParticles();
      case PlayFx.flashRed:
        _boomTint = true;
      case PlayFx.win:
        _spawnWinBurst();
    }
  }

  /// Салют победы: искры взлетают из каждого узла вверх.
  void _spawnWinBurst() {
    final rnd = math.Random();
    const colors = [Pal.green, Pal.cyan, Pal.yellow, Color(0xFFE8CE7A)];
    for (final p in widget.play.nodes) {
      for (var i = 0; i < 12; i++) {
        final an = -math.pi / 2 + (rnd.nextDouble() - .5) * 1.6;
        final sp = 2.5 + rnd.nextDouble() * 5;
        _particles.add(_Particle(
            p[0], p[1], math.cos(an) * sp, math.sin(an) * sp, colors[rnd.nextInt(4)]));
      }
    }
  }

  void _spawnParticles() {
    final rnd = math.Random();
    const colors = [Color(0xFFFF8A5B), Color(0xFF5BC8B8), Color(0xFFFFC24D), Color(0xFFE8564B)];
    for (final p in widget.play.nodes) {
      for (var i = 0; i < 14; i++) {
        final an = rnd.nextDouble() * math.pi * 2;
        final sp = 1.5 + rnd.nextDouble() * 5;
        _particles.add(_Particle(
            p[0], p[1], math.cos(an) * sp, math.sin(an) * sp, colors[rnd.nextInt(4)]));
      }
    }
  }

  @override
  void dispose() {
    widget.play.removeListener(_onPlayChanged);
    widget.play.onFx = null;
    _tick.dispose();
    super.dispose();
  }

  int _nodeAt(Offset p) {
    var best = -1;
    // Хитбокс чуть больше самого разъёма и растёт вместе с ним.
    var bd = 26.0 * widget.play.scale;
    for (var i = 0; i < widget.play.nodes.length; i++) {
      final n = widget.play.nodes[i];
      final d = (Offset(n[0], n[1]) - p).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final play = widget.play;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) => play.resize(w, h));
      return Listener(
        onPointerDown: (e) {
          final p = e.localPosition;
          final i = _nodeAt(p);
          if (i >= 0) {
            _dragging = play.pointerDown(i, p.dx, p.dy);
            _tapPointer = -1;
          } else {
            _tapPointer = e.pointer;
            _tapPos = p;
          }
        },
        onPointerMove: (e) {
          if (_dragging) play.pointerMove(e.localPosition.dx, e.localPosition.dy);
        },
        onPointerUp: (e) {
          if (_dragging) {
            play.pointerUp();
            _dragging = false;
          } else if (_tapPointer == e.pointer &&
              (e.localPosition - _tapPos).distance < 14) {
            play.toggleBridge(e.localPosition.dx, e.localPosition.dy);
          }
          _tapPointer = -1;
        },
        onPointerCancel: (e) {
          if (_dragging) {
            play.pointerUp();
            _dragging = false;
          }
        },
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([play, _tick]),
            builder: (context, _) {
              _stepParticles();
              return CustomPaint(
                size: Size(w, h),
                isComplex: true,
                willChange: true,
                painter: _FieldPainter(
                  play: play,
                  mat: kCableMats[widget.themeIndex],
                  now: _now,
                  buildTime: _buildTime,
                  particles: _particles,
                  snapRings: _snapRings,
                  edgeFlash: _edgeFlash,
                  boomTint: _boomTint,
                ),
              );
            },
          ),
        ),
      );
    });
  }

  void _stepParticles() {
    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += .13;
      p.life -= .014;
    }
    _particles.removeWhere((p) => p.life <= 0);
    _snapRings.removeWhere((r) => _now - r.$2 > 430);
    _edgeFlash.removeWhere((_, until) => _now > until);
  }
}

class _FieldPainter extends CustomPainter {
  final PlayState play;
  final CableMat mat;
  final int now;
  final int buildTime;
  final List<_Particle> particles;
  final List<(Pt, int)> snapRings;
  final Map<int, int> edgeFlash;
  final bool boomTint;

  _FieldPainter({
    required this.play,
    required this.mat,
    required this.now,
    required this.buildTime,
    required this.particles,
    required this.snapRings,
    required this.edgeFlash,
    required this.boomTint,
  });

  /// Множитель геометрии: на планшете всё крупнее.
  double get g => play.scale;

  double get _pulse => (now % 1600) / 1600; // общий пульс для анимаций

  @override
  void paint(Canvas canvas, Size size) {
    _paintDust(canvas, size);
    _paintZones(canvas);
    _paintSockets(canvas);
    _paintCables(canvas);
    _paintTwinLinks(canvas);
    _paintPick(canvas);
    _paintNodes(canvas);
    _paintSnapRings(canvas);
    _paintParticles(canvas);
  }

  /// Живой фон: медленно дрейфующие пылинки-светлячки.
  void _paintDust(Canvas canvas, Size size) {
    final t = now / 1000.0;
    for (var i = 0; i < 16; i++) {
      final seed = i * 37.7;
      final x = size.width * (0.5 + 0.46 * math.sin(seed * 1.7 + t * (0.05 + i % 5 * 0.012)));
      final y = size.height * (0.5 + 0.44 * math.cos(seed * 2.3 + t * (0.04 + i % 7 * 0.01)));
      final tw = 0.5 + 0.5 * math.sin(t * (0.6 + i % 3 * 0.3) + seed);
      canvas.drawCircle(
        Offset(x, y),
        1.0 + (i % 3) * 0.6,
        Paint()..color = const Color(0xFF7CE0FF).withValues(alpha: 0.04 + 0.07 * tw),
      );
    }
  }

  // Протечка: мягкое синее пятно без границы.
  void _paintZones(Canvas canvas) {
    for (final z in play.zones) {
      final rect = Rect.fromLTWH(z.x, z.y, z.w, z.h);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x4D2979FF), const Color(0x1A2979FF), const Color(0x002979FF)],
          stops: const [0, .6, 1],
        ).createShader(rect.inflate(14));
      canvas.drawOval(rect.inflate(10), paint);
    }
  }

  void _paintSockets(Canvas canvas) {
    final dragging = play.dragIdx >= 0;
    for (var k = 0; k < play.sockets.length; k++) {
      final q = play.sockets[k];
      final c = Offset(q[0], q[1]);
      canvas.drawCircle(c, 20 * g, Paint()..color = const Color(0xFF0C1420));
      canvas.drawCircle(
          c,
          20,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (dragging ? 2.4 : 1.2) * g
            ..color = dragging ? const Color(0xF200E5FF) : const Color(0x2996BEEB));
      if (dragging) {
        canvas.drawCircle(c, 20 * g, Paint()..color = const Color(0x2900E5FF));
      }
      canvas.drawCircle(c, 16 * g, Paint()..color = const Color(0xFF04080E));
      // Верхняя тёмная и нижняя светлая дуги — объём каверны.
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xCC000000);
      canvas.drawArc(Rect.fromCircle(center: c, radius: 16), math.pi * 1.2, math.pi * .6, false, arc);
      arc
        ..strokeWidth = 2
        ..color = const Color(0x6BAACDF5);
      canvas.drawArc(Rect.fromCircle(center: c, radius: 16), math.pi * .2, math.pi * .6, false, arc);
      _dashedCircle(canvas, c, 8 * g,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = const Color(0x4D78A5D7));
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const seg = 3.0, gap = 4.0;
    final circ = 2 * math.pi * r;
    var a = 0.0;
    while (a < circ) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a / r, seg / r, false, paint);
      a += seg + gap;
    }
  }

  // ---------- кабели ----------
  Path _wirePath(Pt a, Pt b, double sag) {
    final mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
    final dx = b[0] - a[0], dy = b[1] - a[1];
    final s = math.min(26.0, math.sqrt(dx * dx + dy * dy) * 0.14) + sag;
    return Path()
      ..moveTo(a[0], a[1])
      ..quadraticBezierTo(mx, my + s, b[0], b[1]);
  }

  void _paintCables(Canvas canvas) {
    final bad = play.badEdges();
    for (var i = 0; i < play.edges.length; i++) {
      final e = play.edges[i];
      final isBad = bad.contains(i);
      final extra = (play.dragIdx == e[0] || play.dragIdx == e[1]) ? 6.0 : 0.0;
      var pal = isBad ? kCableBad : kCableOk;
      if (i == play.hiLite) pal = kCableHint;
      if (i == play.liveEdge) pal = kCableLive;
      if (play.bridges.contains(i)) pal = kCableBridge;
      var k = 1.0;
      if (i == play.hiLite || i == play.liveEdge) {
        k = 1.14;
      } else if (isBad) {
        k = 1.04;
      }
      final ghost =
          i == play.ghostEdge && play.dragIdx != e[0] && play.dragIdx != e[1];
      final flash = edgeFlash.containsKey(i);
      _paintCable(canvas, play.nodes[e[0]], play.nodes[e[1]], extra, pal, k,
          ghost: ghost, dash: play.bridges.contains(i), flash: flash);
    }
  }

  Color _mix(Color c, double toWhite) => Color.lerp(c, Colors.white, toWhite)!;

  void _paintCable(Canvas canvas, Pt a, Pt b, double sag, CablePal pal, double k,
      {required bool ghost, required bool dash, required bool flash}) {
    final path = _wirePath(a, b, sag);
    // Нормаль к хорде, всегда «вверх» — слои смещаются поперёк кабеля.
    var vx = b[0] - a[0], vy = b[1] - a[1];
    final ln = math.sqrt(vx * vx + vy * vy);
    var nx = 0.0, ny = -1.0;
    if (ln > 0) {
      nx = -vy / ln;
      ny = vx / ln;
      if (ny > 0) {
        nx = -nx;
        ny = -ny;
      }
    }
    final m = mat.w * g;
    final opacity = ghost ? 0.09 : (boomTint ? 0.25 : 1.0);
    final boost = flash ? .35 : 0.0;

    Color lc(Color c) {
      var col = boomTint ? const Color(0xFFE8564B) : c;
      if (boost > 0) col = _mix(col, boost);
      return col.withValues(alpha: col.a * opacity);
    }

    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = color;

    void drawLayer(double width, Color color, double off, {List<double>? dashPat}) {
      final p = path.shift(Offset(nx * off, ny * off));
      if (dashPat != null) {
        _drawDashedPath(canvas, p, stroke(width, color), dashPat);
      } else {
        canvas.drawPath(p, stroke(width, color));
      }
    }

    // Тень — в экранных координатах, свет сверху-слева.
    final shadow = stroke(CableW.shadow * k * m, Color.fromRGBO(0, 0, 0, .4 * opacity))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawPath(path.shift(Offset(3 * g, 6 * g)), shadow);

    final dashPat = dash ? const [15.0, 10.0] : null;
    drawLayer(CableW.base * k * m,
        lc(pal.l0).withValues(alpha: (mat.texMode == 'core' ? .5 : 1) * opacity), 0);
    drawLayer(CableW.mid * k * m,
        lc(pal.l1).withValues(alpha: (mat.texMode == 'core' ? .72 : 1) * opacity), 0.5 * g,
        dashPat: dashPat);
    drawLayer(CableW.top * k * m, lc(pal.l2), 2 * g, dashPat: dashPat);
    if (mat.hi > 0) {
      drawLayer(CableW.hi * k * m, lc(pal.l3).withValues(alpha: mat.hi * opacity), 3.6 * g,
          dashPat: dashPat);
    }
    // Фактура материала (жила/оплётка/спираль).
    if (mat.texMode != null) {
      final tw = CableW.base * k * m * mat.texWidth;
      final tc = mat.texMode == 'weave' ? const Color(0xFF06090F) : pal.l3;
      final ta = (mat.texMode == 'core' ? 1.2 : 2.6) * g;
      final texPaint = stroke(tw, lc(tc).withValues(alpha: mat.texOpacity * opacity))
        ..strokeCap = mat.texMode == 'core' ? StrokeCap.round : StrokeCap.butt;
      final p = path.shift(Offset(nx * ta, ny * ta));
      final pat = dash ? const [15.0, 10.0] : mat.texDash;
      if (pat != null) {
        _drawDashedPath(canvas, p, texPaint, pat);
      } else {
        canvas.drawPath(p, texPaint);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, List<double> pattern) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      var i = 0;
      while (d < metric.length) {
        final len = pattern[i % pattern.length];
        if (i.isEven) {
          canvas.drawPath(metric.extractPath(d, math.min(d + len, metric.length)), paint);
        }
        d += len;
        i++;
      }
    }
  }

  // Спайка: линия между спаянными узлами.
  void _paintTwinLinks(Canvas canvas) {
    final done = <int>{};
    play.twin.forEach((a, b) {
      if (done.contains(a) || done.contains(b)) return;
      done.addAll([a, b]);
      if (a >= play.nodes.length || b >= play.nodes.length) return;
      final p = play.nodes[a], q = play.nodes[b];
      canvas.drawLine(
        Offset(p[0], p[1]),
        Offset(q[0], q[1]),
        Paint()
          ..strokeWidth = 3 * g
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x80FFD400),
      );
    });
  }

  void _paintPick(Canvas canvas) {
    if (play.pickIdx < 0 || play.pickIdx >= play.sockets.length) return;
    final q = play.sockets[play.pickIdx];
    final c = Offset(q[0], q[1]);
    final s = 1 + 0.14 * math.sin(_pulse * 2 * math.pi).abs();
    canvas.drawCircle(c, 15 * s * g, Paint()..color = const Color(0x29FFD400));
    canvas.drawCircle(
        c,
        15 * s * g,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * g
          ..color = Pal.yellow);
    // Молния в центре — вектор, а не эмодзи-глиф.
    final bs = 8.0 * g;
    final bolt = Path()
      ..moveTo(c.dx + .25 * bs, c.dy - bs)
      ..lineTo(c.dx - .55 * bs, c.dy + .15 * bs)
      ..lineTo(c.dx - .05 * bs, c.dy + .15 * bs)
      ..lineTo(c.dx - .25 * bs, c.dy + bs)
      ..lineTo(c.dx + .55 * bs, c.dy - .15 * bs)
      ..lineTo(c.dx + .05 * bs, c.dy - .15 * bs)
      ..close();
    canvas.drawPath(bolt, Paint()..color = Pal.yellow);
  }

  // ---------- узлы ----------
  void _paintNodes(Canvas canvas) {
    final clean = play.crossings == 0;
    for (var i = 0; i < play.nodes.length; i++) {
      final n = play.nodes[i];
      final c = Offset(n[0], n[1]);
      final t = play.ntype[i];
      final isDrag = play.dragIdx == i;

      // Появление узлов: pop с лесенкой 45 мс.
      final age = now - buildTime - i * 45;
      var scale = 1.0;
      if (age < 0) {
        scale = 0;
      } else if (age < 450) {
        final x = age / 450;
        scale = Curves.elasticOut.transform(x.clamp(0, 1));
      }
      if (isDrag) scale *= 1.1;
      if (scale <= 0) continue;

      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(scale);

      // Кольцо состояния (box-shadow в исходнике).
      Color? ring;
      double ringW = 3;
      if (isDrag) ring = const Color(0x8CFFD400);
      if (t == 4) ring = const Color(0x66B8860B);
      if (t == 6) {
        ring = const Color(0x73B06CFF);
        ringW = 2.5;
      }
      if (t == 7) {
        ring = const Color(0x6BFF6BD6);
        ringW = 2.5;
      }
      if (t == 8) ring = const Color(0x59FFD400);
      if (i == play.bombIdx) {
        final k = .5 + .5 * math.sin(_pulse * 2 * math.pi);
        ring = Color.lerp(const Color(0x4DFF3B30), const Color(0x80FF3B30), k);
        ringW = 3 + 2 * k;
      }
      if (t == 2) {
        final k = .5 + .5 * math.sin(_pulse * 2 * math.pi);
        ring = Color.lerp(const Color(0x009FD16B), const Color(0x599FD16B), k);
        ringW = 4;
      }
      if (ring != null) {
        canvas.drawCircle(Offset.zero, 20 * g + ringW / 2,
            Paint()..color = ring..style = PaintingStyle.stroke..strokeWidth = ringW);
      }

      // Тень.
      canvas.drawCircle(
          Offset(0, 5 * g),
          20 * g,
          Paint()
            ..color = const Color(0x9E000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

      // Металлический фланец.
      final flange = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCE6F2), Color(0xFF93A2B6), Color(0xFF4C596B), Color(0xFF7C8A9C)],
          stops: [0, .34, .62, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 20 * g));
      canvas.drawCircle(Offset.zero, 20 * g, flange);
      canvas.drawCircle(
          Offset.zero,
          20 * g,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x8C060A12));

      // Каверна.
      final cavity = Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.36),
          colors: [Color(0xFF101A26), Color(0xFF03060B)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 15 * g));
      canvas.drawCircle(Offset.zero, 15 * g, cavity);

      // Ядро: цвет состояния.
      final (coreHi, coreMid, coreLo) = _coreColors(i, t, clean, isDrag);
      final core = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.16, -.32),
          colors: [coreHi, coreMid, coreLo],
          stops: const [0, .38, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 9 * g));
      // Свечение ядра.
      canvas.drawCircle(Offset.zero, 9 * g,
          Paint()..color = coreMid.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(Offset.zero, 9 * g, core);

      canvas.restore();

      // Счётчик бомбы.
      if (i == play.bombIdx) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${play.bombLeft}',
            style: const TextStyle(
                fontFamily: Fonts.disp,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bc = c + Offset(12 * g, -20 * g);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: bc, width: math.max(19, tp.width + 8), height: 19),
              const Radius.circular(10)),
          Paint()..color = Pal.red,
        );
        tp.paint(canvas, bc - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  (Color, Color, Color) _coreColors(int i, int t, bool clean, bool isDrag) {
    if (isDrag) return (const Color(0xFFFFF6D8), const Color(0xFFFFD400), const Color(0xFF7A6200));
    switch (t) {
      case 1:
        return (const Color(0xFFFFF1CE), const Color(0xFFF0C14B), const Color(0xFF6B5320));
      case 4:
        return (const Color(0xFFFFEEC0), const Color(0xFFB8860B), const Color(0xFF2E2408));
      case 2:
        return (const Color(0xFFEBFFDD), const Color(0xFF9FD16B), const Color(0xFF33511C));
      case 3:
        return (const Color(0xFFE4E4EC), const Color(0xFFB9B9C4), const Color(0xFF4A4A55));
      case 6:
        return (const Color(0xFFF0E2FF), const Color(0xFFB06CFF), const Color(0xFF3D1A6B));
      case 7:
        return (const Color(0xFFFFE0F6), const Color(0xFFFF6BD6), const Color(0xFF6B1454));
      case 8:
        return (const Color(0xFFFFF6CC), const Color(0xFFFFD400), const Color(0xFF6B5300));
    }
    if (i == play.bombIdx) {
      return (const Color(0xFFFFDCD9), const Color(0xFFFF3B30), const Color(0xFF6B0F0A));
    }
    if (clean) {
      return (const Color(0xFFE8FFF2), const Color(0xFF00E676), const Color(0xFF046B34));
    }
    return (const Color(0xFFEAFDFF), const Color(0xFF4FE6FF), const Color(0xFF00697E));
  }

  void _paintSnapRings(Canvas canvas) {
    for (final (p, t0) in snapRings) {
      final k = ((now - t0) / 430).clamp(0.0, 1.0);
      final r = (20 + 32 * k) * g;
      canvas.drawCircle(
          Offset(p[0], p[1]),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * (1 - k) + .5
            ..color = Pal.cyan.withValues(alpha: (1 - k) * .8));
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final p in particles) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(p.x, p.y), width: 4, height: 4),
        Paint()..color = p.color.withValues(alpha: p.life.clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) => true;
}
