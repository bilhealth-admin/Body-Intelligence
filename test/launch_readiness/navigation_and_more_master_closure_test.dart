import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every literal go or push destination is registered', () {
    final routeSources = Directory('lib/app/router')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final registered = RegExp(
      r'''path:\s*['"]([^'"]+)['"]''',
    ).allMatches(routeSources).map((match) => match.group(1)!).toSet();

    final missing = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'''context\.(?:go|push)\(\s*['"]([^'"]+)['"]''',
      ).allMatches(source)) {
        final raw = match.group(1)!;
        if (raw.contains(r'$')) continue;
        final path = raw.split('?').first;
        if (!registered.contains(path)) missing.add('${file.path}: $raw');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('priority white-screen routes have concrete builders', () {
    final router = Directory('lib/app/router')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    for (final route in <String>[
      '/dashboard',
      '/daily-log',
      '/daily-log/body-context',
      '/quick-add/meal-camera',
      '/connected-health',
      '/settings',
      '/health-information-sources',
      '/analytics',
      '/profile-summary',
      '/plans',
      '/login',
      '/community',
      '/intelligence-center',
    ]) {
      expect(router, contains("path: '$route'"), reason: route);
    }
    expect(
      router,
      isNot(contains('builder: (_, _) => const SizedBox.shrink()')),
    );
    expect(router, isNot(contains('builder: (_, _) => Container()')));
  });

  test('More keeps routes, authority gates, RTL and sync boundaries', () {
    final source = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    for (final route in <String>[
      '/profile-summary',
      '/plans',
      '/connected-health',
      '/settings/language',
      '/goals',
      '/history',
      '/weekly-report',
      '/analytics/nutrition',
      '/intelligence-center',
      '/settings/ai-coach',
      '/community',
      '/settings/preferences',
      '/notification-settings',
      '/settings/sharing-privacy',
      '/health-information-sources',
      '/help',
      '/admin/ai-coach',
    ]) {
      expect(source, contains(route), reason: route);
    }
    expect(source, contains('aiCoachAdminAccessProvider'));
    expect(source, contains('cloudManualSyncStatusProvider'));
    expect(source, contains('connectedHealthProvider'));
    expect(source, contains("context.push('/connected-health')"));
    expect(source, contains('Directionality.of(context) == TextDirection.rtl'));
    expect(source, contains("Key('more-devices-sync-card')"));
    expect(source, contains('PremiumCrownEmblem'));
  });
}
