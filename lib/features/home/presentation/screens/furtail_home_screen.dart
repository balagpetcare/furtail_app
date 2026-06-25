import 'dart:async';

import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furtail_app/core/config/policy_features_provider.dart';
import 'package:furtail_app/core/network/connectivity_service.dart';
import 'package:furtail_app/core/providers/current_user_provider.dart';
import 'package:furtail_app/core/widgets/offline_banner.dart';
import 'package:furtail_app/core/widgets/placeholder_screen.dart';

// Ã Â¦â€°Ã Â¦â€¡Ã Â¦Å“Ã Â§â€¡Ã Â¦Å¸ Ã Â¦â€¡Ã Â¦Â®Ã Â¦ÂªÃ Â§â€¹Ã Â¦Â°Ã Â§ÂÃ Â¦Å¸
import 'widgets/home_app_bar.dart';
import 'widgets/service_grid.dart';
import 'widgets/feed_list.dart';
import 'widgets/custom_bottom_nav.dart';
import 'widgets/custom_drawer.dart';
import 'videos_tab_screen.dart';
import 'package:furtail_app/features/story/presentation/widgets/my_day_section.dart';
import 'package:furtail_app/features/story/presentation/screens/create_story_screen.dart';
import 'package:furtail_app/core/services/post_upload_manager.dart';

// Ã Â¦Â¸Ã Â§ÂÃ Â¦â€¢Ã Â§ÂÃ Â¦Â°Ã Â¦Â¿Ã Â¦Â¨ Ã Â¦â€¡Ã Â¦Â®Ã Â¦ÂªÃ Â§â€¹Ã Â¦Â°Ã Â§ÂÃ Â¦Å¸
import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart';
import 'package:furtail_app/features/legacy/presentation/screens/create_post_screen.dart';
import 'package:furtail_app/features/legacy/presentation/screens/shop_screen.dart';
import 'package:furtail_app/features/legacy/presentation/screens/services_screen.dart';
import 'package:furtail_app/features/profile/presentation/screens/user_profile_screen.dart';

import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_feed_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_create_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_payout_methods_screen.dart';
import 'package:furtail_app/features/wallet/presentation/screens/wallet_screen.dart';

import 'package:furtail_app/core/navigation/home_back_handler.dart';
import 'package:furtail_app/app/router/app_routes.dart';

// Ã¢Å“â€¦ Pet create screen import (Ã Â¦â€ Ã Â¦ÂªÃ Â¦Â¨Ã Â¦Â¾Ã Â¦Â° path Ã Â¦â€¦Ã Â¦Â¨Ã Â§ÂÃ Â¦Â¯Ã Â¦Â¾Ã Â§Å¸Ã Â§â‚¬ Ã Â¦Â Ã Â¦Â¿Ã Â¦â€¢ Ã Â¦â€¢Ã Â¦Â°Ã Â§ÂÃ Â¦Â¨)

import 'package:furtail_app/features/pets/presentation/pet_create_screen.dart';
import 'package:furtail_app/features/campaign/presentation/screens/campaign_hub_screen.dart';
import 'package:furtail_app/features/notifications/presentation/providers/notification_controller.dart';
import 'package:furtail_app/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:furtail_app/features/settings/presentation/screens/account_settings_screen.dart';
import 'package:furtail_app/features/settings/presentation/screens/notification_preferences_screen.dart';

class FurtailHomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const FurtailHomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<FurtailHomeScreen> createState() => _FurtailHomeScreenState();
}

class _FurtailHomeScreenState extends ConsumerState<FurtailHomeScreen> {
  late int _selectedIndex;

  // Ã¢Å“â€¦ Rebuild/refresh tokens for each tab (IndexedStack keeps state; tokens force reload)
  int _homeRefreshToken = 0;
  int _shopRefreshToken = 0;
  int _servicesRefreshToken = 0;
  int _profileRefreshToken = 0;

  // Connectivity: auto-refresh feed when internet returns.
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  ConnectivityStatus _lastConnectivity = ConnectivityStatus.unknown;

  // Scroll controller for the Home feed.
  final _scrollController = ScrollController();

