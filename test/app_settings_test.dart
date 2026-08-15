import 'dart:io';

import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an existing saved locale is preserved during startup', () async {
    final service = _MemorySettingsService();
    final controller = AppSettingsController(service);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.localeCode, 'ar');
  });

  test('locale and theme changes are persisted by the controller', () async {
    final service = _MemorySettingsService();
    final controller = AppSettingsController(service);
    await Future<void>.delayed(Duration.zero);

    await controller.setLocale('en');
    await controller.setThemeMode('dark');
    await controller.setHighContrast(true);
    await controller.setReduceMotion(true);

    expect(controller.state.localeCode, 'en');
    expect(controller.state.themeMode, 'dark');
    expect((await service.load()).themeMode, 'dark');
    expect((await service.load()).highContrast, isTrue);
    expect((await service.load()).reduceMotion, isTrue);
  });

  test('system theme survives controller persistence and restart', () async {
    final service = _MemorySettingsService();
    final controller = AppSettingsController(service);
    await Future<void>.delayed(Duration.zero);

    await controller.setThemeMode('dark');
    await controller.setThemeMode('system');

    expect(controller.state.themeMode, 'system');
    expect((await service.load()).themeMode, 'system');
  });

  test('failed settings write retains the last persisted state', () async {
    final service = _MemorySettingsService();
    final controller = AppSettingsController(service);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.themeMode, 'system');

    service.failNextSave = true;
    await expectLater(controller.setThemeMode('dark'), throwsStateError);

    expect(controller.state.themeMode, 'system');
    expect((await service.load()).themeMode, 'system');
  });

  test('settings mutations are serialized after a failed write', () async {
    final service = _MemorySettingsService()..failNextSave = true;
    final controller = AppSettingsController(service);
    await Future<void>.delayed(Duration.zero);

    final failed = controller.setThemeMode('dark');
    final recovered = controller.setLocale('en');
    await expectLater(failed, throwsStateError);
    await recovered;

    expect(controller.state.themeMode, 'system');
    expect(controller.state.localeCode, 'en');
    expect((await service.load()).localeCode, 'en');
  });

  test('native settings store rejects a false persistence receipt', () {
    final source = File(
      'lib/app/services/settings_store_native.dart',
    ).readAsStringSync();
    expect(source, contains('final persisted = await'));
    expect(source, contains('if (!persisted)'));
    expect(
      source,
      contains("throw StateError('App settings were not persisted.')"),
    );
    expect(source, contains('if (!migrated)'));
  });
}

class _MemorySettingsService extends AppSettingsService {
  AppSettings value = AppSettings(localeCode: 'ar', themeMode: 'system');
  bool failNextSave = false;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('injected settings write failure');
    }
    value = settings;
  }
}
