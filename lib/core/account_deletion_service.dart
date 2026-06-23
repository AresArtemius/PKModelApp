import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'supabase_provider.dart';
import 'supabase_compat.dart';

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(ref.read(supabaseProvider));
});

class AccountDeletionService {
  const AccountDeletionService(this._sb);

  final SupabaseClient _sb;

  Future<void> deleteMyAccount() async {
    try {
      await _sb.rpc('delete_my_account');
    } on PostgrestException catch (e, stack) {
      AppLogger.error(
        'Account deletion RPC failed',
        error: e,
        stackTrace: stack,
      );
      if (SupabaseCompat.isMissingRpc(e, 'delete_my_account')) {
        throw const AccountDeletionSetupRequiredException();
      }
      throw AccountDeletionFailedException(e.message);
    }
  }
}

class AccountDeletionSetupRequiredException implements Exception {
  const AccountDeletionSetupRequiredException();
}

class AccountDeletionFailedException implements Exception {
  const AccountDeletionFailedException(this.message);

  final String message;
}
