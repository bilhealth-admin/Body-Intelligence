import 'dart:io';

import 'package:body_intelligence_log/app/analytics/bil_launch_deep_link.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final routerSource = <String>[
    'lib/app/router/app_router.dart',
    'lib/app/router/app_wellness_routes.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
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

  test('every router path is runtime-linked or explicitly classified', () {
    const explicitlyUnlinked = <String, String>{
      '/context':
          'LifeContextPage is declared in the production router but has no '
          'current runtime literal entry point; keep it explicitly tracked.',
      '/meal-image-guide':
          'The released feature opens MealImageGuidePage through '
          'openMealImageGuide/Navigator instead of a GoRouter literal.',
      '/premium-logging-intro':
          'No current runtime literal entry point; keep this dormant route '
          'explicit until it is either wired or removed.',
      '/settings/account-connections/facebook':
          'No current runtime literal entry point; provider-specific settings '
          'remain an explicitly tracked dormant route.',
      '/settings/account-connections/google':
          'No current runtime literal entry point; provider-specific settings '
          'remain an explicitly tracked dormant route.',
      '/settings/account-password':
          'No current runtime literal entry point; password recovery uses its '
          'separate reset-password flow.',
      '/settings/analytics':
          'No current runtime literal entry point; released analytics '
          'navigation uses the analytics routes outside settings.',
    };

    final runtimeSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              !file.path.replaceAll('\\', '/').endsWith(
                'lib/app/router/app_router.dart',
              ) &&
              !file.path.replaceAll('\\', '/').endsWith(
                'lib/app/router/app_wellness_routes.dart',
              ),
        )
        .map((file) => file.readAsStringSync())
        .join('\n');

    bool isRuntimeLinked(String path) {
      if (runtimeSource.contains("'$path'") ||
          runtimeSource.contains('"$path"') ||
          runtimeSource.contains("'$path?") ||
          runtimeSource.contains('"$path?')) {
        return true;
      }
      final parameterIndex = path.indexOf('/:');
      if (parameterIndex < 0) return false;
      final prefix = path.substring(0, parameterIndex + 1);
      return runtimeSource.contains("'$prefix") ||
          runtimeSource.contains('"$prefix');
    }

    final unlinked = routerPaths.where((path) => !isRuntimeLinked(path)).toSet();

    expect(unlinked, explicitlyUnlinked.keys.toSet());
    for (final reason in explicitlyUnlinked.values) {
      expect(reason.trim(), isNotEmpty);
    }
    expect(runtimeSource, contains('openMealImageGuide'));
    expect(runtimeSource, contains('MealImageGuidePage'));
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
