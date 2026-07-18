import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/app_typography.dart';
// ✅ আপনার পেজগুলোর সঠিক ইমপোর্ট (ফোল্ডার স্ট্রাকচার অনুযায়ী)
import '../../../../../features/legacy/presentation/screens/vet_screen.dart';
import 'package:furtail_app/features/campaign/presentation/screens/campaign_hub_screen.dart';
import '../../../../../features/legacy/presentation/screens/shop_screen.dart';
import 'package:furtail_app/app/router/app_routes.dart';
// import '../../grooming_screen.dart'; // যদি থাকে

class ServiceGrid extends StatelessWidget {
  const ServiceGrid({super.key});

  @override
  Widget build(BuildContext context) {
    // সার্ভিস লিস্ট এবং তাদের অন-ট্যাপ অ্যাকশন
    final List<Map<String, dynamic>> services = [
      {
        'icon': Icons.vaccines_rounded,
        'label': 'Vaccination',
        'color': Colors.blue,
        'onTap': (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CampaignHubScreen()),
        ),
      },
      {
        'icon': Icons.local_hospital_rounded,
        'label': 'Vet Services',
        'color': Colors.redAccent,
        'onTap': (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VetScreen()),
        ),
      },
      {
        'icon': Icons.store_rounded,
        'label': 'Pet Shop',
        'color': Colors.orange,
        'onTap': (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ShopScreen()),
        ),
      },
      {
        'icon': Icons.volunteer_activism_rounded,
        'label': 'Donation',
        'color': Colors.pink,
        'onTap': (context) => Navigator.pushNamed(context, AppRoutes.donation),
      },
      {
        'icon': Icons.home_rounded,
        'label': 'Adoption',
        'color': Colors.green,
        'onTap': (context) => Navigator.pushNamed(context, AppRoutes.adoption),
      },
      // --- নিচের গুলোর জন্য পেজ তৈরি না থাকলে মেসেজ দেখাবে ---
      {
        'icon': Icons.content_cut_rounded,
        'label': 'Grooming',
        'color': Colors.purple,
        'onTap': (context) => _showComingSoon(context, "Grooming"),
      },
      {
        'icon': Icons.pets_rounded,
        'label': 'Training',
        'color': Colors.brown,
        'onTap': (context) => _showComingSoon(context, "Training"),
      },
      {
        'icon': Icons.hotel_rounded,
        'label': 'Pet Hotel',
        'color': Colors.blue,
        'onTap': (context) => _showComingSoon(context, "Pet Hotel"),
      },
      {
        'icon': Icons.local_shipping_rounded,
        'label': 'Transport',
        'color': Colors.teal,
        'onTap': (context) => _showComingSoon(context, "Transport"),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth / 4.5).clamp(72.0, 96.0);
        return SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: services.length,
            itemBuilder: (context, index) {
              return _buildServiceItem(
                context,
                services[index],
                itemWidth: itemWidth,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildServiceItem(
    BuildContext context,
    Map<String, dynamic> service, {
    required double itemWidth,
  }) {
    final cs = context.colorScheme;
    final color = service['color'] as Color? ?? cs.primary;
    return Container(
      width: itemWidth,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: InkWell(
        onTap: () {
          if (service['onTap'] != null) {
            service['onTap'](context);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(service['icon'], color: color, size: 26),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              service['label'],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.appText.labelMedium!.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: AppTypographyScale.meta,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // হেল্পার ফাংশন (যেগুলোর পেজ নেই)
  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$title feature coming soon!"),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
