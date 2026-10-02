import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/brand/ui_constants.dart';
import 'page_reload_stub.dart' if (dart.library.html) 'page_reload_web.dart';
import 'release_update.dart';

/// Loads a deferred library before building its page.
///
/// On web, `import '…' deferred as x` puts the library into a separate
/// JavaScript part that is downloaded only when `x.loadLibrary()` runs, so
/// rarely used areas (the admin back office) stay out of the startup bundle.
/// On mobile the load completes immediately.
///
/// The part files are not content-hashed, so a tab that loaded an older
/// release cannot fetch its parts once a new release is deployed. That case
/// is detected via `release.json` and shown as «new version — reload»
/// instead of a connection error.
class DeferredPage extends StatefulWidget {
  const DeferredPage({
    super.key,
    required this.libraryKey,
    required this.load,
    required this.builder,
  });

  /// Stable identifier of the deferred library, used to skip the loading
  /// state once that library has been loaded in this session.
  final String libraryKey;
  final Future<void> Function() load;
  final WidgetBuilder builder;

  static final Set<String> _loaded = <String>{};

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

/// The running bundle is older than the deployed one.
class _StaleReleaseError implements Exception {
  const _StaleReleaseError();
}

class _DeferredPageState extends State<DeferredPage> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _start();
  }

  Future<void> _start() async {
    if (DeferredPage._loaded.contains(widget.libraryKey)) return;
    try {
      await widget.load();
    } catch (error) {
      if (await _deployedReleaseDiffers()) throw const _StaleReleaseError();
      rethrow;
    }
    DeferredPage._loaded.add(widget.libraryKey);
  }

  Future<bool> _deployedReleaseDiffers() async {
    if (!kIsWeb || kAppReleaseSha.isEmpty) return false;
    try {
      final deployed = await fetchDeployedReleaseSha();
      return deployed != null && deployed != kAppReleaseSha;
    } catch (_) {
      return false;
    }
  }

  void _retry() => setState(() => _future = _start());

  @override
  Widget build(BuildContext context) {
    if (DeferredPage._loaded.contains(widget.libraryKey)) {
      return widget.builder(context);
    }
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        if (snapshot.hasError) {
          final ru = Localizations.localeOf(context).languageCode == 'ru';
          final stale = snapshot.error is _StaleReleaseError;
          return Scaffold(
            backgroundColor: Tokens.bg,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Tokens.surface,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          stale
                              ? Icons.system_update_alt_rounded
                              : Icons.cloud_off_rounded,
                          size: 32,
                          color: Tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        stale
                            ? (ru
                                  ? 'Вышла новая версия сайта'
                                  : 'A new version of the site is live')
                            : (ru
                                  ? 'Не удалось загрузить раздел'
                                  : 'Could not load this section'),
                        textAlign: TextAlign.center,
                        style: AppText.h2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stale
                            ? (ru
                                  ? 'Обновите страницу, чтобы открыть раздел.'
                                  : 'Reload the page to open this section.')
                            : (ru
                                  ? 'Проверьте подключение и попробуйте ещё раз.'
                                  : 'Check the connection and try again.'),
                        textAlign: TextAlign.center,
                        style: AppText.small.copyWith(
                          color: Tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: stale ? reloadPage : _retry,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(160, Tokens.controlHeight),
                        ),
                        child: Text(
                          stale
                              ? (ru ? 'Обновить страницу' : 'Reload page')
                              : (ru ? 'Повторить' : 'Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: Tokens.bg,
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
