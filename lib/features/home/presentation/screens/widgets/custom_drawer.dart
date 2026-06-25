import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

// ================================================================
//  Navigation Destinations
// ================================================================
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
  // v2 — expandable section destinations
  savedItems,
  dashboard,
  helpCenter,
  contactSupport,
  reportProblem,
  safetyGuidelines,
  privacy,
  security,
  notificationSettings,
  language,
  furtailMember,
  petCensus,
  campaigns,
  aboutFurtail,
}

// ================================================================
//  FurtailAppDrawer — Facebook-style social drawer
// ================================================================
class FurtailAppDrawer extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final String? avatarUrl;
  final bool isLoggedIn;
  final bool donationEnabled;
  final int unreadCount;
  final void Function(BPADrawerDestination destination) onSelect;

  const FurtailAppDrawer({
    super.key,
    required this.onSelect,
    this.userName,
    this.userEmail,
    this.avatarUrl,
    this.isLoggedIn = false,
    this.donationEnabled = true,
    this.unreadCount = 0,
  });

  @override
  State<FurtailAppDrawer> createState() => _FurtailAppDrawerState();
}

class _FurtailAppDrawerState extends State<FurtailAppDrawer> {
  bool _helpExpanded = false;
  bool _settingsPrivacyExpanded = false;
  bool _moreExpanded = false;

  String get _name {
    final n = widget.userName?.trim() ?? '';
    if (n.isEmpty) return widget.isLoggedIn ? 'Furtail User' : 'Guest';
    return n;
  }

  String get _email {
    final e = widget.userEmail?.trim() ?? '';
    if (e.isEmpty) return widget.isLoggedIn ? '' : 'Login to unlock features';
    return e;
  }

  void _onTap(BPADrawerDestination dest) {
    Navigator.pop(context);
    widget.onSelect(dest);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth * 0.84).clamp(280.0, 400.0);
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      width: drawerWidth,
      backgroundColor: cs.surface,
      elevation: 2,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile Card ─────────────────────────────────────
            DrawerProfileCard(
              name: _name,
              email: _email,
              avatarUrl: widget.avatarUrl,
              isLoggedIn: widget.isLoggedIn,
              unreadCount: widget.unreadCount,
              onProfileTap: () => _onTap(BPADrawerDestination.profile),
              onNotificationTap: () =>
                  _onTap(BPADrawerDestination.notifications),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),

