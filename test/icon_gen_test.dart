// Генератор иконки приложения — арт в стиле игры (штекер + кабели),
// рисуется кодом и сохраняется в assets/icon/.
// Запуск: flutter test test/icon_gen_test.dart --update-goldens
// затем: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

void _cable(Canvas c, Offset a, Offset ctrl, Offset b, double w,
    {bool cyan = false}) {
  final path = Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
  final layers = cyan
      ? [
          (const Color(0xFF062430), w),
          (const Color(0xFF0E5F72), w * .74),
          (const Color(0xFF22A8C4), w * .42),
          (const Color(0xFF8FE9FF), w * .12),
        ]
      : [
          (const Color(0xFF031B13), w),
          (const Color(0xFF0E6E42), w * .74),
          (const Color(0xFF1FAE63), w * .42),
          (const Color(0xFF5FD996), w * .12),
        ];
  // Тень под кабелем.
  c.drawPath(
      path.shift(const Offset(0, 14)),
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
  for (final (col, sw) in layers) {
    c.drawPath(
        path,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
  }
}

void _plug(Canvas c, Offset p, double r) {
  // Неоновое гало — узкое, чтобы фон не заливало розовым.
  c.drawCircle(
      p,
      r * 1.12,
      Paint()
        ..color = const Color(0x4DFF2ED1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55));
  // Тень.
  c.drawCircle(
      p.translate(0, r * .12),
      r,
      Paint()
        ..color = const Color(0xB3000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
  // Металлическое кольцо.
  c.drawCircle(
      p,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDCE6F2),
            Color(0xFF93A2B6),
            Color(0xFF4C596B),
            Color(0xFF7C8A9C),
          ],
          stops: [0, .34, .62, 1],
        ).createShader(Rect.fromCircle(center: p, radius: r)));
  // Тёмная сердцевина.
  c.drawCircle(
      p,
      r * .74,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.36),
          colors: [Color(0xFF101A26), Color(0xFF03060B)],
        ).createShader(Rect.fromCircle(center: p, radius: r * .74)));
  // Магента-ядро.
  c.drawCircle(
      p,
      r * .5,
      Paint()
        ..color = const Color(0x80FF2ED1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34));
  c.drawCircle(
      p,
      r * .42,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.16, -.32),
          colors: [Color(0xFFFFE6F8), Color(0xFFFF2ED1), Color(0xFF6B0C55)],
          stops: [0, .38, 1],
        ).createShader(Rect.fromCircle(center: p, radius: r * .42)));
  // Блик на кольце.
  c.drawArc(
      Rect.fromCircle(center: p, radius: r * .88),
      -math.pi * .82,
      math.pi * .5,
      false,
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .07
        ..strokeCap = StrokeCap.round);
}

void _sparks(Canvas c, int seed, double scale) {
  final rnd = math.Random(seed);
  for (var i = 0; i < 14; i++) {
    final p = Offset(rnd.nextDouble() * _size, rnd.nextDouble() * _size);
    final r = (1.5 + rnd.nextDouble() * 3.5) * scale;
    final col = [
      const Color(0xFF00E5FF),
      const Color(0xFFFF2ED1),
      const Color(0xFFFFD400),
    ][rnd.nextInt(3)];
    c.drawCircle(
        p, r * 2.4, Paint()..color = col.withValues(alpha: .18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawCircle(p, r, Paint()..color = col.withValues(alpha: .8));
  }
}

/// Полная иконка: фон + сцена.
void _paintIcon(Canvas c) {
  const center = Offset(_size / 2, _size / 2 - 20);
  // Фон.
  c.drawRect(
      const Rect.fromLTWH(0, 0, _size, _size),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.15,
          colors: [Color(0xFF162244), Color(0xFF070B18), Color(0xFF03050C)],
          stops: [0, .55, 1],
        ).createShader(const Rect.fromLTWH(0, 0, _size, _size)));
  // Цветные дымки по углам — едва заметные.
  c.drawCircle(
      const Offset(120, 110),
      260,
      Paint()
        ..color = const Color(0x1AFF2ED1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 150));
  c.drawCircle(
      const Offset(920, 940),
      270,
      Paint()
        ..color = const Color(0x1F00E5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 150));

  _sparks(c, 7, 1);

  // Кабели: бирюзовый «мост» позади, два зелёных к штекеру.
  _cable(c, const Offset(-80, 850), const Offset(430, 640),
      const Offset(1104, 210), 58, cyan: true);
  _cable(c, const Offset(-80, 300), const Offset(290, 210), center, 92);
  _cable(c, const Offset(1104, 760), const Offset(770, 800), center, 92);

  _plug(c, center, 300);

  // Виньетка.
  c.drawRect(
      const Rect.fromLTWH(0, 0, _size, _size),
      Paint()
        ..shader = const RadialGradient(
          radius: .95,
          colors: [Color(0x00000000), Color(0x59000000)],
          stops: [.72, 1],
        ).createShader(const Rect.fromLTWH(0, 0, _size, _size)));
}

/// Foreground адаптивной иконки: прозрачный фон, арт в безопасной зоне.
void _paintForeground(Canvas c) {
  const center = Offset(_size / 2, _size / 2);
  c.save();
  c.translate(center.dx, center.dy);
  c.scale(.60);
  c.translate(-center.dx, -center.dy);
  _cable(c, const Offset(-260, 260), const Offset(240, 190), center, 100);
  _cable(c, const Offset(1284, 790), const Offset(800, 830), center, 100);
  _plug(c, center, 320);
  c.restore();
}

Future<void> _save(String path, void Function(Canvas) paint) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(_size.toInt(), _size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  img.dispose();
}

void main() {
  // ОТКЛЮЧЕНО: владелец положил собственный арт в assets/icon/ —
  // генератор оставлен как референс, но не должен его перезаписывать.
  testWidgets('иконка приложения', skip: true,
      (tester) async {
    await tester.runAsync(() async {
      await _save('assets/icon/icon.png', _paintIcon);
      await _save('assets/icon/icon-foreground.png', _paintForeground);
    });
  });
}
