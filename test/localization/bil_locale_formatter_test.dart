import 'package:body_intelligence_log/app/localization/bil_health_glossary.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  test(
    'dynamic number/date/currency formatting works across target scripts',
    () async {
      await initializeDateFormatting();
      for (final tag in const ['en', 'ar', 'de', 'pt-BR', 'ru', 'zh-Hans']) {
        final formatter = BilLocaleFormatter(tag);
        expect(formatter.decimal(1234.5), isNotEmpty, reason: tag);
        expect(formatter.percent(.25), isNotEmpty, reason: tag);
        expect(formatter.currency(4.99, 'USD'), isNotEmpty, reason: tag);
        expect(
          formatter.shortDate(DateTime(2026, 8, 12)),
          isNotEmpty,
          reason: tag,
        );
        expect(
          formatter.measurement(82.5, 'kg'),
          contains('\u00a0'),
          reason: tag,
        );
      }
    },
  );

  test('health glossary keys are unique and cover high-risk domains', () {
    final terms = BilHealthGlossary.terms;
    expect(terms.map((e) => e.key).toSet(), hasLength(terms.length));
    expect(
      terms.map((e) => e.domain).toSet(),
      containsAll(BilGlossaryDomain.values),
    );
  });
}
