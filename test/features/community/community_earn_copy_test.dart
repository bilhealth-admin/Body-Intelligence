import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_ai_reward.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AI reward copy covers every release locale without English fallback',
    () {
      expect(
        CommunityAiRewardRuntimeCopy.rows.keys.toSet(),
        BilLocalePolicy.productionTags.toSet(),
      );
      for (final tag in BilLocalePolicy.productionTags) {
        final row = CommunityAiRewardRuntimeCopy.rows[tag]!;
        expect(row.length, CommunityAiRewardRuntimeCopy.sources.length);
        for (var i = 0; i < row.length; i++) {
          expect(row[i].trim(), isNotEmpty);
          expect(
            communityTextForLanguage(
              tag,
              CommunityAiRewardRuntimeCopy.sources[i],
              'unused',
            ),
            row[i],
          );
          if (tag != 'en') {
            expect(row[i], isNot(CommunityAiRewardRuntimeCopy.sources[i]));
          }
        }
        expect(row.last, contains('+5'));
        expect(row.last, contains('BIL Gold'));
      }
    },
  );

  test(
    'Earn route retains existing gates and passes only a presentation hint',
    () {
      final routes = File(
        'lib/app/router/app_community_routes.dart',
      ).readAsStringSync();
      final route = routes
          .split('GoRoute(')
          .singleWhere((part) => part.contains("path: '/community/compose',"));
      expect(route, contains('PremiumRouteGlassGate('));
      expect(route, contains('CommunityEntryGate('));
      expect(route, contains('CommunityComposePage('));
      expect(route, contains("state.uri.queryParameters['origin'] == 'earn'"));
      final entry = File(
        'lib/features/community/presentation/community_compose_entry_page.dart',
      ).readAsStringSync();
      expect(entry, contains('final _draft = _CommunityComposerDraft();'));
      expect(entry, contains('return _CommunityPostComposerPage('));
      expect(entry, isNot(contains('publishRichPost(')));
      expect(entry, isNot(contains('claimCommunityQuest(')));
      expect(entry, isNot(contains('acceptCommunityPolicy(')));
      expect(entry, isNot(contains('createMyCommunityEntryProfile(')));
    },
  );
}
