import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

void main() {
  test(
    'FundraisingCampaign parses feed DTO contract with minor-unit strings',
    () {
      final campaign = FundraisingCampaign.fromJson({
        'id': 42,
        'publicId': 'fund_42',
        'slug': 'save-milo',
        'title': 'Save Milo',
        'status': 'ACTIVE',
        'currencyCode': 'BDT',
        'targetAmountMinor': '150000',
        'raisedAmountMinor': '175000',
        'donorsCount': 12,
        'deadline': '2026-08-01T00:00:00.000Z',
        'coverMediaUrl': 'https://cdn.example.com/fundraiser.jpg',
        'creator': {
          'displayName': 'Furtail Rescue',
          'username': 'furtail',
          'avatarUrl': 'https://cdn.example.com/avatar.jpg',
        },
      });

      expect(campaign.id, 42);
      expect(campaign.targetAmount, 150000);
      expect(campaign.stats.raisedAmount, 175000);
      expect(campaign.stats.donorsCount, 12);
      expect(campaign.media.first.url, contains('fundraiser.jpg'));
    },
  );

  test(
    'PostModel preserves canonical fundraiser id for legacy fundraiser refs',
    () {
      final post = PostModel.fromJson({
        'id': 10,
        'type': 'TEXT',
        'category': 'FUNDRAISING',
        'createdAt': '2026-07-25T00:00:00.000Z',
        'author': {
          'id': 7,
          'profile': {'displayName': 'Author'},
        },
        'fundraisingCampaignId': '88',
        'fundraisingEmbed': {
          'campaignId': '88',
          'title': 'Legacy fundraiser',
          'targetAmountMinor': '5000',
          'raisedAmountMinor': '3000',
        },
        '_count': {'likes': 0, 'comments': 0},
      });

      expect(post.fundraisingCampaignId, 88);
      expect(post.fundraisingEmbed?.id, 88);
      expect(post.fundraisingEmbed?.safeTarget, 5000);
    },
  );
}
