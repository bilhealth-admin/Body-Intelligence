import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
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
import 'app/services/app_switcher_privacy_shield.dart';
import 'app/services/app_observability.dart';
import 'app/services/app_settings_provider.dart';
import 'features/notifications/services/inactivity_reminder_coordinator.dart';
import 'app/theme/bil_flagship_theme.dart';
import 'shared/widgets/bil_wordmark.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppObservability.crashes.record(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    assert(() {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      return true;
    }());
    AppObservability.crashes.record(error, stack);
    return true;
  };

  runApp(const ProviderScope(child: _BILBootstrap()));
}

class _BILBootstrap extends StatefulWidget {
  const _BILBootstrap();

  @override
  State<_BILBootstrap> createState() => _BILBootstrapState();
}

class _BILBootstrapState extends State<_BILBootstrap> {
  bool ready = !AppEnvironment.cloudConfigured;
  Object? failure;

  @override
  void initState() {
    super.initState();
    if (!ready) {
      // Paint the branded startup frame before cloud SDK platform setup.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_initializeCloud());
      });
    }
  }

  Future<void> _initializeCloud() async {
    setState(() => failure = null);
    try {
      await Supabase.initialize(
        url: AppEnvironment.supabaseUrl,
        publishableKey: AppEnvironment.supabaseAnonKey,
      );
      if (!mounted) return;
      setState(() => ready = true);
    } catch (error, stack) {
      AppObservability.crashes.record(error, stack);
      if (!mounted) return;
      setState(() => failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ready) return const _BILLinkBootstrap(child: BILApp());
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087FCE),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050505),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BilWordmark(height: 48, color: Colors.white),
                  const SizedBox(height: 32),
                  if (failure == null)
                    const SizedBox.shrink()
                  else ...[
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
                ],
              ),
            ),
          ),
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

  @override
  void initState() {
    super.initState();
    _controller = BilIncomingLinkController(
      analytics: const DisabledBilLaunchAnalyticsSink(),
      navigate: AppRouter.router.go,
      clock: DateTime.now,
    );
    unawaited(_bind());
  }

  Future<void> _bind() async {
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    if (initial != null) await _controller.handle(initial);
    _controller.bind(appLinks.uriLinkStream);
  }

  @override
  void dispose() {
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
