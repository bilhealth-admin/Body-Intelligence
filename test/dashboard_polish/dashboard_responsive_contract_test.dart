import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard responsive metric surfaces reserve safe vertical space', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(source, contains('? 104.0'));
    expect(source, contains('? 226.0'));
    expect(source, contains(': 306.0'));
    expect(source, contains('childAspectRatio: wideScreen ? 1.35 : 1.65'));
    expect(source, contains('height: fixedDesktopGrid ? 216 : 196'));
    expect(source, contains('childAspectRatio: .88'));
    expect(source, contains('minHeight: compact ? 92 : 84'));
    expect(source, contains('minHeight: compact ? 64 : 96'));
    expect(source, contains('maxLines: 2'));
  });

  test('responsive package stays inside dashboard presentation', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('class TruthEngine')));
    expect(source, isNot(contains('class DecisionEngine')));
    expect(source, isNot(contains('SupabaseClient')));
  });
}
