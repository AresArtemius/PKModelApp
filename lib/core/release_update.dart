import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../ui/brand/brand_theme.dart';
import 'app_logger.dart';
import 'page_reload_stub.dart' if (dart.library.html) 'page_reload_web.dart';

/// Git commit the running web bundle was built from. Set by the deploy
/// workflow (`--dart-define=APP_RELEASE_SHA=$GITHUB_SHA`); empty in local
/// builds, which disables the check.
const String kAppReleaseSha = String.fromEnvironment('APP_RELEASE_SHA');

/// How often an open tab re-checks `release.json`.
const Duration kReleaseCheckInterval = Duration(minutes: 10);

/// Minimum gap between checks triggered by the tab becoming visible again.
const Duration _kResumeCheckThrottle = Duration(minutes: 1);

const Duration _kFetchTimeout = Duration(seconds: 8);

/// Fetches `release.json` from the site root and returns the deployed commit
/// sha, or null when the file is missing or malformed.
Future<String?> fetchDeployedReleaseSha() async {
  final base = Uri.base;
  final uri = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/release.json',
    queryParameters: {
      'ts': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );
  final response = await http
      .get(uri, headers: const {'Cache-Control': 'no-cache'})
      .timeout(_kFetchTimeout);
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) return null;
  final sha = decoded['sha'];
  if (sha is! String || sha.isEmpty) return null;
  return sha;
}

/// Shows a "new version available" banner over [child] once the deployed
/// release differs from the one this tab loaded. Web only; a no-op elsewhere
/// and in builds without [kAppReleaseSha].
class ReleaseUpdateBanner extends StatefulWidget {
  const ReleaseUpdateBanner({super.key, required this.child});

  final Widget child;

  @override
  State<ReleaseUpdateBanner> createState() => _ReleaseUpdateBannerState();
}

class _ReleaseUpdateBannerState extends State<ReleaseUpdateBanner>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastCheck;
  bool _checking = false;
  String? _availableSha;
  String? _dismissedSha;

  bool get _enabled => kIsWeb && kAppReleaseSha.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(kReleaseCheckInterval, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last != null &&
        DateTime.now().difference(last) < _kResumeCheckThrottle) {
      return;
    }
    _check();
  }

  Future<void> _check() async {
    if (!_enabled || _checking || !mounted) return;
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final deployed = await fetchDeployedReleaseSha();
      if (!mounted || deployed == null) return;
      if (deployed != kAppReleaseSha && deployed != _availableSha) {
        setState(() => _availableSha = deployed);
      }
    } catch (error, stackTrace) {
      // Offline or a transient server error: try again on the next tick.
      AppLogger.warning(
        'release check failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _checking = false;
    }
  }

  void _dismiss() => setState(() => _dismissedSha = _availableSha);

  @override
  Widget build(BuildContext context) {
    final sha = _availableSha;
    final visible = sha != null && sha != _dismissedSha;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 1.2),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 240),
                child: _ReleaseBannerCard(
                  onReload: reloadPage,
                  onDismiss: _dismiss,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReleaseBannerCard extends StatelessWidget {
  const _ReleaseBannerCard({required this.onReload, required this.onDismiss});

  final VoidCallback onReload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final title = isEnglish
        ? 'A new version is available'
        : 'Доступна новая версия';
    final subtitle = isEnglish
        ? 'Reload the page to get the latest updates.'
        : 'Обновите страницу, чтобы получить последние изменения.';
    final reloadLabel = isEnglish ? 'Reload' : 'Обновить';
    final laterLabel = isEnglish ? 'Later' : 'Позже';

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: const Color(0xFF161616),
              elevation: 12,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.system_update_alt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xB3FFFFFF),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(laterLabel),
                    ),
                    FilledButton(
                      onPressed: onReload,
                      style: FilledButton.styleFrom(
                        backgroundColor: BrandTheme.redTop,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(reloadLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
