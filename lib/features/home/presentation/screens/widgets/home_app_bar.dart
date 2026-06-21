import 'package:bpa_app/core/accessibility/a11y_widgets.dart';
import 'package:bpa_app/core/theme/spacing.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:bpa_app/core/widgets/bpa_network_image.dart';
import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget {
  final String userName;
  final String? avatarUrl;

  const HomeAppBar({super.key, this.userName = 'Guest', this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final hPad = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.md
        : AppSpacing.lg;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.sm),
      child: Row(
        children: [
          MinTouchTarget(
            semanticLabel: 'Open navigation menu',
            onTap: () => Scaffold.of(context).openDrawer(),
            child: BpaNetworkAvatar(
              imageUrl: avatarUrl,
              displayName: userName,
              radius: 22,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              textField: true,
              label: 'Search BPA',
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: cs.outline),
                ),
                child: TextField(
                  textAlignVertical: TextAlignVertical.center,
                  style: context.appText.bodyMedium!.copyWith(
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search BPA...',
                    hintStyle: context.appText.bodyMedium!.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AccessibleIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            semanticLabel: 'Notifications',
            color: cs.onSurface,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
