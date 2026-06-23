import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furtail_app/core/config/policy_features_provider.dart';

// উইজেট ইমপোর্ট
import 'package:furtail_app/features/campaign/widgets/campaign_home_section.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/story_section.dart';
import 'widgets/service_grid.dart';
import 'widgets/feed_list.dart';
import 'widgets/custom_bottom_nav.dart';
import 'widgets/custom_drawer.dart';

// স্ক্রিন ইমপোর্ট
import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart'
    hide HomeAppBar;
import 'package:furtail_app/features/legacy/presentation/screens/create_post_screen.dart';
import 'package:furtail_app/features/legacy/presentation/screens/shop_screen.dart';
import 'package:furtail_app/features/legacy/presentation/screens/services_screen.dart';
import 'package:furtail_app/features/profile/presentation/screens/user_profile_screen.dart';

import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_feed_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_create_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_payout_methods_screen.dart';
import 'package:furtail_app/features/wallet/presentation/screens/wallet_screen.dart';

import 'package:furtail_app/core/navigation/home_back_handler.dart';
import 'package:furtail_app/core/utils/app_snackbar.dart';
import 'package:furtail_app/app/router/app_routes.dart';

// ✅ Pet create screen import (আপনার path অনুযায়ী ঠিক করুন)

import 'package:furtail_app/features/pets/presentation/pet_create_screen.dart';
import 'package:furtail_app/features/campaign/presentation/screens/campaign_hub_screen.dart';

class FurtailHomeScreen extends StatefulWidget {
  const FurtailHomeScreen({super.key});

  @override
  State<FurtailHomeScreen> createState() => _FurtailHomeScreenState();
}

class _FurtailHomeScreenState extends State<FurtailHomeScreen> {
  int _selectedIndex = 0;

  // ✅ Rebuild/refresh tokens for each tab (IndexedStack keeps state; tokens force reload)
  int _homeRefreshToken = 0;
  int _shopRefreshToken = 0;
  int _servicesRefreshToken = 0;
  int _profileRefreshToken = 0;

  // ✅ Home feed post-create status
  bool _showPostCreatingBanner = false;

  String userName = "Guest";
  String userEmail = "";
  String? avatarUrl;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ইউজার ডাটা লোড করা
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final newUserName = prefs.getString('userName') ?? "Guest";
    final newUserEmail = prefs.getString('userEmail') ?? "";
    final newAvatarUrl = prefs.getString('avatarUrl');
    final newToken = prefs.getString('token');

    // If token just became available (e.g., right after login), refresh the feed.
    final bool tokenBecameAvailable =
        (token == null || token!.isEmpty) && (newToken != null && newToken.isNotEmpty);

