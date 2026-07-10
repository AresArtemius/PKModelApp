import 'package:flutter/foundation.dart';

String legalUserAgent() {
  if (kIsWeb) return 'flutter-web';
  return 'flutter-${defaultTargetPlatform.name}';
}
