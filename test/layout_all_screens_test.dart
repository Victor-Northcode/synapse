// Каждый экран открывается на каждом размере и в обеих ориентациях.
// Любое переполнение вёрстки (RenderFlex overflow) роняет тест.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:games_services/games_services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse/core/palette.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/state/play_state.dart';
import 'package:synapse/ui/overlays/mech_overlay.dart';
import 'package:synapse/ui/overlays/privacy_overlay.dart';
import 'package:synapse/ui/overlays/result_overlay.dart';
import 'package:synapse/ui/overlays/story_overlay.dart';
import 'package:synapse/ui/screens/boot_screen.dart';
import 'package:synapse/ui/screens/leaderboard_screen.dart';
import 'package:synapse/ui/screens/play_screen.dart';

/// Реальный набор устройств: от самого узкого телефона до iPad Pro,
/// в обеих ориентациях (телефоны в альбоме тоже — Android допускает
/// принудительный поворот в некоторых оболочках и split-screen).
const _sizes = <(String, Size)>[
  ('phone-320', Size(320, 568)),
  ('fold-closed', Size(280, 653)),
  ('phone-360', Size(360, 640)),
  ('phone-430', Size(430, 932)),
  ('phone-land', Size(740, 360)),
  ('tablet-768', Size(768, 1024)),
  ('tablet-land', Size(1024, 768)),
  ('tablet-pro', Size(1366, 1024)),
  ('split-600', Size(600, 900)),
];

Future<AppState> _app(String lang) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.instance.init();
  final app = AppState()..loadSaved();
  app.setLang(lang);
  app.introSeen = true;
  app.birthYear = 1995;
  app.tokens = 40;
  app.shards = 9;
  app.level = 12;
  return app;
}

Widget _wrap(AppState app, Widget child) => ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: Fonts.mono),
        home: Scaffold(backgroundColor: Pal.bg, body: child),
      ),
    );

PlayerData _holder(String n) =>
    PlayerData.fromJson({'displayName': n, 'playerID': n, 'iconImage': null});

LeaderboardScoreData _row(int rank, String name, int score) => LeaderboardScoreData(
    rank: rank,
    displayScore: '$score',
    rawScore: score,
    timestampMillis: 0,
    scoreHolder: _holder(name));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, size) in _sizes) {
    // ru — основной, de — самые длинные слова, ar — RTL.
    for (final lang in ['ru', 'de', 'ar']) {
      testWidgets('$name $lang: все экраны без переполнений', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final app = await _app(lang);

        Future<void> show(Widget w, {int ms = 260}) async {
          await tester.pumpWidget(_wrap(app, w));
          await tester.pump(Duration(milliseconds: ms));
        }

        // Загрузка.
        await show(BootScreen(onDone: () {}), ms: 1200);

        // Игровой экран (портрет и альбом раскладываются по-разному).
        final play = PlayState(app, size.width - 40, size.height - 300)..start(12);
        await show(PlayScreen(
          play: play,
          onQuit: () {},
          onHintAd: () async {},
          onInfo: (_) {},
        ));

        // Результат: победа и провал.
        for (final win in [true, false]) {
          await show(ResultOverlay(
            app: app,
            result: LevelResult(win, 3, 2, 12, win ? 0 : 4, 14, 18, 15),
            onNext: () {},
            onHub: () {},
            onContinue: () {},
            onToast: (_) {},
          ));
        }

        // Карточки механик: самая длинная подпись и мост.
        for (final card in [const MechCard('obstacle', 2), const MechCard('bridge', 0)]) {
          await show(MechOverlay(app: app, card: card, maxBridges: 2, onOk: () {}));
        }

        // Сюжет: вступление и финал главы.
        await show(StoryOverlay(app: app, mode: StoryMode.intro, onDone: () {}), ms: 900);
        app.chapter = 1;
        await show(
            StoryOverlay(app: app, mode: StoryMode.chapterFinale, onDone: () {}),
            ms: 1500);

        // Таблица лидеров с длинными именами.
        await show(
          LeaderboardScreen(
            app: app,
            onClose: () {},
            previewData: (
              [
                _row(1, 'ОченьДлинноеИмяОператора2026', 214),
                _row(2, 'neon_kid', 187),
                _row(3, 'x', 3),
              ],
              _row(137, 'Ты', 24)
            ),
          ),
          ms: 900,
        );

        // Политика приватности (самый длинный текст в игре).
        await show(PrivacyOverlay(app: app, onClose: () {}), ms: 400);

        play.quit();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
        play.dispose();
      });
    }
  }

  testWidgets('поворот экрана не ломает вёрстку и уровень', (tester) async {
    tester.view.physicalSize = const Size(768 * 2, 1024 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final app = await _app('ru');
    final play = PlayState(app, 700, 900)..start(9);

    Widget screen() => _wrap(
        app,
        PlayScreen(
            play: play, onQuit: () {}, onHintAd: () async {}, onInfo: (_) {}));

    await tester.pumpWidget(screen());
    await tester.pump(const Duration(milliseconds: 300));

    // Поворот в альбом и обратно — по три раза, как крутит игрок.
    for (var i = 0; i < 3; i++) {
      tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
      await tester.pumpWidget(screen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(play.nodes.every((n) => n[0].isFinite && n[1].isFinite), isTrue,
          reason: 'координаты узлов должны оставаться конечными');

      tester.view.physicalSize = const Size(768 * 2, 1024 * 2);
      await tester.pumpWidget(screen());
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Узлы остаются внутри поля после всех поворотов.
    for (final n in play.nodes) {
      expect(n[0], inInclusiveRange(0, play.w));
      expect(n[1], inInclusiveRange(0, play.h));
    }

    play.quit();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    play.dispose();
  });
}
