import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'app_settings_service.dart';
import '../localization/bil_locale_policy.dart';
import 'display_locale_sync_service.dart';

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
      return AppSettingsController(
        ref.watch(appSettingsServiceProvider),
        ref.watch(displayLocaleSyncGatewayProvider),
      );
    });

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(
    this._service, [
    DisplayLocaleSyncGateway localeSyncGateway =
        const NoopDisplayLocaleSyncGateway(),
  ]) : _localeSyncGateway = localeSyncGateway,
       super(
         AppSettings(
           localeCode: AppSettingsService.systemLocaleCode(),
           themeMode: 'light',
         ),
       ) {
    _loaded = _load();
    _authSubscription = _localeSyncGateway.watchSignedInUserId().listen((
      ownerId,
    ) {
      if (ownerId != null) unawaited(_syncCurrentLocaleAfterLoad());
    });
  }

  final AppSettingsService _service;
  final DisplayLocaleSyncGateway _localeSyncGateway;
  late final Future<void> _loaded;
  late final StreamSubscription<String?> _authSubscription;
  Future<void> _mutationTail = Future<void>.value();
  Future<void> _localeSyncTail = Future<void>.value();
  bool _disposed = false;

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> setLocale(String code) async {
    final canonical = BilLocalePolicy.canonicalSupportedTag(code);
    if (canonical == null) return;
    await _commit((current) => current.copyWith(localeCode: canonical));
    _queueLocaleSync(canonical);
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

  Future<void> _syncCurrentLocaleAfterLoad() async {
    await _loaded;
    if (_disposed) return;
    _queueLocaleSync(state.localeCode);
  }

  void _queueLocaleSync(String localeTag) {
    _localeSyncTail = _localeSyncTail.then((_) async {
      if (_disposed) return;
      try {
        await _localeSyncGateway.syncLocale(localeTag);
      } catch (_) {
        // Display-language sync is best effort and must never block local
        // settings, sign-in, or offline app use. The next auth/locale event
        // retries the current value.
      }
    });
  }

  /// Lets focused tests wait for the best-effort queue without exposing
  /// network completion to product UI.
  Future<void> flushLocaleSyncForTesting() async {
    await _loaded;
    await Future<void>.delayed(Duration.zero);
    await _localeSyncTail;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
