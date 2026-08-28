import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_picker/country_picker.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/environment/app_environment.dart';
import 'app/analytics/bil_incoming_link_controller.dart';
import 'app/analytics/bil_launch_event.dart';
import 'app/localization/app_localizations.dart';
import 'app/localization/bil_locale_policy.dart';
import 'app/router/app_router.dart';
import 'app/security/bil_play_integrity_service.dart';
import 'app/services/app_switcher_privacy_shield.dart';
import 'app/services/app_observability.dart';
import 'app/services/app_settings_provider.dart';
import 'features/ads/presentation/ad_runtime_bootstrap.dart';
import 'features/auth/bil_auth_callback_controller.dart';
import 'features/notifications/services/inactivity_reminder_coordinator.dart';
import 'features/startup/premium_splash_experience.dart';
import 'app/theme/bil_flagship_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppObservability.crashes.record(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    assert(() {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      return true;
    }());
    AppObservability.crashes.record(error, stack);
    return true;
  };

  // Submit Flutter's first frame immediately so Android never holds its
  // native starting window while a branding asset is decoded. The motion
  // splash owns the deliberate launch duration; this decode is only a
  // best-effort fallback and therefore belongs after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_predecodeLaunchWordmark());
  });
  runApp(const ProviderScope(child: _BILBootstrap()));
}

Future<void> _predecodeLaunchWordmark() async {
  try {
    final data = await rootBundle.load(
      'assets/branding/bil_splash_identity.png',
    );
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 864,
      targetHeight: 864,
    );
    try {
      bilPredecodedLaunchWordmark = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  } catch (error, stack) {
    // The Flutter widget retains an AssetImage fallback. A branding decode
    // issue must never prevent local-first startup.
    AppObservability.crashes.record(error, stack);
  }
}

class _BILBootstrap extends StatefulWidget {
  const _BILBootstrap();

  @override
  State<_BILBootstrap> createState() => _BILBootstrapState();
}

class _BILBootstrapState extends State<_BILBootstrap> {
  bool ready = !AppEnvironment.cloudConfigured;
  Object? failure;
  bool nativeLaunchDismissed = false;

