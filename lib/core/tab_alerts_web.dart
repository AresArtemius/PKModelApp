import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Browser-tab alerts for the web build: an unread badge in the tab title
/// («(3) PK Management»), a short sound and a system notification through
/// the Notification API while the tab is open — no push / FCM involved.
class TabAlerts {
  TabAlerts() {
    _watchTitle();
  }

  int _badge = 0;
  web.MutationObserver? _observer;
  bool _applying = false;

  bool get supported => true;

  bool get hidden => web.document.hidden;

  // ---------------------------------------------------------------- badge

  void setBadge(int count) {
    if (count == _badge) return;
    _badge = count < 0 ? 0 : count;
    _applyBadge();
  }

  static final _badgePrefix = RegExp(r'^\(\d+\+?\)\s+');

  void _applyBadge() {
    final current = web.document.title;
    final bare = current.replaceFirst(_badgePrefix, '');
    final label = _badge > 99 ? '99+' : '$_badge';
    final next = _badge == 0 ? bare : '($label) $bare';
    if (next == current) return;
    _applying = true;
    web.document.title = next;
    _applying = false;
  }

  /// Flutter rewrites `<title>` on every route change; re-apply the badge
  /// whenever that happens.
  void _watchTitle() {
    final head = web.document.head;
    if (head == null) return;
    final observer = web.MutationObserver(
      ((JSArray<web.MutationRecord> records, web.MutationObserver observer) {
        if (_applying || _badge == 0) return;
        _applyBadge();
      }).toJS,
    );
    observer.observe(
      head,
      web.MutationObserverInit(subtree: true, childList: true, characterData: true),
    );
    _observer = observer;
  }

  void dispose() {
    _observer?.disconnect();
    _observer = null;
  }

  // ---------------------------------------------------------------- sound

  web.AudioContext? _audio;

  void playSound() {
    try {
      final ctx = _audio ??= web.AudioContext();
      if (ctx.state == 'suspended') {
        // Needs a user gesture first; resume for the next time.
        unawaited(ctx.resume().toDart);
        return;
      }
      final now = ctx.currentTime;
      final gain = ctx.createGain();
      gain.gain.value = 0.0001;
      gain.gain.exponentialRampToValueAtTime(0.12, now + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.22);
      gain.connect(ctx.destination);
      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = 880;
      osc.connect(gain);
      osc.start(now);
      osc.stop(now + 0.24);
      final osc2 = ctx.createOscillator();
      osc2.type = 'sine';
      osc2.frequency.value = 1174.66;
      osc2.connect(gain);
      osc2.start(now + 0.09);
      osc2.stop(now + 0.24);
    } catch (_) {
      // Audio is best effort.
    }
  }

  // -------------------------------------------------------- notifications

  bool get _hasNotificationApi =>
      (web.window as JSObject).hasProperty('Notification'.toJS).toDart;

  bool get notificationsGranted =>
      _hasNotificationApi && web.Notification.permission == 'granted';

  bool get notificationsDenied =>
      _hasNotificationApi && web.Notification.permission == 'denied';

  Future<bool> requestNotificationPermission() async {
    if (!_hasNotificationApi) return false;
    if (web.Notification.permission == 'granted') return true;
    if (web.Notification.permission == 'denied') return false;
    try {
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  void notify({
    required String title,
    required String body,
    String? tag,
    String? icon,
    void Function()? onClick,
  }) {
    if (!notificationsGranted) return;
    try {
      final options = web.NotificationOptions(
        body: body,
        tag: tag ?? '',
        icon: icon ?? '/icons/Icon-192.png',
        silent: true,
      );
      final notification = web.Notification(title, options);
      notification.onclick = ((web.Event event) {
        web.window.focus();
        notification.close();
        onClick?.call();
      }).toJS;
      // Close by itself so stale alerts do not pile up.
      Timer(const Duration(seconds: 8), () => notification.close());
    } catch (_) {
      // Notification is best effort.
    }
  }
}
