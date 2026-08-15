@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all stale dashboard contracts match the approved production design',
    () {
      final production = File(
        'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
      ).readAsStringSync();
      final r1 = File(
        'test/home_intelligence/home_intelligence_r1_contract_test.dart',
      ).readAsStringSync();
      final review = File(
        'test/product_owner_review_closure_contract_test.dart',
      ).readAsStringSync();
      final visual = File(
        'test/product_owner_visual_review_r6_contract_test.dart',
      ).readAsStringSync();

      expect(
        production,
        contains(
          'childAspectRatio: phone ? 1.20 : layout.metricChildAspectRatio',
        ),
      );
      expect(
        production,
        contains('minHeight: compact ? 148 : (phone ? 190 : 172)'),
      );
      expect(production, contains('TextOverflow.fade'));
      expect(production, contains('softWrap: true'));

      expect(r1, contains('phone ? 1.20'));
      expect(visual, contains('phone ? 1.20'));
      expect(visual, contains('phone ? 190 : 172'));
      expect(review, contains("contains('TextOverflow.fade')"));
      expect(review, contains("contains('softWrap: true')"));

      expect(r1, isNot(contains('phone ? 1.05')));
      expect(visual, isNot(contains('phone ? 1.05')));
      expect(review, isNot(contains("contains('TextOverflow.ellipsis')")));
    },
  );
}
