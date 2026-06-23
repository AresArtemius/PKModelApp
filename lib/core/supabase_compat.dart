import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCompat {
  const SupabaseCompat._();

  static String message(PostgrestException error) {
    return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();
  }

  static bool mentionsAny(PostgrestException error, Iterable<String> needles) {
    final msg = message(error);
    return needles.any((needle) => msg.contains(needle.toLowerCase()));
  }

  static bool isMissingColumn(PostgrestException error, String column) {
    final msg = message(error);
    return msg.contains(column.toLowerCase()) &&
        (msg.contains('column') || msg.contains('schema cache'));
  }

  static bool isMissingAnyColumn(
    PostgrestException error,
    Iterable<String> columns,
  ) {
    return columns.any((column) => isMissingColumn(error, column));
  }

  static bool isMissingRelation(
    PostgrestException error,
    Iterable<String> relationNames,
  ) {
    final msg = message(error);
    return relationNames.any((name) => msg.contains(name.toLowerCase())) &&
        (msg.contains('schema cache') ||
            msg.contains('relation') ||
            msg.contains('table') ||
            msg.contains('not found'));
  }

  static bool isMissingRpc(PostgrestException error, String rpcName) {
    final msg = message(error);
    return msg.contains(rpcName.toLowerCase()) ||
        msg.contains('function') ||
        msg.contains('schema cache') ||
        error.code == 'PGRST202';
  }

  static bool isRlsRecursion(PostgrestException error) {
    final msg = message(error);
    return error.code == '42P17' ||
        msg.contains('infinite recursion') ||
        msg.contains('recursion detected');
  }
}
