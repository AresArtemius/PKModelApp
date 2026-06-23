import 'package:supabase_flutter/supabase_flutter.dart';

class CastingsRepository {
  CastingsRepository(this._sb);

  final SupabaseClient _sb;
  static const int castingsPageLimit = 80;

  Future<List<Map<String, dynamic>>> fetchCastings() async {
    final res = await _sb
        .from('castings')
        .select('id,title,description,rights,fee,dates,created_at')
        .order('created_at', ascending: false)
        .limit(castingsPageLimit);

    final list = (res as List).cast<dynamic>();
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }
}
