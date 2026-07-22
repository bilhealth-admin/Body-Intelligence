import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard exposes explicit priority hierarchy', () {
    final page = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    final frame = File(
      'lib/features/dashboard/widgets/dashboard_experience_frame.dart',
    ).readAsStringSync();

    expect(page, contains('DashboardExperienceFrame('));
    expect(frame, contains("key: const Key('dashboard-priority-heading')"));
    expect(frame, contains('Today priorities followed by supporting detail'));
    expect(frame, contains('Your day, in priority order'));
  });
}
