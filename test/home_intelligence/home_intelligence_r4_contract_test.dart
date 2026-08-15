@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R4 fixes the actual applied R3 summary geometry', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(
      summary,
      contains(
        'childAspectRatio: phone ? 1.20 : layout.metricChildAspectRatio',
      ),
    );
    expect(summary, contains('final columns = phone ? 2'));
    expect(summary, contains('maxLines: 2'));
    expect(summary, contains('softWrap: true'));
  });

  test('R4 removes the obsolete technical fallback completely', () {
    final engine = File(
      'lib/features/intelligence_center/services/intelligence_center_engine.dart',
    ).readAsStringSync();

    expect(engine, isNot(contains('local-bil-boundary')));
    expect(engine, isNot(contains('IntelligenceCenterReply _local(')));
    expect(engine, contains('IntelligenceCenterReply _plain('));
    expect(engine, contains('bool _isGreeting('));
    expect(engine, contains('bool _isPlanRequest('));
  });
}
