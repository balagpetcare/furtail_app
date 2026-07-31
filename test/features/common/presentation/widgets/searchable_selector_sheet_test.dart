import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/common/presentation/widgets/searchable_selector_sheet.dart';

void main() {
  Widget host(VoidCallback onOpen) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              ElevatedButton(onPressed: onOpen, child: const Text('open')),
        ),
      ),
    );
  }

  testWidgets('shows a loading state while fetching', (tester) async {
    final completer = Completer<List<SelectorItem<int>>>();
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    unawaited(
      showSearchableSelectorSheet<int>(
        context: ctx,
        title: 'Species',
        load: () => completer.future,
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('shows an empty state when no items match', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    unawaited(
      showSearchableSelectorSheet<int>(
        context: ctx,
        title: 'Species',
        emptyMessage: 'No species available.',
        load: () async => const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No species available.'), findsOneWidget);
  });

  testWidgets(
    'shows an error state with a retry action, and retry re-fetches',
    (tester) async {
      late BuildContext ctx;
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      unawaited(
        showSearchableSelectorSheet<int>(
          context: ctx,
          title: 'Species',
          load: () async {
            attempts++;
            if (attempts == 1) throw Exception('network down');
            return const [SelectorItem(value: 1, label: 'Dog')];
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Dog'), findsOneWidget);
    },
  );

  testWidgets(
    'supports search filtering by label and alias, case-insensitively',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      unawaited(
        showSearchableSelectorSheet<int>(
          context: ctx,
          title: 'Breed',
          load: () async => const [
            SelectorItem(
              value: 1,
              label: 'German Shepherd',
              searchTerms: ['GSD', 'Alsatian'],
            ),
            SelectorItem(value: 2, label: 'Labrador', searchTerms: ['Lab']),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('German Shepherd'), findsOneWidget);
      expect(find.text('Labrador'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'gsd');
      await tester.pumpAndSettle();
      expect(find.text('German Shepherd'), findsOneWidget);
      expect(find.text('Labrador'), findsNothing);
    },
  );

  testWidgets('indicates the currently-selected item with a check mark', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    unawaited(
      showSearchableSelectorSheet<int>(
        context: ctx,
        title: 'Breed',
        selectedValue: 2,
        load: () async => const [
          SelectorItem(value: 1, label: 'German Shepherd'),
          SelectorItem(value: 2, label: 'Labrador'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('returns the picked value when a row is tapped', (tester) async {
    late BuildContext ctx;
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showSearchableSelectorSheet<int>(
      context: ctx,
      title: 'Breed',
      load: () async => const [SelectorItem(value: 42, label: 'Labrador')],
    ).then((value) => picked = value);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labrador'));
    await tester.pumpAndSettle();
    expect(picked, 42);
  });

  testWidgets('renders long names without overflow errors', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    unawaited(
      showSearchableSelectorSheet<int>(
        context: ctx,
        title: 'Breed',
        load: () async => const [
          SelectorItem(
            value: 1,
            label:
                'A Very Long Breed Name That Could Overflow A Narrow Screen Without Wrapping Or Ellipsis Handling',
            subtitle:
                'একটি অনেক লম্বা প্রজাতির নাম যা স্ক্রিনে ওভারফ্লো করতে পারে',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet never covers the full screen height', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    unawaited(
      showSearchableSelectorSheet<int>(
        context: ctx,
        title: 'Breed',
        load: () async =>
            List.generate(50, (i) => SelectorItem(value: i, label: 'Item $i')),
      ),
    );
    await tester.pumpAndSettle();

    final sheetFinder = find.byType(DraggableScrollableSheet);
    expect(sheetFinder, findsOneWidget);
    final sheetSize = tester.getSize(sheetFinder);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(sheetSize.height, lessThan(screenHeight));
  });

  testWidgets(
    'search field and options carry semantic labels for screen readers',
    (tester) async {
      final handle = tester.ensureSemantics();
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      unawaited(
        showSearchableSelectorSheet<int>(
          context: ctx,
          title: 'Species',
          searchHint: 'Search species',
          load: () async => const [SelectorItem(value: 1, label: 'Dog')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Search species'), findsWidgets);
      expect(find.bySemanticsLabel('Dog'), findsWidgets);
      handle.dispose();
    },
  );
}
