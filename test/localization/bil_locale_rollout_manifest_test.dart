import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('mandatory plan has 18 unique language/script targets', () {
    final tags = BilLocaleRolloutManifest.mandatory18.map((e) => e.tag).toSet();
    expect(tags, hasLength(18));
    expect(tags, containsAll(['zh-Hans', 'zh-Hant', 'ru', 'ur', 'fa']));
  });

  test('all exact release targets are selectable after automated QA', () {
    final production = AppLocalizations.supportedLocales
        .map(BilLocalePolicy.canonicalTag)
        .toSet();
    expect(production, BilLocaleRolloutManifest.releaseTargets25);
    for (final tag in BilLocaleRolloutManifest.releaseTargets25) {
      expect(
        BilLocalePolicy.readinessForTag(tag),
        BilLocaleReadiness.production,
        reason: tag,
      );
    }
  });

  test('rtl planning is explicit for Arabic Urdu and Persian only', () {
    final rtl = BilLocaleRolloutManifest.mandatory18
        .where((entry) => entry.textDirection == 'rtl')
        .map((entry) => entry.tag)
        .toSet();
    expect(rtl, {'ar', 'ur', 'fa'});
  });

  test('client and server share the exact 25 BCP-47 release targets', () {
    expect(BilLocaleRolloutManifest.releaseTargets25, hasLength(25));
    expect(
      BilLocaleRolloutManifest.releaseTargets25,
      containsAll(['pt-BR', 'pt-PT', 'zh-Hans', 'zh-Hant']),
    );
    expect(BilLocaleRolloutManifest.releaseTargets25, isNot(contains('pt')));
    expect(BilLocaleRolloutManifest.releaseTargets25, isNot(contains('zh')));
    final server = File(
      'supabase/functions/_shared/bcp47.ts',
    ).readAsStringSync();
    for (final tag in BilLocaleRolloutManifest.releaseTargets25) {
      expect(server, contains("'$tag'"), reason: 'server missing $tag');
    }
  });

  test('authenticated and settings surfaces expose the language selector', () {
    final auth = File(
      'lib/features/auth/auth_language_selector.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/reference_settings_home_page.dart',
    ).readAsStringSync();
    final names = File(
      'lib/app/localization/bil_locale_names.dart',
    ).readAsStringSync();
    final router = File(
      'lib/app/router/app_router.dart',
    ).readAsStringSync();
    final languagePage = File(
      'lib/features/settings/language_settings_page.dart',
    ).readAsStringSync();
    expect(auth, contains('BilLocaleNames.native'));
    expect(settings, contains("'/settings/language'"));
    expect(router, contains("path: '/settings/language'"));
    expect(router, contains('const LanguageSettingsPage()'));
    expect(languagePage, contains('BilLocaleNames.native'));
    for (final tag in BilLocaleRolloutManifest.releaseTargets25) {
      expect(names, contains("'$tag':"), reason: tag);
    }
  });
}
