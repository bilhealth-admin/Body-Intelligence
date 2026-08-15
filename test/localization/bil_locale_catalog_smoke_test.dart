import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/bil_reviewed_locale_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('draft terms render in narrow LTR and RTL cards', (tester) async {
    var rendered = 0;
    for (final catalog in BilDraftLocaleCatalogs.all) {
      final direction = BilLocalePolicy.isRtlTag(catalog.localeTag)
          ? TextDirection.rtl
          : TextDirection.ltr;
      for (final value in catalog.values.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: Center(
                  child: SizedBox(width: 240, child: Text(value, maxLines: 3)),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: catalog.localeTag);
        rendered++;
      }
    }
    expect(rendered, 260);
  });

  test('smoke execution cannot promote a locale', () {
    expect(
      BilDraftLocaleCatalogs.all.every(
        (catalog) => !catalog.eligibleForProduction,
      ),
      isTrue,
    );
  });
}
