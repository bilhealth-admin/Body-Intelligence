import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gateway follows premium iPhone-like welcome hierarchy', () {
    final gateway = File(
      'lib/features/auth/premium_account_gateway_page.dart',
    ).readAsStringSync();

    expect(gateway, contains('final pageBackground = scheme.brightness'));
    expect(gateway, contains('backgroundColor: pageBackground'));
    expect(gateway, contains('AuthEntryCopyKey.welcomeTo'));
    expect(gateway, contains('BilFullWordmark'));
    expect(gateway, contains('child: AuthLanguageSelector()'));
    expect(gateway, contains('const _gatewayStoryViewportFraction = .87;'));
    expect(gateway, contains('const _gatewayStoryCardAspectRatio = 1.0;'));
    expect(gateway, contains("Key('gateway-story-viewport')"));
    expect(gateway, contains("Key('gateway-story-copy-slot')"));
    expect(gateway, contains('IndexedStack('));
    expect(gateway, contains('bil_sleep_insights_v2.png'));
    expect(gateway, contains('bil_meal_discovery_v2.png'));
    expect(gateway, isNot(contains('bil_sleep_insights_v1.png')));
    expect(gateway, isNot(contains('bil_meal_discovery_v1.png')));
    expect(gateway, contains('_StoryGlassSignal'));
    expect(gateway, contains('BackdropFilter'));
    expect(gateway, contains("Key('gateway-account-action')"));
    expect(gateway, contains("Key('gateway-continue-locally')"));
    expect(gateway, contains("() => context.go('/login')"));

    // The build method uses a helper widget for the brand header. Verify the
    // actual visual hierarchy in two bounded regions instead of comparing
    // unrelated source-file offsets across separate class declarations.
    final buildHeader = gateway.indexOf(
      '_GatewayBrandHeader(compact: compact)',
    );
    final languageControl = gateway.indexOf('child: AuthLanguageSelector()');
    expect(buildHeader, greaterThanOrEqualTo(0));
    expect(languageControl, greaterThan(buildHeader));

    final brandClass = gateway.indexOf('class _GatewayBrandHeader');
    final storyClass = gateway.indexOf('class _GatewayStoryPager');
    expect(brandClass, greaterThanOrEqualTo(0));
    expect(storyClass, greaterThan(brandClass));
    final brandRegion = gateway.substring(brandClass, storyClass);
    expect(
      brandRegion.indexOf('AuthEntryCopyKey.welcomeTo'),
      lessThan(brandRegion.indexOf('BilFullWordmark')),
    );

    expect(gateway, isNot(contains('AuthEntryCopyKey.privacyFooter')));
  });

  test(
    'language control is iPhone-like, icon-free and alphabetically governed',
    () {
      final selector = File(
        'lib/features/auth/auth_language_selector.dart',
      ).readAsStringSync();
      final localeNames = File(
        'lib/app/localization/bil_locale_names.dart',
      ).readAsStringSync();

      expect(selector, contains('BilLocaleNames.englishFirstAlphabeticalTags'));
      for (final locale in [
        "'ar'",
        "'bn'",
        "'zh-Hans'",
        "'zh-Hant'",
        "'nl'",
        "'en'",
        "'fr'",
        "'de'",
        "'hi'",
        "'id'",
        "'it'",
        "'ja'",
        "'ko'",
        "'ms'",
        "'fa'",
        "'pl'",
        "'pt-BR'",
        "'pt-PT'",
        "'ru'",
        "'es'",
        "'th'",
        "'tr'",
        "'uk'",
        "'ur'",
        "'vi'",
      ]) {
        expect(localeNames, contains(locale), reason: locale);
      }
      expect(selector, contains('showModalBottomSheet<void>'));
      expect(selector, contains('Color(0xFFF2F2F7)'));
      expect(selector, contains('Color(0xFF8E8E93)'));
      expect(selector, isNot(contains('Icons.language_rounded')));
      expect(selector, isNot(contains('Border.all(')));
      expect(selector, isNot(contains('PopupMenuButton')));
    },
  );

  test(
    'login and OTP use the canonical full wordmark below navigation headers',
    () {
      final login = File(
        'lib/features/auth/premium_login_page.dart',
      ).readAsStringSync();
      final verify = File(
        'lib/features/auth/verify_email_page.dart',
      ).readAsStringSync();

      for (final source in [login, verify]) {
        expect(source, contains('backgroundColor: pageBackground'));
        expect(source, contains('Color(0xFFFAFAFC)'));
        expect(source, contains('scheme.surfaceContainerLow'));
        expect(source, contains('scheme.onSurface'));
        expect(source, contains('CircleBorder()'));
        expect(source, contains('Icons.arrow_back_ios_new_rounded'));
        expect(source, contains('BilFullWordmark'));
        expect(source, isNot(contains('BilWordmark(')));
        expect(source, isNot(contains('auth_language_selector.dart')));
      }

      expect(login, contains('AuthEntryCopyKey.emailAddress'));
      expect(login, contains("key: Key('login-wordmark')"));
      expect(
        login,
        matches(
          RegExp(
            r"BilFullWordmark\([\s\S]{0,240}key: Key\('login-wordmark'\),"
            r'[\s\S]{0,120}alignment: Alignment\.center,',
          ),
        ),
      );
      expect(login, contains('Color(0xFF0877F9)'));
      expect(login, contains('elevation: 5'));
      expect(verify, contains('List.generate(6'));
      expect(verify, contains('authEntryResendCountdown(context, _clock)'));
    },
  );

  test(
    'Google uses the multicolour brand asset and privacy remains reachable',
    () {
      final login = File(
        'lib/features/auth/premium_login_page.dart',
      ).readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final google = File('assets/branding/google_g.svg').readAsStringSync();

      expect(login, contains('assets/branding/google_g.svg'));
      expect(login, contains("context.push('/legal/privacy')"));
      expect(pubspec, contains('assets/branding/google_g.svg'));
      for (final color in ['#4285F4', '#34A853', '#FBBC05', '#EA4335']) {
        expect(google, contains(color), reason: color);
      }
    },
  );
}
