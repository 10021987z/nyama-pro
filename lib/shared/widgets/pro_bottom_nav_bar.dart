import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Bottom nav NYAMA Pro — style pill orange pour l'item actif,
/// icône blanche + label orange 10px. Aucune bordure visible.
class ProBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ProBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = <_NavItemData>[
    _NavItemData(icon: Icons.restaurant_menu, label: 'COMMANDES'),
    _NavItemData(icon: Icons.menu_book, label: 'MENU'),
    _NavItemData(icon: Icons.payments, label: 'REVENUS'),
    _NavItemData(icon: Icons.star_rounded, label: 'AVIS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  data: _items[i],
                  isActive: currentIndex == i,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                data.icon,
                size: 22,
                color: isActive ? Colors.white : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
