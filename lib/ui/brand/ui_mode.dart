/// Step 57: the v2 design (white pages, flat inputs, no pills) is the only
/// design on every platform. Pages used to switch on `kIsWeb`; they now
/// switch on this flag, so iOS and Android get the same screens as the web.
/// `kIsWeb` stays only for browser-specific mechanics (URLs, JS, tabs).
///
/// Read from the environment so the old screens can still be built for a
/// comparison (`--dart-define=UI_V2=false`); the analyzer then does not treat
/// the old branches as dead code.
const bool uiV2 = bool.fromEnvironment('UI_V2', defaultValue: true);
