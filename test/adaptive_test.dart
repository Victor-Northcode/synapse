import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/main.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/ui/widgets/common.dart';

/// Вёрстка не должна переполняться ни на маленьких экранах,
/// ни на планшете, ни на «длинных» языках (de) и RTL (ar).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = [
    Size(320, 568), // iPhone SE 1-го поколения
    Size(360, 640), // компактный Android
    Size(430, 932), // iPhone Pro Max
    Size(800, 1280), // планшет
  ];
  const langs = ['ru', 'de', 'ar', 'ja'];

  for (final size in sizes) {
    for (final lang in langs) {
      testWidgets('хаб/склад/настройки: $lang @ ${size.width}x${size.height}',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        await Storage.instance.init();
        final app = AppState()..loadSaved();
        app.setLang(lang);
        app.introSeen = true; // сразу в хаб
        app.tokens = 25; // задачи подсвечены «можно купить»
        app.shards = 9;

        await tester.pumpWidget(SynapseApp(app: app));
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pump(const Duration(milliseconds: 300));

        // Склад.
        await tester.tap(find.text(app.t('tab2')).first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ShardIcon), findsWidgets);

        // Настройки.
        await tester.tap(find.byWidgetPredicate(
            (w) => w is GameIcon && w.name == 'gear'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(app.t('set')), findsOneWidget);

        // Игровой экран.
        await tester.tap(find.byWidgetPredicate(
            (w) => w is Glyph && w.kind == GlyphKind.chevronLeft));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byType(PillButton).first);
        await tester.pump(const Duration(milliseconds: 900));
        await tester.tap(find.byWidgetPredicate(
            (w) => w is Glyph && w.kind == GlyphKind.close));
        await tester.pump(const Duration(milliseconds: 300));
      });
    }
  }
}
