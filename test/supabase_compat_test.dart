import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/core/supabase_compat.dart';
import 'package:modelapp/features/profile/profile_supabase_schema.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseCompat', () {
    test('detects missing columns from schema cache errors', () {
      const error = PostgrestException(
        message: "Could not find the 'is_verified' column of 'profiles'",
        code: 'PGRST204',
        details: 'Column not found in the schema cache',
      );

      expect(SupabaseCompat.isMissingColumn(error, 'is_verified'), isTrue);
      expect(SupabaseCompat.isMissingColumn(error, 'is_pro'), isFalse);
      expect(ProfileSupabaseSchema.isMissingVerificationColumn(error), isTrue);
    });

    test('detects missing relations and missing RPCs', () {
      const relationError = PostgrestException(
        message: "Could not find the table 'casting_agent_folders'",
        details: 'Not Found',
        hint: 'Check the schema cache',
      );
      const rpcError = PostgrestException(
        message: 'Could not find function catalog_filter_bounds',
        code: 'PGRST202',
      );

      expect(
        SupabaseCompat.isMissingRelation(relationError, const [
          'casting_agent_folders',
        ]),
        isTrue,
      );
      expect(
        SupabaseCompat.isMissingRpc(rpcError, 'catalog_filter_bounds'),
        isTrue,
      );
    });

    test('detects recursive RLS policy errors', () {
      const error = PostgrestException(
        message:
            'infinite recursion detected in policy for relation selections',
        code: '42P17',
      );

      expect(SupabaseCompat.isRlsRecursion(error), isTrue);
    });
  });

  group('ProfileSupabaseSchema', () {
    test('builds profile selects from centralized column sets', () {
      final ownFull = ProfileSupabaseSchema.selectOwn(includeOptional: true);
      final ownBasic = ProfileSupabaseSchema.selectOwn(includeOptional: false);
      final catalog = ProfileSupabaseSchema.selectCatalog(
        includeUnavailableDays: true,
        includePro: true,
        includeVerification: true,
      );

      expect(ownFull, contains('profile_type'));
      expect(ownFull, contains('verification_status'));
      expect(ownBasic, isNot(contains('profile_type')));
      expect(ownBasic, isNot(contains('verification_status')));
      expect(catalog, contains('is_pro'));
      expect(catalog, contains('pro_until'));
      expect(catalog, contains('unavailable_days'));
      expect(catalog, contains('is_verified'));
    });

    test('removes unsupported professional payload fields', () {
      final payload = ProfileSupabaseSchema.withoutProfessionalPayload({
        'user_id': 'u1',
        'profile_type': 'photographer',
        'experience': '5 years',
        'skills': 'fashion',
        'full_name': 'Anna',
      });

      expect(payload, containsPair('user_id', 'u1'));
      expect(payload, containsPair('full_name', 'Anna'));
      expect(payload.containsKey('profile_type'), isFalse);
      expect(payload.containsKey('experience'), isFalse);
      expect(payload.containsKey('skills'), isFalse);
    });
  });
}
