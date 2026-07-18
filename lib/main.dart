import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/localization/app_localizations.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme_data.dart';
import 'app/services/app_settings_provider.dart';

void main() {
  runApp(const ProviderScope(child: BILApp()));
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
      theme: AppThemeData.lightTheme(Brightness.light),
      darkTheme: AppThemeData.lightTheme(Brightness.dark),
      routerConfig: AppRouter.router,
    );
  }
}
