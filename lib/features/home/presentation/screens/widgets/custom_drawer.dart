import 'package:flutter/material.dart';

import 'package:furtail_app/core/constants/app_colors.dart';
import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
/// ===========================
/// Furtail Drawer Destination Enum
/// ===========================
enum BPADrawerDestination {
  home,
  petList,
  petRegister,
  services,
  vet,
  vaccinationCampaign,
  grooming,
  training,
  shop,
  adoption,
  donation,
  wallet,
  startFundraising,
  payoutMethods,
  profile,
  community,
  events,
  messages,
  notifications,
  settings,
  help,
  about,
  logout,
}

/// =====================================
/// Premium Furtail Drawer (Glass + Sections)
/// =====================================
class BPACustomDrawer extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final String? avatarUrl; // optional
  final bool isLoggedIn;
  /// Phase 5: Hide Donation/Wallet/Fundraising when policy disables DONATION
  final bool donationEnabled;

  /// Drawer item click handling parent screen এ করবেন
  final void Function(BPADrawerDestination destination) onSelect;

  static const Color _gold = Color(0xFFFFD700);

  const BPACustomDrawer({
    super.key,
    required this.onSelect,
    this.userName,
    this.userEmail,
    this.avatarUrl,
    this.isLoggedIn = false,
    this.donationEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final name = (userName == null || userName!.trim().isEmpty)
        ? (isLoggedIn ? "Furtail Member" : "Guest")
        : userName!.trim();

    final email = (userEmail == null || userEmail!.trim().isEmpty)
        ? (isLoggedIn ? "member@furtail.app" : "Login to unlock features")
        : userEmail!.trim();

    final drawerWidth = MediaQuery.sizeOf(context).width * 0.825;

    return Drawer(
      width: drawerWidth.clamp(280.0, 400.0),
      backgroundColor: context.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(
              name: name,
              email: email,
              avatarUrl: avatarUrl,
              isLoggedIn: isLoggedIn,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                children: [
                  _sectionTitle(context, "MAIN"),
                  _drawerTile(
                    context,
                    icon: Icons.home_rounded,
                    title: "Home",
                    onTap: () => onSelect(BPADrawerDestination.home),
                  ),
                  _drawerTile(
                    context,
                    icon: Icons.notifications_rounded,
                    title: "Notifications",
                    trailing: _badge(context, "3"),
                    onTap: () => onSelect(BPADrawerDestination.notifications),
                  ),

                  const SizedBox(height: 14),
                  _sectionTitle(context, "PETS"),
                  _drawerTile(
                    context,
                    icon: Icons.pets_rounded,
                    title: "My Pets (Pet List)",
                    onTap: () => onSelect(BPADrawerDestination.petList),
                  ),

                  _drawerTile(
                    context,
                    icon: Icons.add_circle_rounded,
                    title: "Register New Pet",
                    subtitle: "Create pet profile + ",
                    onTap: () => onSelect(BPADrawerDestination.petRegister),
                  ),

                  const SizedBox(height: 14),
                  _sectionTitle(context, "SERVICES"),
                  _expansionCard(
                    context,
                    title: "All Services",
                    subtitle: "Vet • Grooming • Training • More",
                    icon: Icons.medical_services_rounded,
                    children: [
                      _drawerTile(
                        context,
                        dense: true,
                        icon: Icons.local_hospital_rounded,
                        title: "Vet Service",
                        onTap: () => onSelect(BPADrawerDestination.vet),
                      ),
                      _drawerTile(
                        context,
                        dense: true,
                        icon: Icons.vaccines_rounded,
                        title: "Vaccination Campaign",
                        onTap: () => onSelect(BPADrawerDestination.vaccinationCampaign),
                      ),
                      _drawerTile(
                        context,
                        dense: true,
                        icon: Icons.cut_rounded,
                        title: "Grooming",
                        onTap: () => onSelect(BPADrawerDestination.grooming),
                      ),
                      _drawerTile(
                        context,
                        dense: true,
                        icon: Icons.school_rounded,
                        title: "Training",
                        onTap: () => onSelect(BPADrawerDestination.training),
                      ),
                      _drawerTile(
                        context,
                        dense: true,
                        icon: Icons.grid_view_rounded,
                        title: "Browse Services",
                        onTap: () => onSelect(BPADrawerDestination.services),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  _sectionTitle(context, "COMMUNITY"),
                  _drawerTile(
                    context,
                    icon: Icons.people_alt_rounded,
                    title: "Community Feed",
                    onTap: () => onSelect(BPADrawerDestination.community),
                  ),
                  _drawerTile(
                    context,
                    icon: Icons.event_rounded,
                    title: "Events",
                    onTap: () => onSelect(BPADrawerDestination.events),
                  ),
                  _drawerTile(
                    context,
                    icon: Icons.chat_bubble_rounded,
                    title: "Messages",
                    onTap: () => onSelect(BPADrawerDestination.messages),
                  ),

                  const SizedBox(height: 14),
                  _sectionTitle(context, "SHOP & CAUSES"),
                  _drawerTile(
                    context,
                    icon: Icons.storefront_rounded,
                    title: "Pet Shop",
                    onTap: () => onSelect(BPADrawerDestination.shop),
                  ),
                  if (donationEnabled) ...[
                    _drawerTile(
                      context,
                      icon: Icons.volunteer_activism_rounded,
                      title: "Donation",
                      subtitle: "Support rescues & shelters",
                      trailing: _pill(context, "New"),
                      onTap: () => onSelect(BPADrawerDestination.donation),
                    ),
                    if (isLoggedIn)
                      _drawerTile(
                        context,
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Wallet",
                        subtitle: "Balance • Activity",
                        onTap: () => onSelect(BPADrawerDestination.wallet),
                      ),
                    _drawerTile(
                      context,
                      icon: Icons.add_rounded,
                      title: "Start Fund Raising",
                      subtitle: "Create a donation request",
                      onTap: () =>
                          onSelect(BPADrawerDestination.startFundraising),
                    ),
                    if (isLoggedIn)
                      _drawerTile(
                        context,
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Payout Methods",
                        subtitle: "Manage bKash • Nagad • Bank",
                        onTap: () =>
                            onSelect(BPADrawerDestination.payoutMethods),
                      ),
                  ],
                  _drawerTile(
                    context,
                    icon: Icons.favorite_rounded,
                    title: "Adoption",
                    subtitle: "Find a new friend",
                    onTap: () => onSelect(BPADrawerDestination.adoption),
                  ),

                  const SizedBox(height: 14),
                  _sectionTitle(context, "APP"),
                  _drawerTile(
                    context,
                    icon: Icons.settings_rounded,
                    title: "Settings",
                    onTap: () => onSelect(BPADrawerDestination.settings),
                  ),
                  _drawerTile(
                    context,
                    icon: Icons.help_rounded,
                    title: "Help & Support",
                    onTap: () => onSelect(BPADrawerDestination.help),
                  ),
                  _drawerTile(
                    context,
                    icon: Icons.info_rounded,
                    title: "About Furtail",
                    onTap: () => onSelect(BPADrawerDestination.about),
                  ),

                  const SizedBox(height: 12),
                  _divider(),

                  // Logout / Login
                  _drawerTile(
                    context,
                    icon: isLoggedIn
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                    title: isLoggedIn ? "Logout" : "Login",
                    titleColor: isLoggedIn ? Colors.redAccent : primary,
                    onTap: () => onSelect(BPADrawerDestination.logout),
                  ),
                ],
              ),
            ),

            // footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.pets, size: 16, color: Colors.black54),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Furtail Super App • Premium Pet Community",
                      style: AppTypography.meta(context).copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // UI helpers
  // =========================

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.drawerSection(context),
      ),
    );
  }

  Widget _divider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 10),
    color: Colors.black12,
  );

  Widget _badge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: context.appText.labelMedium!.copyWith(color: context.colorScheme.onPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _gold.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: context.appText.labelMedium!.copyWith(color: Color(0xFF8A6A00), fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _expansionCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.bpaCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: context.colorScheme.primary),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.drawerMenu(context),
          ),
          subtitle: (subtitle == null)
              ? null
              : Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.drawerSubtitle(context),
                ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    bool dense = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.bpaCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        dense: dense,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.colorScheme.primary),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.drawerMenu(
            context,
            color: titleColor ?? context.colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.drawerSubtitle(context),
              ),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.pop(context); // drawer close
          onTap();
        },
      ),
    );
  }
}

/// Drawer profile header — avatar, identity, membership, action chips.
class _DrawerHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isLoggedIn;

  const _DrawerHeader({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FurtailNetworkAvatar(
                imageUrl: avatarUrl,
                displayName: name,
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
                badge: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: isLoggedIn
                        ? AppColors.accentGold
                        : Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                  child: Icon(
                    isLoggedIn
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_outline_rounded,
                    size: 14,
                    color: isLoggedIn
                        ? const Color(0xFF5B4300)
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.pageTitle(context).copyWith(
                        color: context.bpaCardColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.drawerSubtitle(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BpaMembershipBadge(isMember: isLoggedIn),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              BpaActionChip(
                icon: Icons.pets_rounded,
                label: 'Pet Care',
                onTap: () => Navigator.pop(context),
              ),
              BpaActionChip(
                icon: Icons.favorite_rounded,
                label: 'Community',
                onTap: () => Navigator.pop(context),
              ),
              if (isLoggedIn)
                BpaActionChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Wallet',
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
