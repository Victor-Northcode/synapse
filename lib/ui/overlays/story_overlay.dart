import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/palette.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/scene_widget.dart';

/// Режим сюжетного экрана.
enum StoryMode { intro, dayScene, chapterFinale }

String romanOf(int n) {
  const v = [10, 9, 5, 4, 1];
  const sym = ['X', 'IX', 'V', 'IV', 'I'];
  var out = '';
  var x = math.max(1, n);
  for (var i = 0; i < v.length; i++) {
    while (x >= v[i]) {
      out += sym[i];
      x -= v[i];
    }
  }
  return out;
}

/// Сюжет: вступление из пяти панелей, сцены дня и финал главы (ovStory).
class StoryOverlay extends StatefulWidget {
  final AppState app;
  final StoryMode mode;
  final int day; // для dayScene
  final VoidCallback onDone;
  const StoryOverlay(
      {super.key,
      required this.app,
      required this.mode,
      this.day = 0,
      required this.onDone});

  @override
  State<StoryOverlay> createState() => _StoryOverlayState();
}

class _StoryOverlayState extends State<StoryOverlay> {
  int page = 0;
  bool _locked = true;

  @override
  void initState() {
    super.initState();
    _lock();
  }

  void _lock() {
    _locked = true;
    final ms = widget.mode == StoryMode.chapterFinale ? 1400 : 700;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _locked = false);
    });
  }

  void _next() {
    if (_locked) return;
    if (widget.mode == StoryMode.intro && page < 4) {
      setState(() {
        page++;
        _lock();
      });
      GameAudio.instance.tone(700, .06, 'sine', .03);
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final isFinale = widget.mode == StoryMode.chapterFinale;
    final scene = switch (widget.mode) {
      StoryMode.intro => '${page + 1}' == '1'
          ? 'net'
          : switch (page + 1) { 2 => 'noise', 3 => 'zoom', 4 => 'console', _ => 'line' },
      StoryMode.dayScene => 'net-ok',
      StoryMode.chapterFinale => 'new',
    };
    final text = switch (widget.mode) {
      StoryMode.intro => app.t('s${page + 1}'),
      StoryMode.dayScene =>
        widget.day < app.dayEnds.length ? app.dayEnds[widget.day] : '',
      StoryMode.chapterFinale => app.chapterStoryText(),
    };
    // Статистика прошлой главы (до пересборки).
    final prevCnt = math.min(30, 12 + (app.chapter - 1) * 2);
    final prevDays = math.min(6, 4 + (app.chapter - 1) ~/ 2);

    return Container(
      decoration: const BoxDecoration(gradient: Pal.fieldGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 20),
          child: Column(children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    if (isFinale) ...[
                      const SizedBox(height: 8),
                      Text(
                        app.t('chapterDone').replaceAll('{n}', romanOf(app.chapter)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: Fonts.mono,
                            fontSize: 9.5,
                            letterSpacing: 2.9,
                            color: Pal.dim),
                      ),
                    ],
                    SceneWidget(scene,
                        lit: widget.mode == StoryMode.dayScene
                            ? (widget.day + 1) / math.max(1, app.days)
                            : .5,
                        assemble: isFinale),
                    if (isFinale)
                      Text(app.modelName(app.chapter - 1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: Fonts.disp,
                              fontSize: 19,
                              letterSpacing: 3.4,
                              color: Pal.text)),
                    const SizedBox(height: 16),
                    _StoryText(text: text, key: ValueKey('$page-${widget.mode}')),
                    if (widget.mode == StoryMode.intro) ...[
                      const SizedBox(height: 18),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < 5; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: i == page ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == page ? Pal.mag : Pal.dotOff,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ]),
                    ],
                    if (isFinale) ...[
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0x1200E676),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment(-.2, -.3),
                                colors: [Color(0xFFFFF3CE), Color(0xFFE8CE7A), Color(0xFF5A4A1C)],
                              ),
                              boxShadow: [BoxShadow(color: Color(0x59E8CE7A), blurRadius: 14)],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(app.t('chDone'),
                                      style: const TextStyle(
                                          fontFamily: Fonts.mono,
                                          fontSize: 11,
                                          color: Pal.text)),
                                  const SizedBox(height: 3),
                                  Text(
                                    app
                                        .t('chStats')
                                        .replaceAll('{n}', '$prevCnt')
                                        .replaceAll('{d}', '$prevDays'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontFamily: Fonts.mono,
                                        fontSize: 9.5,
                                        color: Pal.faint),
                                  ),
                                ]),
                          ),
                          const SizedBox(width: 12),
                          Row(mainAxisSize: MainAxisSize.min, children: const [
                            Text('+5',
                                style: TextStyle(
                                    fontFamily: Fonts.disp,
                                    fontSize: 17,
                                    color: Pal.cyan)),
                            SizedBox(width: 4),
                            ShardIcon(size: 13, color: Pal.cyan),
                          ]),
                        ]),
                      ),
                    ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _locked ? .35 : 1,
              child: PillButton(
                onTap: _next,
                minHeight: 76,
                child: switch (widget.mode) {
                  StoryMode.intro =>
                    Text(page >= 4 ? app.t('beginBtn') : app.t('nextBtn')),
                  StoryMode.dayScene => Text(app.t('nextBtn')),
                  StoryMode.chapterFinale => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(app
                            .t('chapterNext')
                            .replaceAll('{n}', romanOf(app.chapter + 1))),
                        const SizedBox(height: 4),
                        Text(
                          app
                              .t('chapterNewModel')
                              .replaceAll('{b}', app.modelName(app.chapter)),
                          style: TextStyle(
                              fontFamily: Fonts.mono,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              color: const Color(0xFF1A0512).withValues(alpha: .7)),
                        ),
                      ],
                    ),
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Текст истории: параграфы проявляются по очереди.
class _StoryText extends StatelessWidget {
  final String text;
  const _StoryText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split(RegExp(r'\n\s*\n'));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(children: [
        for (var i = 0; i < parts.length; i++)
          TweenAnimationBuilder<double>(
            key: ValueKey('$i-${parts[i].hashCode}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Interval(math.min(.9, i * .25), 1, curve: Curves.easeOut),
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: i < parts.length - 1 ? 20 : 0),
              child: Text(parts[i],
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                      fontFamily: Fonts.mono,
                      fontSize: 13.5,
                      height: 1.85,
                      color: Pal.bodyDim)),
            ),
          ),
      ]),
    );
  }
}
