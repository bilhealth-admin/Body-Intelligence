import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BIL-03 app settings verified persistence', () {
    test('ordinary save is independently read back and revisioned', () async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);

      await service.save(AppSettings(localeCode: 'ar', themeMode: 'dark'));

      final stored = await service.readCommitted();
      expect(stored.localeCode, 'ar');
      expect(stored.themeMode, 'dark');
      expect(stored.revision, 1);
      expect(store.readCount, greaterThanOrEqualTo(2));
    });

    test('readback failure is not converted into a successful save', () async {
      final store = _MemorySettingsStore(failReadCalls: {2});
      final service = AppSettingsService(store: store);

      await expectLater(
        service.saveVerified(AppSettings(localeCode: 'en', themeMode: 'dark')),
        throwsStateError,
      );
    });

    test('write failure never changes durable settings', () async {
      final store = _MemorySettingsStore(failWrites: true);
      final service = AppSettingsService(store: store);

      await expectLater(
        service.saveVerified(AppSettings(localeCode: 'ar', themeMode: 'dark')),
        throwsStateError,
      );
      store.failWrites = false;
      final stored = await service.readCommitted();
      expect(stored.localeCode, 'en');
      expect(stored.themeMode, 'light');
      expect(stored.revision, 0);
    });
  });

  group('BIL-03 durable Coach setting journal', () {
    test(
      'operation survives service reopen and Undo verifies readback',
      () async {
        final store = _MemorySettingsStore();
        final first = AppSettingsService(store: store);
        final operation = await first.commitCoachSetting(
          operationId: 'bil03-theme-reopen',
          field: 'themeMode',
          value: 'dark',
        );
        expect(operation.beforeValue, 'light');
        expect(operation.afterValue, 'dark');

        final reopened = AppSettingsService(store: store);
        final restored = await reopened.readCoachSettingOperation(
          'bil03-theme-reopen',
        );
        expect(restored, isNotNull);
        expect(restored!.canUndo, isTrue);

        final undone = await reopened.undoCoachSetting(
          operationId: 'bil03-theme-reopen',
        );
        expect(undone.canUndo, isFalse);
        final readback = await reopened.readCommitted();
        expect(readback.themeMode, 'light');
        expect(readback.revision, operation.afterRevision + 1);
      },
    );

    test('newer Settings edit blocks stale Coach Undo', () async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await service.commitCoachSetting(
        operationId: 'bil03-theme-newer',
        field: 'themeMode',
        value: 'dark',
      );
      final current = await service.readCommitted();
      await service.saveVerified(current.copyWith(themeMode: 'light'));

      await expectLater(
        service.undoCoachSetting(operationId: 'bil03-theme-newer'),
        throwsA(
          isA<AppSettingsOperationConflict>().having(
            (error) => error.reason,
            'reason',
            'newer_setting_change',
          ),
        ),
      );
      expect((await service.readCommitted()).themeMode, 'light');
    });

    test('A to B to A still blocks old Undo by revision', () async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await service.commitCoachSetting(
        operationId: 'bil03-theme-aba',
        field: 'themeMode',
        value: 'dark',
      );
      var current = await service.readCommitted();
      await service.saveVerified(current.copyWith(themeMode: 'light'));
      current = await service.readCommitted();
      await service.saveVerified(current.copyWith(themeMode: 'dark'));
      expect((await service.readCommitted()).themeMode, 'dark');

      await expectLater(
        service.undoCoachSetting(operationId: 'bil03-theme-aba'),
        throwsA(
          isA<AppSettingsOperationConflict>().having(
            (error) => error.reason,
            'reason',
            'newer_setting_change',
          ),
        ),
      );
      expect((await service.readCommitted()).themeMode, 'dark');
    });

    test(
      'unrelated newer setting revision conservatively blocks Undo',
      () async {
        final store = _MemorySettingsStore();
        final service = AppSettingsService(store: store);
        await service.commitCoachSetting(
          operationId: 'bil03-locale-newer',
          field: 'localeCode',
          value: 'ar',
        );
        final current = await service.readCommitted();
        await service.saveVerified(current.copyWith(highContrast: true));

        await expectLater(
          service.undoCoachSetting(operationId: 'bil03-locale-newer'),
          throwsA(isA<AppSettingsOperationConflict>()),
        );
        expect((await service.readCommitted()).localeCode, 'ar');
      },
    );

    test(
      'write permission revoked after Coach commit write rolls back exact snapshot',
      () async {
        final store = _MemorySettingsStore();
        final service = AppSettingsService(store: store);
        var checks = 0;

        await expectLater(
          service.commitCoachSetting(
            operationId: 'bil03-theme-confirm-race',
            field: 'themeMode',
            value: 'dark',
            checkWritePermission: () => ++checks < 4,
          ),
          throwsA(
            isA<AppSettingsOperationConflict>().having(
              (error) => error.reason,
              'reason',
              'write_permission_revoked',
            ),
          ),
        );
        final stored = await service.readCommitted();
        expect(stored.themeMode, 'light');
        expect(stored.revision, 0);
        expect(stored.operations, isEmpty);
      },
    );

    test(
      'write permission revoked during Undo leaves value unchanged',
      () async {
        final store = _MemorySettingsStore();
        final service = AppSettingsService(store: store);
        await service.commitCoachSetting(
          operationId: 'bil03-theme-permission',
          field: 'themeMode',
          value: 'dark',
        );
        var checks = 0;

        await expectLater(
          service.undoCoachSetting(
            operationId: 'bil03-theme-permission',
            checkWritePermission: () => ++checks < 2,
          ),
          throwsA(
            isA<AppSettingsOperationConflict>().having(
              (error) => error.reason,
              'reason',
              'write_permission_revoked',
            ),
          ),
        );
        expect((await service.readCommitted()).themeMode, 'dark');
        expect(
          (await service.readCoachSettingOperation(
            'bil03-theme-permission',
          ))!.canUndo,
          isTrue,
        );
      },
    );

    test(
      'write permission revoked after Undo write restores committed setting',
      () async {
        final store = _MemorySettingsStore();
        final service = AppSettingsService(store: store);
        await service.commitCoachSetting(
          operationId: 'bil03-theme-undo-race',
          field: 'themeMode',
          value: 'dark',
        );
        var checks = 0;

        await expectLater(
          service.undoCoachSetting(
            operationId: 'bil03-theme-undo-race',
            checkWritePermission: () => ++checks < 5,
          ),
          throwsA(
            isA<AppSettingsOperationConflict>().having(
              (error) => error.reason,
              'reason',
              'write_permission_revoked',
            ),
          ),
        );
        final stored = await service.readCommitted();
        expect(stored.themeMode, 'dark');
        expect(stored.revision, 1);
        expect(
          (await service.readCoachSettingOperation(
            'bil03-theme-undo-race',
          ))!.canUndo,
          isTrue,
        );
      },
    );

    test('operation id cannot be replayed with different payload', () async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await service.commitCoachSetting(
        operationId: 'bil03-replay',
        field: 'themeMode',
        value: 'dark',
      );
      await expectLater(
        service.commitCoachSetting(
          operationId: 'bil03-replay',
          field: 'themeMode',
          value: 'light',
        ),
        throwsA(
          isA<AppSettingsOperationConflict>().having(
            (error) => error.reason,
            'reason',
            'operation_mismatch',
          ),
        ),
      );
    });
  });
}

class _MemorySettingsStore implements SettingsStore {
  _MemorySettingsStore({this.failWrites = false, Set<int>? failReadCalls})
    : failReadCalls = failReadCalls ?? <int>{};

  String? value;
  bool failWrites;
  final Set<int> failReadCalls;
  int readCount = 0;

  @override
  Future<String?> read() async {
    readCount += 1;
    if (failReadCalls.contains(readCount)) {
      throw StateError('synthetic settings read failure');
    }
    return value;
  }

  @override
  Future<void> write(String next) async {
    if (failWrites) throw StateError('synthetic settings write failure');
    value = next;
  }
}
