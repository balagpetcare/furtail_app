import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';

void main() {
  test(
    'MediaUrl.normalize preserves absolute URLs and resolves relative paths',
    () {
      expect(
        MediaUrl.normalize('https://cdn.example.test/pets/luna.jpg'),
        'https://cdn.example.test/pets/luna.jpg',
      );
      expect(
        MediaUrl.normalize('/media/adoption/luna.jpg'),
        'http://localhost:7200/media/adoption/luna.jpg',
      );
      expect(
        MediaUrl.normalize('memory://media/8/5/scaled_1000547672.jpg'),
        'http://localhost:7200/api/v1/media/legacy/memory%3A%2F%2Fmedia%2F8%2F5%2Fscaled_1000547672.jpg',
      );
    },
  );

  test(
    'AdoptionPetUiModel.fromApiJson picks the first usable image for the public card',
    () {
      final pet = AdoptionPetUiModel.fromApiJson({
        'id': 42,
        'name': 'Luna',
        'species': 'DOG',
        'breed': 'Mixed',
        'status': 'PUBLISHED',
        'country': {'name': 'Bangladesh'},
        'owner': {
          'id': 7,
          'profile': {
            'displayName': 'Owner Seven',
            'username': 'ownerseven',
            'avatarMedia': null,
          },
        },
        'shelterProfile': {},
        'criteria': {},
        '_count': {'favorites': 0, 'comments': 0, 'applications': 0},
        'media': [
          {
            'id': 11,
            'media': {
              'id': 11,
              'url': '/media/adoption/luna-primary.jpg',
              'thumbnailUrl': '/media/adoption/luna-thumb.jpg',
              'type': 'IMAGE',
              'mimeType': 'image/jpeg',
            },
          },
          {
            'id': 12,
            'media': {
              'id': 12,
              'url': '/media/adoption/luna-second.jpg',
              'type': 'IMAGE',
              'mimeType': 'image/jpeg',
            },
          },
        ],
        'galleryImageUrls': ['/media/adoption/luna-gallery.jpg'],
      });

      expect(pet.coverMedia, isNotNull);
      expect(
        pet.coverMedia!.displayUrl,
        'http://localhost:7200/media/adoption/luna-primary.jpg',
      );
      expect(
        pet.galleryImageUrls,
        contains('http://localhost:7200/media/adoption/luna-gallery.jpg'),
      );
      expect(pet.media, hasLength(2));
    },
  );
}
