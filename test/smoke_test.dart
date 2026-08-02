import 'package:flutter_test/flutter_test.dart';
import 'package:synapse/ui/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/main.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/ui/screens/play_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('загрузка → интро → уровень 1 → выход в хаб', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
    final app = AppState()..loadSaved();
    app.setLang('ru');

    await tester.pumpWidget(SynapseApp(app: app));
    // Экран загрузки ~2 c (в игре есть вечные анимации — settle не ждём).
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 200));

    // Интро: пять панелей.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 800)); // замок текста
      final next = find.textContaining(RegExp('Дальше|Начать'));
      expect(next, findsOneWidget, reason: 'панель $i интро');
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // После интро сразу стартует уровень 1.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.textContaining('СВЯЗЬ #1'), findsOneWidget);

    // Выход в хаб.
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Glyph && w.kind == GlyphKind.close));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PlayScreen), findsNothing);
    expect(find.textContaining('OBEN AI'), findsWidgets);

    // Магазин открывается: цены отрисованы векторными осколками.
    await tester.tap(find.text('СКЛАД'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ShardIcon), findsWidgets);

    // Таймеры уровня и анимации не должны висеть.
    await tester.pump(const Duration(seconds: 2));
  });
}
