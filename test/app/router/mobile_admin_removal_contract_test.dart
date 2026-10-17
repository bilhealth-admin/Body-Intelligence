import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile app has no hidden admin route', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final more = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    expect(router, isNot(contains("path: '/admin/ai-coach'")));
    expect(router, isNot(contains('ai_coach_admin_page.dart')));
    expect(more, isNot(contains("'/admin/ai-coach'")));
    expect(more, isNot(contains('aiCoachAdminAccessProvider')));
    expect(more, isNot(contains('settings-ai-coach-admin-entry')));
  });
}
