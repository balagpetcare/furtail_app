import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/profile/data/safety_service.dart';
import 'package:furtail_app/features/profile/presentation/screens/settings/safety_screen.dart';

class _FakeSafetyService extends SafetyService {
  _FakeSafetyService();

  @override
  Future<List<int>> listBlocked() async => [1, 2];

  @override
  Future<List<int>> listMuted() async => [];

  @override
  Future<List<int>> listRestricted() async => [3];

  @override
  Future<Map<String, String?>?> lookupUser(int userId) async => {
    'displayName': 'User $userId',
    'username': 'user$userId',
  };
}

void main() {
  testWidgets('each tab shows only its own data — Blocked/Muted/Restricted never cross-map', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: SafetyScreen(safetyService: _FakeSafetyService())));
    await tester.pumpAndSettle();

    // Tab 0 (Blocked): 2 blocked users, matching empty text absent.
    expect(find.text('User 1'), findsOneWidget);
    expect(find.text('User 2'), findsOneWidget);
    expect(find.text('No muted users.'), findsNothing);
    expect(find.text('No restricted users.'), findsNothing);

    // Switch to tab 1 (Muted): must show the muted-empty state, never the
    // blocked users or the restricted-empty text.
    await tester.tap(find.text('Muted'));
    await tester.pumpAndSettle();
    expect(find.text('No muted users.'), findsOneWidget);
    expect(find.text('User 1'), findsNothing);
    expect(find.text('No restricted users.'), findsNothing);
    expect(find.text('No blocked users.'), findsNothing);

    // Switch to tab 2 (Restricted): must show only the restricted user.
    await tester.tap(find.text('Restricted'));
    await tester.pumpAndSettle();
    expect(find.text('User 3'), findsOneWidget);
    expect(find.text('No muted users.'), findsNothing);
    expect(find.text('User 1'), findsNothing);
  });

  testWidgets('selected tab uses onPrimary text; TabBar has an explicit indicator color', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: SafetyScreen(safetyService: _FakeSafetyService())));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final context = tester.element(find.byType(TabBar));
    final colors = Theme.of(context).colorScheme;

    expect(tabBar.labelColor, colors.onPrimary);
    expect(tabBar.indicatorColor, colors.onPrimary);
    expect(tabBar.unselectedLabelColor, isNot(equals(Colors.grey)));
  });
}
