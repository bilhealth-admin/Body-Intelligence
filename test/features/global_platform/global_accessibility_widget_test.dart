import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/globalization/global_product_accessibility.dart';

void main() {
  testWidgets(
    'product status exposes semantics touch target text scaling and RTL',
    (tester) async {
      var hit = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: BilAccessibleStatus(
                label: 'المزامنة',
                detail: 'مكتملة',
                status: 'جاهز',
                onActivate: () => hit = true,
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(BilAccessibleStatus)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byType(InkWell));
      expect(hit, isTrue);
      final semantics = tester.getSemantics(find.byType(BilAccessibleStatus));
      expect(semantics.label, contains('المزامنة'));
    },
  );
}
