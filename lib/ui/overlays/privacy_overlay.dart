import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/story_data.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Политика приватности: текст хранится в приложении и открывается офлайн.
class PrivacyOverlay extends StatelessWidget {
  final AppState app;
  final VoidCallback onClose;
  const PrivacyOverlay({super.key, required this.app, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final raw = kPrivacyText[app.lang] ?? kPrivacyText['en']!;
    return Container(
      color: const Color(0xB804060E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: Pal.ovCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Pal.ovBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(app.t('privacy'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontSize: 17,
                  letterSpacing: 1.6,
                  height: 1.5,
                  color: Pal.text)),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Text.rich(
                _parse(raw),
                style: const TextStyle(
                    fontFamily: Fonts.mono, fontSize: 11.5, height: 1.65, color: Pal.bodyDim),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PillButton(onTap: onClose, minHeight: 60, child: Text(app.t('mechOk'))),
        ]),
      ),
    );
  }

  /// Разбор простой разметки текста политики: <b>…</b> и <i></i>-разделители.
  TextSpan _parse(String raw) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'<b>(.*?)</b>|<i></i>', dotAll: true);
    var last = 0;
    for (final m in re.allMatches(raw)) {
      if (m.start > last) spans.add(TextSpan(text: raw.substring(last, m.start)));
      if (m.group(0) == '<i></i>') {
        spans.add(const TextSpan(text: '\n'));
      } else {
        spans.add(TextSpan(
            text: m.group(1),
            style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)));
      }
      last = m.end;
    }
    if (last < raw.length) spans.add(TextSpan(text: raw.substring(last)));
    return TextSpan(children: spans);
  }
}
