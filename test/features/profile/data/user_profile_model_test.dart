import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/profile/data/models/user_profile_model.dart';

void main() {
  test('parses shared-profile fields from canonical payload', () {
    final model = UserProfileModel.fromApi({
      'data': {
        'id': 42,
        'auth': {'email': 'owner@example.com', 'phone': '+8801000000000'},
        'profile': {
          'displayName': 'Puti Parent',
          'username': 'puti_parent',
          'bio': 'Loves pets.',
          'visibility': 'FOLLOWERS_ONLY',
          'showEmail': true,
          'showPhone': false,
          'education': 'Dhaka University',
          'placeLive': 'Dhaka',
          'from': 'Sylhet',
          'workStatus': 'Creator',
          'religiousStatus': 'Islam',
          'gender': 'FEMALE',
          'birthdate': '1992-01-20T00:00:00.000Z',
          'maritalStatus': 'Single',
          'avatarMedia': {'url': '/media/avatar.jpg'},
          'coverMedia': {'url': '/media/cover.jpg'},
        },
      },
    });

    expect(model.name, 'Puti Parent');
    expect(model.username, 'puti_parent');
    expect(model.visibility, 'FOLLOWERS_ONLY');
    expect(model.showEmail, isTrue);
    expect(model.showPhone, isFalse);
    expect(model.education, 'Dhaka University');
    expect(model.placeLive, 'Dhaka');
    expect(model.from, 'Sylhet');
    expect(model.workStatus, 'Creator');
    expect(model.religiousStatus, 'Islam');
    expect(model.gender, 'FEMALE');
    expect(model.birthdate, DateTime.parse('1992-01-20T00:00:00.000Z'));
    expect(model.maritalStatus, 'Single');
    expect(model.photoUrl, isNotEmpty);
    expect(model.coverUrl, isNotEmpty);
  });
}
