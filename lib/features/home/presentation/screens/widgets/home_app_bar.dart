import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/accessibility/a11y_widgets.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/features/messaging/presentation/providers/messaging_providers.dart'
    show messagesUnreadCountProvider;

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
      child: Row(
        children: [
          MinTouchTarget(
            semanticLabel: 'Open navigation menu',
            onTap: () => Scaffold.of(context).openDrawer(),
            child: FurtailNetworkAvatar(
              imageUrl: avatarUrl,
              displayName: userName,
              radius: 20,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              textField: true,
              label: 'Search Furtail',
              child: Container(
                height: 40,
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
                    hintText: 'Search Furtail…',
                    hintStyle: context.appText.bodyMedium!.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notificationsList),
          ),
          Consumer(
            builder: (context, ref, _) {
              final unread =
                  ref.watch(messagesUnreadCountProvider).valueOrNull ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  AccessibleIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Messages',
                    semanticLabel: 'Messages',
                    color: cs.onSurface,
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.messagesInbox),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: cs.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
