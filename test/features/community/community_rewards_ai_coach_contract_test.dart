import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach exposes BIL Gold and Earn without owning reward authority', () {
    final page = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/features/intelligence_center/presentation/intelligence_coach_reference_header.dart',
    ).readAsStringSync();
    expect(page, contains("part 'intelligence_coach_reference_header.dart';"));
    final action = File(
      'lib/features/community/presentation/community_gold_balance_action.dart',
    ).readAsStringSync();
    final rewards = File(
      'lib/features/community/presentation/community_rewards_page.dart',
    ).readAsStringSync();

    expect(page, contains('community_gold_balance_action.dart'));
    expect(widgets, contains('CommunityGoldBalanceAction'));
    expect(action, contains("context.push('/community/rewards')"));
    expect(action, contains('loadGoldBalance'));
    expect(rewards, contains('claimCommunityQuest'));
    expect(rewards, isNot(contains('bil_post_gold_ledger_v1')));
    expect(rewards, isNot(contains("from('bil_gold_accounts')")));
    expect(action, isNot(contains('bil_post_gold_ledger_v1')));
  });
}
