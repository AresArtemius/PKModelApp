import 'package:web/web.dart' as web;

Future<bool> openExternalUrl(String url) async {
  final clean = url.trim();
  if (clean.isEmpty) return false;
  web.window.open(clean, '_blank');
  return true;
}
