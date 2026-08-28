import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/notifications/presentation/notification_settings_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String notificationSettingsSource() => [
    'lib/features/notifications/presentation/notification_settings_page.dart',
    'lib/features/notifications/presentation/notification_settings_actions.dart',
    'lib/features/notifications/presentation/notification_settings_components.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');

  test('notification core copy resolves across all 25 production locales', () {
    expect(RuntimeCopy.supported, hasLength(25));
    final english = NotificationSettingsCopy.forLanguage('en');
    for (final locale in RuntimeCopy.supported) {
      final copy = NotificationSettingsCopy.forLanguage(locale);
      expect(copy.title.trim(), isNotEmpty, reason: locale);
      expect(copy.intro.trim(), isNotEmpty, reason: locale);
      expect(copy.permissionError.trim(), isNotEmpty, reason: locale);
      expect(
        copy.labels.values.every((value) => value.trim().isNotEmpty),
        isTrue,
      );
      if (ExtendedRuntimeCopy.supported.contains(locale)) {
        expect(
          copy.title,
          isNot(english.title),
          reason: 'title fallback $locale',
        );
      }
    }
  });

  test('every extended _ui surface has direct generated copy', () {
    final source = notificationSettingsSource();
    final keys = RegExp(
      r"_ui\(\s*'([^']+)'",
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)!).toSet();
    expect(keys, isNotEmpty);
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = ExtendedRuntimeCopy.values[key]?[locale]?.trim();
        expect(value, isNotNull, reason: 'missing $locale/$key');
        expect(value, isNotEmpty, reason: 'blank $locale/$key');
        expect(value, isNot(key), reason: 'English fallback $locale/$key');
      }
    }
  });

  test('loading, mutation and Supabase boundaries fail closed', () {
    final source = notificationSettingsSource();
    expect(source, contains('AppEnvironment.supabaseRuntimeReady'));
    expect(source, contains('canPop: !busy'));
    expect(source, contains("key: const Key('add-reminder')"));
    expect(source, contains('reminders == null || busy ? null'));
    expect(source, contains('_loadError != null'));
    expect(source, contains('onPressed: _load'));
    expect(source, contains('enabled: !_saving'));
  });
}
