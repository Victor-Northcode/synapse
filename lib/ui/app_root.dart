import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/ads.dart';
import '../core/audio.dart';
import '../core/haptics.dart';
import '../core/leaderboard.dart';
import '../core/palette.dart';
import '../state/app_state.dart';
import '../state/play_state.dart';
import 'overlays/mech_overlay.dart';
import 'overlays/privacy_overlay.dart';
import 'overlays/result_overlay.dart';
import 'overlays/story_overlay.dart';
import 'screens/boot_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/play_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/common.dart';

/// Корень интерфейса: экраны, слои и оверлеи — как Stack из index.html.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool booting = true;
  bool settings = false;
  bool showLb = false;
  PlayState? play;
  bool showResult = false;
  StoryMode? storyMode;
  int storyDay = 0;
  bool showPrivacy = false;

  // Тост.
  String? toastText;
  bool toastOnField = false;
  Timer? _toastTimer;
  String? _pendingToast;

  AppState get app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      app.onEvent = _onEvent;
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    play?.dispose();
    super.dispose();
  }

  bool get _narrativeOpen => storyMode != null || (play?.pendingCard != null);

  void _onEvent(GameEvent e) {
    switch (e.type) {
      case GameEventType.toast:
        _toast(e.text ?? '');
      case GameEventType.dayScene:
        setState(() {
          storyMode = StoryMode.dayScene;
          storyDay = e.day ?? 0;
        });
        GameAudio.instance.tone(560, .14, 'sine', .05);
      case GameEventType.chapterFinale:
        PlayState.resetSeenFill();
        setState(() => storyMode = StoryMode.chapterFinale);
      case GameEventType.storyIntro:
        setState(() {
          settings = false;
          storyMode = StoryMode.intro;
        });
    }
  }

  /// Тост: в игре — над бустерами, в хабе — под шапкой; при открытом
  /// сюжете или карточке механики сообщение придерживается.
  void _toast(String text) {
    if (_narrativeOpen) {
      _pendingToast = text;
      return;
    }
    _toastTimer?.cancel();
    setState(() {
      toastText = text;
      toastOnField = play != null && !showResult;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => toastText = null);
    });
  }

  void _flushToast() {
    final t = _pendingToast;
    _pendingToast = null;
    if (t != null) {
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _toast(t);
      });
    }
  }

  // ---------- уровень ----------
  /// Старый PlayState хороним только после кадра: виджеты поля ещё
  /// подписаны на него до перестройки дерева.
  void _retire(PlayState? old) {
    if (old == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _startLevel(int lvl) {
    final size = MediaQuery.of(context).size;
    final w = (size.width - 56).clamp(200.0, 900.0);
    final h = (size.height - 330).clamp(260.0, 1200.0);
    final p = PlayState(app, w, h);
    p.onToast = _toast;
    p.onWin = () => setState(() => showResult = true);
    p.onBoom = () => setState(() => showResult = true);
    final old = play;
    setState(() {
      play = p;
      showResult = false;
    });
    _retire(old);
    p.start(lvl);
  }

  void _quitToHub() {
    final old = play;
    setState(() {
      play = null;
      showResult = false;
    });
    _retire(old);
  }

  Future<void> _hintViaAd() async {
    _toast(app.t('adWatch'));
    final ok = await Ads.instance.rewarded();
    if (!ok) {
      _toast(Ads.instance.hasAds ? app.t('adFail') : app.t('adOff'));
      return;
    }
    app.hintStock++;
    app.save();
    app.notify();
    _toast(app.t('hintGot'));
    GameAudio.instance.tone(900, .12, 'sine', .05);
    Haptics.instance.light();
  }

  void _bootDone() {
    setState(() => booting = false);
    if (!app.introSeen) {
      setState(() => storyMode = StoryMode.intro);
    }
    _flushToast();
  }

  // ---------- back ----------
  bool _handleBack() {
    if (booting) return true;
    if (showPrivacy) {
      setState(() => showPrivacy = false);
      return true;
    }
    if (showLb) {
      setState(() => showLb = false);
      return true;
    }
    if (storyMode == StoryMode.dayScene || storyMode == StoryMode.chapterFinale) {
      _closeStory();
      return true;
    }
    if (storyMode == StoryMode.intro) return true; // интро не прерываем
    if (showResult) return true;
    if (play?.pendingCard != null) return true;
    if (settings) {
      setState(() => settings = false);
      Haptics.instance.light();
      return true;
    }
    if (play != null) {
      play!.quit();
      _quitToHub();
      Haptics.instance.light();
      return true;
    }
    return false; // свернуть приложение
  }

  void _closeStory() {
    final mode = storyMode;
    setState(() => storyMode = null);
    _flushToast();
    if (mode == StoryMode.intro) {
      app.markIntroSeen();
      if (play == null) _startLevel(app.level);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = play;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_handleBack()) {
          SystemNavigator.pop(); // некуда возвращаться — уходим из игры
        }
      },
      child: Directionality(
        textDirection: app.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          decoration: const BoxDecoration(gradient: Pal.fieldGradient),
          child: Stack(children: [
            // Базовый слой: шапка + хаб/настройки.
            SafeArea(
              child: Column(children: [
                _topBar(app),
                Expanded(
                  child: settings
                      ? SettingsScreen(
                          onShowIntro: () => setState(() {
                            settings = false;
                            storyMode = StoryMode.intro;
                          }),
                          onShowPrivacy: () => setState(() => showPrivacy = true),
                        )
                      : HubScreen(onPlay: () => _startLevel(app.level)),
                ),
              ]),
            ),

            // Игровой слой.
            if (p != null)
              Positioned.fill(
                child: SlideUpIn(
                  key: ValueKey(p),
                  child: PlayScreen(
                      play: p, onQuit: _quitToHub, onHintAd: _hintViaAd, onInfo: _toast),
                ),
              ),

            // Карточка механики.
            if (p != null && p.pendingCard != null)
              Positioned.fill(
                child: PopIn(
                  child: MechOverlay(
                    app: app,
                    card: p.pendingCard!,
                    maxBridges: p.maxBridges,
                    onOk: () {
                      p.dismissCard();
                      _flushToast();
                    },
                  ),
                ),
              ),

            // Результат.
            if (p != null && showResult && p.result != null)
              Positioned.fill(
                child: PopIn(
                  key: ValueKey(p.result),
                  child: ResultOverlay(
                    app: app,
                    result: p.result!,
                    onToast: _toast,
                    onNext: () => _startLevel(p.result!.win ? app.level : p.result!.level),
                    onHub: _quitToHub,
                    onContinue: () {
                      setState(() => showResult = false);
                      p.continueAfterAd();
                    },
                  ),
                ),
              ),

            // Сюжет.
            if (storyMode != null)
              Positioned.fill(
                child: PopIn(
                  key: ValueKey(storyMode),
                  child: StoryOverlay(
                    app: app,
                    mode: storyMode!,
                    day: storyDay,
                    onDone: _closeStory,
                  ),
                ),
              ),

            // Топ операторов.
            if (showLb)
              Positioned.fill(
                child: PopIn(
                  child: LeaderboardScreen(
                      app: app, onClose: () => setState(() => showLb = false)),
                ),
              ),

            // Политика.
            if (showPrivacy)
              Positioned.fill(
                child: PopIn(
                  child: PrivacyOverlay(
                      app: app, onClose: () => setState(() => showPrivacy = false)),
                ),
              ),

            // Загрузка.
            if (booting) Positioned.fill(child: BootScreen(onDone: _bootDone)),

            // Тост: всплывает с лёгким сдвигом.
            if (toastText != null)
              Positioned(
                left: 16,
                right: 16,
                top: toastOnField ? null : MediaQuery.of(context).padding.top + 64,
                bottom: toastOnField
                    ? MediaQuery.of(context).padding.bottom + 92
                    : null,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(toastText),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                          offset: Offset(0, (toastOnField ? 10 : -10) * (1 - v)),
                          child: child),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: Pal.panel,
                        border: Border.all(color: Pal.yellow),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: IconText(toastText!,
                          align: TextAlign.start,
                          style: const TextStyle(
                              fontFamily: Fonts.mono,
                              fontSize: 12,
                              height: 1.5,
                              color: Pal.text)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _topBar(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('SYNAPSE',
              style: TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: .7,
                  height: 1,
                  color: Pal.text)),
          SizedBox(height: 3),
          Text('//oben ai',
              style: TextStyle(
                  fontFamily: Fonts.mono, fontSize: 8.5, letterSpacing: .5, color: Pal.dim)),
        ]),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('${app.free}',
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Pal.yellow)),
          const SizedBox(width: 2),
          const GameIcon('bolt', size: 15, solid: true, color: Pal.yellow),
          const SizedBox(width: 8),
          Text('${app.shards}',
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Pal.cyan)),
          const SizedBox(width: 2),
          const ShardIcon(size: 10, color: Pal.cyan),
        ]),
        if (Lb.instance.available) ...[
          const SizedBox(width: 10),
          Pressable(
            onTap: () => setState(() => showLb = true),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x59FFD400)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const GameIcon('trophy', size: 17, color: Pal.yellow),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Pressable(
          onTap: () => setState(() => settings = !settings),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Pal.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: settings
                ? const Glyph(GlyphKind.chevronLeft, size: 20, color: Pal.text)
                : const GameIcon('gear', size: 17, color: Pal.dim),
          ),
        ),
      ]),
    );
  }
}
