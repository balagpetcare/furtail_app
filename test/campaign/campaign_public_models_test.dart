import 'package:furtail_app/features/campaign/data/models/campaign_public_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublicCampaign', () {
    test('fromJson parses pricing and mobile banner from metadata', () {
      final c = PublicCampaign.fromJson({
        'id': 1,
        'name': 'Cat Flu 2026',
        'slug': 'cat-flu-2026',
        'description': 'Protect your cat',
        'startDate': '2026-06-01T00:00:00.000Z',
        'endDate': '2026-12-31T00:00:00.000Z',
        'pricingType': 'PAID',
        'priceAmount': 500,
        'metadataJson': {
          'mobile': {'bannerImageUrl': 'https://cdn.example/banner.jpg'},
        },
        'locations': [
          {'id': 10, 'name': 'Dhaka Center', 'address': 'Mirpur'},
        ],
        'config': {
          'bookingEnabled': true,
          'showRemainingSlots': true,
          'slotRequired': true,
          'maxCatsPerBooking': 3,
        },
        'pricing': {
          'totalPrice': 500,
          'vaccineCost': 400,
          'serviceCharge': 100,
          'currency': 'BDT',
          'isFree': false,
        },
      });

      expect(c.slug, 'cat-flu-2026');
      expect(c.imageUrl, 'https://cdn.example/banner.jpg');
      expect(c.displayPrice, '৳500');
      expect(c.locations.single.name, 'Dhaka Center');
      expect(c.config?.maxCatsPerBooking, 3);
    });

    test('isFree when pricingType FREE', () {
      final c = PublicCampaign.fromJson({
        'id': 2,
        'name': 'Free drive',
        'slug': 'free',
        'startDate': '2026-06-01',
        'endDate': '2026-12-31',
        'pricingType': 'FREE',
      });
      expect(c.isFree, isTrue);
      expect(c.displayPrice, 'Free');
    });

    test('toCacheJson round-trip', () {
      final original = PublicCampaign.fromJson({
        'id': 3,
        'name': 'Round trip',
        'slug': 'rt',
        'startDate': '2026-06-01',
        'endDate': '2026-06-30',
        'pricingType': 'PAID',
        'priceAmount': 300,
      });
      final restored = PublicCampaign.fromCacheJson(original.toCacheJson());
      expect(restored.slug, original.slug);
      expect(restored.name, original.name);
    });
  });

  group('PublicCampaignSlot', () {
    test('displayTime uses labels when present', () {
      const slot = PublicCampaignSlot(
        slotId: 1,
        date: '2026-06-10',
        startTime: '09:00',
        endTime: '10:00',
        startTimeLabel: '9 AM',
        endTimeLabel: '10 AM',
        capacity: 20,
        bookedCount: 5,
        availableCount: 15,
        status: 'OPEN',
      );
      expect(slot.displayTime, '9 AM – 10 AM');
    });
  });

  group('CheckoutInitResult', () {
    test('fromJson', () {
      final r = CheckoutInitResult.fromJson({
        'checkoutId': 'chk_1',
        'amount': 500,
        'currency': 'BDT',
        'requiresPayment': false,
        'expiresAt': '2026-06-10T12:00:00.000Z',
        'bookingRef': 'VC-ABC',
      });
      expect(r.checkoutId, 'chk_1');
      expect(r.requiresPayment, isFalse);
      expect(r.bookingRef, 'VC-ABC');
    });
  });

  group('PublicCampaignNotification', () {
    test('fromFcm maps campaign slug action', () {
      final n = PublicCampaignNotification.fromFcm({
        'type': 'campaign_new',
        'title': 'New campaign',
        'body': 'Book now',
        'campaignSlug': 'cat-flu-2026',
      });
      expect(n.type, 'campaign_new');
      expect(n.campaignSlug, 'cat-flu-2026');
    });
  });
}
