import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('locale and theme changes are persisted by the controller', () async {
    final service = _MemorySettingsService();
    final controller = AppSettingsController(service);
    await Future<void>.delayed(Duration.zero);

    await controller.setLocale('en');
    await controller.setThemeMode('dark');

    expect(controller.state.localeCode, 'en');
    expect(controller.state.themeMode, 'dark');
    expect((await service.load()).themeMode, 'dark');
  });
}

class _MemorySettingsService extends AppSettingsService {
  AppSettings value = AppSettings(localeCode: 'ar', themeMode: 'system');

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }
}
