/// Browser-tab alerts (title badge, sound, system notification) — no-op
/// outside the web build. See tab_alerts_web.dart.
class TabAlerts {
  const TabAlerts();

  bool get supported => false;

  bool get hidden => false;

  /// Prefixes the tab title with «(N) »; 0 removes the badge.
  void setBadge(int count) {}

  /// Short notification sound (needs a prior user gesture on the page).
  void playSound() {}

  /// Whether the Notification API permission has been granted.
  bool get notificationsGranted => false;

  bool get notificationsDenied => false;

  /// Asks for permission; call from a user gesture (a click).
  Future<bool> requestNotificationPermission() async => false;

  /// Shows a system notification; [onClick] runs when the user clicks it
  /// (the tab is focused first).
  void notify({
    required String title,
    required String body,
    String? tag,
    String? icon,
    void Function()? onClick,
  }) {}
}
