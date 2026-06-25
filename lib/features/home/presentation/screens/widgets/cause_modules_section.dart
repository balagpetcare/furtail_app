import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
/// Dummy (static) modules that must appear on the home feed.
///
/// Includes: Adoption, Donation/Fund Collection, Campaign.
class CauseModulesSection extends StatelessWidget {
  const CauseModulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Explore',
              style: AppTypography.sectionTitle(context).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth * 0.72).clamp(200.0, 260.0);
              return SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: [
                    _CauseCard(
                      width: cardWidth,
                      icon: Icons.pets_rounded,
                      title: 'Adoption',
                      subtitle: 'Find a new friend',
                      chipText: 'Explore',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _CauseCard(
                      width: cardWidth,
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Donation',
                      subtitle: 'Fund collection',
                      chipText: 'Active',
                      showProgress: true,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _CauseCard(
                      width: cardWidth,
                      icon: Icons.campaign_rounded,
                      title: 'Campaign',
                      subtitle: 'Spread kindness',
                      chipText: 'New',
                    ),
                  ],
                ),
              );
            },
          ),
          Divider(thickness: 1, color: cs.outline, height: 1),
        ],
      ),
    );
  }
}

class _CauseCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final String chipText;
  final bool showProgress;

  const _CauseCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chipText,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: cs.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: context.colorScheme.primary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: Text(
                    chipText,
                    style: AppTypography.caption(context).copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appText.bodyMedium!.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.appText.bodySmall!.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.25,
              ),
            ),
            const Spacer(),
            if (showProgress) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: 0.62,
                  backgroundColor: const Color(0xFFF0F0F0),
                  valueColor: AlwaysStoppedAnimation(context.colorScheme.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '৳ 62,000 / ৳ 100,000',
                style: AppTypography.caption(context).copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE6E6E6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    'View',
                    style: AppTypography.bodyRegular(context).copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
