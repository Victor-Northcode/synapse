// Бюджет производительности: кадр игрового поля обязан рисоваться
// заметно быстрее 16 мс, иначе на слабом телефоне будут просадки.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/state/play_state.dart';
import 'package:synapse/ui/widgets/field_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Замер идёт в программной растеризации (в тестах нет GPU), поэтому
  // цифры заведомо хуже, чем на устройстве. Бюджеты выставлены как
  // сторож от регрессий, а не как оценка реального fps.
  Future<PlayState> heavyLevel({double w = 360, double h = 620}) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
    final app = AppState()..loadSaved();
    // Уровень 60 — максимум узлов и рёбер.
    return PlayState(app, w, h)..start(60);
  }

  testWidgets('кадр поля рисуется быстрее бюджета', (tester) async {
    final play = await heavyLevel(w: 900, h: 780);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 900,
          height: 780,
          child: FieldWidget(play: play, themeIndex: 0),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Рисуем сцену в изоляции много раз и берём среднее.
    final painter = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(FieldWidget), matching: find.byType(CustomPaint)));
    const runs = 60;
    final sw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.painter!.paint(canvas, const Size(900, 780));
      recorder.endRecording().dispose();
    }
    sw.stop();
    final perFrame = sw.elapsedMicroseconds / runs / 1000.0;
    // ignore: avoid_print
    print('paint: ${perFrame.toStringAsFixed(2)} ms/кадр '
        '(${play.nodes.length} узлов, ${play.edges.length} кабелей)');
    expect(perFrame, lessThan(8.0),
        reason: 'отрисовка поля должна укладываться в половину кадра 60 fps');

    // С растеризацией: здесь считаются размытия теней и свечений —
    // самая дорогая часть на слабых GPU.
    await tester.runAsync(() async {
      const rasterRuns = 15;
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < rasterRuns; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.painter!.paint(canvas, const Size(900, 780));
        final pic = recorder.endRecording();
        final img = await pic.toImage(900, 780);
        img.dispose();
        pic.dispose();
      }
      sw2.stop();
      final raster = sw2.elapsedMicroseconds / rasterRuns / 1000.0;
      // ignore: avoid_print
      print('raster (планшет 900x780, software): ${raster.toStringAsFixed(2)} ms');
      expect(raster, lessThan(22.0),
          reason: 'планшетный кадр в софтверной растеризации: сторож от регрессий');
    });

    play.quit();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    play.dispose();
  });

  testWidgets('телефонный кадр укладывается в 60 fps', (tester) async {
    final play = await heavyLevel(); // 360x620 — типичный телефон
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 620,
          child: FieldWidget(play: play, themeIndex: 3), // самый тяжёлый материал
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final painter = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(FieldWidget), matching: find.byType(CustomPaint)));

    await tester.runAsync(() async {
      const runs = 20;
      final sw = Stopwatch()..start();
      for (var i = 0; i < runs; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.painter!.paint(canvas, const Size(360, 620));
        final pic = recorder.endRecording();
        final img = await pic.toImage(360, 620);
        img.dispose();
        pic.dispose();
      }
      sw.stop();
      final raster = sw.elapsedMicroseconds / runs / 1000.0;
      // ignore: avoid_print
      print('raster (телефон 360x620, software): ${raster.toStringAsFixed(2)} ms');
      expect(raster, lessThan(16.0), reason: 'телефонный кадр — строгий бюджет');
    });

    play.quit();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    play.dispose();
  });

  test('пересчёт пересечений не тормозит перетаскивание', () async {
    final play = await heavyLevel();
    // 300 движений пальцем — примерно пять секунд активного перетаскивания.
    play.pointerDown(0, play.nodes[0][0], play.nodes[0][1]);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 300; i++) {
      play.pointerMove(100 + i % 200, 120 + (i * 7) % 300);
    }
    sw.stop();
    final per = sw.elapsedMicroseconds / 300 / 1000.0;
    // ignore: avoid_print
    print('drag: ${per.toStringAsFixed(3)} ms/движение');
    expect(per, lessThan(4.0), reason: 'перетаскивание должно быть мгновенным');
    play.quit();
    play.dispose();
  });
}
