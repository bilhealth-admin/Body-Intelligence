@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R5 aligns R3 contract with the approved larger tile geometry', () {
    final production = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final r3 = File(
      'test/home_intelligence/home_intelligence_r3_contract_test.dart',
    ).readAsStringSync();

    expect(
      production,
      contains('minHeight: compact ? 148 : (phone ? 190 : 172)'),
    );
    expect(r3, contains("contains('phone ? 190 : 172')"));
    expect(r3, isNot(contains("contains('phone ? 176 : 164')")));
  });

  test('R4 production repairs remain present', () {
    final production = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final engine = File(
      'lib/features/intelligence_center/services/intelligence_center_engine.dart',
    ).readAsStringSync();

    expect(
      production,
      contains(
        'childAspectRatio: phone ? 1.20 : layout.metricChildAspectRatio',
      ),
    );
    expect(engine, isNot(contains('local-bil-boundary')));
    expect(engine, isNot(contains('IntelligenceCenterReply _local(')));
  });
}
