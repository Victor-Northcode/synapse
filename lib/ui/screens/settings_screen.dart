import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ads.dart';
import '../../core/palette.dart';
import '../../state/app_state.dart';
import '../layout.dart';
import '../widgets/common.dart';

const kLangNames = {
  'en': 'English',
  'ru': 'Русский',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'ja': '日本語',
  'ko': '한국어',
  'ar': 'العربية',
};

/// Экран настроек: тумблеры, язык, интро, политика, сброс.
class SettingsScreen extends StatelessWidget {
  final VoidCallback onShowIntro;
  final VoidCallback onShowPrivacy;
  const SettingsScreen(
      {super.key, required this.onShowIntro, required this.onShowPrivacy});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ContentColumn(
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          child: Text(app.t('set'),
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  letterSpacing: .9,
                  color: Pal.text)),
        ),
        _switchRow(app.t('sound'), app.soundOn, app.setSound),
        _switchRow(app.t('vibro'), app.vibroOn, app.setVibro),
        _switchRow(app.t('push'), app.pushOn, (v) => app.setPush(v)),
        _langRow(context, app),
        const SizedBox(height: 16),
        GhostButton(onTap: onShowIntro, child: Text(app.t('intro'))),
        const SizedBox(height: 10),
        GhostButton(onTap: onShowPrivacy, child: Text(app.t('privacy'))),
        if (Ads.instance.needsPrivacyOptions) ...[
          const SizedBox(height: 10),
          GhostButton(
            onTap: () => Ads.instance.openPrivacyOptions(),
            child: Text(app.t('adpriv')),
          ),
        ],
        const SizedBox(height: 10),
        GhostButton(
          onTap: () => _confirmReset(context, app),
          borderColor: Pal.red,
          textColor: Pal.red,
          child: Text(app.t('reset')),
        ),
      ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Pal.line))),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 12,
                  letterSpacing: .7,
                  color: Pal.text)),
        ),
        _NeonSwitch(value: value, onChanged: onChanged),
      ]),
    );
  }

  Widget _langRow(BuildContext context, AppState app) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
      child: Row(children: [
        Expanded(
          child: Text(app.t('lang'),
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 12,
                  letterSpacing: .7,
                  color: Pal.text)),
        ),
        Pressable(
          onTap: () => _pickLang(context, app),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: Pal.panel,
              border: Border.all(color: Pal.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(kLangNames[app.lang] ?? app.lang,
                style: const TextStyle(
                    fontFamily: Fonts.mono, fontSize: 12, color: Pal.text)),
          ),
        ),
      ]),
    );
  }

  void _pickLang(BuildContext context, AppState app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Pal.ovCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(14),
          children: [
            for (final e in kLangNames.entries)
              GestureDetector(
                onTap: () {
                  app.setLang(e.key);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: e.key == app.lang ? const Color(0x1200E5FF) : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e.key == app.lang
                            ? Pal.cyan
                            : const Color(0xFF2A3446),
                        border: Border.all(color: const Color(0xFF080D16), width: 3),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(e.value,
                        style: TextStyle(
                            fontFamily: Fonts.mono,
                            fontSize: 15,
                            color: e.key == app.lang ? Pal.text : Pal.dim)),
                    const Spacer(),
                    Text(e.key.toUpperCase(),
                        style: TextStyle(
                            fontFamily: Fonts.disp,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: e.key == app.lang ? Pal.cyan : Pal.ghost)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, AppState app) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0C0507),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0x66FF3B30)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(app.t('reset'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.disp,
                    fontSize: 15,
                    letterSpacing: 1.4,
                    color: Pal.red)),
            const SizedBox(height: 20),
            GhostButton(
              onTap: () {
                Navigator.pop(context);
                app.resetProgress();
              },
              borderColor: const Color(0x80FF3B30),
              textColor: Pal.red,
              minHeight: 52,
              child: Text(app.t('reset')),
            ),
            const SizedBox(height: 10),
            GhostButton(
              onTap: () => Navigator.pop(context),
              minHeight: 52,
              fill: const Color(0x0F78A0FF),
              child: Text(app.t('mechOk')),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Переключатель в неоновом стиле (.sw).
class _NeonSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NeonSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? const Color(0x4D00E676) : Pal.line,
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? Pal.green : Pal.dim,
            ),
          ),
        ),
      ),
    );
  }
}
