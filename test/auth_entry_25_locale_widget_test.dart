import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_names.dart';
import 'package:body_intelligence_log/features/auth/premium_login_page.dart';
import 'package:body_intelligence_log/features/auth/login_page.dart'
    show StoreReviewerLoginPage;
import 'package:body_intelligence_log/features/auth/auth_five_locale_copy.dart';
import 'package:body_intelligence_log/features/auth/verify_email_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sign-in wordmark is centered in LTR and RTL', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final locale in const [Locale('en'), Locale('ar')]) {
      await tester.pumpWidget(_localizedApp(locale, const LoginPage()));
      await tester.pump(const Duration(milliseconds: 120));

      final wordmark = find.byKey(const Key('login-wordmark'));
      expect(wordmark, findsOneWidget);
      final align = find.descendant(of: wordmark, matching: find.byType(Align));
      expect(align, findsOneWidget);
      expect(tester.widget<Align>(align).alignment, Alignment.center);

      final lockup = find.descendant(of: wordmark, matching: find.byType(Row));
      expect(lockup, findsOneWidget);
      expect(
        tester.getCenter(lockup).dx,
        closeTo(tester.getCenter(wordmark).dx, 0.5),
        reason: locale.toLanguageTag(),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('email login and OTP render across every declared locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    expect(BilLocaleNames.native.length, 25);

    for (final localeTag in BilLocaleNames.native.keys) {
      for (final key in const [
        'Store reviewer access',
        'Use only the dedicated credentials supplied in the store review notes.',
        'Password',
      ]) {
        expect(
          authHasExactReviewedCopy(localeTag, key),
          isTrue,
          reason: 'Missing exact reviewer copy for $localeTag:$key',
        );
      }
    }

    for (final localeTag in BilLocaleNames.native.keys) {
      final locale = _localeFromTag(localeTag);

      await tester.pumpWidget(_localizedApp(locale, const LoginPage()));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Login failed to render for $localeTag',
      );
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.byKey(const Key('auth-language-selector')), findsNothing);

      await tester.pumpWidget(
        _localizedApp(
          locale,
          const VerifyEmailPage(email: 'person@example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.takeException(),
        isNull,
        reason: 'OTP failed to render for $localeTag',
      );
      expect(find.byKey(const Key('verification-code-boxes')), findsOneWidget);
      expect(find.byKey(const Key('auth-language-selector')), findsNothing);

      await tester.pumpWidget(
        _localizedApp(locale, const StoreReviewerLoginPage()),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Reviewer login failed to render for $localeTag',
      );
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.byKey(const Key('login-password')), findsOneWidget);
      expect(find.byKey(const Key('reviewer-login-back')), findsOneWidget);

      // Dispose the page and its countdown timer before advancing locales.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('login and OTP keep themed surfaces in dark mode at 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0877F9),
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      _localizedApp(
        const Locale('en'),
        const LoginPage(),
        theme: darkTheme,
        textScale: 2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      darkTheme.colorScheme.surface,
    );
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.text('BODY INTELLIGENCE LOG'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('BODY INTELLIGENCE LOG')).style?.color,
      const Color(0xFF050505),
    );

    await tester.pumpWidget(
      _localizedApp(
        const Locale('en'),
        const VerifyEmailPage(email: 'person@example.com'),
        theme: darkTheme,
        textScale: 2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      darkTheme.colorScheme.surface,
    );
    expect(find.byKey(const Key('verification-code-boxes')), findsOneWidget);
    expect(find.text('BODY INTELLIGENCE LOG'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'reviewer header preserves every control on a narrow phone at 200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in const [
        Locale('en'),
        Locale('ar'),
        Locale('pt', 'BR'),
      ]) {
        await tester.pumpWidget(
          _localizedApp(locale, const StoreReviewerLoginPage(), textScale: 2),
        );
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          tester.takeException(),
          isNull,
          reason: '${locale.toLanguageTag()} reviewer header overflowed',
        );
        expect(
          find.byKey(const Key('reviewer-login-header-actions')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('reviewer-login-back')), findsOneWidget);
        expect(find.byKey(const Key('auth-language-selector')), findsOneWidget);
        expect(
          find.byKey(const Key('auth-language-selector-label')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}

Widget _localizedApp(
  Locale locale,
  Widget home, {
  ThemeData? theme,
  double textScale = 1.6,
}) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    theme: theme,
    darkTheme: theme,
    themeMode: theme == null ? ThemeMode.system : ThemeMode.dark,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  ),
);

Locale _localeFromTag(String localeTag) {
  final parts = localeTag.trim().replaceAll('_', '-').split('-');
  final language = parts.first.toLowerCase();
  String? script;
  String? country;
  for (final part in parts.skip(1)) {
    if (part.length == 4 && script == null) {
      script = part[0].toUpperCase() + part.substring(1).toLowerCase();
    } else if ((part.length == 2 || part.length == 3) && country == null) {
      country = part.toUpperCase();
    }
  }
  return Locale.fromSubtags(
    languageCode: language,
    scriptCode: script,
    countryCode: country,
  );
}
