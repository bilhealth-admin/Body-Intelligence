import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const roots = [
    'lib/features/life_context',
    'lib/features/share_studio',
    'lib/features/notifications',
    'lib/features/challenges',
    'lib/features/commerce',
  ];

  test(
    'small feature surfaces contain no binary locale branches or mojibake',
    () {
      final source = roots
          .expand((root) => Directory(root).listSync(recursive: true))
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.contains('services'))
          .where((file) => !file.path.contains('repositories'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      for (final marker in const [
        'arabic ?',
        '_arabic ?',
        'isArabic ?',
        'error.toString()',
        'Ã',
        'Â',
        'Ø',
        'Ù',
        'â€™',
      ]) {
        expect(source, isNot(contains(marker)), reason: marker);
      }
    },
  );

  test('runtime copy remains balanced across five release locales', () {
    expect(RuntimeCopy.balanced, isTrue);
    final sources = [
      'lib/features/life_context/life_context_page.dart',
      'lib/features/life_context/decision_memory_page.dart',
      'lib/features/share_studio/share_studio_page.dart',
      'lib/features/challenges/challenges_page.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final keys = RegExp(
      r"(?:\bt|\.text|\btr)\(\s*(?:context,\s*)?'([^']+)'",
    ).allMatches(sources).map((match) => match.group(1)!).toSet();
    for (final key in keys) {
      for (final locale in const ['ar', 'fr', 'es', 'tr']) {
        expect(
          RuntimeCopy.resolve(key, locale),
          isNotNull,
          reason: '$locale:$key',
        );
      }
    }
  });

  test('notifications and store plans declare all release locales', () {
    final notificationCopy = File(
      'lib/features/notifications/presentation/notification_settings_copy.dart',
    ).readAsStringSync();
    final storeCopy = File(
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
    ).readAsStringSync();
    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(notificationCopy, contains("'$locale':"));
      if (locale != 'ar' && locale != 'en') {
        expect(storeCopy, contains("'$locale':"));
      }
    }
  });
}
