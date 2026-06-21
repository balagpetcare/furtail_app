import 'package:flutter/material.dart';

import '../../app/router/app_routes.dart';
import '../../features/campaign/presentation/screens/campaign_details_page.dart';
import '../../features/campaign/presentation/screens/campaign_hub_screen.dart';
import '../../features/fundraising/presentation/screens/fundraising_details_screen.dart';
import '../../features/pets/presentation/screens/pet_profile_screen.dart';
import '../../features/posts/presentation/screens/post_details_by_id_screen.dart';
import '../../features/profile/presentation/screens/visitor_profile_screen.dart';
import 'deep_link_target.dart';

/// Maps [DeepLinkTarget] to in-app navigation.
abstract final class DeepLinkNavigator {
  static Future<bool> navigate(
    NavigatorState? navigator,
    DeepLinkTarget target,
  ) async {
    final nav = navigator;
    if (nav == null) return false;

    final route = _routeFor(target);
    if (route == null) return false;

    await nav.push(route);
    return true;
  }

  static Route<dynamic>? _routeFor(DeepLinkTarget target) {
    switch (target.kind) {
      case DeepLinkKind.campaignDetail:
        final slug = target.id.trim();
        if (slug.isEmpty) return null;
        return MaterialPageRoute(
          builder: (_) => CampaignDetailsPage(slug: slug),
          settings: RouteSettings(name: AppRoutes.campaignDetail, arguments: {'slug': slug}),
        );
      case DeepLinkKind.campaign:
        return MaterialPageRoute(
          builder: (_) => const CampaignHubScreen(),
          settings: RouteSettings(
            name: AppRoutes.campaignHub,
            arguments: {'campaignId': target.id},
          ),
        );
      case DeepLinkKind.post:
        final postId = int.tryParse(target.id);
        if (postId == null || postId <= 0) return null;
        return MaterialPageRoute(
          builder: (_) => PostDetailsByIdScreen(postId: postId),
          settings: RouteSettings(name: AppRoutes.postDetails),
        );
      case DeepLinkKind.pet:
        final petId = int.tryParse(target.id);
        if (petId == null || petId <= 0) return null;
        return MaterialPageRoute(
          builder: (_) => PetProfileScreen(petId: petId),
          settings: RouteSettings(name: AppRoutes.petProfile),
        );
      case DeepLinkKind.fundraising:
        final campaignId = int.tryParse(target.id);
        if (campaignId == null || campaignId <= 0) return null;
        return MaterialPageRoute(
          builder: (_) => FundraisingDetailsScreen(campaignId: campaignId),
          settings: RouteSettings(name: AppRoutes.fundraisingDetails),
        );
      case DeepLinkKind.profile:
        final userId = int.tryParse(target.id);
        if (userId == null || userId <= 0) return null;
        return MaterialPageRoute(
          builder: (_) => VisitorProfileScreen(userId: userId),
          settings: RouteSettings(name: AppRoutes.visitorProfile),
        );
    }
  }
}
