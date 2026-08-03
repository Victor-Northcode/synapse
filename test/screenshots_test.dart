// Скриншоты экранов для визуальной проверки дизайна.
// Запуск: flutter test test/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/ui/screens/leaderboard_screen.dart';
import 'package:synapse/main.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/state/play_state.dart';
import 'package:synapse/ui/overlays/result_overlay.dart';
import 'package:synapse/ui/screens/play_screen.dart';
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

    // Склад: два pump — первый запускает анимацию перехода вкладки,
    // второй дорисовывает её до конца.
    await tester.tap(find.text('СКЛАД'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('05-shop');

    // Топ игроков.
    await tester.tap(find.text('ТОП'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));
    await shot('10-top');
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

  testWidgets('iPad альбом: хаб, игра, сюжет', skip: !autoUpdateGoldenFiles,
      (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1194 * 2, 834 * 2); // iPad Pro 11 альбом
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
    final app = AppState()..loadSaved();
    app.setLang('ru');
    app.introSeen = true;
    app.tokens = 34;
    app.shards = 7;
    app.level = 12;

    await tester.pumpWidget(SynapseApp(app: app));
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
        find.byType(SynapseApp), matchesGoldenFile('goldens/08-ipad-hub.png'));
    stdout.writeln('shot: 08-ipad-hub');

    // Игровой экран в альбоме. Появление узлов завязано на реальное
    // время, поэтому ждём по-настоящему, а не виртуальными кадрами.
    await tester.tap(find.textContaining(RegExp('связь #')));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 1600)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(PlayScreen), findsOneWidget,
        reason: 'кнопка связи должна открывать уровень');
    await expectLater(
        find.byType(SynapseApp), matchesGoldenFile('goldens/09-ipad-play.png'));
    stdout.writeln('shot: 09-ipad-play');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('экран топа', skip: !autoUpdateGoldenFiles, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
    final app = AppState()..loadSaved();
    app.setLang('ru');

    PlayerData holder(String name) =>
        PlayerData.fromJson({'displayName': name, 'playerID': name, 'iconImage': null});
    LeaderboardScoreData row(int rank, String name, int score) =>
        LeaderboardScoreData(
            rank: rank,
            displayScore: '$score',
            rawScore: score,
            timestampMillis: 0,
            scoreHolder: holder(name));
    final rows = [
      row(1, 'VESPER_OP', 214),
      row(2, 'neon_kid', 187),
      row(3, 'Оператор 9', 165),
      row(4, 'tanglefox', 140),
      row(5, 'MERIDIAN', 128),
      row(6, 'wire_witch', 117),
      row(7, 'Kestrel', 103),
      row(8, 'plug&play', 96),
      row(9, 'somebody', 88),
      row(10, 'HALCYON', 71),
    ];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'JetBrains Mono'),
      home: Scaffold(
        body: LeaderboardScreen(
          app: app,
          onClose: () {},
          previewData: (rows, row(37, 'Ты', 24)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/07-leaderboard.png'));
    stdout.writeln('shot: 07-leaderboard');
  });
}
