import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps allowlisted community notification links to app routes', () {
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://community/connections')),
      '/community/connections',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://community/messages')),
      '/community/messages',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://community/messages/new')),
      '/community/messages/new',
    );
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse('bil://community/chat/8c2d80b2-266c-4a7c-820e-a36b4ef9ac28'),
      ),
      '/community/chat/8c2d80b2-266c-4a7c-820e-a36b4ef9ac28',
    );
  });

  test('maps product deep-link aliases to canonical router paths', () {
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://connected-health')),
      '/connected-health',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://connected-health/steps')),
      '/connected-health/steps',
    );
    expect(CommunityDeepLink.routeFor(Uri.parse('bil://goals')), '/goals');
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://settings/preferences')),
      '/settings/preferences',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://wellness/workouts/log')),
      '/wellness/workouts/log',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://trust-support')),
      '/trust-support',
    );
    expect(CommunityDeepLink.routeFor(Uri.parse('bil://help')), '/help');
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://help/faq')),
      '/help/faq',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://help/delete-account')),
      '/help/delete-account',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://legal/privacy')),
      '/legal/privacy',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://legal/terms')),
      '/legal/terms',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://legal/health-disclaimer')),
      '/legal/health-disclaimer',
    );

    const canonicalPaths = <String>[
      '/food-libraries',
      '/foods',
      '/advertising-privacy',
      '/notification-settings',
      '/intelligence-center',
      '/wellness/learn',
      '/wellness/sleep',
      '/settings/appearance',
      '/settings/diary',
      '/settings/diary/search-tab',
      '/settings/diary/sharing',
      '/settings/diary/meal-names',
      '/settings/sharing-privacy',
      '/settings/local-export',
      '/settings/nutrition-goals',
    ];
    for (final path in canonicalPaths) {
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil:/$path')),
        path,
        reason: 'The installed app must normalize bil:/$path to $path.',
      );
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://$path')),
        path,
        reason: 'The installed app must normalize bil://$path to $path.',
      );
    }
  });

  test('product aliases preserve action and return query parameters', () {
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse('bil:/daily-log?action=barcode&from=%2Fdashboard'),
      ),
      '/daily-log?action=barcode&from=%2Fdashboard',
    );
  });

  test('rejects external and unknown schemes', () {
    expect(
      CommunityDeepLink.routeFor(Uri.parse('https://example.com/community')),
      isNull,
    );
    expect(CommunityDeepLink.routeFor(Uri.parse('bil://unknown/path')), isNull);
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://community/admin')),
      isNull,
    );
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse('bil://community/connections/unexpected'),
      ),
      isNull,
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://settings/unknown')),
      isNull,
    );
  });
}
