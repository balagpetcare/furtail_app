import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_typography.dart';

/// Facebook-style root back behavior for [BPAHomeScreen].
///
/// - Closes drawer if open
/// - Switches to home tab when another tab is selected
/// - Double-press within 2s to exit when already on home tab
class HomeBackHandler extends StatefulWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onSelectHomeTab;
  final Widget child;

  const HomeBackHandler({
    super.key,
    required this.selectedTabIndex,
    required this.onSelectHomeTab,
    required this.child,
  });

  @override
  State<HomeBackHandler> createState() => _HomeBackHandlerState();
}

class _HomeBackHandlerState extends State<HomeBackHandler> {
  DateTime? _lastBackPress;

  Future<bool> _handleBack() async {
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState?.isDrawerOpen == true) {
      scaffoldState!.closeDrawer();
      return false;
    }

    if (widget.selectedTabIndex != 0) {
      widget.onSelectHomeTab(0);
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Press back again to exit',
            style: AppTypography.bodyRegular(context).copyWith(
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleBack();
        if (shouldExit && context.mounted) {
          await SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
