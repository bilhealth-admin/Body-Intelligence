import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/auth/auth_entry_locale_copy.dart';
import 'package:body_intelligence_log/features/auth/premium_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Widget _login({
  required Locale locale,
  required Brightness brightness,
  required double scale,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(brightness: brightness, platform: TargetPlatform.iOS),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: const LoginPage(),
);

double _effectiveFontSize(WidgetTester tester, Finder text) {
  final widget = tester.widget<Text>(text);
  final fontSize = widget.style!.fontSize!;
  final scaler =
      widget.textScaler ?? MediaQuery.textScalerOf(tester.element(text));
  return scaler.scale(fontSize);
}

void _expectProviderSizes(WidgetTester tester, Locale locale, double scale) {
  final google = find.byKey(const Key('oauth-google'));
  final apple = find.byKey(const Key('oauth-apple'));
  final googleLabel = find.text(
    authEntryTextForTag(
      locale.toLanguageTag(),
      AuthEntryCopyKey.continueGoogle,
    ),
  );
  final appleLabel = find.text(
    authEntryTextForTag(locale.toLanguageTag(), AuthEntryCopyKey.continueApple),
  );
  final expectedHeight = 44 * (scale < 1 ? 1 : scale);
  expect(tester.getSize(google).height, closeTo(expectedHeight, .01));
  expect(tester.getSize(apple), tester.getSize(google));
  expect(
    _effectiveFontSize(tester, googleLabel),
    closeTo(44 * .43 * scale, .01),
  );
  expect(
    _effectiveFontSize(tester, appleLabel),
    closeTo(_effectiveFontSize(tester, googleLabel), .01),
    reason: 'Apple must not enlarge the already height-scaled text again',
  );
  expect(tester.getTopLeft(google).dy, lessThan(tester.getTopLeft(apple).dy));
  expect(
    Directionality.of(tester.element(appleLabel)),
    ['ar', 'fa', 'ur'].contains(locale.languageCode)
        ? TextDirection.rtl
        : TextDirection.ltr,
  );
  final native = tester.widget<SignInWithAppleButton>(apple);
  expect(native.onPressed, AppEnvironment.cloudConfigured ? isNotNull : isNull);

  final facebook = find.byKey(const Key('oauth-facebook'));
  if (AppEnvironment.facebookLoginEnabled) {
    expect(tester.getSize(facebook), tester.getSize(apple));
    final facebookLabel = find.text(
      authEntryTextForTag(
        locale.toLanguageTag(),
        AuthEntryCopyKey.continueFacebook,
      ),
    );
    expect(
      _effectiveFontSize(tester, facebookLabel),
      closeTo(_effectiveFontSize(tester, appleLabel), .01),
    );
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: facebook, matching: find.byType(InkWell)),
    );
    expect(
      inkWell.onTap,
      AppEnvironment.facebookLoginReady ? isNotNull : isNull,
    );
  } else {
    expect(facebook, findsNothing);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    for (final brightness in Brightness.values) {
      for (final scale in [.8, 1.0, 1.3, 1.6]) {
        testWidgets(
          'Apple matches provider size: $locale $brightness x$scale',
          (tester) async {
            addTearDown(() => tester.binding.setSurfaceSize(null));
            for (final width in [320.0, 390.0, 430.0]) {
              await tester.binding.setSurfaceSize(Size(width, 1100));
              await tester.pumpWidget(
                _login(locale: locale, brightness: brightness, scale: scale),
              );
              await tester.pumpAndSettle();
              _expectProviderSizes(tester, locale, scale);
              final native = tester.widget<SignInWithAppleButton>(
                find.byKey(const Key('oauth-apple')),
              );
              expect(
                native.style,
                brightness == Brightness.dark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
              );
            }
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }

  testWidgets(
    'all released locales retain equal native provider dimensions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(
          _login(locale: locale, brightness: Brightness.light, scale: 1),
        );
        await tester.pumpAndSettle();
        _expectProviderSizes(tester, locale, 1);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
