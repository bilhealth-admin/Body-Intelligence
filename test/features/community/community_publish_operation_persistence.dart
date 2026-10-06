part of 'community_publish_operation_test.dart';

class _JournalPlatform extends InMemorySharedPreferencesStore {
  _JournalPlatform() : super.empty();

  bool rejectWrites = false;
  bool rejectRemovals = false;
  bool pretendRemovalSuccess = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (rejectWrites) return Future.value(false);
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    if (rejectRemovals) return Future.value(pretendRemovalSuccess);
    return super.remove(key);
  }
}

_JournalPlatform _installJournalPlatform() {
  final original = SharedPreferencesStorePlatform.instance;
  final platform = _JournalPlatform();
  SharedPreferences.resetStatic();
  SharedPreferencesStorePlatform.instance = platform;
  addTearDown(() {
    SharedPreferencesStorePlatform.instance = original;
    SharedPreferences.resetStatic();
  });
  return platform;
}

void _registerPublishPersistenceTests() {
  for (final pretendSuccess in [false, true]) {
    test(
      'durable journal removal readback rejects unremoved identity $pretendSuccess',
      () async {
        final platform = _installJournalPlatform();
        final backend = _OperationBackend()..loseCommittedResponse = true;
        final service = await _service(backend);
        await expectLater(
          service.publish(_fields(), [_image()]),
          throwsA(isA<http.ClientException>()),
        );
        backend.postUnavailable = true;
        platform
          ..rejectRemovals = true
          ..pretendRemovalSuccess = pretendSuccess;
        await expectLater(service.cancelPending(), throwsStateError);
        expect(backend.deletes, 0);
        expect(backend.objects, hasLength(1));
        // Inspect actual platform state, not the optimistic SharedPreferences
        // cache which remove() already cleared before the failed native write.
        final persisted = await platform.getAll();
        expect(
          persisted.keys.where((key) => key.contains('publish.operation')),
          hasLength(1),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(
          prefs.getKeys().where((key) => key.contains('publish.operation')),
          hasLength(1),
        );
        platform.rejectRemovals = false;
        await expectLater(
          service.cancelPending(),
          throwsA(isA<CommunityPublishOperationUnavailable>()),
        );
        expect(backend.deletes, 0);
        expect(
          (await platform.getAll()).keys.where(
            (key) => key.contains('publish.operation'),
          ),
          isEmpty,
        );
      },
    );
  }

  test(
    'failed durable journal save cannot reach reservation or upload',
    () async {
      final platform = _installJournalPlatform()..rejectWrites = true;
      final backend = _OperationBackend();
      final service = await _service(backend);
      await expectLater(
        service.publish(_fields(), [_image()]),
        throwsStateError,
      );
      expect(backend.operations, isEmpty);
      expect(backend.commits, 0);
      expect(backend.uploads, 0);
      expect(backend.rows, 0);
      expect(await platform.getAll(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(
        prefs.getKeys().where((key) => key.contains('publish.operation')),
        isEmpty,
      );
      platform.rejectWrites = false;
      await service.publish(_fields(), []);
      expect(backend.rows, 1);
    },
  );
}
