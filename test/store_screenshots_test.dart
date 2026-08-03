// Скриншоты для App Store: 6.9" iPhone (1320x2868) и 13" iPad (2064x2752),
// локали ru/en, подписи по спецификации STORE.md (сверху, фон #04060E).
// Запуск: flutter test test/store_screenshots_test.dart --update-goldens
import 'dart:io';

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
  await load('JetBrains Mono', ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf']);
}

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

/// Кадр витрины: подпись сверху на фоне #04060E, ниже — живой экран игры.
Widget _frame(String caption, Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
    home: ColoredBox(
      color: const Color(0xFF04060E),
      child: Column(children: [
        SizedBox(
          height: 132,
          child: Center(
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Fonts.disp,
                fontWeight: FontWeight.w700,
                fontSize: 19,
                height: 1.4,
                letterSpacing: 1.6,
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
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // (устройство, ширина, высота, dpr) — физический размер = логический × dpr.
  const devices = [
    ('iphone69', 440.0, 956.0, 3.0), // 1320x2868
    ('iphone65', 428.0, 926.0, 3.0), // 1284x2778
    ('ipad13', 1032.0, 1376.0, 2.0), // 2064x2752
  ];

  for (final (dev, w, h, dpr) in devices) {
    for (final lang in ['ru', 'en']) {
      testWidgets('витрина $dev $lang', skip: !autoUpdateGoldenFiles,
          (tester) async {
        await _loadFonts();
        tester.view.physicalSize = Size(w * dpr, h * dpr);
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);
        final cap = _captions[lang]!;
        var n = 0;

        Future<void> shot(Widget frame, {int settleMs = 600}) async {
          n++;
          await tester.pumpWidget(frame);
          await tester.pump(Duration(milliseconds: settleMs));
          await expectLater(find.byType(MaterialApp).first,
              matchesGoldenFile('goldens/store/$dev-$lang-$n.png'));
          stdout.writeln('shot: store/$dev-$lang-$n');
        }

        // 1. Игровое поле с пересечениями.
        final app1 = await _makeApp(lang);
        await tester.pumpWidget(_frame(cap[0], SynapseApp(app: app1)));
        await tester.pump(const Duration(milliseconds: 2750)); // загрузка
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byType(PillButton).first);
        await tester.pump(const Duration(milliseconds: 1300)); // pop узлов
        n = 1;
        await expectLater(find.byType(MaterialApp).first,
            matchesGoldenFile('goldens/store/$dev-$lang-1.png'));
        stdout.writeln('shot: store/$dev-$lang-1');

        // 2. Победа: связь восстановлена.
        final app2 = await _makeApp(lang);
        await shot(_frame(
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
        await tester.pumpWidget(_frame(cap[2], SynapseApp(app: app3)));
        await tester.pump(const Duration(milliseconds: 2750));
        await tester.pump(const Duration(milliseconds: 1000));
        n = 3;
        await expectLater(find.byType(MaterialApp).first,
            matchesGoldenFile('goldens/store/$dev-$lang-3.png'));
        stdout.writeln('shot: store/$dev-$lang-3');

        // 4. Карточка механики: нестабильный узел (бомба).
        final app4 = await _makeApp(lang);
        await shot(_frame(
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
          _frame(
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
        await tester.pumpWidget(_frame(cap[5], SynapseApp(app: app6)));
        await tester.pump(const Duration(milliseconds: 2750));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text(app6.t('tab2')).first);
        await tester.pump(const Duration(milliseconds: 400));
        n = 6;
        await expectLater(find.byType(MaterialApp).first,
            matchesGoldenFile('goldens/store/$dev-$lang-6.png'));
        stdout.writeln('shot: store/$dev-$lang-6');

        // Демонтируем дерево, чтобы таймеры уровня погасились.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      });
    }
  }
}
