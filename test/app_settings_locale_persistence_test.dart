import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

class MemorySettingsStore implements SettingsStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  test('all 25 locale tags persist across service restart', () async {
    final store = MemorySettingsStore();
    for (final tag in AppSettingsService.supportedLocaleCodes) {
      final first = AppSettingsService(store: store);
      await first.save(AppSettings(localeCode: tag, themeMode: 'light'));
      final restarted = AppSettingsService(store: store);
      expect((await restarted.load()).localeCode, tag);
    }
    expect(AppSettingsService.supportedLocaleCodes.length, 25);
  });
}
