import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/palette.dart';
import '../../data/icons_data.dart';

/// Осколок ✦ — четырёхлучевая звезда, отрисованная вектором,
/// чтобы не зависеть от эмодзи-глифов системного шрифта.
class ShardIcon extends StatelessWidget {
  final double size;
  final Color color;
  const ShardIcon({super.key, this.size = 12, this.color = Pal.cyan});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _ShardPainter(color));
  }
}

class _ShardPainter extends CustomPainter {
  final Color color;
  _ShardPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const k = .28; // «талия» звезды
    final path = Path()..moveTo(c.dx, c.dy - r);
    for (var i = 0; i < 4; i++) {
      final a0 = -math.pi / 2 + i * math.pi / 2;
      final aMid = a0 + math.pi / 4;
      final aNext = a0 + math.pi / 2;
      path.lineTo(c.dx + math.cos(aMid) * r * k, c.dy + math.sin(aMid) * r * k);
      path.lineTo(c.dx + math.cos(aNext) * r, c.dy + math.sin(aNext) * r);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ShardPainter old) => old.color != color;
}

/// Шестиугольник результата: контур — победа, залитый — перегрузка.
class HexIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;
  const HexIcon({super.key, this.size = 52, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _HexPainter(color, filled));
  }
}

class _HexPainter extends CustomPainter {
  final Color color;
  final bool filled;
  _HexPainter(this.color, this.filled);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 6);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) =>
      old.color != color || old.filled != filled;
}

/// Штриховые мини-глифы (✕ ✓ ‹) — рисуются вектором в стиле спрайта игры:
/// round caps, толщина 1.8/24 от размера, без шрифтовых глифов.
enum GlyphKind { close, check, chevronLeft }

class Glyph extends StatelessWidget {
  final GlyphKind kind;
  final double size;
  final Color color;
  const Glyph(this.kind, {super.key, this.size = 16, this.color = Pal.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GlyphPainter(kind, color));
  }
}

class _GlyphPainter extends CustomPainter {
  final GlyphKind kind;
  final Color color;
  _GlyphPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 2.0 / 24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path();
    switch (kind) {
      case GlyphKind.close:
        path
          ..moveTo(s * .27, s * .27)
          ..lineTo(s * .73, s * .73)
          ..moveTo(s * .73, s * .27)
          ..lineTo(s * .27, s * .73);
      case GlyphKind.check:
        path
          ..moveTo(s * .22, s * .54)
          ..lineTo(s * .42, s * .74)
          ..lineTo(s * .78, s * .30);
      case GlyphKind.chevronLeft:
        path
          ..moveTo(s * .60, s * .24)
          ..lineTo(s * .36, s * .50)
          ..lineTo(s * .60, s * .76);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.kind != kind || old.color != color;
}

/// Обёртка нажатия: мягкое сжатие и притухание — живой отклик без Material-ряби.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .965 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedOpacity(
          opacity: _down ? .85 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Иконка из спрайта игры: 24x24, контур 1.8 текущим цветом.
class GameIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final bool solid;
  const GameIcon(this.name,
      {super.key, this.size = 16, this.color = Pal.text, this.solid = false});

  @override
  Widget build(BuildContext context) {
    final inner = kIconPaths[name];
    if (inner == null) return SizedBox.square(dimension: size);
    final svg = solid
        ? '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none">$inner</svg>'
        : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">$inner</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
    );
  }
}

/// Текст с плейсхолдерами иконок вида {tv} {bulb} {gift} {bolt} — порт icText().
class IconText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign align;
  const IconText(this.text, {super.key, required this.style, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    // Простая разметка словаря: <br> — перенос, <b>…</b> — акцент.
    final src = text.replaceAll('<br>', '\n');
    final spans = <InlineSpan>[];
    final boldRe = RegExp(r'<b>(.*?)</b>', dotAll: true);
    final boldStyle = style.copyWith(color: Pal.text, fontWeight: FontWeight.w700);
    var last = 0;
    for (final m in boldRe.allMatches(src)) {
      if (m.start > last) {
        spans.addAll(_inline(src.substring(last, m.start), style));
      }
      spans.addAll(_inline(m.group(1)!, boldStyle));
      last = m.end;
    }
    if (last < src.length) spans.addAll(_inline(src.substring(last), style));
    return Text.rich(TextSpan(children: spans, style: style), textAlign: align);
  }

  /// {tv} {bulb} {gift} {bolt} — плейсхолдеры словаря; ✦ и ✓ — векторные.
  List<InlineSpan> _inline(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\{(tv|bulb|gift|bolt)\}|✦|✓');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: style));
      }
      final sz = (style.fontSize ?? 12) * 1.15;
      if (m.group(0) == '✓') {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Glyph(GlyphKind.check, size: sz, color: style.color ?? Pal.green),
        ));
      } else if (m.group(0) == '✦') {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: ShardIcon(size: sz * .82, color: style.color ?? Pal.cyan),
          ),
        ));
      } else {
        final name = m.group(1)!;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: GameIcon(name,
                size: sz, color: style.color ?? Pal.text, solid: name == 'bolt'),
          ),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: style));
    }
    return spans;
  }
}

/// Главная кнопка-пилюля (btn-primary): мадженто-заливка и неоновое гало.
class PillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final double minHeight;
  final double glow;
  const PillButton({
    super.key,
    required this.child,
    this.onTap,
    this.color = Pal.mag,
    this.textColor = const Color(0xFF1A0512),
    this.minHeight = 88,
    this.glow = .45,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: glow), blurRadius: 52, spreadRadius: 0),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: Fonts.disp,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: 2.4,
            color: textColor,
          ),
          textAlign: TextAlign.center,
          child: child,
        ),
      ),
    );
  }
}

/// Прозрачная кнопка-пилюля с рамкой (btn-ghost).
class GhostButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color borderColor;
  final Color textColor;
  final double minHeight;
  final Color? fill;
  const GhostButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor = Pal.line,
    this.textColor = Pal.text,
    this.minHeight = 58,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(999),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: Fonts.mono,
            fontSize: 14,
            letterSpacing: 1.6,
            color: textColor,
          ),
          textAlign: TextAlign.center,
          child: child,
        ),
      ),
    );
  }
}

/// Бейдж сложности уровня (kb k0/k1/k2).
class KindBadge extends StatelessWidget {
  final int kind; // -1 / 1 / 2
  final String label;
  const KindBadge(this.kind, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, br) = switch (kind) {
      2 => (const Color(0x33E8564B), const Color(0xFFF08A7E), const Color(0x8CE8564B)),
      1 => (const Color(0x3300E5FF), const Color(0xFF7FD8C8), const Color(0x8000E5FF)),
      _ => (const Color(0x2E00E676), const Color(0xFFA7DF83), const Color(0x7300E676)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: br),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: Fonts.mono,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Панель с фоном и рамкой (по мотивам .dc / .ov-in).
class GamePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color borderColor;
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 13,
    this.color = Pal.panel,
    this.borderColor = Pal.line,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Заголовок секции склада: подпись + линия (shop-t).
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconText(text.toUpperCase(),
          style: const TextStyle(
              fontFamily: Fonts.mono, fontSize: 9, letterSpacing: 1.8, color: Pal.dim)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: const Color(0x1F78A0FF))),
    ]);
  }
}
