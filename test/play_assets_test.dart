// Ресурсы для Google Play: значок 512, картинка для описания 1024x500
// и скриншоты (телефон 1080x1920 · 9:16, планшет 2560x1440 · 16:9 —
// один комплект годится и для 7", и для 10").
// Запуск: flutter test test/play_assets_test.dart --update-goldens
// Результат: game/out/playstore/
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse/core/palette.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/main.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/state/play_state.dart';
import 'package:synapse/ui/overlays/mech_overlay.dart';
import 'package:synapse/ui/overlays/result_overlay.dart';
import 'package:synapse/ui/overlays/story_overlay.dart';
import 'package:synapse/ui/widgets/common.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('Unbounded', ['Unbounded-Bold.ttf', 'Unbounded-Black.ttf']);
  await load(
      'JetBrains Mono', ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf']);
}

// ---------------------------------------------------------------------------
// Картинка для описания (feature graphic) 1024x500 — арт в стиле иконки.
// ---------------------------------------------------------------------------

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
  c.drawPath(
      path.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
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
  c.drawCircle(
      p,
      r * 1.12,
      Paint()
        ..color = const Color(0x4DFF2ED1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
  c.drawCircle(
      p.translate(0, r * .12),
      r,
      Paint()
        ..color = const Color(0xB3000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
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
  c.drawCircle(
      p,
      r * .74,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.36),
          colors: [Color(0xFF101A26), Color(0xFF03060B)],
        ).createShader(Rect.fromCircle(center: p, radius: r * .74)));
  c.drawCircle(
      p,
      r * .5,
      Paint()
        ..color = const Color(0x80FF2ED1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
  c.drawCircle(
      p,
      r * .42,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.16, -.32),
          colors: [Color(0xFFFFE6F8), Color(0xFFFF2ED1), Color(0xFF6B0C55)],
          stops: [0, .38, 1],
        ).createShader(Rect.fromCircle(center: p, radius: r * .42)));
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

void _paintFeature(Canvas c, String tagline) {
  const w = 1024.0, h = 500.0;
  const rect = Rect.fromLTWH(0, 0, w, h);
  c.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 1.4,
          colors: [Color(0xFF162244), Color(0xFF070B18), Color(0xFF03050C)],
          stops: [0, .55, 1],
        ).createShader(rect));
  c.drawCircle(
      const Offset(90, 70),
      180,
      Paint()
        ..color = const Color(0x1AFF2ED1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90));
  c.drawCircle(
      const Offset(960, 460),
      190,
      Paint()
        ..color = const Color(0x1F00E5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90));

  // Искры-пылинки.
  final rnd = math.Random(7);
  for (var i = 0; i < 18; i++) {
    final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
    final r = 1.0 + rnd.nextDouble() * 2.4;
    final col = const [
      Color(0xFF00E5FF),
      Color(0xFFFF2ED1),
      Color(0xFFFFD400),
    ][rnd.nextInt(3)];
    c.drawCircle(p, r * 2.4,
        Paint()..color = col.withValues(alpha: .16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    c.drawCircle(p, r, Paint()..color = col.withValues(alpha: .75));
  }

  // Кабели уходят к штекеру справа; бирюзовый «мост» позади.
  const plugAt = Offset(810, 258);
  _cable(c, const Offset(560, 560), const Offset(700, 380),
      const Offset(1084, 60), 26, cyan: true);
  _cable(c, const Offset(1084, 430), const Offset(940, 400), plugAt, 40);
  _cable(c, const Offset(560, -40), const Offset(660, 120), plugAt, 40);
  _plug(c, plugAt, 128);

  // Заголовок и подпись — слева, в фирменных шрифтах.
  final title = TextPainter(
    text: const TextSpan(
      text: 'SYNAPSE',
      style: TextStyle(
        fontFamily: Fonts.disp,
        fontWeight: FontWeight.w900,
        fontSize: 96,
        letterSpacing: 4,
        color: Pal.text,
        shadows: [
          Shadow(color: Color(0x8000E5FF), blurRadius: 34),
          Shadow(color: Color(0x59FF2ED1), blurRadius: 60, offset: Offset(0, 6)),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  title.paint(c, Offset(64, h / 2 - title.height / 2 - 34));

  final sub = TextPainter(
    text: TextSpan(
      text: tagline,
      style: const TextStyle(
        fontFamily: Fonts.mono,
        fontWeight: FontWeight.w700,
        fontSize: 25,
        letterSpacing: 7,
        color: Pal.cyan,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  sub.paint(c, Offset(68, h / 2 + 34));

  // Виньетка.
  c.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 1.1,
          colors: [Color(0x00000000), Color(0x4D000000)],
          stops: [.72, 1],
        ).createShader(rect));
}

Future<void> _savePng(String path, ui.Image img) async {
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  img.dispose();
}

// ---------------------------------------------------------------------------
// Скриншоты: тот же сценарий, что для App Store, в размерах Google Play.
// ---------------------------------------------------------------------------

const _captions = {
  'ru': [
    'Разведи провода так,\nчтобы ни один не пересекался',
    'Ноль пересечений —\nсвязь восстановлена',
    'Каждая связь возвращает\nмодели память',
    '14 элементов поля,\nу каждого своё правило',
    'История машины,\nкоторая вспоминает себя',
    'Всё в лавке\nзарабатывается игрой',
  ],
  'en': [
    'Route the wires so that\nnone of them cross',
    'Zero crossings —\nlink restored',
    'Every link brings back\nthe model’s memory',
    '14 field elements,\neach with its own rule',
    'A story of a machine\nremembering itself',
    'Everything in the shop\nis earned by playing',
  ],
};

Widget _frame(String caption, Widget child,
    {double capHeight = 96, double fontSize = 15}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
    home: ColoredBox(
      color: const Color(0xFF04060E),
      child: Column(children: [
        SizedBox(
          height: capHeight,
          child: Center(
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Fonts.disp,
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                height: 1.4,
                letterSpacing: 1.4,
                color: Pal.text,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        Expanded(child: ClipRect(child: child)),
      ]),
    ),
  );
}

Future<AppState> _makeApp(String lang) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.instance.init();
  final app = AppState()..loadSaved();
  app.setLang(lang);
  app.introSeen = true;
  app.birthYear = 1995;
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('значок 512 и картинка для описания', skip: !autoUpdateGoldenFiles,
      (tester) async {
    await tester.runAsync(() async {
      await _loadFonts();

      // Значок: авторский арт assets/icon/icon.png уменьшается до 512.
      final raw = File('assets/icon/icon.png').readAsBytesSync();
      final src = await decodeImageFromList(raw);
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        const Rect.fromLTWH(0, 0, 512, 512),
        Paint()..filterQuality = FilterQuality.high,
      );
      await _savePng('../out/playstore/icon-512.png',
          await rec.endRecording().toImage(512, 512));
      src.dispose();

      // Картинка для описания — ru и en варианты.
      for (final (name, tag) in [
        ('feature-1024x500-ru.png', 'РАСПУТАЙ СЕТЬ'),
        ('feature-1024x500-en.png', 'UNTANGLE THE NET'),
      ]) {
        final r2 = ui.PictureRecorder();
        _paintFeature(Canvas(r2), tag);
        await _savePng(
            '../out/playstore/$name', await r2.endRecording().toImage(1024, 500));
      }
    });
  });

  // (папка, ширина, высота, dpr, высота подписи, кегль подписи)
  const devices = [
    ('phone-1080x1920', 360.0, 640.0, 3.0, 96.0, 15.0), // 9:16, телефон
    ('tablet-2560x1440', 1280.0, 720.0, 2.0, 104.0, 19.0), // 16:9, планшеты 7"/10"
  ];

  for (final (dev, w, h, dpr, capH, capF) in devices) {
    for (final lang in ['ru', 'en']) {
      testWidgets('play-витрина $dev $lang', skip: !autoUpdateGoldenFiles,
          (tester) async {
        await _loadFonts();
        tester.view.physicalSize = Size(w * dpr, h * dpr);
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);
        final cap = _captions[lang]!;
        var n = 0;

        Widget frame(String c, Widget child) =>
            _frame(c, child, capHeight: capH, fontSize: capF);

        String out(int i) => '../../out/playstore/$dev/$lang/0$i.png';

        Future<void> shot(Widget f, {int settleMs = 600}) async {
          n++;
          await tester.pumpWidget(f);
          await tester.pump(Duration(milliseconds: settleMs));
          await expectLater(
              find.byType(MaterialApp).first, matchesGoldenFile(out(n)));
          stdout.writeln('shot: playstore/$dev/$lang/0$n');
        }

        // 1. Игровое поле с пересечениями (связь №8 — живой клубок).
        final app1 = await _makeApp(lang);
        app1.level = 8;
        await tester.pumpWidget(frame(cap[0], SynapseApp(app: app1)));
        await tester.pump(const Duration(milliseconds: 2750)); // загрузка
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byType(PillButton).first);
        // Два pump'а: первый строит кадр и запускает SlideUpIn игрового
        // экрана, второй доводит анимацию до конца (иначе в кадр попадает
        // хаб, а поле ещё за нижней границей).
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 1400)); // pop узлов
        n = 1;
        await expectLater(
            find.byType(MaterialApp).first, matchesGoldenFile(out(1)));
        stdout.writeln('shot: playstore/$dev/$lang/01');

        // 2. Победа: связь восстановлена.
        final app2 = await _makeApp(lang);
        await shot(frame(
          cap[1],
          Scaffold(
            body: ResultOverlay(
              app: app2,
              result: const LevelResult(true, 3, 2, 7, 0, 11, 14, 11),
              onNext: () {},
              onHub: () {},
              onContinue: () {},
              onToast: (_) {},
            ),
          ),
        ));

        // 3. Хаб: целостность модели растёт.
        final app3 = await _makeApp(lang);
        app3.tokens = 34;
        for (var i = 0; i < 5; i++) {
          app3.spent += app3.tasks[i].cost;
          app3.done[i] = true;
        }
        app3.level = 23;
        app3.shards = 6;
        await tester.pumpWidget(frame(cap[2], SynapseApp(app: app3)));
        await tester.pump(const Duration(milliseconds: 2750));
        await tester.pump(const Duration(milliseconds: 1000));
        n = 3;
        await expectLater(
            find.byType(MaterialApp).first, matchesGoldenFile(out(3)));
        stdout.writeln('shot: playstore/$dev/$lang/03');

        // 4. Карточка механики: нестабильный узел (бомба).
        final app4 = await _makeApp(lang);
        await shot(frame(
          cap[3],
          Scaffold(
            body: MechOverlay(
              app: app4,
              card: const MechCard('fill', 2),
              maxBridges: 2,
              onOk: () {},
            ),
          ),
        ));

        // 5. Сюжет.
        final app5 = await _makeApp(lang);
        await shot(
          frame(
            cap[4],
            Scaffold(
              body: StoryOverlay(
                app: app5,
                mode: StoryMode.intro,
                onDone: () {},
              ),
            ),
          ),
          settleMs: 900,
        );

        // 6. Склад.
        final app6 = await _makeApp(lang);
        app6.shards = 9;
        app6.tokens = 12;
        await tester.pumpWidget(frame(cap[5], SynapseApp(app: app6)));
        await tester.pump(const Duration(milliseconds: 2750));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text(app6.t('tab2')).first);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 500));
        n = 6;
        await expectLater(
            find.byType(MaterialApp).first, matchesGoldenFile(out(6)));
        stdout.writeln('shot: playstore/$dev/$lang/06');

        // Демонтируем дерево, чтобы таймеры уровня погасились.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      });
    }
  }
}
