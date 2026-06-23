import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/account_profile_service.dart';
import 'core/app_logger.dart';
import 'core/auth_providers.dart';
import 'core/go_router_provider.dart';
import 'core/push_notifications_service.dart';
import 'gen_l10n/app_localizations.dart';
import 'core/locale_provider.dart';
import 'ui/brand/app_theme.dart';

Widget _buildBaseApp({
  required Locale? locale,
  Widget? home,
  RouterConfig<Object>? routerConfig,
  String Function(BuildContext)? onGenerateTitle,
}) {
  assert(
    (routerConfig != null) ^ (home != null),
    'Provide either routerConfig or home (exactly one).',
  );
  if (routerConfig != null) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: _kSupportedLocales,
      localizationsDelegates: _kLocalizationsDelegates,
      onGenerateTitle: onGenerateTitle,
      theme: buildModelAppTheme(),
      builder: (context, child) => _WebAppFrame(child: child),
      routerConfig: routerConfig,
    );
  }

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: _kSupportedLocales,
    localizationsDelegates: _kLocalizationsDelegates,
    onGenerateTitle: onGenerateTitle,
    theme: buildModelAppTheme(),
    builder: (context, child) => _WebAppFrame(child: child),
    home: home,
  );
}

const _kSupportedLocales = AppLocalizations.supportedLocales;
const _kLocalizationsDelegates = AppLocalizations.localizationsDelegates;

const double _kWebCabinetMaxWidth = 1440.0;
const double _kBootstrapErrorMaxWidth = 520.0;
const EdgeInsets _kBootstrapErrorPadding = EdgeInsets.all(24);
const double _kBootstrapErrorGap = 12.0;

class _WebAppFrame extends StatelessWidget {
  const _WebAppFrame({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final app = child ?? const SizedBox.shrink();
    if (!kIsWeb) return app;

    return ColoredBox(
      color: const Color(0xFFE7E7E7),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kWebCabinetMaxWidth),
          child: app,
        ),
      ),
    );
  }
}

class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isValid =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

enum _BootstrapErrorKind { config, init }

void _runBootstrap(_BootstrapErrorKind kind, {String? details}) {
  runApp(
    ProviderScope(
      child: _BootstrapErrorApp(kind: kind, details: details),
    ),
  );
}

({String title, String message}) _resolveBootstrapTexts({
  required AppLocalizations t,
  required _BootstrapErrorKind kind,
  String? details,
}) {
  switch (kind) {
    case _BootstrapErrorKind.config:
      return (
        title: t.bootstrapConfigErrorTitle,
        message: t.bootstrapConfigErrorMessage,
      );
    case _BootstrapErrorKind.init:
      final d = details ?? '';
      return (
        title: t.bootstrapInitErrorTitle,
        message: d.isEmpty
            ? t.bootstrapInitErrorMessage
            : '${t.bootstrapInitErrorMessage}\n$d',
      );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'platform_dispatcher',
        context: ErrorDescription('unhandled platform error'),
      ),
    );
    return false;
  };

  await runZonedGuarded(
    () async {
      if (!AppConfig.isValid) {
        _runBootstrap(_BootstrapErrorKind.config);
        return;
      }

      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
      } catch (e, stack) {
        AppLogger.error(
          'Supabase initialization failed',
          error: e,
          stackTrace: stack,
        );
        _runBootstrap(_BootstrapErrorKind.init);
        return;
      }

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      AppLogger.error('Bootstrap zone error', error: error, stackTrace: stack);
      _runBootstrap(_BootstrapErrorKind.init);
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final locale = ref.watch(localeProvider);
    ref.watch(accountProfileSyncProvider);
    ref.watch(authSessionValidatorProvider);
    ref.watch(pushRegistrationProvider);
    unawaited(
      ref.read(pushNotificationsServiceProvider).configureTapHandling(router),
    );

    return _buildBaseApp(
      locale: locale,
      routerConfig: router,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    );
  }
}

class _BootstrapErrorApp extends ConsumerWidget {
  const _BootstrapErrorApp({required this.kind, this.details});

  final _BootstrapErrorKind kind;
  final String? details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return _buildBaseApp(
      locale: locale,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _kBootstrapErrorMaxWidth,
            ),
            child: Padding(
              padding: _kBootstrapErrorPadding,
              child: Builder(
                builder: (context) {
                  final t = AppLocalizations.of(context)!;
                  final texts = _resolveBootstrapTexts(
                    t: t,
                    kind: kind,
                    details: details,
                  );

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        texts.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: _kBootstrapErrorGap),
                      SelectableText(
                        texts.message,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
