import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/localization/app_localizations.dart';
import 'app/router/app_router.dart';
import 'app/services/app_observability.dart';
import 'app/services/app_settings_provider.dart';
import 'app/theme/bil_flagship_theme.dart';
import 'features/global_platform/runtime/global_product_composition_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GlobalNativeIntegrationHost.instance.initialize();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppObservability.crashes.record(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppObservability.crashes.record(error, stack);
    return true;
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: BILApp())),
    AppObservability.crashes.record,
  );
}

class BILApp extends ConsumerWidget {
  const BILApp({super.key, this.locale, this.themeMode});

  final Locale? locale;
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final selectedLocale = locale ?? Locale(settings.localeCode);
    final selectedThemeMode =
        themeMode ??
        switch (settings.themeMode) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        };

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'BIL – Body Intelligence Log',
      locale: selectedLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
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
        if (!settings.reduceMotion) {
          return child ?? const SizedBox.shrink();
        }

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: AppRouter.router,
    );
  }
}
