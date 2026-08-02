import 'package:flutter/widgets.dart';

/// Дизайн-токены SYNAPSE — перенос :root из design/www/index.html.
abstract final class Pal {
  static const bg = Color(0xFF07080F);
  static const panel = Color(0xFF0D111E);
  static const line = Color(0xFF1E2438);
  static const text = Color(0xFFE9ECF8);
  static const dim = Color(0xFF8A90A8);
  static const red = Color(0xFFFF3B30);

  // Тонируемые темой цвета живут в GameTheme; это — тема «Неон» по умолчанию.
  static const mag = Color(0xFFFF2ED1);
  static const cyan = Color(0xFF00E5FF);
  static const yellow = Color(0xFFFFD400);
  static const green = Color(0xFF00E676);

  static const deepBg = Color(0xFF04050C);
  static const ovCard = Color(0xFF080C18);
  static const ovBorder = Color(0xFF1F2A44);
  static const fieldBorder = Color(0xFF141C33);
  static const bodyDim = Color(0xFFA2A8BE);
  static const faint = Color(0xFF5D6683);
  static const ghost = Color(0xFF3E4762);
  static const dotOff = Color(0xFF2E3652);

  static const hardTeal = Color(0xFF5BC8B8);
  static const superRed = Color(0xFFE8564B);

  /// Радиальный фон приложения и игрового поля:
  /// #0E1730 → #060A16 (52%) → #03050C.
  static const fieldGradient = RadialGradient(
    center: Alignment(0, -0.4),
    radius: 1.1,
    colors: [Color(0xFF0E1730), Color(0xFF060A16), Color(0xFF03050C)],
    stops: [0.0, 0.52, 1.0],
  );

  static const hubCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A0B26), panel, Color(0xFF07131E)],
    stops: [0.0, 0.55, 1.0],
  );
}

/// Шрифтовые семейства.
abstract final class Fonts {
  static const disp = 'Unbounded';
  static const mono = 'JetBrains Mono';
}
