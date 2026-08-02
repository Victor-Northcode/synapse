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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Игра вертикальная: головоломка не читается в ландшафте.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler
                  .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.2),
            ),
            child: child!,
          );
        },
        home: const Scaffold(body: AppRoot()),
      ),
    );
  }
}
