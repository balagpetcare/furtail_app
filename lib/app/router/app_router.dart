import 'package:flutter/material.dart';
import 'app_routes.dart';

// screens imports (refactor path অনুযায়ী)
import '../../features/home/presentation/screens/furtail_home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/legacy/presentation/screens/splash_screen.dart';
import '../../features/legacy/presentation/screens/country_picker_screen.dart';
import '../../features/legacy/presentation/screens/shop_screen.dart';
import '../../features/legacy/presentation/screens/services_screen.dart';
import '../../features/legacy/presentation/screens/donation_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_create_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_details_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/profile/presentation/screens/visitor_profile_screen.dart';
import '../../features/profile/presentation/screens/visitor_profile_resolver_screen.dart';
import '../../features/legacy/presentation/screens/create_post_screen.dart';
import '../../features/legacy/presentation/screens/edit_post_screen.dart';
import 'package:furtail_app/features/posts/presentation/screens/post_details_screen.dart';
import 'package:furtail_app/features/posts/presentation/screens/media_viewer_screen.dart';
import 'package:furtail_app/features/posts/presentation/screens/post_media_detail_screen.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/reels_player_screen.dart';
import 'package:furtail_app/features/posts/presentation/screens/saved_posts_screen.dart';
import 'package:furtail_app/features/pets/presentation/pet_create_screen.dart';
import 'package:furtail_app/features/pets/presentation/screens/pet_profile_screen.dart';
import 'package:furtail_app/features/pets/presentation/screens/pet_public_profile_screen.dart';
import '../../features/settings/presentation/screens/account_settings_screen.dart';
import '../../features/settings/presentation/screens/media_storage_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'package:furtail_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:furtail_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:furtail_app/features/campaign/presentation/screens/campaign_hub_screen.dart';
import 'package:furtail_app/features/campaign/presentation/screens/certificate_viewer_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_home_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.countryPicker:
        return MaterialPageRoute(builder: (_) => const CountryPickerScreen());

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => LoginScreen()); // const নয়

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const FurtailHomeScreen());

      case AppRoutes.shop:
        return MaterialPageRoute(builder: (_) => const ShopScreen());

      case AppRoutes.services:
        return MaterialPageRoute(builder: (_) => const ServicesScreen());

      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const UserProfileScreen());

      case AppRoutes.visitorProfile:
        final args = (settings.arguments as Map?) ?? {};
        final rawUid = args['userId'];
        final userId = rawUid is int ? rawUid : int.tryParse(rawUid?.toString() ?? '');
        if (userId == null || userId <= 0) {
          return _notFound('Profile not available');
        }
        return MaterialPageRoute(
          builder: (_) => VisitorProfileScreen(userId: userId),
        );

      case AppRoutes.visitorProfileByUsername:
        final args = (settings.arguments as Map?) ?? {};
        final rawUsername = args['username'] as String? ?? '';
        final username = rawUsername.trim().replaceFirst(RegExp(r'^@'), '');
        if (username.isEmpty) {
          return _notFound('Profile not available');
        }
        return MaterialPageRoute(
          builder: (_) => VisitorProfileResolverScreen(username: username),
        );

      case AppRoutes.createPost:
        return MaterialPageRoute(builder: (_) => const CreatePostScreen());

      case AppRoutes.savedPosts:
        return MaterialPageRoute(builder: (_) => const SavedPostsScreen());

      case AppRoutes.postDetails:
        final args = (settings.arguments as Map?) ?? {};
        final post = args['post'];
        if (post == null) {
          return _notFound('Post argument missing');
        }
        return MaterialPageRoute(builder: (_) => PostDetailsScreen(post: post));

      case AppRoutes.postEdit:
        final args = (settings.arguments as Map?) ?? {};
        final post = args['post'];
        if (post == null) {
          return _notFound('Post argument missing');
        }
        return MaterialPageRoute(builder: (_) => EditPostScreen(post: post));

      case AppRoutes.mediaViewer:
      case AppRoutes.postMediaDetail:
        final args = (settings.arguments as Map?) ?? {};
        final post = args['post'] as PostModel?;
        final initialIndex = args['initialIndex'] as int? ?? 0;
        if (post != null) {
          return MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              post: post,
              initialIndex: initialIndex,
            ),
          );
        }
        // Fallback for legacy callers that pass individual fields
        final postId = args['postId'] as int? ?? 0;
        final media = (args['media'] as List?)?.cast<PostMediaModel>() ?? const [];
        final author = args['author'] as PostAuthorModel?;
        final caption = args['caption'] as String? ?? '';
        if (author == null) {
          return _notFound('Author details missing');
        }
        return MaterialPageRoute(
          builder: (_) => PostMediaDetailScreen(
            postId: postId,
            media: media,
            initialIndex: initialIndex,
            author: author,
            caption: caption,
          ),
        );

      case AppRoutes.reelsPlayer:
        final args = (settings.arguments as Map?) ?? {};
        final reels = args['reels'];
        final initialIndex = (args['initialIndex'] as int?) ?? 0;
        if (reels == null) {
          return _notFound('Reels argument missing');
        }
        return MaterialPageRoute(
          builder: (_) => ReelsPlayerScreen(
            reels: List.of(reels),
            initialIndex: initialIndex,
          ),
        );

      case AppRoutes.petCreate:
        return MaterialPageRoute(builder: (_) => const PetCreateScreen());

      case AppRoutes.petProfile:
        final args = (settings.arguments as Map?) ?? {};
        final petId = (args['petId'] as int?) ?? 0;
        return MaterialPageRoute(
          builder: (_) => PetProfileScreen(petId: petId),
        );

      case AppRoutes.petPublicProfile:
        final args = (settings.arguments as Map?) ?? {};
        final rawPid = args['petId'];
        final petId = rawPid is int ? rawPid : int.tryParse(rawPid?.toString() ?? '');
        if (petId == null || petId <= 0) {
          return _notFound('Pet profile not available');
        }
        return MaterialPageRoute(
          builder: (_) => PetPublicProfileScreen(petId: petId),
        );

      case AppRoutes.donation:
        return MaterialPageRoute(builder: (_) => const DonationScreen());

      case AppRoutes.adoption:
        return MaterialPageRoute(builder: (_) => const AdoptionHomeScreen());

      case AppRoutes.wallet:
        return MaterialPageRoute(builder: (_) => const WalletScreen());

      case AppRoutes.fundraisingCreate:
        return MaterialPageRoute(
          builder: (_) => const FundraisingCreateScreen(),
        );

      case AppRoutes.fundraisingDetails:
        final args = (settings.arguments as Map?) ?? {};
        final campaignId = (args['campaignId'] as int?) ?? 0;
        return MaterialPageRoute(
          builder: (_) => FundraisingDetailsScreen(campaignId: campaignId),
        );

      case AppRoutes.campaignHub:
        return MaterialPageRoute(builder: (_) => const CampaignHubScreen());

      case AppRoutes.campaignCertificate:
        final args = (settings.arguments as Map?) ?? {};
        final token = (args['token'] as String?) ?? '';
        return MaterialPageRoute(
          builder: (_) => CertificateViewerScreen(token: token),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case AppRoutes.accountSettings:
        return MaterialPageRoute(builder: (_) => const AccountSettingsScreen());

      // editProfile: navigate to own profile where avatar/bio editing lives
      case AppRoutes.editProfile:
        return MaterialPageRoute(builder: (_) => const UserProfileScreen());

      case AppRoutes.mediaStorageSettings:
        return MaterialPageRoute(
          builder: (_) => const MediaStorageSettingsScreen(),
        );


      case AppRoutes.notificationsList:
        return MaterialPageRoute(
          builder: (_) => const FurtailHomeScreen(initialIndex: 4),
        );

      // case AppRoutes.petList:
      //   return MaterialPageRoute(builder: (_) => const PetListScreen());

      default:
        return _notFound('Route not found');
    }
  }

  static Route<dynamic> _notFound(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(body: Center(child: Text(message))),
    );
  }
}
