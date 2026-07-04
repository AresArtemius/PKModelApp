import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/features/catalog/catalog_controller.dart';
import 'package:modelapp/features/catalog/catalog_repository.dart';
import 'package:modelapp/features/catalog/model_data.dart';
import 'package:modelapp/features/profile/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  CatalogController controller() {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );
    return CatalogController(repo: CatalogRepository(client));
  }

  ModelVm model({
    required String id,
    required String fullName,
    int age = 20,
    int height = 175,
    int? shoeSize = 39,
    String city = 'Moscow',
    String country = 'Russia',
    String eyeColor = 'Brown',
    String hairColor = 'Black',
    int? minHourlyRate = 1000,
    int? minDailyFee = 8000,
    List<DateTime> unavailableDays = const [],
  }) {
    return ModelVm(
      id: id,
      profileType: ProfessionalProfileType.model,
      fullName: fullName,
      age: age,
      height: height,
      bust: 85,
      waist: 60,
      hips: 90,
      city: city,
      photoUrls: const [],
      shoeSize: shoeSize,
      minHourlyRate: minHourlyRate,
      minDailyFee: minDailyFee,
      eyeColor: eyeColor,
      hairColor: hairColor,
      country: country,
      unavailableDays: unavailableDays,
    );
  }

  test('CatalogFilterSnapshot normalizes json values and date-only fields', () {
    final snapshot = CatalogFilterSnapshot.fromJson({
      'query': ' anna ',
      'ageFrom': '18',
      'heightTo': 180.9,
      'city': ' Paris ',
      'needDate': '2026-05-27T14:30:00.000Z',
    });

    expect(snapshot.query, ' anna ');
    expect(snapshot.ageFrom, 18);
    expect(snapshot.heightTo, 180);
    expect(snapshot.city, ' Paris ');
    expect(snapshot.needDate, DateTime(2026, 5, 27));
    expect(snapshot.toJson()['needDate'], '2026-05-27');
  });

  test('applyLocalFilters filters by numeric ranges and text fields', () {
    final c = controller();
    c.applyAdvancedFilters(
      reset: false,
      ageFrom: 18,
      ageTo: 25,
      heightFrom: 170,
      heightTo: 180,
      shoeFrom: 38,
      shoeTo: 40,
      city: 'mos',
      country: 'rus',
      eyeColor: 'bro',
      hairColor: 'bla',
      minHourlyRateTo: 1500,
      minDailyFeeTo: 9000,
    );

    final result = c.applyLocalFilters([
      model(id: '1', fullName: 'Anna'),
      model(id: '2', fullName: 'Too young', age: 16),
      model(id: '3', fullName: 'Wrong city', city: 'Paris'),
      model(id: '4', fullName: 'Too expensive', minHourlyRate: 3000),
    ]);

    expect(result.map((m) => m.id), ['1']);
  });

  test('applyLocalFilters excludes unavailable models for requested date', () {
    final c = controller();
    c.applyAdvancedFilters(reset: false, needDate: DateTime(2026, 6, 1));

    final result = c.applyLocalFilters([
      model(
        id: 'busy',
        fullName: 'Busy',
        unavailableDays: [DateTime(2026, 6, 1, 20)],
      ),
      model(id: 'free', fullName: 'Free'),
    ]);

    expect(result.map((m) => m.id), ['free']);
  });

  test('ModelVm.fromMap parses booleans, dates and de-duplicates media', () {
    final vm = ModelVm.fromMap({
      'id': 'p1',
      'profile_type': 'photographer',
      'profile_roles': ['photographer', 'videographer'],
      'full_name': ' Alice ',
      'age': '31',
      'height': 170.8,
      'city': ' Berlin ',
      'photo_urls': ['a.jpg', 'a.jpg', ' ', 'b.jpg'],
      'cover_photo_url': 'b.jpg',
      'unavailable_days': ['2026-06-02T18:00:00Z', 'bad-date', '2026-06-01'],
      'is_pro': 'yes',
      'pro_until': '2026-12-01T00:00:00Z',
      'is_verified': 1,
    });

    expect(vm.profileType, ProfessionalProfileType.photographer);
    expect(vm.effectiveProfileRoles, [
      ProfessionalProfileType.photographer,
      ProfessionalProfileType.videographer,
    ]);
    expect(vm.fullName, 'Alice');
    expect(vm.age, 31);
    expect(vm.height, 170);
    expect(vm.photoUrls, ['a.jpg', 'b.jpg']);
    expect(vm.primaryPhotoUrl, 'b.jpg');
    expect(vm.displayPhotoUrls, ['b.jpg', 'a.jpg']);
    expect(vm.unavailableDays, [DateTime(2026, 6, 1), DateTime(2026, 6, 2)]);
    expect(vm.isPro, isTrue);
    expect(vm.proUntil, DateTime.parse('2026-12-01T00:00:00Z'));
    expect(vm.isVerified, isTrue);
  });
}
