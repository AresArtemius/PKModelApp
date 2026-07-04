import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/features/profile/profile_model.dart';

void main() {
  test('profile type parsing supports professional roles', () {
    expect(profileTypeFromString('model'), ProfessionalProfileType.model);
    expect(profileTypeFromString('ACTOR'), ProfessionalProfileType.actor);
    expect(
      profileTypeFromString('photographer'),
      ProfessionalProfileType.photographer,
    );
    expect(
      profileTypeFromString('makeup_artist'),
      ProfessionalProfileType.makeupArtist,
    );
    expect(
      profileTypeFromString('hair_stylist'),
      ProfessionalProfileType.hairStylist,
    );
    expect(profileTypeFromString('unknown'), ProfessionalProfileType.model);
  });

  test('MyProfileState.fromMap parses database values defensively', () {
    final profile = MyProfileState.fromMap({
      'id': 'profile-1',
      'user_id': 'user-1',
      'profile_type': 'makeup_artist',
      'full_name': '  Anna Pro  ',
      'age': '28',
      'height': 172.9,
      'bust': '84',
      'waist': 60.5,
      'hips': '90',
      'shoe_size': '39',
      'min_hourly_rate': '2500',
      'min_daily_fee': 15000.4,
      'eye_color': 'green',
      'hair_color': 'brown',
      'country': 'Russia',
      'resume': 'Resume',
      'experience': '5 years',
      'skills': 'beauty, fashion',
      'services': 'makeup',
      'genres': 'commercial',
      'equipment': 'kit',
      'unavailable_days': ['2026-06-01', '', '2026-06-02'],
      'city': 'Moscow',
      'is_available': 'yes',
      'status': 'approved',
      'moderation_comment': ' ok ',
      'is_verified': '1',
      'verification_status': 'verified',
      'photo_urls': ['a.jpg', '', 'b.jpg'],
      'photo_category_labels': ['Портрет', '', 'Polaroid'],
      'cover_photo_url': 'b.jpg',
      'video_urls': ['v.mp4'],
      'video_preview_urls': ['v.jpg'],
      'video_category_labels': ['Showreel'],
      'showreel_url': 'v.mp4',
      'showreel_preview_url': 'v.jpg',
      'pending_photo_urls': ['pending.jpg'],
      'pending_photo_category_labels': ['Backstage'],
      'pending_cover_photo_url': 'pending.jpg',
      'pending_video_urls': ['pending.mp4'],
      'pending_video_preview_urls': ['pending-video.jpg'],
      'pending_video_category_labels': ['Работы'],
      'pending_showreel_url': 'pending.mp4',
      'pending_showreel_preview_url': 'pending-video.jpg',
      'has_pending_media': 1,
    });

    expect(profile.id, 'profile-1');
    expect(profile.userId, 'user-1');
    expect(profile.profileType, ProfessionalProfileType.makeupArtist);
    expect(profile.fullName, 'Anna Pro');
    expect(profile.age, 28);
    expect(profile.height, 172);
    expect(profile.waist, 60);
    expect(profile.minDailyFee, 15000);
    expect(profile.unavailableDays, ['2026-06-01', '2026-06-02']);
    expect(profile.isAvailable, isTrue);
    expect(profile.status, ProfileStatus.approved);
    expect(profile.moderationComment, 'ok');
    expect(profile.isVerified, isTrue);
    expect(profile.verificationStatus, ProfileVerificationStatus.verified);
    expect(profile.photoUrls, ['a.jpg', 'b.jpg']);
    expect(profile.photoCategoryLabels, ['Портрет', 'Polaroid']);
    expect(profile.coverPhotoUrl, 'b.jpg');
    expect(profile.effectiveCoverPhotoUrl, 'b.jpg');
    expect(profile.videoUrls, ['v.mp4']);
    expect(profile.videoCategoryLabels, ['Showreel']);
    expect(profile.showreelUrl, 'v.mp4');
    expect(profile.showreelPreviewUrl, 'v.jpg');
    expect(profile.pendingPhotoUrls, ['pending.jpg']);
    expect(profile.pendingPhotoCategoryLabels, ['Backstage']);
    expect(profile.pendingCoverPhotoUrl, 'pending.jpg');
    expect(profile.pendingVideoCategoryLabels, ['Работы']);
    expect(profile.pendingShowreelUrl, 'pending.mp4');
    expect(profile.pendingShowreelPreviewUrl, 'pending-video.jpg');
    expect(profile.hasPendingMedia, isTrue);
  });

  test('MyProfileState.copyWith can clear moderation comment', () {
    final base = MyProfileState.blank(
      userId: 'u',
    ).copyWith(moderationComment: 'Needs review');

    expect(base.moderationComment, 'Needs review');
    expect(base.copyWith().moderationComment, 'Needs review');
    expect(base.copyWith(moderationComment: null).moderationComment, isNull);
  });
}
