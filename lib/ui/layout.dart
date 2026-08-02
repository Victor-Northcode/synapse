import 'package:flutter/widgets.dart';

/// Размерный класс экрана.
/// compact — телефон, medium — крупный телефон/малый планшет,
/// expanded — планшет.
enum SizeClass { compact, medium, expanded }

/// Адаптивная раскладка: один источник правды о размерах и режимах.
///
/// Игра вертикальная по своей природе, поэтому на телефоне ориентация
/// заблокирована в портрет, а на планшете разрешены все четыре —
/// там альбомный режим раскладывается в две колонки.
class Layout {
  final Size size;
  final bool isLandscape;
  final SizeClass sizeClass;

  const Layout._(this.size, this.isLandscape, this.sizeClass);

  factory Layout.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = mq.size;
    final short = s.shortestSide;
    final cls = short >= 840
        ? SizeClass.expanded
        : (short >= 600 ? SizeClass.medium : SizeClass.compact);
    return Layout._(s, s.width > s.height, cls);
  }

  /// Планшет: от него зависят и ориентации, и раскладка.
  bool get isTablet => sizeClass != SizeClass.compact;

  /// Две колонки имеют смысл только когда ширины реально хватает.
  bool get twoColumn => isLandscape && size.width >= 720;

  /// Ширина колонки контента: на широких экранах не растягиваем на всю
  /// ширину — читать строки длиной в экран невозможно.
  double get contentMaxWidth => switch (sizeClass) {
        SizeClass.compact => 560,
        SizeClass.medium => 640,
        SizeClass.expanded => 760,
      };

  /// Максимальная ширина карточек-оверлеев.
  double get overlayMaxWidth => isTablet ? 520 : 340;

  /// Множитель кегля: на планшете весь интерфейс на шаг крупнее.
  double get textScale => switch (sizeClass) {
        SizeClass.compact => 1.0,
        SizeClass.medium => 1.08,
        SizeClass.expanded => 1.16,
      };

  /// Короткий экран (SE, телефон в альбоме): ужимаем вертикальные отступы.
  bool get isShort => size.height < 700;

  double get gutter => isTablet ? 22 : 16;
}

/// Ограничивает контент по ширине и центрирует — базовый приём для
/// планшетов и альбомной ориентации.
class ContentColumn extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  const ContentColumn({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final l = Layout.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? l.contentMaxWidth),
        child: child,
      ),
    );
  }
}
