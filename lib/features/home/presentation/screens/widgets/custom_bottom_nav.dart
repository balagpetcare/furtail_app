import 'package:furtail_app/core/accessibility/a11y_widgets.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
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
    return Material(
      color: cs.surface,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.home_outlined,
                    Icons.home_rounded,
                    'Home',
                    0,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.play_circle_outline_rounded,
                    Icons.play_circle_fill_rounded,
                    'Videos',
                    1,
                  ),
                ),
                Expanded(child: _buildCreateItem(context)),
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.medical_services_outlined,
                    Icons.medical_services_rounded,
                    'Services',
                    3,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.person_outline_rounded,
                    Icons.person_rounded,
                    'Profile',
                    4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    IconData selectedIcon,
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
            isSelected ? selectedIcon : icon,
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

  Widget _buildCreateItem(BuildContext context) {
    final cs = context.colorScheme;
    return MinTouchTarget(
      semanticLabel: 'Create',
      onTap: onFabPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.add_rounded, color: cs.onPrimary, size: 26),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Create',
              maxLines: 1,
              style: context.appText.bodySmall!.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