  String userName = "Guest";
  String userEmail = "";
  String? avatarUrl;
  String? token;

  // Upload dialog deduplication Ã¢â‚¬â€ track the task id + status of the last shown
  // dialog so the same terminal state never opens a duplicate sheet.
  String? _lastDialogTaskId;
  PostUploadStatus? _lastDialogStatus;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserData();
    _startConnectivityWatch();
    PostUploadManager.instance.state.addListener(_onUploadStateChanged);
  }

  void _onUploadStateChanged() {
    final uploadState = PostUploadManager.instance.state.value;
    final taskId = PostUploadManager.instance.currentTask?.id;

    // Reset dedup when a new attempt starts so retry-then-fail can re-show the dialog.
    if (uploadState.status == PostUploadStatus.preparing) {
      _lastDialogStatus = null;
    }

    if (uploadState.status == PostUploadStatus.posted) {
      // Refresh feed 2 s after success so the new post appears.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _homeRefreshToken++);
      });
      if (_lastDialogTaskId == taskId &&
          _lastDialogStatus == PostUploadStatus.posted) {
        return;
      }
      _lastDialogTaskId = taskId;
      _lastDialogStatus = PostUploadStatus.posted;
      _showUploadSuccessSnackBar();
    } else if (uploadState.status == PostUploadStatus.failed) {
      if (_lastDialogTaskId == taskId &&
          _lastDialogStatus == PostUploadStatus.failed) {
        return;
      }
      _lastDialogTaskId = taskId;
      _lastDialogStatus = PostUploadStatus.failed;
      _showUploadFailedSheet(uploadState);
    }
  }

  void _showUploadFailedSheet(PostUploadState uploadState) {
    if (!mounted) return;
    final rawError = uploadState.error ?? '';
    // Size errors are permanent Ã¢â‚¬â€ retry will fail for the same file.
    final isSizeError =
        rawError.toLowerCase().contains('too large') ||
        rawError.contains('Maximum allowed');

    // Sanitize: never show raw stack traces / module paths to users
    String sanitizedError = rawError;
    if (rawError.contains('Cannot find module') ||
        rawError.contains('require stack') ||
        rawError.contains('.ts') ||
        rawError.contains(':\\') && rawError.contains('node_modules') ||
        rawError.startsWith('Error: ') && rawError.length > 200) {
      sanitizedError = 'Upload failed due to a server issue. Please try again.';
    }

    bool actionTaken = false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _UploadFailedSheet(
        errorMessage: sanitizedError,
        showRetry: !isSizeError,
        onRetry: () {
          actionTaken = true;
          Navigator.of(context, rootNavigator: true).pop();
          PostUploadManager.instance.retry().catchError((e) {
            debugPrint('[Home] Retry error: $e');
          });
        },
        onCancel: () {
          actionTaken = true;
          Navigator.of(context, rootNavigator: true).pop();
          // Dismiss the "Tap to retry" system-tray notification before resetting
          // so the user can't re-trigger a cancelled task from the shade.
          PostUploadManager.instance.cancelNotification();
          PostUploadManager.instance.reset();
        },
      ),
    ).whenComplete(() {
      // User swiped the sheet away without tapping a button Ã¢â‚¬â€ treat as cancel.
      if (!actionTaken &&
          PostUploadManager.instance.state.value.status ==
              PostUploadStatus.failed) {
        PostUploadManager.instance.cancelNotification();
        PostUploadManager.instance.reset();
      }
    });
  }

  void _showUploadSuccessSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Posted successfully'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    // Auto-reset state after snackbar duration
    Future.delayed(const Duration(milliseconds: 500), () {
      if (PostUploadManager.instance.state.value.status ==
          PostUploadStatus.posted) {
        PostUploadManager.instance.reset();
      }
    });
  }

  void _startConnectivityWatch() {
    final service = ref.read(connectivityServiceProvider);
    _connectivitySub = service.onStatusChange.listen((status) {
      if (_lastConnectivity != ConnectivityStatus.online &&
          status == ConnectivityStatus.online) {
        // Internet just came back Ã¢â‚¬â€œ silently refresh the feed.
        if (mounted) setState(() => _homeRefreshToken++);
      }
      _lastConnectivity = status;
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _scrollController.dispose();
    PostUploadManager.instance.state.removeListener(_onUploadStateChanged);
    super.dispose();
  }

  // Ã Â¦â€¡Ã Â¦â€°Ã Â¦Å“Ã Â¦Â¾Ã Â¦Â° Ã Â¦Â¡Ã Â¦Â¾Ã Â¦Å¸Ã Â¦Â¾ Ã Â¦Â²Ã Â§â€¹Ã Â¦Â¡ Ã Â¦â€¢Ã Â¦Â°Ã Â¦Â¾
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final newUserName = prefs.getString('userName') ?? "Guest";
    final newUserEmail = prefs.getString('userEmail') ?? "";
    final newAvatarUrl = prefs.getString('avatarUrl');
    final newToken = prefs.getString('token');

    // If token just became available (e.g., right after login), refresh the feed.
    final bool tokenBecameAvailable =
        (token == null || token!.isEmpty) &&
        (newToken != null && newToken.isNotEmpty);

    setState(() {
      userName = newUserName;
      userEmail = newUserEmail;
      avatarUrl = newAvatarUrl;
      token = newToken;

      if (tokenBecameAvailable) {
        _homeRefreshToken++;
      }
    });

    // Keep the reactive provider in sync so HomeAppBar and drawer rebuild.
    ref.read(currentUserProvider.notifier).reloadFromPrefs();
  }

  bool get _isLoggedIn => token != null && token!.isNotEmpty;

  // Ã Â¦Â¸Ã Â§â€¹Ã Â§Å¸Ã Â¦Â¾Ã Â¦â€¡Ã Â¦Âª Ã Â¦Å¸Ã Â§Â Ã Â¦Â°Ã Â¦Â¿Ã Â¦Â«Ã Â§ÂÃ Â¦Â°Ã Â§â€¡Ã Â¦Â¶ Ã Â¦Â¹Ã Â§ÂÃ Â¦Â¯Ã Â¦Â¾Ã Â¦Â¨Ã Â§ÂÃ Â¦Â¡Ã Â¦Â²Ã Â¦Â¾Ã Â¦Â°
  Future<void> _handleRefresh() async {
    // RefreshIndicator (Home feed only)
    await _loadUserData();
    if (mounted) {
      setState(() => _homeRefreshToken++);
    }
  }

  // bottom nav tap
  void _onItemTapped(int index) async {
    if (index == 2) {
      _showCreateSheet();
      return;
    }

    final isSameTab = index == _selectedIndex;
    if (index == 4) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final t = prefs.getString('token');

      if (t == null || t.isEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
        await _loadUserData();
        return;
      }
    }

    if (index == 0) {
      await _loadUserData();
    }
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
      if (index == 0) _homeRefreshToken++;
      if (index == 1) _shopRefreshToken++;
      if (index == 3) _servicesRefreshToken++;
      if (index == 4 && isSameTab) _profileRefreshToken++;
    });
  }

  Future<void> _showCreateSheet() async {
    final selected = await showModalBottomSheet<_CreateAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CreateSheetTile(
              icon: Icons.edit_note_rounded,
              label: 'Create Post',
              action: _CreateAction.post,
            ),
            _CreateSheetTile(
              icon: Icons.video_call_rounded,
              label: 'Upload Video',
              action: _CreateAction.video,
            ),
            _CreateSheetTile(
              icon: Icons.auto_stories_rounded,
              label: 'Add Story',
              action: _CreateAction.story,
            ),
            _CreateSheetTile(
              icon: Icons.pets_rounded,
              label: 'Add Pet',
              action: _CreateAction.pet,
            ),
            _CreateSheetTile(
              icon: Icons.medical_services_rounded,
              label: 'Book Service',
              action: _CreateAction.service,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    if (selected != _CreateAction.service && !_isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      await _loadUserData();
      if (!mounted || !_isLoggedIn) return;
    }

    switch (selected) {
      case _CreateAction.post:
      case _CreateAction.video:
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        );
        if (created == true && mounted) setState(() => _homeRefreshToken++);
        return;
      case _CreateAction.story:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
        );
        return;
      case _CreateAction.pet:
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PetCreateScreen()),
        );
        if (changed == true && mounted) await _loadUserData();
        return;
      case _CreateAction.service:
        if (mounted) setState(() => _selectedIndex = 3);
        return;
    }
  }

  // Ã¢Å“â€¦ Drawer click handler
  Future<void> _handleDrawerSelect(BPADrawerDestination dest) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final t = prefs.getString('token');
    final loggedIn = t != null && t.isNotEmpty;

    // Helper: push to login if not authenticated.
    Future<bool> ensureLoggedIn() async {
      if (loggedIn) return true;
      if (!mounted) return false;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      if (!mounted) return false;
      await _loadUserData();
      if (!mounted) return false;
      final p = await SharedPreferences.getInstance();
      return p.getString('token') != null && p.getString('token')!.isNotEmpty;
    }

    // Protected routes (login needed)
    bool requiresLogin(BPADrawerDestination d) {
      return d == BPADrawerDestination.petList ||
          d == BPADrawerDestination.petRegister ||
          d == BPADrawerDestination.vaccinationCampaign ||
          d == BPADrawerDestination.messages ||
          d == BPADrawerDestination.notifications ||
          d == BPADrawerDestination.settings ||
          d == BPADrawerDestination.adoption ||
          d == BPADrawerDestination.donation ||
          d == BPADrawerDestination.startFundraising ||
          d == BPADrawerDestination.payoutMethods;
    }

    if (requiresLogin(dest) && !loggedIn) {
      final ok = await ensureLoggedIn();
      if (!ok || !mounted) return;
    }

    // Close drawer (if open) before navigating
    if (mounted) {
      try {
        Navigator.of(context).pop();
      } catch (_) {}
    }
    if (!mounted) return;

    // Helper: push a simple placeholder screen.
    void pushPlaceholder(
      String title,
      String message, {
      IconData icon = Icons.construction_rounded,
    }) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PlaceholderScreen(title: title, message: message, icon: icon),
        ),
      );
    }

    // Navigate / switch tabs
    switch (dest) {
      case BPADrawerDestination.home:
        await _loadUserData();
        if (mounted) setState(() => _selectedIndex = 0);
        return;

      case BPADrawerDestination.shop:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopScreen()),
          );
          return;
        }

      case BPADrawerDestination.services:
        if (mounted) setState(() => _selectedIndex = 3);
        return;

      case BPADrawerDestination.petRegister:
        {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PetCreateScreen()),
          );
          if (changed == true && mounted) {
            await _loadUserData();
            if (mounted) setState(() {});
          }
          return;
        }

      case BPADrawerDestination.petList:
        {
          pushPlaceholder(
            'Pet List',
            'Pet list is coming soon. Stay tuned!',
            icon: Icons.pets_rounded,
          );
          return;
        }

      case BPADrawerDestination.vet:
      case BPADrawerDestination.grooming:
      case BPADrawerDestination.training:
        {
          if (mounted) setState(() => _selectedIndex = 3);
          return;
        }

      case BPADrawerDestination.vaccinationCampaign:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CampaignHubScreen()),
          );
          return;
        }

      case BPADrawerDestination.community:
      case BPADrawerDestination.events:
      case BPADrawerDestination.messages:
        {
          pushPlaceholder(
            'Coming Soon',
            'This feature is being built and will be available soon.',
          );
          return;
        }

      case BPADrawerDestination.notifications:
        {
          await Navigator.pushNamed(context, AppRoutes.notificationsList);
          return;
        }

      case BPADrawerDestination.profile:
        if (mounted) setState(() => _selectedIndex = 4);
        return;

      case BPADrawerDestination.settings:
        {
          // Use pushNamed with a name so no duplicate route is created
          // when the user taps Settings multiple times.
          final currentRoute = ModalRoute.of(context);
          if (currentRoute?.settings.name != AppRoutes.settings) {
            await Navigator.pushNamed(context, AppRoutes.settings);
          }
          return;
        }

      case BPADrawerDestination.help:
      case BPADrawerDestination.about:
        {
          pushPlaceholder('Coming Soon', 'This section is being updated.');
          return;
        }

      case BPADrawerDestination.donation:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FundraisingFeedScreen()),
          );
          return;
        }

      case BPADrawerDestination.wallet:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WalletScreen()),
          );
          return;
        }

      case BPADrawerDestination.startFundraising:
        {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const FundraisingCreateScreen()),
          );
          if (created == true && mounted) {
            await _loadUserData();
            if (mounted) setState(() {});
          }
          return;
        }

      case BPADrawerDestination.payoutMethods:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FundraisingPayoutMethodsScreen(),
            ),
          );
          return;
        }

      case BPADrawerDestination.adoption:
        {
          pushPlaceholder(
            'Adoption',
            'Adoption screen is not added yet. Come back soon!',
            icon: Icons.favorite_rounded,
          );
          return;
        }

      case BPADrawerDestination.logout:
        {
          try {
            await ref
                .read(notificationControllerProvider.notifier)
                .unregisterPush();
          } catch (_) {}
          if (!mounted) return;

          await prefs.remove('token');
          await prefs.remove('userName');
          await prefs.remove('userEmail');
          ref.read(currentUserProvider.notifier).clear();

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
          );
          return;
        }

      // Ã¢â€â‚¬Ã¢â€â‚¬ v2 / expandable-section destinations Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

      case BPADrawerDestination.savedItems:
        {
          await Navigator.pushNamed(context, AppRoutes.savedPosts);
          return;
        }

      case BPADrawerDestination.dashboard:
        {
          pushPlaceholder(
            'Dashboard',
            'Dashboard is coming soon. You\'ll see your insights and activity here.',
            icon: Icons.dashboard_rounded,
          );
          return;
        }

      case BPADrawerDestination.helpCenter:
        {
          pushPlaceholder(
            'Help Center',
            'Browse articles and FAQs to get the most out of Furtail.',
            icon: Icons.menu_book_rounded,
          );
          return;
        }

      case BPADrawerDestination.contactSupport:
        {
          pushPlaceholder(
            'Contact Support',
            'Our team will get back to you within 24 hours.',
            icon: Icons.support_agent_rounded,
          );
          return;
        }

      case BPADrawerDestination.reportProblem:
        {
          pushPlaceholder(
            'Report a Problem',
            'Help us improve by reporting any issues you encounter.',
            icon: Icons.flag_rounded,
          );
          return;
        }

      case BPADrawerDestination.safetyGuidelines:
        {
          pushPlaceholder(
            'Safety & Guidelines',
            'Learn how we keep the Furtail community safe and welcoming.',
            icon: Icons.shield_rounded,
          );
          return;
        }

      case BPADrawerDestination.privacy:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
          );
          return;
        }

      case BPADrawerDestination.security:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
          );
          return;
        }

      case BPADrawerDestination.notificationSettings:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationPreferencesScreen(),
            ),
          );
          return;
        }

      case BPADrawerDestination.language:
        {
          pushPlaceholder(
            'Language',
            'Language selection is coming soon.',
            icon: Icons.language_rounded,
          );
          return;
        }

      case BPADrawerDestination.furtailMember:
      case BPADrawerDestination.petCensus:
        {
          pushPlaceholder(
            'Coming Soon',
            'This feature is being built and will be available soon.',
          );
          return;
        }

      case BPADrawerDestination.campaigns:
        {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CampaignHubScreen()),
          );
          return;
        }

      case BPADrawerDestination.aboutFurtail:
        {
          pushPlaceholder(
            'About Furtail',
            'Furtail is the ultimate pet community Ã¢â‚¬â€ connecting pet lovers, sharing moments, and caring for animals together.',
            icon: Icons.info_rounded,
          );
          return;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ã Â¦ÂªÃ Â§â€¡Ã Â¦Å“ Ã Â¦Â²Ã Â¦Â¿Ã Â¦Â¸Ã Â§ÂÃ Â¦Å¸
    final List<Widget> pages = [
      RefreshIndicator(
        onRefresh: _handleRefresh,
        color: context.colorScheme.primary,
        backgroundColor: context.colorScheme.surface,
        child: HomeContentAssembly(
          key: ValueKey('home_$_homeRefreshToken'),
          userName: userName,
          refreshToken: _homeRefreshToken,
          scrollController: _scrollController,
        ),
      ),
      KeyedSubtree(
        key: ValueKey('videos_$_shopRefreshToken'),
        child: VideosTabScreen(refreshToken: _shopRefreshToken),
      ),
      const SizedBox.shrink(),
      KeyedSubtree(
        key: ValueKey('services_$_servicesRefreshToken'),
        child: const ServicesScreen(),
      ),
      KeyedSubtree(
        key: ValueKey('profile_$_profileRefreshToken'),
        child: UserProfileScreen(
          onPetChanged: () async {
            await _loadUserData();
            if (mounted) setState(() => _profileRefreshToken++);
          },
        ),
      ),
    ];

    return HomeBackHandler(
      selectedTabIndex: _selectedIndex,
      onSelectHomeTab: (index) => setState(() => _selectedIndex = index),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).colorScheme.surface,

        // Ã¢Å“â€¦ Updated drawer (required parameters). Phase 5: donationEnabled from policy
        drawer: Consumer(
          builder: (context, ref, _) {
            final featuresAsync = ref.watch(policyFeaturesProvider);
            final donationEnabled =
                featuresAsync.valueOrNull?.donationEnabled ?? true;
            final currentUser = ref.watch(currentUserProvider);
            final notifState = ref.watch(notificationsListProvider);
            return BPACustomDrawer(
              isLoggedIn: _isLoggedIn,
              userName: currentUser.name,
              userEmail: currentUser.email,
              onSelect: _handleDrawerSelect,
              avatarUrl: currentUser.avatarUrl,
              donationEnabled: donationEnabled,
              unreadCount: notifState.unreadCount,
            );
          },
        ),

        body: SafeArea(
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),

        // Bottom nav is always visible Ã¢â‚¬â€ no scroll-based hiding.
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
          onFabPressed: _showCreateSheet,
        ),
      ),
    );
  }
}

