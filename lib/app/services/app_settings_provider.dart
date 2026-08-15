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
    _loaded = _load();
  }

  final AppSettingsService _service;
  late final Future<void> _loaded;
  Future<void> _mutationTail = Future<void>.value();

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> setLocale(String code) async {
    final canonical = BilLocalePolicy.canonicalSupportedTag(code);
    if (canonical == null) return;
    await _commit((current) => current.copyWith(localeCode: canonical));
  }

  Future<void> setThemeMode(String mode) async {
    if (!const {'system', 'light', 'dark'}.contains(mode)) return;
    await _commit((current) => current.copyWith(themeMode: mode));
  }

  Future<void> setHighContrast(bool enabled) async {
    await _commit((current) => current.copyWith(highContrast: enabled));
  }

  Future<void> setReduceMotion(bool enabled) async {
    await _commit((current) => current.copyWith(reduceMotion: enabled));
  }

  Future<void> _commit(AppSettings Function(AppSettings) update) {
    final operation = _mutationTail.then((_) async {
      await _loaded;
      final candidate = update(state);
      await _service.save(candidate);
      state = candidate;
    });
    _mutationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}
