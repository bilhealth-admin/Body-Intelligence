import 'dart:async';

import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/display_locale_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved locale syncs after an already-authenticated startup', () async {
    final settings = _MemorySettingsService(localeCode: 'pt-BR');
    final gateway = _FakeDisplayLocaleSyncGateway(initialOwnerId: 'owner-1');
    final controller = AppSettingsController(settings, gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);

    await controller.flushLocaleSyncForTesting();

    expect(gateway.syncedLocales, <String>['pt-BR']);
  });

  test(
    'locale selected before sign-in syncs when auth becomes ready',
    () async {
      final settings = _MemorySettingsService(localeCode: 'en');
      final gateway = _FakeDisplayLocaleSyncGateway();
      final controller = AppSettingsController(settings, gateway);
      addTearDown(controller.dispose);
      addTearDown(gateway.close);

      await controller.setLocale('zh_hant');
      await controller.flushLocaleSyncForTesting();
      expect(controller.state.localeCode, 'zh-Hant');
      expect(gateway.syncedLocales, isEmpty);

      gateway.signIn('owner-1');
      await controller.flushLocaleSyncForTesting();

      expect(gateway.syncedLocales, <String>['zh-Hant']);
    },
  );

  test('each authenticated locale change syncs canonical BCP-47', () async {
    final settings = _MemorySettingsService(localeCode: 'en');
    final gateway = _FakeDisplayLocaleSyncGateway(initialOwnerId: 'owner-1');
    final controller = AppSettingsController(settings, gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await controller.flushLocaleSyncForTesting();
    gateway.syncedLocales.clear();

    await controller.setLocale('PT_br');
    await controller.flushLocaleSyncForTesting();

    expect(controller.state.localeCode, 'pt-BR');
    expect(gateway.syncedLocales, <String>['pt-BR']);
  });

  test(
    'network failure never rolls back or fails local locale choice',
    () async {
      final settings = _MemorySettingsService(localeCode: 'en');
      final gateway = _FakeDisplayLocaleSyncGateway(
        initialOwnerId: 'owner-1',
        failSync: true,
      );
      final controller = AppSettingsController(settings, gateway);
      addTearDown(controller.dispose);
      addTearDown(gateway.close);
      await controller.flushLocaleSyncForTesting();

      await expectLater(controller.setLocale('uk'), completes);
      await expectLater(controller.flushLocaleSyncForTesting(), completes);

      expect(controller.state.localeCode, 'uk');
      expect((await settings.load()).localeCode, 'uk');
    },
  );

  test('same-owner auth event retries a transient failed sync', () async {
    final settings = _MemorySettingsService(localeCode: 'fr');
    final gateway = _FakeDisplayLocaleSyncGateway(
      initialOwnerId: 'owner-1',
      transientFailures: 1,
    );
    final controller = AppSettingsController(settings, gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);

    await controller.flushLocaleSyncForTesting();
    expect(gateway.syncedLocales, isEmpty);

    gateway.emitAuthEvent('owner-1');
    await controller.flushLocaleSyncForTesting();

    expect(gateway.syncedLocales, <String>['fr']);
  });

  test('unsupported locale is neither persisted nor synchronized', () async {
    final settings = _MemorySettingsService(localeCode: 'en');
    final gateway = _FakeDisplayLocaleSyncGateway(initialOwnerId: 'owner-1');
    final controller = AppSettingsController(settings, gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await controller.flushLocaleSyncForTesting();
    gateway.syncedLocales.clear();

    await controller.setLocale('pt');
    await controller.flushLocaleSyncForTesting();

    expect(controller.state.localeCode, 'en');
    expect(gateway.syncedLocales, isEmpty);
  });
}

final class _MemorySettingsService extends AppSettingsService {
  _MemorySettingsService({required String localeCode})
    : value = AppSettings(localeCode: localeCode, themeMode: 'light');

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }
}

final class _FakeDisplayLocaleSyncGateway implements DisplayLocaleSyncGateway {
  _FakeDisplayLocaleSyncGateway({
    this.initialOwnerId,
    this.failSync = false,
    this.transientFailures = 0,
  }) : _ownerId = initialOwnerId;

  final String? initialOwnerId;
  final bool failSync;
  int transientFailures;
  final StreamController<String?> _authChanges =
      StreamController<String?>.broadcast();
  final List<String> syncedLocales = <String>[];
  String? _ownerId;

  @override
  Stream<String?> watchSignedInUserId() async* {
    yield initialOwnerId;
    yield* _authChanges.stream;
  }

  @override
  Future<void> syncLocale(String localeTag) async {
    if (_ownerId == null) return;
    if (transientFailures > 0) {
      transientFailures -= 1;
      throw StateError('transient_offline');
    }
    if (failSync) throw StateError('offline');
    syncedLocales.add(localeTag);
  }

  void signIn(String ownerId) {
    emitAuthEvent(ownerId);
  }

  void emitAuthEvent(String ownerId) {
    _ownerId = ownerId;
    _authChanges.add(ownerId);
  }

  Future<void> close() => _authChanges.close();
}
