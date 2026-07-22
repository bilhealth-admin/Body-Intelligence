import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard deep insights use deterministic containment', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(source, contains('DashboardInsightsSurface('));
    expect(
      source,
      isNot(
        contains(
          'child: ExpansionTile(\n'
          '            initiallyExpanded: false,\n'
          '            leading: const Icon(Icons.insights_outlined)',
        ),
      ),
    );
  });

  test('approved Arabic dashboard labels remain readable', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    for (final label in const <String>[
      'التحليلات والتقدم والأدلة',
      'السعرات',
      'البروتين',
      'الكربوهيدرات',
      'الدهون',
      'التقدم نحو الهدف',
      'أدلة العناصر المتاحة',
    ]) {
      expect(source, contains(label), reason: 'Missing Arabic label: $label');
    }
  });
}
