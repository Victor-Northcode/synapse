import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/palette.dart';
import '../../state/app_state.dart';
import '../layout.dart';
import '../widgets/common.dart';

/// Нейтральный возрастной экран (требование Google Play «Приложения
/// для всей семьи» и Apple): показывается один раз при первом запуске,
/// ДО любой рекламы. Нейтральность: ни один год не подставлен заранее,
/// никаких подсказок «сколько ввести» — пользователь сам выбирает год
/// из списка. По ответу настраиваются COPPA/GDPR-K-флаги рекламы.
class AgeGate extends StatefulWidget {
  final AppState app;
  final VoidCallback onDone;
  const AgeGate({super.key, required this.app, required this.onDone});

  @override
  State<AgeGate> createState() => _AgeGateState();
}

class _AgeGateState extends State<AgeGate> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final now = DateTime.now().year;
    final years = [for (var y = now; y >= now - 99; y--) y];
    return Container(
      color: const Color(0xE604060E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: BoxConstraints(
            maxWidth: Layout.of(context).overlayMaxWidth,
            maxHeight:
                (MediaQuery.of(context).size.height * .74).clamp(320.0, 560.0)),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: Pal.ovCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Pal.ovBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(app.lt('ageT'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontSize: 17,
                  letterSpacing: 1.6,
                  height: 1.4,
                  color: Pal.text)),
          const SizedBox(height: 10),
          Text(app.lt('ageB'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 10.5,
                  height: 1.55,
                  color: Pal.bodyDim)),
          const SizedBox(height: 14),
          Flexible(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.9,
              children: [
                for (final y in years)
                  Pressable(
                    onTap: () {
                      Haptics.instance.snap();
                      setState(() => _year = y);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _year == y
                            ? const Color(0x2400E5FF)
                            : const Color(0x0D78A0FF),
                        border: Border.all(
                            color: _year == y
                                ? const Color(0x8C00E5FF)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$y',
                          style: TextStyle(
                              fontFamily: Fonts.mono,
                              fontSize: 12,
                              fontWeight: _year == y
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: _year == y ? Pal.cyan : Pal.text)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _year == null ? .4 : 1,
            child: PillButton(
              minHeight: 60,
              onTap: _year == null
                  ? null
                  : () {
                      widget.app.setBirthYear(_year!);
                      widget.onDone();
                    },
              child: Text(app.lt('ageBtn')),
            ),
          ),
        ]),
      ),
    );
  }
}
