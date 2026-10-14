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
    final ownerOperation = File(
      'lib/features/admin/services/admin_owner_operation.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'AdminOwnerOperation\.invoke\(').allMatches(aiCoach),
      hasLength(3),
    );
    expect(
      RegExp(
        r'\.timeout\(const Duration\(seconds: 12\)\)',
      ).allMatches(ownerOperation),
      hasLength(1),
    );
    expect(
      RegExp(
        r'\.timeout\(const Duration\(seconds: 20\)\)',
      ).allMatches(ownerOperation),
      hasLength(1),
    );
    expect(
      ownerOperation,
      contains('BilMobileIntegrityService.instance.protect('),
    );
    expect(ownerOperation, contains('client.auth.currentUser?.id != owner'));
    for (final source in [moderator, members]) {
      expect(source, contains('AdminOwnerOperation.invoke('));
    }
  });

  test('the deployed contract is explicit about the shared admin function', () {
    final source = File(
      'lib/features/admin/services/admin_owner_operation.dart',
    ).readAsStringSync();
    expect(source, contains("'ai-coach-global-reset'"));
  });
}
