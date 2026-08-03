import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/palette.dart';
import 'common.dart';

/// Пункт нижнего меню.
class NavItem {
  final String icon;
  final String label;
  const NavItem(this.icon, this.label);
}

/// Нижнее меню, прикреплённое к низу экрана: Журнал · Склад · Топ ·
/// Настройки. Активная вкладка подсвечена неоновой «таблеткой», переход
/// анимирован, безопасная зона (жестовая полоса) учтена.
class BottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  const BottomNav(
      {super.key, required this.items, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF20A0E1A),
        border: Border(top: BorderSide(color: Pal.line)),
        boxShadow: [
          BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, -10)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _NavButton(
                item: items[i],
                active: i == index,
                onTap: () {
                  if (i != index) {
                    Haptics.instance.light();
                    onTap(i);
                  }
                },
              )),
          ]),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? Pal.cyan : Pal.dim;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0x1A00E5FF) : Colors.transparent,
          border: Border.all(
              color: active ? const Color(0x5200E5FF) : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? const [BoxShadow(color: Color(0x2E00E5FF), blurRadius: 18)]
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(
            scale: active ? 1.12 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: GameIcon(item.icon, size: 19, color: color),
          ),
          const SizedBox(height: 4),
          // Длинные подписи (НАСТРОЙКИ, EINSTELLUNGEN) ужимаются,
          // а не переносятся и не режутся.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontFamily: Fonts.mono,
                fontSize: 8.5,
                letterSpacing: 1.1,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
