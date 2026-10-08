import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_settings_tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = CoachSettingsToolCatalog();

  test('local settings catalog is separate and validates unit writes', () {
    expect(CoachSettingsToolCatalog.toolNames, hasLength(4));
    expect(
      catalog.validate('set_unit_preference', {
        'dimension': 'weight',
        'value': 'Kilograms',
      }),
      isNotNull,
    );
    expect(
      catalog.validate('set_unit_preference', {
        'dimension': 'weight',
        'value': 'stone-ish',
      }),
      isNull,
    );
  });

  test('reminder schema rejects invalid time and unknown kind', () {
    expect(
      catalog.validate('set_reminder', {
        'kind': 'water',
        'enabled': true,
        'hour': 17,
        'minute': 30,
      }),
      isNotNull,
    );
    expect(
      catalog.validate('set_reminder', {
        'kind': 'water',
        'enabled': true,
        'hour': 25,
      }),
      isNull,
    );
  });

  test('export schema requires canonical range and allowlisted datasets', () {
    expect(
      catalog.validate('prepare_local_export', {
        'from': '2026-09-01',
        'to': '2026-09-30',
        'datasets': ['progress'],
      }),
      isNotNull,
    );
    expect(
      catalog.validate('prepare_local_export', {
        'from': '2026-10-02',
        'to': '2026-10-01',
      }),
      isNull,
    );
    expect(
      catalog.validate('prepare_local_export', {
        'datasets': ['private_everything'],
      }),
      isNull,
    );
  });
}