    setState(() {
      userName = newUserName;
      userEmail = newUserEmail;
      avatarUrl = newAvatarUrl;
      token = newToken;

      if (tokenBecameAvailable) {
        _homeRefreshToken++;
      }
    });
  }

  bool get _isLoggedIn => token != null && token!.isNotEmpty;

  // সোয়াইপ টু রিফ্রেশ হ্যান্ডলার
  Future<void> _handleRefresh() async {
    // RefreshIndicator (Home feed only)
    await _loadUserData();
    if (mounted) {
      setState(() => _homeRefreshToken++);
    }
  }

  // bottom nav tap
  void _onItemTapped(int index) async {
    final isSameTab = index == _selectedIndex;
    if (index == 3) {
      // প্রোফাইলে যাওয়ার আগে টোকেন চেক
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString('token');

      if (t != null && t.isNotEmpty) {
        setState(() {
          _selectedIndex = index;
          // ✅ tap again → reload
          if (isSameTab) _profileRefreshToken++;
        });
      } else {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        ).then((_) => _loadUserData());
      }
    } else {
      if (index == 0) {
        await _loadUserData();
      }

      setState(() {
        _selectedIndex = index;
        // ✅ Every tab click (even same tab) should reload that tab
        if (index == 0) _homeRefreshToken++;
        if (index == 1) _shopRefreshToken++;
        if (index == 2) _servicesRefreshToken++;
      });
    }
  }

  // ✅ Drawer click handler
  Future<void> _handleDrawerSelect(BPADrawerDestination dest) async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('token');
    final loggedIn = t != null && t.isNotEmpty;

    // helper: login screen open
    Future<void> _openLogin() async {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      await _loadUserData();
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
      await _openLogin();
      return;
    }

    // Close drawer (if open) before navigating
    if (mounted) {
      try {
        Navigator.of(context).pop();
      } catch (_) {}
    }

    // Navigate / switch tabs
    switch (dest) {
      case BPADrawerDestination.home:
        // Drawer থেকে Home এ গেলে Home data reload করা
        await _loadUserData();
        if (mounted) setState(() => _selectedIndex = 0);
        return;

      case BPADrawerDestination.shop:
        setState(() => _selectedIndex = 1);
        return;

      case BPADrawerDestination.services:
        setState(() => _selectedIndex = 2);
        return;

      case BPADrawerDestination.petRegister:
        {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PetCreateScreen()),
          );

          // pet create শেষে true return করলে profile/home refresh
          if (changed == true) {
            await _loadUserData();
            if (mounted) setState(() {});
          }
          return;
        }

      case BPADrawerDestination.petList:
        {
          // ✅ আপনার কাছে PetListScreen থাকলে এখানে বসাবেন
          // Navigator.push(context, MaterialPageRoute(builder: (_) => const PetListScreen()));
          showAppSnackBar(context, 'Pet List screen is not available yet.');
          return;
        }

      case BPADrawerDestination.vet:
      case BPADrawerDestination.grooming:
      case BPADrawerDestination.training:
        {
          // আপাতত Services tab এ নিয়ে যাওয়া হলো
          setState(() => _selectedIndex = 2);
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
      case BPADrawerDestination.notifications:
        {
          showAppSnackBar(context, 'This feature is coming soon ✅');
          return;
        }

      case BPADrawerDestination.profile:
        setState(() => _selectedIndex = 3);
        return;

      case BPADrawerDestination.settings:
        {
          Navigator.pushNamed(context, AppRoutes.settings);
          return;
        }

      case BPADrawerDestination.help:
      case BPADrawerDestination.about:
        {
          showAppSnackBar(context, 'This screen is coming soon ✅');
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
          if (created == true) {
            // refresh home in case a new fundraising post should appear in feed
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
          showAppSnackBar(context, 'Adoption screen is not added yet.');
          return;
        }

      case BPADrawerDestination.logout:
        {
          // Logout
          await prefs.remove('token');
          await prefs.remove('userName');
          await prefs.remove('userEmail');

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
          );
          return;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // পেজ লিস্ট
    final List<Widget> pages = [
      RefreshIndicator(
        onRefresh: _handleRefresh,
        color: context.colorScheme.primary,
        backgroundColor: context.colorScheme.surface,
        child: HomeContentAssembly(
          key: ValueKey('home_$_homeRefreshToken'),
          userName: userName,
          refreshToken: _homeRefreshToken,
          showPostCreatingBanner: _showPostCreatingBanner,
        ),
      ),
      KeyedSubtree(
        key: ValueKey('shop_$_shopRefreshToken'),
        child: const ShopScreen(),
      ),
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

      // ✅ Updated drawer (required parameters). Phase 5: donationEnabled from policy
      drawer: Consumer(
        builder: (context, ref, _) {
          final featuresAsync = ref.watch(policyFeaturesProvider);
          final donationEnabled = featuresAsync.valueOrNull?.donationEnabled ?? true;
          return BPACustomDrawer(
            isLoggedIn: _isLoggedIn,
            userName: userName,
            userEmail: userEmail,
            onSelect: _handleDrawerSelect,
            avatarUrl: avatarUrl,
            donationEnabled: donationEnabled,
          );
        },
      ),

      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),

      floatingActionButton: _selectedIndex == 3
          ? null
          : Semantics(
        label: 'Create new post',
        button: true,
        child: FloatingActionButton(
        onPressed: () async {
          // login না থাকলে post create করার আগে login screen দেখাবেন
          if (!_isLoggedIn) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            );
            await _loadUserData();
            return;
          }

          if (!mounted) return;
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );

          if (created == true && mounted) {
            // ✅ After post create: show "creating" banner and refresh feed
            setState(() {
              _showPostCreatingBanner = true;
              _homeRefreshToken++;
            });

            await Future.delayed(const Duration(seconds: 2));

            if (mounted) {
              setState(() {
                _showPostCreatingBanner = false;
                _homeRefreshToken++;
              });
            }
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 30,
        ),
      ),
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        onFabPressed: () {},
      ),
    ),
    );
  }
}

// ------------------------------------------
// HOME CONTENT ASSEMBLY
// ------------------------------------------
class HomeContentAssembly extends StatelessWidget {
  final String userName;
  final int refreshToken;
  final bool showPostCreatingBanner;

  const HomeContentAssembly({
    super.key,
    required this.userName,
    required this.refreshToken,
    required this.showPostCreatingBanner,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ✅ Scroll behaviour fix:
        // Users reported that the top bar + "My Day/Story" area felt like it was
        // "floating" back into view while scrolling up.
        // - Keep only the AppBar pinned (stable)
        // - Do NOT float/snap back
        // - Story section should scroll naturally
        // ✅ Hide on scroll down, show on scroll up (Search/Profile/Notification bar)
        SliverAppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          pinned: false,
          floating: true,
          snap: true,
          toolbarHeight: 72,
          flexibleSpace: SafeArea(
            bottom: false,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: HomeAppBar(userName: userName),
            ),
          ),
        ),
        const CampaignHomeSliver(),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const StorySection(),
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
        ),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: showPostCreatingBanner
                ? Container(
                    key: const ValueKey('post_banner'),
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6E6E6)),
                    ),
                    child: Row(
                      children: const [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your post is being uploaded...\nIt will appear in the feed once complete ✅',
                            style: TextStyle(height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('post_banner_off')),
          ),
        ),
        FeedList(refreshToken: refreshToken),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}
