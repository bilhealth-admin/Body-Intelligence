import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'app_settings_service.dart';
import '../localization/bil_locale_policy.dart';

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
      return AppSettingsController(ref.watch(appSettingsServiceProvider));
    });

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(this._service)
    : super(
        AppSettings(
          localeCode: AppSettingsService.systemLocaleCode(),
          themeMode: 'light',
        ),
      ) {
    _load();
  }

  final AppSettingsService _service;

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> setLocale(String code) async {
    final canonical = BilLocalePolicy.canonicalSupportedTag(code);
    if (canonical == null) return;
    state = state.copyWith(localeCode: canonical);
    await _service.save(state);
  }

  Future<void> setThemeMode(String mode) async {
    if (!const {'system', 'light', 'dark'}.contains(mode)) return;
    state = state.copyWith(themeMode: mode);
    await _service.save(state);
  }

  Future<void> setHighContrast(bool enabled) async {
    state = state.copyWith(highContrast: enabled);
    await _service.save(state);
  }

  Future<void> setReduceMotion(bool enabled) async {
    state = state.copyWith(reduceMotion: enabled);
    await _service.save(state);
  }
}
