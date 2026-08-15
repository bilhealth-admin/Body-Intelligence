import 'dart:io';

import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';

void main() {
  final file = File(
    'lib/features/notifications/domain/community_deep_link.dart',
  );
  final source = file.readAsStringSync();
  final start = source.indexOf('static const _appAliases');
  final end = source.indexOf('  };', start);
  if (start < 0 || end <= start) {
    stderr.writeln('DEEP_LINK_NORMALIZATION=FAIL alias map not found');
    exitCode = 1;
    return;
  }

  final entries = RegExp(
    r"'([^']+)':\s*'([^']+)'",
  ).allMatches(source.substring(start, end));
  final failures = <String>[];
  for (final entry in entries) {
    final alias = entry.group(1)!;
    final expected = entry.group(2)!;
    for (final uri in <Uri>[
      Uri.parse('bil://$alias'),
      Uri.parse('bil://$alias/'),
      Uri.parse('bil:/$alias'),
      Uri.parse('bil:/$alias/'),
    ]) {
      final actual = CommunityDeepLink.routeFor(uri);
      if (actual != expected) {
        failures.add('$uri expected=$expected actual=$actual');
      }
    }
  }

  const fixedRoutes = <String, String>{
    'community/': '/community',
    'community/connections/': '/community/connections',
    'community/people/': '/community/people',
    'community/messages/': '/community/messages',
    'community/messages/new/': '/community/messages/new',
    'community/safety/': '/community/safety',
    'settings/': '/settings',
    'settings/notifications/': '/notification-settings',
  };
  for (final entry in fixedRoutes.entries) {
    final actual = CommunityDeepLink.routeFor(Uri.parse('bil://${entry.key}'));
    if (actual != entry.value) {
      failures.add('bil://${entry.key} expected=${entry.value} actual=$actual');
    }
  }

  const rejected = <String>[
    'bil://unknown/path',
    'bil://community/admin',
    'bil://community/connections/unexpected',
    'bil://settings/unknown',
    'https://example.com/community',
  ];
  for (final value in rejected) {
    if (CommunityDeepLink.routeFor(Uri.parse(value)) != null) {
      failures.add('$value should be rejected');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('DEEP_LINK_NORMALIZATION=FAIL');
    for (final failure in failures) {
      stderr.writeln(failure);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('DEEP_LINK_NORMALIZATION=PASS');
  stdout.writeln('STATIC_ALIASES=${entries.length}');
  stdout.writeln('FORMS_PER_ALIAS=4');
  stdout.writeln('FIXED_TRAILING_ROUTES=${fixedRoutes.length}');
  stdout.writeln('REJECTED_INVALID=${rejected.length}');
}
