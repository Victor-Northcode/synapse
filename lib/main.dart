import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/ads.dart';
import 'core/audio.dart';
import 'core/notifications.dart';
import 'core/palette.dart';
import 'core/storage.dart';
import 'state/app_state.dart';
import 'ui/app_root.dart';
import 'ui/layout.dart';

/// Телефон играется только вертикально — головоломка на боку
/// превращается в нечитаемую полосу. Планшету разрешаем всё: там
/// альбомный режим раскладывается в две колонки.
Future<void> applyOrientations() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  final isTablet = size.shortestSide >= 600;
  await SystemChrome.setPreferredOrientations(isTablet
      ? const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
      : const [DeviceOrientation.portraitUp]);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await applyOrientations();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Storage.instance.init();
  final app = AppState()..loadSaved();

  // Звук и уведомления поднимаются в фоне, реклама — лениво при
  // первом запросе ролика (согласие соберётся до инициализации SDK).
  GameAudio.instance.init();
  Push.instance.init();
  Ads.instance.init().ignore();

  runApp(SynapseApp(app: app));
}

class SynapseApp extends StatelessWidget {
  final AppState app;
  const SynapseApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        title: 'SYNAPSE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Pal.bg,
          fontFamily: Fonts.mono,
          colorScheme: const ColorScheme.dark(
            primary: Pal.mag,
            secondary: Pal.cyan,
            surface: Pal.panel,
          ),
        ),
        builder: (context, child) {
          // Системное масштабирование шрифта не должно ломать вёрстку HUD.
          // На планшете весь интерфейс идёт на шаг крупнее.
          final mq = MediaQuery.of(context);
          final tabletScale = Layout.of(context).textScale;
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler
                  .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.2)
                  .clamp(minScaleFactor: tabletScale, maxScaleFactor: 1.2 * tabletScale),
            ),
            child: child!,
          );
        },
        home: const Scaffold(body: AppRoot()),
      ),
    );
  }
}
