// Скриншоты экранов для визуальной проверки дизайна.
// Запуск: flutter test test/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/main.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/state/play_state.dart';
import 'package:synapse/ui/overlays/result_overlay.dart';
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
  await load('JetBrains Mono', ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Уровень генерируется случайно, поэтому эталоны не сравниваем —
  // тест существует только для съёмки экранов (запуск с --update-goldens).
  testWidgets('скриншоты экранов', skip: !autoUpdateGoldenFiles,
      (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
    final app = AppState()..loadSaved();
    app.setLang('ru');

    await tester.pumpWidget(SynapseApp(app: app));

    Future<void> shot(String name) async {
      await expectLater(find.byType(SynapseApp),
          matchesGoldenFile('goldens/$name.png'));
      stdout.writeln('shot: $name');
    }

    // Загрузка (середина анимации).
    await tester.pump(const Duration(milliseconds: 1200));
    await shot('01-boot');

    // Интро, панель 1.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 900));
    await shot('02-intro');

    // Пропускаем интро.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 800));
      final next = find.textContaining(RegExp('Дальше|Начать'));
      if (next.evaluate().isEmpty) break;
      await tester.tap(next.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Уровень 1.
    await tester.pump(const Duration(milliseconds: 1200));
    await shot('03-play');

    // Хаб.
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Glyph && w.kind == GlyphKind.close));
    await tester.pump(const Duration(milliseconds: 1000));
    await shot('04-hub');

    // Склад.
    await tester.tap(find.text('СКЛАД'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('05-shop');
  });

  testWidgets('экран результата', skip: !autoUpdateGoldenFiles, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
    final app = AppState()..loadSaved();
    app.setLang('ru');

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'JetBrains Mono'),
      home: Scaffold(
        body: ResultOverlay(
          app: app,
          result: const LevelResult(true, 3, 2, 4, 0, 9, 12, 10),
          onNext: () {},
          onHub: () {},
          onContinue: () {},
          onToast: (_) {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/06-result.png'));
    stdout.writeln('shot: 06-result');
  });
}
