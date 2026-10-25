import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Profile summary does not gate the whole page on secondary providers', () {
    final source = File(
      'lib/features/profile/profile_summary_page.dart',
    ).readAsStringSync();

    expect(source, contains('ProfilePrimaryLoadNotice('));
    expect(source, contains('profileAvatarStateProvider'));
    expect(source, contains('ownerId: avatar.owner'));
    expect(source, contains('bil-profile-details-retry'));
    expect(source, contains('profileFriendsCountProvider'));
    expect(source, contains('profileAuthIdentityProvider'));
    expect(source, contains('client.auth.currentUser?.id != owner'));
    expect(source, isNot(contains('body: const Center(child: CircularProgressIndicator())')));
    expect(source, isNot(contains('if ((profileState.isLoading && !profileState.hasValue) ||')));
    expect(source, isNot(contains('if (profileState.hasError ||\n        weightsState.hasError ||')));
  });

  test('My Plan preserves same-owner visible plan on transient read failure', () {
    final source = File(
      'lib/features/smart_plan/presentation/bil_smart_plan_page.dart',
    ).readAsStringSync();

    expect(source, contains('classifySmartPlanLoadFailure('));
    expect(source, contains('if (readPlan != null) _plan = readPlan;'));
    expect(source, contains('if (_plan != null) _catalogBlocked = true;'));
    expect(source, contains("failureCode == 'smart_plan_owner_mismatch'"));
    expect(source, contains('ref.read(preferencesRepositoryProvider).localOwnerId != owner'));
    expect(source, isNot(contains('_plan = null;\n        _busy = false;\n        _error = error.toString();')));
  });
}