// ------------------------------------------
// HOME CONTENT ASSEMBLY
// ------------------------------------------

enum _CreateAction { post, video, story, pet, service }

class _CreateSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final _CreateAction action;

  const _CreateSheetTile({
    required this.icon,
    required this.label,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.pop(context, action),
    );
  }
}

class HomeContentAssembly extends ConsumerWidget {
  final String userName;
  final int refreshToken;
  final ScrollController? scrollController;

  const HomeContentAssembly({
    super.key,
    required this.userName,
    required this.refreshToken,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Ã¢Å“â€¦ Hide on scroll down, show on scroll up (Search/Profile/Notification bar)
        SliverAppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          pinned: true,
          floating: false,
          snap: false,
          toolbarHeight: 60,
          flexibleSpace: SafeArea(
            bottom: false,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: HomeAppBar(
                userName: userName,
                avatarUrl: ref.watch(currentUserProvider).avatarUrl,
              ),
            ),
          ),
        ),
        // Ã¢â€â‚¬Ã¢â€â‚¬ Offline / poor-connection banner Ã¢â€â‚¬Ã¢â€â‚¬
        const SliverToBoxAdapter(child: OfflineBanner()),

        // Ã¢â€â‚¬Ã¢â€â‚¬ My Day / Story (replaces old CampaignHomeSliver + static StorySection) Ã¢â€â‚¬Ã¢â€â‚¬
        SliverToBoxAdapter(
          child: Column(
            children: [
              const MyDaySection(),
              const SizedBox(height: 15),
              const ServiceGrid(),
              const SizedBox(height: 10),
              Divider(
                thickness: 1,
                height: 1,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
        // Ã¢â€â‚¬Ã¢â€â‚¬ Feed list Ã¢â€â‚¬Ã¢â€â‚¬
        FeedList(refreshToken: refreshToken),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬ Upload result bottom sheets Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// These are shown only for terminal states (failed / posted).
// All in-progress updates appear exclusively in the Android system notification.

class _UploadFailedSheet extends StatelessWidget {
  final String? errorMessage;
  final bool showRetry;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _UploadFailedSheet({
    required this.onRetry,
    required this.onCancel,
    this.errorMessage,
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade600,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Failed',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: 24),
            if (showRetry)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
