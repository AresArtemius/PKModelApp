import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_compat.dart';
import 'supabase_provider.dart';

final mfaRecoveryCodeServiceProvider = Provider<MfaRecoveryCodeService>((ref) {
  return MfaRecoveryCodeService(ref.read(supabaseProvider));
});

final mfaRecoveryCodeStatusProvider =
    FutureProvider.autoDispose<MfaRecoveryCodeStatus?>((ref) {
      return ref.read(mfaRecoveryCodeServiceProvider).loadStatus();
    });

class MfaRecoveryCodeStatus {
  const MfaRecoveryCodeStatus({
    required this.activeCount,
    required this.usedCount,
    required this.lastGeneratedAt,
  });

  factory MfaRecoveryCodeStatus.fromMap(Map<String, dynamic> map) {
    return MfaRecoveryCodeStatus(
      activeCount: _intFrom(map['active_count']),
      usedCount: _intFrom(map['used_count']),
      lastGeneratedAt: DateTime.tryParse(
        (map['last_generated_at'] ?? '').toString(),
      ),
    );
  }

  final int activeCount;
  final int usedCount;
  final DateTime? lastGeneratedAt;

  bool get hasCodes => activeCount > 0;
}

class MfaRecoveryCodeService {
  const MfaRecoveryCodeService(this._sb);

  final SupabaseClient _sb;

  Future<MfaRecoveryCodeStatus?> loadStatus() async {
    if (_sb.auth.currentUser == null) return null;
    try {
      final rows = await _sb.rpc<List<dynamic>>(
        'get_my_mfa_recovery_code_status',
      );
      if (rows.isEmpty) {
        return const MfaRecoveryCodeStatus(
          activeCount: 0,
          usedCount: 0,
          lastGeneratedAt: null,
        );
      }
      return MfaRecoveryCodeStatus.fromMap(
        Map<String, dynamic>.from(rows.first as Map),
      );
    } on PostgrestException catch (e) {
      if (_isMissingRpc(e, 'get_my_mfa_recovery_code_status')) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<String>?> rotateCodes({int count = 10}) async {
    if (_sb.auth.currentUser == null) return null;
    try {
      final rows = await _sb.rpc<List<dynamic>>(
        'rotate_my_mfa_recovery_codes',
        params: {'p_count': count},
      );
      return rows
          .map((row) => (row as Map)['code']?.toString().trim() ?? '')
          .where((code) => code.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (_isMissingRpc(e, 'rotate_my_mfa_recovery_codes')) {
        return null;
      }
      rethrow;
    }
  }

  Future<bool> consumeCode(String code) async {
    if (_sb.auth.currentUser == null) return false;
    final used = await _sb.rpc<bool>(
      'consume_my_mfa_recovery_code',
      params: {'p_code': code},
    );
    return used;
  }
}

int _intFrom(Object? value) {
  if (value is int) return value;
  return int.tryParse((value ?? '').toString()) ?? 0;
}

bool _isMissingRpc(PostgrestException error, String rpcName) {
  final msg = SupabaseCompat.message(error);
  if (error.code == 'PGRST202') return true;
  if (!msg.contains(rpcName.toLowerCase())) return false;
  return msg.contains('schema cache') ||
      msg.contains('function') ||
      msg.contains('not found');
}
