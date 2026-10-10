import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Step 50: product goals for Yandex Metrika. `index.html` defines
/// `window.pkReachGoal(name, params)` which forwards to `ym(id, 'reachGoal')`
/// when the counter is configured; nothing happens otherwise.
void reachGoal(String name, [Map<String, Object?>? params]) {
  try {
    final fn = web.window.getProperty<JSAny?>('pkReachGoal'.toJS);
    if (fn == null || fn.isUndefinedOrNull) return;
    (fn as JSFunction).callAsFunction(null, name.toJS, params?.jsify());
  } catch (_) {
    // Analytics must never break the app.
  }
}