  @override
  void initState() {
    super.initState();
    // Never initialize platform plugins before Flutter submits its first
    // frame. On a standalone Android install SharedPreferences/AppLinks setup
    // can be substantially slower than it is under `flutter run`; invoking it
    // here synchronously kept Android's plain-blue starting window above an
    // otherwise-ready Flutter tree. The first post-frame callback is the
    // authoritative boundary: Android can remove its starting window before
    // cloud session recovery begins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dismissNativeLaunch();
      if (!ready) unawaited(_initializeCloud());
    });
  }

  Future<void> _initializeCloud() async {
    setState(() => failure = null);
    // Supabase creates its client synchronously before its first await, while
    // restoring SharedPreferences/auth can take much longer on a freshly
    // installed APK. Let the local-first router run as soon as that client
    // exists; StartupPage listens for the authoritative initialSession while
    // restoration continues in parallel.
    final cloudInitialization = Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabaseAnonKey,
      // BILLinkBootstrap is the single owner of initial/deferred app links.
      // A second AppLinks observer inside Supabase delayed Android startup
      // and could consume the initial auth link before the allow-list router.
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    if (mounted) setState(() => ready = true);
    try {
      await cloudInitialization;
      if (Supabase.instance.client.auth.currentSession != null) {
        // Play Integrity may bind Google Play services on Android's main
        // thread. Defer that optional observation until BIL has painted its
        // first real app frame so the native launch screen can disappear.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(
            BilPlayIntegrityService.instance.observe(
              action: 'session.bootstrap',
              payload: const <String, Object?>{'phase': 'closed_testing'},
            ),
          );
        });
      }
    } catch (error, stack) {
      AppObservability.crashes.record(error, stack);
      // Local data, onboarding and the dashboard remain usable. Cloud actions
      // fail closed through their runtime/auth/consent gates rather than
      // trapping the complete application on its splash screen.
      if (mounted) setState(() => failure = error);
    }
  }

  void _dismissNativeLaunch() {
    if (nativeLaunchDismissed) return;
    nativeLaunchDismissed = true;
    unawaited(
      const MethodChannel(
        'bil/launch',
      ).invokeMethod<void>('ready').catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ready) {
      return const BilAndroidUmpBootstrap(
        child: _BILLinkBootstrap(child: BILApp()),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087FCE),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: bilLaunchBlue,
      ),
      home: Scaffold(
        backgroundColor: bilLaunchBlue,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const BilStartupLoadingSurface(),
            if (failure != null)
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'تعذر الاتصال الآمن بالخدمة السحابية. لم تتغير بياناتك.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _initializeCloud,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.strings.text('Try again')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BILLinkBootstrap extends StatefulWidget {
  const _BILLinkBootstrap({required this.child});

  final Widget child;

  @override
  State<_BILLinkBootstrap> createState() => _BILLinkBootstrapState();
}

class _BILLinkBootstrapState extends State<_BILLinkBootstrap> {
  late final BilIncomingLinkController _controller;
  late final BilAuthCallbackController _authController;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _controller = BilIncomingLinkController(
      analytics: const DisabledBilLaunchAnalyticsSink(),
      navigate: AppRouter.router.go,
      clock: DateTime.now,
    );
    _authController = BilAuthCallbackController(
      resolve: (uri) async {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      },
      navigate: AppRouter.router.go,
      onError: (error, _) {
        AppObservability.logger.record(
          AppLogLevel.warning,
          'native_auth_callback_failed',
          attributes: {'errorType': error.runtimeType.toString()},
        );
      },
    );
    unawaited(_bind());
  }

  Future<void> _bind() async {
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    if (initial != null) await _handleIncomingUri(initial);
    _linkSubscription = appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleIncomingUri(uri)),
    );
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (await _authController.handle(uri)) return;
    await _controller.handle(uri);
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class BILApp extends ConsumerWidget {
  const BILApp({super.key, this.locale, this.themeMode});

  final Locale? locale;
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final selectedLocale =
        locale ?? BilLocalePolicy.localeFromTag(settings.localeCode);
    // Legacy copy helpers without a BuildContext must observe the selected
    // exact locale during the same build, rather than waiting for the async
    // localization delegate to update its compatibility bridge.
    AppLocalizations.activate(selectedLocale);
    final selectedThemeMode =
        themeMode ??
        switch (settings.themeMode) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          // Legacy or malformed values must never re-link the app palette to
          // the operating system. The user explicitly chooses Daylight or
          // Night mode; unknown values safely migrate to Daylight.
          _ => ThemeMode.light,
        };

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) =>
          AppLocalizations.of(context).get('app_title'),
      locale: selectedLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supported) {
        if (locale != null) return locale;
        final tag = BilLocalePolicy.canonicalTag(selectedLocale);
        return supported.firstWhere(
          (candidate) => BilLocalePolicy.canonicalTag(candidate) == tag,
          orElse: () {
            final languageMatches = supported
                .where(
                  (candidate) =>
                      candidate.languageCode == selectedLocale.languageCode,
                )
                .toList(growable: false);
            return languageMatches.length == 1
                ? languageMatches.single
                : const Locale('en');
          },
        );
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: selectedThemeMode,
      theme: BilFlagshipTheme.light(
        highContrast: settings.highContrast,
        isArabic: selectedLocale.languageCode.toLowerCase() == 'ar',
      ),
      darkTheme: BilFlagshipTheme.dark(
        highContrast: settings.highContrast,
        isArabic: selectedLocale.languageCode.toLowerCase() == 'ar',
      ),
      builder: (context, child) {
        final content = settings.reduceMotion
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child ?? const SizedBox.shrink(),
              )
            : child ?? const SizedBox.shrink();
        return InactivityReminderCoordinator(
          child: AppSwitcherPrivacyShield(
            child: Semantics(
              container: true,
              label: AppLocalizations.of(context).get('app_title'),
              child: content,
            ),
          ),
        );
      },
      routerConfig: AppRouter.router,
    );
  }
}
