import 'package:bpa_app/core/accessibility/a11y_widgets.dart';
import 'package:bpa_app/core/theme/spacing.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final VoidCallback onFabPressed;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onFabPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: cs.brightness == Brightness.light ? cs.surface : cs.surface,
      elevation: 10,
      child: SizedBox(
        height: 60,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fabGap = constraints.maxWidth < 360 ? 44.0 : 52.0;
            return Row(
              children: [
                Expanded(child: _buildNavItem(context, Icons.home, 'Home', 0)),
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.shopping_bag_outlined,
                    'Shop',
                    1,
                  ),
                ),
                SizedBox(width: fabGap),
                Expanded(
                  child: _buildNavItem(context, Icons.pets, 'Services', 2),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.person_outline,
                    'Profile',
                    3,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final cs = context.colorScheme;
    final isSelected = selectedIndex == index;
    return MinTouchTarget(
      semanticLabel: '$label tab${isSelected ? ', selected' : ''}',
      selected: isSelected,
      onTap: () => onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? cs.primary : cs.onSurfaceVariant,
            size: 24,
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: context.appText.bodySmall!.copyWith(
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
