import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('script and region tags remain distinct', () {
    expect(
      BilLocalePolicy.canonicalTag(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
      'zh-Hans',
    );
    expect(BilLocalePolicy.canonicalTag(const Locale('pt', 'BR')), 'pt-BR');
  });

  test('RTL covers Arabic Urdu Persian across production locales', () {
    for (final code in const ['ar', 'ur', 'fa']) {
      expect(BilLocalePolicy.isRtlTag(code), isTrue);
    }
    expect(BilLocalePolicy.isProduction(const Locale('ur')), isTrue);
    expect(
      BilLocalePolicy.readinessForTag('pt-BR'),
      BilLocaleReadiness.production,
    );
  });

  test('storage accepts exact tags and rejects ambiguous regional tags', () {
    expect(BilLocalePolicy.canonicalSupportedTag('PT_br'), 'pt-BR');
    expect(BilLocalePolicy.canonicalSupportedTag('zh_hant'), 'zh-Hant');
    expect(BilLocalePolicy.canonicalSupportedTag('pt'), isNull);
    expect(BilLocalePolicy.canonicalSupportedTag('zh'), isNull);
  });
}
