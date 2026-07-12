import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/account_profile_service.dart';
import 'core/app_logger.dart';
import 'core/auth_providers.dart';
import 'core/go_router_provider.dart';
import 'core/push_notifications_service.dart';
import 'gen_l10n/app_localizations.dart';
import 'core/locale_provider.dart';
import 'ui/brand/app_theme.dart';
import 'ui/brand/brand_theme.dart';

Widget _buildBaseApp({
  required Locale? locale,
  Widget? home,
  RouterConfig<Object>? routerConfig,
  String Function(BuildContext)? onGenerateTitle,
  Widget? startupOverlay,
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
      builder: (context, child) =>
          _WebAppFrame(startupOverlay: startupOverlay, child: child),
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
    builder: (context, child) =>
        _WebAppFrame(startupOverlay: startupOverlay, child: child),
    home: home,
  );
}

const _kSupportedLocales = AppLocalizations.supportedLocales;
const _kLocalizationsDelegates = AppLocalizations.localizationsDelegates;

const double _kWebCabinetMaxWidth = 1440.0;
const double _kBootstrapErrorMaxWidth = 520.0;
const EdgeInsets _kBootstrapErrorPadding = EdgeInsets.all(24);
const double _kBootstrapErrorGap = 12.0;
const int _kWebImageCacheCount = 450;
const int _kMobileImageCacheCount = 280;
const int _kWebImageCacheMb = 180;
const int _kMobileImageCacheMb = 96;
const Duration _kStartupSplashDuration = Duration(milliseconds: 2200);

void _configureImageCache() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = kIsWeb
      ? _kWebImageCacheCount
      : _kMobileImageCacheCount;
  imageCache.maximumSizeBytes =
      (kIsWeb ? _kWebImageCacheMb : _kMobileImageCacheMb) * 1024 * 1024;
}

class _WebAppFrame extends StatelessWidget {
  const _WebAppFrame({required this.child, this.startupOverlay});

  final Widget? child;
  final Widget? startupOverlay;

  @override
  Widget build(BuildContext context) {
    final app = Stack(
      fit: StackFit.expand,
      children: [
        child ?? const SizedBox.shrink(),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: startupOverlay == null
                  ? const SizedBox.shrink(key: ValueKey('startup-empty'))
                  : KeyedSubtree(
                      key: const ValueKey('startup-splash'),
                      child: startupOverlay!,
                    ),
            ),
          ),
        ),
      ],
    );
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
      final d = (details ?? '').trim();
      return (
        title: t.bootstrapInitErrorTitle,
        message: d.isEmpty
            ? '${t.bootstrapInitErrorMessage}\nДетали: неизвестная ошибка инициализации.'
            : '${t.bootstrapInitErrorMessage}\n$d',
      );
  }
}

Future<void> main() async {
  var appStarted = false;
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _configureImageCache();

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
        _runBootstrap(_BootstrapErrorKind.init, details: e.toString());
        return;
      }

      runApp(const ProviderScope(child: MyApp()));
      appStarted = true;
    },
    (error, stack) {
      AppLogger.error('App zone error', error: error, stackTrace: stack);
      if (!appStarted) {
        _runBootstrap(_BootstrapErrorKind.init, details: error.toString());
        return;
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'app_zone',
          context: ErrorDescription('unhandled asynchronous app error'),
        ),
      );
    },
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _showStartupSplash = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      unawaited(HapticFeedback.lightImpact());
    }
    Future<void>.delayed(_kStartupSplashDuration, () {
      if (mounted) setState(() => _showStartupSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
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
      startupOverlay: _showStartupSplash ? const _StartupSplashScreen() : null,
    );
  }
}

class _StartupSplashScreen extends StatefulWidget {
  const _StartupSplashScreen();

  @override
  State<_StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<_StartupSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1320),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _scale = Tween<double>(begin: 0.94, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.85, curve: Curves.easeOutBack),
        ),
      );

  late final Animation<Offset> _brandSlide =
      Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.28, 1, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF020202),
                Color(0xFF140507),
                Color(0xFF42000A),
                Color(0xFF760012),
              ],
              stops: [0.0, 0.46, 0.78, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.18),
                      radius: 0.72,
                      colors: [
                        BrandTheme.redTop.withValues(alpha: 0.34),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 132,
                      height: 132,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.13),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: BrandTheme.redTop.withValues(alpha: 0.46),
                            blurRadius: 42,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/pk-logo-red-512.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: SafeArea(
                  top: false,
                  child: SlideTransition(
                    position: _brandSlide,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Text(
                        'PK MANAGEMENT',
                        textAlign: TextAlign.center,
                        style: BrandTheme.pillText.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