            // ── Shortcuts ─────────────────────────────────────────
            DrawerShortcutList(onTap: _onTap, isLoggedIn: widget.isLoggedIn),

            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),

            // ── Scrollable Menu ───────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  DrawerMenuItem(
                    icon: Icons.home_rounded,
                    title: 'News Feed',
                    onTap: () => _onTap(BPADrawerDestination.home),
                  ),
                  DrawerMenuItem(
                    icon: Icons.people_alt_rounded,
                    title: 'Friends & Community',
                    onTap: () => _onTap(BPADrawerDestination.community),
                  ),
                  DrawerMenuItem(
                    icon: Icons.pets_rounded,
                    title: 'My Pets',
                    onTap: () => _onTap(BPADrawerDestination.petList),
                  ),
                  DrawerMenuItem(
                    icon: Icons.medical_services_rounded,
                    title: 'Pet Care',
                    onTap: () => _onTap(BPADrawerDestination.services),
                  ),
                  if (widget.isLoggedIn)
                    DrawerMenuItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Wallet',
                      onTap: () => _onTap(BPADrawerDestination.wallet),
                    ),
                  DrawerMenuItem(
                    icon: Icons.favorite_rounded,
                    title: 'Adoption',
                    onTap: () => _onTap(BPADrawerDestination.adoption),
                  ),
                  DrawerMenuItem(
                    icon: Icons.volunteer_activism_rounded,
                    title: 'Fund Raising',
                    onTap: () => _onTap(BPADrawerDestination.startFundraising),
                  ),
                  DrawerMenuItem(
                    icon: Icons.bookmark_rounded,
                    title: 'Saved Items',
                    onTap: () => _onTap(BPADrawerDestination.savedItems),
                  ),
                  DrawerMenuItem(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    badge: widget.unreadCount > 0
                        ? (widget.unreadCount > 99
                              ? '99+'
                              : '${widget.unreadCount}')
                        : null,
                    onTap: () => _onTap(BPADrawerDestination.notifications),
                  ),

                  // Settings removed from main list — it lives under Settings & Privacy below.
                  const _DrawerDivider(),

                  // ── Help & Support ────────────────────────────
                  DrawerExpandableSection(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    isExpanded: _helpExpanded,
                    onToggle: () =>
                        setState(() => _helpExpanded = !_helpExpanded),
                    children: [
                      DrawerMenuItem(
                        icon: Icons.menu_book_rounded,
                        title: 'Help Center',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.helpCenter),
                      ),
                      DrawerMenuItem(
                        icon: Icons.support_agent_rounded,
                        title: 'Contact Support',
                        dense: true,
                        onTap: () =>
                            _onTap(BPADrawerDestination.contactSupport),
                      ),
                      DrawerMenuItem(
                        icon: Icons.flag_rounded,
                        title: 'Report a Problem',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.reportProblem),
                      ),
                      DrawerMenuItem(
                        icon: Icons.shield_rounded,
                        title: 'Safety & Guidelines',
                        dense: true,
                        onTap: () =>
                            _onTap(BPADrawerDestination.safetyGuidelines),
                      ),
                    ],
                  ),

                  // ── Settings & Privacy ────────────────────────
                  DrawerExpandableSection(
                    icon: Icons.lock_outline_rounded,
                    title: 'Settings & Privacy',
                    isExpanded: _settingsPrivacyExpanded,
                    onToggle: () => setState(
                      () =>
                          _settingsPrivacyExpanded = !_settingsPrivacyExpanded,
                    ),
                    children: [
                      DrawerMenuItem(
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.settings),
                      ),
                      DrawerMenuItem(
                        icon: Icons.privacy_tip_rounded,
                        title: 'Privacy',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.privacy),
                      ),
                      DrawerMenuItem(
                        icon: Icons.security_rounded,
                        title: 'Security',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.security),
                      ),
                      DrawerMenuItem(
                        icon: Icons.notifications_active_rounded,
                        title: 'Notification Settings',
                        dense: true,
                        onTap: () =>
                            _onTap(BPADrawerDestination.notificationSettings),
                      ),
                      DrawerMenuItem(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.language),
                      ),
                    ],
                  ),

                  // ── More from Furtail ─────────────────────────
                  DrawerExpandableSection(
                    icon: Icons.apps_rounded,
                    title: 'More from Furtail',
                    isExpanded: _moreExpanded,
                    onToggle: () =>
                        setState(() => _moreExpanded = !_moreExpanded),
                    children: [
                      DrawerMenuItem(
                        icon: Icons.workspace_premium_rounded,
                        title: 'Furtail Member',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.furtailMember),
                      ),
                      DrawerMenuItem(
                        icon: Icons.format_list_numbered_rounded,
                        title: 'Pet Census',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.petCensus),
                      ),
                      DrawerMenuItem(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'Donation',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.donation),
                      ),
                      DrawerMenuItem(
                        icon: Icons.campaign_rounded,
                        title: 'Campaigns',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.campaigns),
                      ),
                      DrawerMenuItem(
                        icon: Icons.dashboard_rounded,
                        title: 'Dashboard',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.dashboard),
                      ),
                      DrawerMenuItem(
                        icon: Icons.info_rounded,
                        title: 'About Furtail',
                        dense: true,
                        onTap: () => _onTap(BPADrawerDestination.aboutFurtail),
                      ),
                    ],
                  ),

                  const _DrawerDivider(),

                  // ── Logout / Login ────────────────────────────
                  DrawerMenuItem(
                    icon: widget.isLoggedIn
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                    title: widget.isLoggedIn ? 'Logout' : 'Login',
                    titleColor: widget.isLoggedIn ? cs.error : null,
                    iconColor: widget.isLoggedIn ? cs.error : null,
                    onTap: () => _onTap(BPADrawerDestination.logout),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────────────
            const DrawerFooter(),
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  DrawerProfileCard
// ================================================================
class DrawerProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isLoggedIn;
  final int unreadCount;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationTap;

  const DrawerProfileCard({
    super.key,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isLoggedIn,
    required this.unreadCount,
    required this.onProfileTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: onProfileTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              FurtailNetworkAvatar(
                imageUrl: avatarUrl,
                displayName: name,
                radius: 28,
              ),
              const SizedBox(width: 12),

              // Identity column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (isLoggedIn) ...[
                      const SizedBox(height: 6),
                      _MemberBadge(themeCs: cs),
                    ],
                  ],
                ),
              ),

              // Notification bell
              Semantics(
                label: 'Open notifications',
                button: true,
                child: InkWell(
                  onTap: onNotificationTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 26,
                          color: cs.onSurfaceVariant,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
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
                                unreadCount > 99 ? '99+' : '$unreadCount',
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberBadge extends StatelessWidget {
  final ColorScheme themeCs;
  const _MemberBadge({required this.themeCs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: themeCs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: themeCs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 12,
            color: themeCs.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Furtail Member',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: themeCs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
//  DrawerShortcutList
// ================================================================
class _ShortcutItemData {
  final IconData icon;
  final String label;
  final BPADrawerDestination destination;
  final Color color;

  const _ShortcutItemData({
    required this.icon,
    required this.label,
    required this.destination,
    required this.color,
  });
}

class DrawerShortcutList extends StatelessWidget {
  final void Function(BPADrawerDestination) onTap;
  final bool isLoggedIn;

  const DrawerShortcutList({
    super.key,
    required this.onTap,
    required this.isLoggedIn,
  });

  static const _shortcuts = <_ShortcutItemData>[
    _ShortcutItemData(
      icon: Icons.pets_rounded,
      label: 'My Pets',
      destination: BPADrawerDestination.petList,
      color: Color(0xFF4CAF50),
    ),
    _ShortcutItemData(
      icon: Icons.person_rounded,
      label: 'Profile',
      destination: BPADrawerDestination.profile,
      color: Color(0xFF1565C0),
    ),
    _ShortcutItemData(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Wallet',
      destination: BPADrawerDestination.wallet,
      color: Color(0xFF7B1FA2),
    ),
    _ShortcutItemData(
      icon: Icons.medical_services_rounded,
      label: 'Pet Care',
      destination: BPADrawerDestination.services,
      color: Color(0xFFE64A19),
    ),
    _ShortcutItemData(
      icon: Icons.favorite_rounded,
      label: 'Adoption',
      destination: BPADrawerDestination.adoption,
      color: Color(0xFFC2185B),
    ),
    _ShortcutItemData(
      icon: Icons.volunteer_activism_rounded,
      label: 'Fund Raising',
      destination: BPADrawerDestination.startFundraising,
      color: Color(0xFFE65100),
    ),
    _ShortcutItemData(
      icon: Icons.bookmark_rounded,
      label: 'Saved',
      destination: BPADrawerDestination.savedItems,
      color: Color(0xFF37474F),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: _shortcuts.length,
        itemBuilder: (context, i) {
          final item = _shortcuts[i];
          return _ShortcutTile(
            item: item,
            onTap: () => onTap(item.destination),
          );
        },
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final _ShortcutItemData item;
  final VoidCallback onTap;

  const _ShortcutTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
//  DrawerMenuItem
// ================================================================
class DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final Color? titleColor;
  final Color? iconColor;
  final bool dense;
  final VoidCallback onTap;

  const DrawerMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.badge,
    this.titleColor,
    this.iconColor,
    this.dense = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final onSurface = context.colorScheme.onSurface;
    final effectiveIconColor = iconColor ?? primary;
    final leftPad = dense ? 32.0 : 16.0;
    final verticalPad = dense ? 9.0 : 11.0;
    final iconBox = dense ? 34.0 : 40.0;
    final iconInner = dense ? 18.0 : 22.0;
    final titleSize = dense ? 13.5 : 15.0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(leftPad, verticalPad, 16, verticalPad),
        child: Row(
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(dense ? 10 : 12),
              ),
              child: Icon(icon, color: effectiveIconColor, size: iconInner),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? onSurface,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colorScheme.error,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  DrawerExpandableSection
// ================================================================
class DrawerExpandableSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const DrawerExpandableSection({
    super.key,
    required this.icon,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final onSurface = context.colorScheme.onSurface;
    final onSurfaceVariant = context.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0.25 : 0,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded children
        if (isExpanded)
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
      ],
    );
  }
}

// ================================================================
//  DrawerFooter
// ================================================================
class DrawerFooter extends StatelessWidget {
  const DrawerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.pets, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Furtail Super App • Premium Pet Community',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
//  Internal helpers
// ================================================================
class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 20,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

// ================================================================
//  Back-compat alias — home screen still references BPACustomDrawer
// ================================================================
class BPACustomDrawer extends FurtailAppDrawer {
  const BPACustomDrawer({
    super.key,
    required super.onSelect,
    super.userName,
    super.userEmail,
    super.avatarUrl,
    super.isLoggedIn,
    super.donationEnabled,
    super.unreadCount,
  });
}
