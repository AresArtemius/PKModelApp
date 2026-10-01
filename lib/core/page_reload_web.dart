import 'package:web/web.dart' as web;

/// Reloads the current tab so the browser picks up the freshly deployed
/// bundle (index.html is served with `Cache-Control: no-cache`).
void reloadPage() {
  web.window.location.reload();
}
