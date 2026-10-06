import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'social routes require identity while private Drafts stays independent',
    () {
      final source = File(
        'lib/app/router/app_community_routes.dart',
      ).readAsStringSync();
      final blocks = source.split('GoRoute(');
      for (final path in [
        '/community',
        '/community/people',
        '/community/code',
        '/community/code/scan',
        '/community/member/:code',
        '/community/notifications',
        '/community/drafts',
        '/community/rewards',
        '/community/connections',
        '/community/food-review',
        '/community/profile/:userId',
        '/community/chat/:userId',
        '/community/messages',
        '/community/messages/new',
      ]) {
        final route = blocks.singleWhere((b) => b.contains("path: '$path',"));
        expect(
          route,
          path == '/community/drafts'
              ? isNot(contains('CommunityEntryGate('))
              : contains('CommunityEntryGate('),
          reason: path == '/community/drafts'
              ? 'Private saved work cannot require a public identity'
              : path,
        );
        expect(
          route,
          contains('PremiumRouteGlassGate('),
          reason: 'existing entitlement: $path',
        );
      }
      final root = blocks.singleWhere((b) => b.contains("path: '/community',"));
      expect(root, contains('showWelcome: true'));
      expect(root, contains('entryWelcomeHandled: true'));
      for (final path in [
        '/community/moderation',
        '/community/invite/:token',
        '/community/safety',
        '/community/profile',
      ]) {
        final route = blocks.singleWhere((b) => b.contains("path: '$path',"));
        expect(
          route,
          isNot(contains('CommunityEntryGate(')),
          reason: 'recovery/policy/moderation: $path',
        );
      }
      final moderator = blocks.singleWhere(
        (b) => b.contains("path: '/community/moderation',"),
      );
      expect(moderator, isNot(contains('PremiumRouteGlassGate(')));
    },
  );

  test('Drafts is a direct private destination distinct from Saved posts', () {
    final routes = File(
      'lib/app/router/app_community_routes.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/features/community/presentation/community_navigation_sheet.dart',
    ).readAsStringSync();
    final drafts = File(
      'lib/features/community/presentation/community_member_profile_drafts.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/community/presentation/community_member_profile_page.dart',
    ).readAsStringSync();

    expect(routes, contains("path: '/community/drafts'"));
    expect(
      routes,
      contains('child: CommunitySurface(child: CommunityDraftsPage())'),
    );
    expect(navigation, contains("'/community/drafts'"));
    expect(navigation, contains("'Saved posts'"));
    expect(navigation, contains("'Drafts'"));
    expect(
      navigation.indexOf("'/community/drafts'"),
      isNot(navigation.indexOf("'saved'")),
    );
    expect(
      drafts,
      contains('class CommunityDraftsPage extends StatefulWidget'),
    );
    // The bounded50-item Profile badge projection remains here; the direct
    // Drafts destination now pages20 at a time beyond the first50 entries.
    expect(profile, contains('listMyCommunityDrafts(limit: 50)'));
    expect(drafts, contains('static const _pageSize = 20;'));
    expect(drafts, contains('listMyCommunityDrafts(limit: _pageSize)'));
    expect(drafts, contains('before: before,'));
    expect(drafts, contains('beforeId: beforeId,'));
    expect(drafts, contains('limit: _pageSize,'));
    expect(drafts, contains('loadMyCommunityDraft(draftId)'));
    expect(drafts, contains('_CommunityComposerDraft.fromPersistent('));
    expect(
      drafts.substring(
        drafts.indexOf('class CommunityDraftsPage extends StatefulWidget'),
        drafts.indexOf('class _CommunityDraftsSheet extends StatefulWidget'),
      ),
      isNot(contains('loadProfileOverview')),
    );
  });
}
