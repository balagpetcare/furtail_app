import 'package:flutter/material.dart';

import '../../app/router/app_routes.dart';
import '../../features/adoption/presentation/screens/adoption_notification_entry_screens.dart';
import '../../features/campaign/presentation/screens/campaign_details_page.dart';
import '../../features/campaign/presentation/screens/campaign_hub_screen.dart';
import '../../features/fundraising/presentation/screens/fundraising_details_screen.dart';
import '../../features/home/presentation/screens/furtail_home_screen.dart';
import '../../features/pets/presentation/screens/pet_profile_screen.dart';
import '../../features/posts/presentation/screens/post_details_by_id_screen.dart';
import '../../features/profile/presentation/screens/visitor_profile_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/profile/presentation/screens/visitor_profile_resolver_screen.dart';
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
          settings: RouteSettings(
            name: AppRoutes.campaignDetail,
            arguments: {'slug': slug},
          ),
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
      case DeepLinkKind.friendRequests:
        return MaterialPageRoute(
          builder: (_) => const FurtailHomeScreen(initialIndex: 4),
          settings: const RouteSettings(name: AppRoutes.notificationsList),
        );
      case DeepLinkKind.adoption:
        final adoptionId = int.tryParse(target.id);
        if (adoptionId == null || adoptionId <= 0) return null;
        return MaterialPageRoute(
          builder: (_) => AdoptionDetailEntryScreen(adoptionId: adoptionId),
          settings: const RouteSettings(name: AppRoutes.adoption),
        );
      case DeepLinkKind.adoptionComments:
        final adoptionId = int.tryParse(target.id);
        if (adoptionId == null || adoptionId <= 0) return null;
        return MaterialPageRoute(
          builder: (_) => AdoptionCommentsEntryScreen(adoptionId: adoptionId),
          settings: const RouteSettings(name: AppRoutes.adoption),
        );
      case DeepLinkKind.adoptionApplication:
        final applicationId = int.tryParse(target.id);
        if (applicationId == null || applicationId <= 0) return null;
        return MaterialPageRoute(
          builder: (_) =>
              AdoptionApplicationEntryScreen(applicationId: applicationId),
          settings: const RouteSettings(name: AppRoutes.adoption),
        );
      case DeepLinkKind.resetPassword:
        final token = target.id.trim();
        if (token.isEmpty) return null;
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(initialToken: token),
          settings: const RouteSettings(name: '/auth/reset-password'),
        );
      case DeepLinkKind.profile:
        final rawId = target.id.trim();
        // Numeric id: /user/123
        final userId = int.tryParse(rawId);
        if (userId != null && userId > 0) {
          return MaterialPageRoute(
            builder: (_) => VisitorProfileScreen(userId: userId),
            settings: RouteSettings(name: AppRoutes.visitorProfile),
          );
        }
        // Username: /user/johndoe or /@johndoe
        final username = rawId.replaceFirst(RegExp(r'^@'), '');
        if (username.isEmpty) return null;
        return MaterialPageRoute(
          builder: (_) => VisitorProfileResolverScreen(username: username),
          settings: RouteSettings(name: AppRoutes.visitorProfileByUsername),
        );
    }
  }
}
