import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_media_models.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_pet_card.dart';

void main() {
  Widget buildTestCard({
    required AdoptionPetUiModel pet,
    required bool isOwnedByMe,
    required ValueChanged<AdoptionCardMenuAction> onMenuSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            AdoptionPetCard(
              pet: pet,
              isOwnedByMe: isOwnedByMe,
              isFavorited: false,
              onOpenDetails: () {},
              onToggleFavorite: () {},
              onComment: () {},
              onShare: () {},
              onMenuSelected: onMenuSelected,
            ),
          ],
        ),
      ),
    );
  }

  const basePet = AdoptionPetUiModel(
    id: 1,
    name: 'Luna',
    species: 'Cat',
    breed: 'Bengal',
    ageLabel: '3 months',
    gender: 'Female',
    location: 'Dhaka',
    description: 'Playful kitten',
    vaccinated: true,
    dewormed: true,
    neutered: false,
    microchipped: false,
    isShelter: false,
    ownerName: 'Owner',
    ownerRoleLabel: 'Member',
    status: 'Draft',
    galleryLabels: [],
    personalityTags: [],
    compatibilityTags: [],
    serviceAreas: [],
    adopterConditions: [],
    story: 'Story',
    healthNotes: 'Healthy',
    applicationCount: 0,
  );

  testWidgets('AdoptionPetCard owner Draft menu options', (tester) async {
    AdoptionCardMenuAction? selectedAction;

    await tester.pumpWidget(
      buildTestCard(
        pet: basePet.copyWith(status: 'Draft'),
        isOwnedByMe: true,
        onMenuSelected: (action) => selectedAction = action,
      ),
    );

    // Open PopupMenu
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Edit listing'), findsOneWidget);
    expect(find.text('Publish now'), findsOneWidget);
    expect(find.text('Delete draft'), findsOneWidget);
    expect(find.text('Pause listing'), findsNothing);

    await tester.tap(find.text('Publish now'));
    await tester.pumpAndSettle();

    expect(selectedAction, AdoptionCardMenuAction.resumeListing);
  });

  testWidgets('AdoptionPetCard owner Published menu options', (tester) async {
    AdoptionCardMenuAction? selectedAction;

    await tester.pumpWidget(
      buildTestCard(
        pet: basePet.copyWith(status: 'Published'),
        isOwnedByMe: true,
        onMenuSelected: (action) => selectedAction = action,
      ),
    );

    // Open PopupMenu
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Edit listing'), findsOneWidget);
    expect(find.text('View applications'), findsOneWidget);
    expect(find.text('Pause listing'), findsOneWidget);
    expect(find.text('Mark as adopted'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.text('Pause listing'));
    await tester.pumpAndSettle();

    expect(selectedAction, AdoptionCardMenuAction.pauseListing);
  });

  testWidgets('AdoptionPetCard owner Paused menu options', (tester) async {
    await tester.pumpWidget(
      buildTestCard(
        pet: basePet.copyWith(status: 'Paused'),
        isOwnedByMe: true,
        onMenuSelected: (_) {},
      ),
    );

    // Open PopupMenu
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Edit listing'), findsOneWidget);
    expect(find.text('Resume publishing'), findsOneWidget);
    expect(find.text('Mark as adopted'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Publish now'), findsNothing);
  });

  testWidgets(
    'AdoptionPetCard renders the adoption image when cover media exists',
    (tester) async {
      await tester.pumpWidget(
        buildTestCard(
          pet: basePet.copyWith(
            media: [
              const AdoptionMediaUiModel(
                id: 11,
                url: 'http://localhost:7200/media/adoption/luna.jpg',
                thumbnailUrl:
                    'http://localhost:7200/media/adoption/luna-thumb.jpg',
                type: 'IMAGE',
              ),
            ],
          ),
          isOwnedByMe: false,
          onMenuSelected: (_) {},
        ),
      );

      expect(find.byType(FurtailCachedImage), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    },
  );

  testWidgets(
    'AdoptionPetCard falls back to placeholder art when no usable image exists',
    (tester) async {
      await tester.pumpWidget(
        buildTestCard(
          pet: basePet.copyWith(media: const []),
          isOwnedByMe: false,
          onMenuSelected: (_) {},
        ),
      );

      expect(find.byType(FurtailCachedImage), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    },
  );
}
