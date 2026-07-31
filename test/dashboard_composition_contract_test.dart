import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'DashboardPage delegates environment and composition responsibilities',
    () {
      final source = File(
        'lib/features/dashboard/dashboard_page.dart',
      ).readAsStringSync();

      expect(source, contains('DashboardShell('));
      expect(source, contains('DashboardComposition('));
      expect(source, isNot(contains('Stack(')));
      expect(source, isNot(contains('LayoutBuilder(')));
      expect(source, isNot(contains('SingleChildScrollView(')));
      expect(source, isNot(contains('class _DashboardTopBar')));
      expect(source, isNot(contains('class FirstValueHandoffCard')));
    },
  );
}
