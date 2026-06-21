import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fundraising_account_setup_screen.dart';
import 'fundraising_create_screen.dart';
import 'fundraising_withdraw_hub_screen.dart';

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

  /// If true, shows Withdraw hub icon.
  final bool showWithdrawHub;

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
    this.showWithdrawHub = false,
    this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
          if (showWithdrawHub)
            IconButton(
              tooltip: 'Withdraw',
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FundraisingWithdrawHubScreen(),
                  ),
                );
              },
            ),
          if (showFilters)
            IconButton(
              tooltip: 'Filters',
              icon: const Icon(Icons.tune_rounded),
              onPressed: onOpenFilters,
            ),

          // ✅ Most important: Verification
          if (showVerification)
            IconButton(
              tooltip: 'Verification',
              icon: const Icon(Icons.verified_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FundraisingAccountSetupScreen(),
                  ),
                );
              },
            ),

          if (showCreate)
            IconButton(
              tooltip: 'Start Fund Raising',
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
        ],
      ),
      body: body,
    );
  }
}
