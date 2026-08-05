import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../state/app_state.dart';
import '../layout.dart';
import '../widgets/common.dart';

/// Правила игры одним экраном: базовое правило, все механики поля и
/// экономика. Тексты механик — те же локализованные строки, что и на
/// карточках при первом появлении (obn/ob, fn/fb, brT/brB), поэтому
/// экран автоматически работает на всех девяти языках.
class RulesOverlay extends StatelessWidget {
  final AppState app;
  final VoidCallback onClose;
  const RulesOverlay({super.key, required this.app, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final obn = app.tl('obn');
    final ob = app.tl('ob');
    final fn = app.tl('fn');
    final fb = app.tl('fb');
    return Container(
      color: const Color(0xE604060E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
            maxWidth: Layout.of(context).overlayMaxWidth + 60,
            maxHeight: MediaQuery.of(context).size.height * .86),
        decoration: BoxDecoration(
          color: Pal.ovCard,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Pal.line),
          boxShadow: const [
            BoxShadow(color: Color(0x9A000000), blurRadius: 70, offset: Offset(0, 30)),
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 12, 8),
            child: Row(children: [
              Expanded(
                child: Text(app.lt('rulesT'),
                    style: const TextStyle(
                        fontFamily: Fonts.disp,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 2,
                        color: Pal.text)),
              ),
              Pressable(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Pal.panel,
                    border: Border.all(color: Pal.line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Glyph(GlyphKind.close, size: 16, color: Pal.text),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              children: [
                IconText(app.lt('rulesCore'),
                    align: TextAlign.start, style: _body),
                const SizedBox(height: 14),
                IconText(app.lt('rulesEco'),
                    align: TextAlign.start, style: _body),
                const SizedBox(height: 18),
                // Заполняемые элементы: энергоблок, протечка, таймер.
                for (var i = 0; i < fn.length && i < fb.length; i++)
                  _rule(fn[i], fb[i]),
                // Мосты.
                _rule(app.t('brT'), app.t('brB').replaceAll('{n}', '2')),
                // Девять препятствий — в порядке появления в игре.
                for (var i = 0; i < obn.length && i < ob.length; i++)
                  _rule(obn[i], ob[i]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static const _body = TextStyle(
      fontFamily: Fonts.mono, fontSize: 12, height: 1.65, color: Pal.bodyDim);

  Widget _rule(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        decoration: BoxDecoration(
          color: Pal.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Pal.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  color: Color(0xFFFFB300))),
          const SizedBox(height: 6),
          Text(body, style: _body),
        ]),
      ),
    );
  }
}
