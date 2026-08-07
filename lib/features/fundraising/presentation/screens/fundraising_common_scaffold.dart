import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fundraising_account_setup_screen.dart';
import 'fundraising_create_screen.dart';
import 'fundraising_my_donations_screen.dart';

AppBar buildFundraisingAppBar({
  required BuildContext context,
  required String title,
  bool showBack = true,
  List<Widget>? actions,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final titleStyle = theme.textTheme.titleLarge?.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.w800,
  );
  return AppBar(
    backgroundColor: scheme.primary,
    foregroundColor: Colors.white,
    surfaceTintColor: scheme.primary,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: titleStyle,
    titleSpacing: 8,
    actionsPadding: const EdgeInsets.only(right: 8),
    title: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(title, maxLines: 1, overflow: TextOverflow.visible),
    ),
    leading: showBack
        ? IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
          )
        : null,
    actions: actions,
  );
}

class FundraisingCommonScaffold extends ConsumerWidget {
  final String title;
  final Widget body;

  /// If true, shows back button like your Feed screen.
  final bool showBack;

  /// If true, shows Filters icon (for feed).
  final bool showFilters;

  /// If true, shows Verify icon (important).
  final bool showVerification;

  /// If true, shows + create icon (feed).
  final bool showCreate;

  /// If true, shows donation history icon.
  final bool showDonationHistory;
  final bool showMyFundraisers;

  /// Called when Filters pressed
  final VoidCallback? onOpenFilters;
  final VoidCallback? onOpenCreate;
  final VoidCallback? onOpenMyFundraisers;
  final VoidCallback? onOpenDonationHistory;
  final VoidCallback? onOpenVerification;

  const FundraisingCommonScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = true,
    this.showFilters = false,
    this.showVerification = true,
    this.showCreate = false,
    this.showDonationHistory = false,
    this.showMyFundraisers = false,
    this.onOpenFilters,
    this.onOpenCreate,
    this.onOpenMyFundraisers,
    this.onOpenDonationHistory,
    this.onOpenVerification,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: buildFundraisingAppBar(
        context: context,
        title: title,
        showBack: showBack,
        actions: [
          if (showFilters)
            IconButton(
              tooltip: 'Filters',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.tune_rounded),
              onPressed: onOpenFilters,
            ),

          if (showCreate)
            IconButton(
              tooltip: 'Create fundraiser',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.add_rounded),
              onPressed: () async {
                if (onOpenCreate != null) {
                  onOpenCreate!();
                  return;
                }
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const FundraisingCreateScreen(),
                  ),
                );
                if (created == true) {
                  // create screen will invalidate providers
                }
              },
            ),
          if (showDonationHistory || showVerification || showMyFundraisers)
            PopupMenuButton<int>(
              tooltip: 'More',
              onSelected: (value) {
                switch (value) {
                  case 1:
                    onOpenMyFundraisers?.call();
                    break;
                  case 2:
                    if (onOpenDonationHistory != null) {
                      onOpenDonationHistory!();
                      break;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FundraisingMyDonationsScreen(),
                      ),
                    );
                    break;
                  case 3:
                    if (onOpenVerification != null) {
                      onOpenVerification!();
                      break;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FundraisingAccountSetupScreen(),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<int>>[
                if (showMyFundraisers)
                  PopupMenuItem<int>(
                    value: 1,
                    child: Semantics(
                      label: 'My fundraisers',
                      button: true,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.campaign_outlined),
                        title: Text('My fundraisers'),
                      ),
                    ),
                  ),
                if (showDonationHistory)
                  const PopupMenuItem<int>(
                    value: 2,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.receipt_long_outlined),
                      title: Text('My donations'),
                    ),
                  ),
                if (showVerification)
                  const PopupMenuItem<int>(
                    value: 3,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.verified_user_outlined),
                      title: Text('Fundraising verification'),
                    ),
                  ),
              ],
            ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: body,
    );
  }
}
