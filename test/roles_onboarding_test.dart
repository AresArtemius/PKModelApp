import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/core/onboarding_provider.dart';
import 'package:modelapp/core/roles_provider.dart';

void main() {
  group('roles', () {
    test('parses known account roles and falls back to user', () {
      expect(accountRoleFromStorage('admin'), AccountRole.admin);
      expect(
        accountRoleFromStorage(' CASTING_AGENT '),
        AccountRole.castingAgent,
      );
      expect(
        accountRoleFromStorage('director_producer'),
        AccountRole.castingAgent,
      );
      expect(accountRoleFromStorage('brand_client'), AccountRole.castingAgent);
      expect(accountRoleFromStorage('moderator'), AccountRole.admin);
      expect(accountRoleFromStorage('support'), AccountRole.admin);
      expect(accountRoleFromStorage('model'), AccountRole.user);
      expect(accountRoleFromStorage(null), AccountRole.user);
    });

    test('only admins and casting agents can create selections', () {
      expect(accountRoleCanCreateSelections(AccountRole.admin), isTrue);
      expect(accountRoleCanCreateSelections(AccountRole.castingAgent), isTrue);
      expect(accountRoleCanCreateSelections(AccountRole.user), isFalse);
    });
  });

  group('registration account types', () {
    test('keeps public storage values and permission roles stable', () {
      expect(RegistrationAccountType.user.storageValue, 'user');
      expect(RegistrationAccountType.user.role, AccountRole.user);
      expect(
        RegistrationAccountType.castingDirector.storageValue,
        'casting_director',
      );
      expect(
        RegistrationAccountType.castingDirector.role,
        AccountRole.castingAgent,
      );
      expect(
        RegistrationAccountType.directorProducer.storageValue,
        'director_producer',
      );
      expect(RegistrationAccountType.brandClient.storageValue, 'brand_client');
      expect(
        RegistrationAccountType.productionAgency.storageValue,
        'production_agency',
      );
      expect(RegistrationAccountType.photoVideo.storageValue, 'photo_video');
      expect(RegistrationAccountType.scoutBooker.storageValue, 'scout_booker');
    });
  });

  group('onboarding account types', () {
    test('keeps storage values stable for all supported roles', () {
      expect(OnboardingAccountType.model.storageValue, 'model');
      expect(OnboardingAccountType.actor.storageValue, 'actor');
      expect(OnboardingAccountType.castingAgent.storageValue, 'casting_agent');
      expect(OnboardingAccountType.brand.storageValue, 'brand');
      expect(OnboardingAccountType.photographer.storageValue, 'photographer');
      expect(OnboardingAccountType.videographer.storageValue, 'videographer');
      expect(OnboardingAccountType.stylist.storageValue, 'stylist');
      expect(OnboardingAccountType.makeupArtist.storageValue, 'makeup_artist');
      expect(OnboardingAccountType.hairStylist.storageValue, 'hair_stylist');
      expect(OnboardingAccountType.agency.storageValue, 'agency');
    });
  });
}
