import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'app_settings_service.dart';

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
      return AppSettingsController(ref.watch(appSettingsServiceProvider));
    });

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(this._service)
    : super(AppSettings(localeCode: 'en', themeMode: 'system')) {
    _load();
  }

  final AppSettingsService _service;

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> setLocale(String code) async {
    if (!const {'ar', 'en'}.contains(code)) return;
    state = state.copyWith(localeCode: code);
    await _service.save(state);
  }

  Future<void> setThemeMode(String mode) async {
    if (!const {'light', 'dark', 'system'}.contains(mode)) return;
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
