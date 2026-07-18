import 'package:flutter/material.dart';
import 'package:furtail_app/app/router/app_routes.dart';

import 'shop_screen.dart';
import 'vet_screen.dart';
import 'package:furtail_app/features/campaign/presentation/screens/campaign_hub_screen.dart';
import 'package:furtail_app/features/pets/presentation/pet_create_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      _ServiceSection(
        title: 'Care',
        items: [
          _ServiceItem(
            'Vet Services',
            Icons.medical_services_rounded,
            const VetScreen(),
          ),
          _ServiceItem(
            'Vaccination',
            Icons.vaccines_rounded,
            const CampaignHubScreen(),
          ),
          _ServiceItem('Emergency Vet', Icons.emergency_rounded, null),
          _ServiceItem('Grooming', Icons.content_cut_rounded, null),
          _ServiceItem('Boarding', Icons.hotel_rounded, null),
        ],
      ),
      _ServiceSection(
        title: 'Marketplace',
        items: [
          _ServiceItem('Pet Shop', Icons.store_rounded, const ShopScreen()),
          _ServiceItem('Pharmacy', Icons.local_pharmacy_rounded, null),
          _ServiceItem('Food', Icons.restaurant_rounded, null),
          _ServiceItem('Accessories', Icons.shopping_bag_rounded, null),
        ],
      ),
      _ServiceSection(
        title: 'Community',
        items: [
          _ServiceItem(
            'Adoption',
            Icons.favorite_rounded,
            null,
            routeName: AppRoutes.adoption,
          ),
          _ServiceItem('Lost & Found', Icons.travel_explore_rounded, null),
          _ServiceItem(
            'Donation',
            Icons.volunteer_activism_rounded,
            null,
            routeName: AppRoutes.donation,
          ),
          _ServiceItem('Rescue Support', Icons.health_and_safety_rounded, null),
        ],
      ),
      _ServiceSection(
        title: 'My Pet',
        items: [
          _ServiceItem(
            'Pet Profile',
            Icons.pets_rounded,
            const PetCreateScreen(),
          ),
          _ServiceItem('Medical Records', Icons.folder_shared_rounded, null),
          _ServiceItem(
            'Vaccination Reminder',
            Icons.event_available_rounded,
            null,
          ),
          _ServiceItem('Appointment History', Icons.history_rounded, null),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        automaticallyImplyLeading: false,
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) =>
            _ServiceSectionView(section: sections[index]),
      ),
    );
  }
}

class _ServiceSection {
  final String title;
  final List<_ServiceItem> items;

  const _ServiceSection({required this.title, required this.items});
}

class _ServiceItem {
  final String title;
  final IconData icon;
  final Widget? page;
  final String? routeName;

  const _ServiceItem(this.title, this.icon, this.page, {this.routeName});
}

class _ServiceSectionView extends StatelessWidget {
  final _ServiceSection section;

  const _ServiceSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            section.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: section.items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 92,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = section.items[index];
            final enabled = item.page != null || item.routeName != null;
            return InkWell(
              onTap: enabled
                  ? () {
                      if (item.routeName != null) {
                        Navigator.pushNamed(context, item.routeName!);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => item.page!),
                      );
                    }
                  : () => _showComingSoon(context, item.title),
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: enabled
                            ? cs.primary.withValues(alpha: 0.12)
                            : cs.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        color: enabled ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (!enabled) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Coming soon',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title is coming soon')));
  }
}
