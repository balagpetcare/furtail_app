import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/accessibility/a11y_widgets.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/widgets/count_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/features/messaging/presentation/providers/messaging_providers.dart'
    show messagesUnreadCountProvider;
import 'package:furtail_app/features/notifications/presentation/providers/notification_controller.dart'
    show notificationsUnreadCountProvider;

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
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.xs),
      child: SizedBox(
        height: 56, // Target approximately 56-64 logical pixels
        child: Row(
          children: [
            AccessibleIconButton(
              icon: Icons.menu,
              tooltip: 'Open navigation menu',
              semanticLabel: 'Open navigation menu',
              color: cs.onSurface,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Furtail',
              style: context.appText.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            AccessibleIconButton(
              icon: Icons.search,
              tooltip: 'Search Furtail',
              semanticLabel: 'Search Furtail',
              color: cs.onSurface,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
            ),
            Consumer(
              builder: (context, ref, child) {
                final unreadAsync = ref.watch(notificationsUnreadCountProvider);
                final count = unreadAsync.valueOrNull ?? 0;

                return CountBadge(
                  count: count,
                  child: AccessibleIconButton(
                    icon: Icons.notifications_outlined,
                    tooltip: 'Notifications',
                    semanticLabel: 'Notifications',
                    color: cs.onSurface,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.notificationsList,
                    ),
                  ),
                );
              },
            ),
            Consumer(
              builder: (context, ref, child) {
                final count =
                    ref.watch(messagesUnreadCountProvider).valueOrNull ?? 0;

                return CountBadge(
                  count: count,
                  child: AccessibleIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Messages',
                    semanticLabel: 'Messages',
                    color: cs.onSurface,
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.messagesInbox),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
