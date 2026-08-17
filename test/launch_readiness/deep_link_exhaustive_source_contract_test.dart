import 'dart:io';

import 'package:body_intelligence_log/app/analytics/bil_launch_deep_link.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final routerSource = File(
    'lib/app/router/app_router.dart',
  ).readAsStringSync();
  final linkSource = File(
    'lib/features/notifications/domain/community_deep_link.dart',
  ).readAsStringSync();

  final routerPaths = RegExp(
    r"GoRoute\(\s*path:\s*'([^']+)'",
    multiLine: true,
  ).allMatches(routerSource).map((match) => match.group(1)!).toSet();
  final aliasBlockStart = linkSource.indexOf('static const _appAliases');
  final aliasBlockEnd = linkSource.indexOf('  };', aliasBlockStart);
  final aliases = <String, String>{
    for (final match in RegExp(
      r"'([^']+)':\s*'([^']+)'",
    ).allMatches(linkSource.substring(aliasBlockStart, aliasBlockEnd)))
      match.group(1)!: match.group(2)!,
  };

  test('all declared router paths are unique and exhaustively discovered', () {
    final declarations = RegExp(
      r"GoRoute\(\s*path:\s*'([^']+)'",
      multiLine: true,
    ).allMatches(routerSource).map((match) => match.group(1)!).toList();
    expect(declarations.length, greaterThanOrEqualTo(80));
    expect(routerPaths.length, declarations.length);
  });

  test('every external alias resolves to a real production route', () {
    expect(aliases.length, greaterThanOrEqualTo(50));
    for (final entry in aliases.entries) {
      expect(
        routerPaths.contains(entry.value),
        isTrue,
        reason: '${entry.key} points to missing ${entry.value}',
      );
    }
  });

  test('cold and warm parsers agree for every alias and URI form', () {
    for (final entry in aliases.entries) {
      for (final uri in <Uri>[
        Uri.parse('bil://${entry.key}'),
        Uri.parse('bil://${entry.key}/'),
        Uri.parse('bil:/${entry.key}'),
        Uri.parse('https://bilhealth.com/${entry.key}'),
      ]) {
        final cold = uri.scheme == 'bil'
            ? CommunityDeepLink.routeFor(uri)
            : entry.value;
        final warm = BilLaunchDeepLink.parse(uri)?.route;
        expect(cold, entry.value, reason: 'cold $uri');
        expect(warm, entry.value, reason: 'warm $uri');
      }
    }
  });

  test('emitted community push links are accepted by both parsers', () {
    final migration = File(
      'supabase/migrations/202608040002_bil_community_cloud_completion.sql',
    ).readAsStringSync();
    expect(migration, contains("'bil://community/connections'"));
    expect(migration, contains("'bil://community/chat/' || new.sender_id"));

    const recipient = '8c2d80b2-266c-4a7c-820e-a36b4ef9ac28';
    for (final raw in <String>[
      'bil://community/connections',
      'bil://community/chat/$recipient',
    ]) {
      final uri = Uri.parse(raw);
      expect(CommunityDeepLink.routeFor(uri), isNotNull);
      expect(BilLaunchDeepLink.parse(uri)?.route, isNotNull);
    }
  });

  test('malformed parameters and open redirects fail closed', () {
    expect(
      BilLaunchDeepLink.parse(
        Uri.parse(
          'bil://daily-log?action=delete-all&from=https%3A%2F%2Fevil.test&token=secret',
        ),
      )?.route,
      '/daily-log',
    );
    expect(
      BilLaunchDeepLink.parse(Uri.parse('bil://community/chat/not-a-uuid')),
      isNull,
    );
    expect(
      BilLaunchDeepLink.parse(Uri.parse('https://evil.test/dashboard')),
      isNull,
    );
  });
}
