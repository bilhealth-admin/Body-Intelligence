import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin mutations cannot wait forever on integrity or Edge transport', () {
    final aiCoach = File(
      'lib/features/admin/services/ai_coach_admin_service.dart',
    ).readAsStringSync();
    final moderator = File(
      'lib/features/admin/services/community_moderator_admin_service.dart',
    ).readAsStringSync();
    final members = File(
      'lib/features/admin/services/community_member_access_admin_service.dart',
    ).readAsStringSync();

    expect(RegExp(r'\.protect\(').allMatches(aiCoach), hasLength(3));
    expect(
      RegExp(r'\.timeout\(const Duration\(seconds: 12\)\)').allMatches(aiCoach),
      hasLength(3),
    );
    expect(
      RegExp(r'\.timeout\(const Duration\(seconds: 20\)\)').allMatches(aiCoach),
      hasLength(3),
    );
    for (final source in [moderator, members]) {
      expect(source, contains('.protect('));
      expect(source, contains('.timeout(const Duration(seconds: 12))'));
      expect(source, contains('.timeout(const Duration(seconds: 20))'));
    }
  });

  test('the deployed contract is explicit about the shared admin function', () {
    final source = File(
      'lib/features/admin/services/ai_coach_admin_service.dart',
    ).readAsStringSync();
    expect(source, contains("invoke('ai-coach-global-reset'"));
  });
}
