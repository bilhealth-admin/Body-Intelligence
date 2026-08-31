import 'dart:io';

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

  test('product aliases strip unknown and malformed query parameters', () {
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse(
          'bil:/daily-log?action=destroy&from=https%3A%2F%2Fevil.test&token=secret',
        ),
      ),
      '/daily-log',
    );
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse(
          'bil:/analytics/nutrition?tab=macros&redirect=https%3A%2F%2Fevil.test',
        ),
      ),
      '/analytics/nutrition?tab=macros',
    );
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse('bil:/settings/local-export?from=2026-02-30&to=2026-08-16'),
      ),
      '/settings/local-export?to=2026-08-16',
    );
  });

  test('every static app alias accepts a trailing slash', () {
    final source = File(
      'lib/features/notifications/domain/community_deep_link.dart',
    ).readAsStringSync();
    final start = source.indexOf('static const _appAliases');
    final end = source.indexOf('  };', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final entries = RegExp(
      r"'([^']+)':\s*'([^']+)'",
    ).allMatches(source.substring(start, end));
    expect(entries.length, greaterThan(30));
    for (final entry in entries) {
      final alias = entry.group(1)!;
      final route = entry.group(2)!;
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://$alias/')),
        route,
        reason: 'Trailing slash must preserve bil://$alias.',
      );
    }
  });

  test('community and settings routes accept a trailing slash', () {
    const expected = <String, String>{
      'community/': '/community',
      'community/connections/': '/community/connections',
      'community/people/': '/community/people',
      'community/messages/': '/community/messages',
      'community/messages/new/': '/community/messages/new',
      'community/safety/': '/community/safety',
      'settings/': '/settings',
      'settings/notifications/': '/notification-settings',
      'settings/ai-coach/': '/intelligence-center',
    };
    for (final entry in expected.entries) {
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://${entry.key}')),
        entry.value,
      );
    }
  });

  test('historical top-level aliases remain backward compatible', () {
    const expected = <String, String>{
      'more': '/settings',
      'weekly-digest': '/weekly-report',
      'recipes': '/wellness/recipes',
      'workouts': '/wellness/workouts',
      'fasting': '/wellness/fasting',
      'profile': '/profile-summary',
    };
    for (final entry in expected.entries) {
      for (final suffix in const ['', '/']) {
        expect(
          CommunityDeepLink.routeFor(Uri.parse('bil://${entry.key}$suffix')),
          entry.value,
          reason: 'Historical bil://${entry.key}$suffix must remain valid.',
        );
      }
    }
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
      CommunityDeepLink.routeFor(Uri.parse('bil://community/chat/not-a-uuid')),
      isNull,
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://settings/unknown')),
      isNull,
    );
  });
}
