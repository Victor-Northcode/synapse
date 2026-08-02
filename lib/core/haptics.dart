import 'package:flutter/services.dart';

/// Тактильная отдача — порт модуля HAP.
/// Правило вкуса сохранено: коротко и сухо, защёлкивание — selectionClick.
class Haptics {
  Haptics._();
  static final Haptics instance = Haptics._();

  bool enabled = true;

  void _run(Future<void> Function() fn) {
    if (!enabled) return;
    fn().catchError((_) {});
  }

  void grab() => _run(HapticFeedback.selectionClick);
  void snap() => _run(HapticFeedback.selectionClick);
  void light() => _run(HapticFeedback.lightImpact);
  void medium() => _run(HapticFeedback.mediumImpact);
  void heavy() => _run(HapticFeedback.heavyImpact);

  /// «Нельзя»: два коротких толчка подряд читаются как отказ.
  void reject() {
    _run(HapticFeedback.mediumImpact);
    Future.delayed(const Duration(milliseconds: 90), () => _run(HapticFeedback.lightImpact));
  }

  void success() => _run(HapticFeedback.mediumImpact);
  void warning() => _run(HapticFeedback.mediumImpact);
  void error() => _run(HapticFeedback.heavyImpact);

  /// Финал главы: нарастание вместо одиночного удара.
  void fanfare() {
    _run(HapticFeedback.lightImpact);
    Future.delayed(const Duration(milliseconds: 110), () => _run(HapticFeedback.mediumImpact));
    Future.delayed(const Duration(milliseconds: 240), () => _run(HapticFeedback.heavyImpact));
  }

  /// Старая сигнатура buzz(n): число → ближайший по силе отклик.
  void buzz(num n) {
    if (n <= 14) {
      snap();
    } else if (n <= 28) {
      light();
    } else if (n <= 55) {
      medium();
    } else {
      heavy();
    }
  }
}
