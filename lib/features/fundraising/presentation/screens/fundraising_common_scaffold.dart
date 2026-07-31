import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fundraising_account_setup_screen.dart';
import 'fundraising_create_screen.dart';
import 'fundraising_my_donations_screen.dart';

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

  /// Called when Filters pressed
  final VoidCallback? onOpenFilters;

  const FundraisingCommonScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = true,
    this.showFilters = false,
    this.showVerification = true,
    this.showCreate = false,
    this.showDonationHistory = false,
    this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        actionsPadding: const EdgeInsets.only(right: 8),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title, maxLines: 1, overflow: TextOverflow.visible),
        ),
        leading: showBack
            ? IconButton(
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
        actions: [
          if (showFilters)
            IconButton(
              tooltip: 'Filters',
              icon: const Icon(Icons.tune_rounded),
              onPressed: onOpenFilters,
            ),

          if (showCreate)
            IconButton(
              tooltip: 'Create fundraiser',
              icon: const Icon(Icons.add_rounded),
              onPressed: () async {
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
          if (showDonationHistory || showVerification)
            PopupMenuButton<int>(
              tooltip: 'More',
              onSelected: (value) {
                switch (value) {
                  case 1:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FundraisingMyDonationsScreen(),
                      ),
                    );
                    break;
                  case 2:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FundraisingAccountSetupScreen(),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<int>>[
                if (showDonationHistory)
                  const PopupMenuItem<int>(
                    value: 1,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.receipt_long_outlined),
                      title: Text('My donations'),
                    ),
                  ),
                if (showVerification)
                  const PopupMenuItem<int>(
                    value: 2,
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
