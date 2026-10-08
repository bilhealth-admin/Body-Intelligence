import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_fasting_commands.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _conversation = 'synthetic-conversation-a';
const _owner = 'synthetic-recovery-owner';
const _metadata = 'healthReceiptRecovery';
final _now = DateTime.utc(2026, 10, 7, 6);

void main() {
  late _Store store;
  setUp(() async => store = await _Store.create());
  tearDown(() => store.close());

  test(
    'lost postcommit readback is rediscovered after closing and reopening SQLite',
    () async {
      final faulty = store.native(
        journalPreferences: _LostReadbackPreferences(store.database),
      );
      final command = await store.prepare('lost-readback', repository: faulty);
      await expectLater(
        faulty.commit(
          command: command,
          scope: store.scope,
          healthRecoveryConversationId: _conversation,
        ),
        throwsA(
          isA<CoachNativeConflict>()
              .having(
                (error) => error.reason,
                'reason',
                CoachNativeConflictReason.readbackUnavailable,
              )
              .having((error) => error.committed, 'committed', true),
        ),
      );
      expect(
        await store.preferences.get(CoachFastingCommandAdapter.targetHoursKey),
        '16',
      );
      expect((await store.journal('lost-readback'))[_metadata], {
        'conversationId': _conversation,
        'receiptAcknowledged': false,
      });
      final durable = await store.preferencesRows();
      await store.restart();
      final restarted = store.native();
      final ids = await restarted.listPendingHealthReceiptOperationIds(
        scope: store.scope,
        conversationId: _conversation,
      );
      expect(ids, ['lost-readback']);
      final recovered = await restarted.readOperation(
        operationId: ids.single,
        scope: store.scope,
      );
      expect(recovered!.state, CoachNativeResultState.committed);
      expect(recovered.canUndo, isTrue);
      expect(recovered.command.toJson(), command.toJson());
      expect(recovered.argumentsDigest, command.argumentsDigest);
      expect(
        await store.preferencesRows(),
        durable,
        reason:
            'Discovery and verification never replay data or write a journal',
      );
    },
  );

  test(
    'metadata and health values roll back together when permission is revoked after journal write',
    () async {
      var allowed = true;
      final repository = store.native(
        journalPreferences: _AfterJournalPreferences(
          store.database,
          () => allowed = false,
        ),
      );
      final command = await store.prepare('rollback', repository: repository);
      await expectLater(
        repository.commit(
          command: command,
          scope: store.scope,
          healthRecoveryConversationId: _conversation,
          checkWritePermission: () {
            if (!allowed) throw StateError('Synthetic permission revocation');
          },
        ),
        throwsStateError,
      );
      expect(await store.preferencesRows(), isEmpty);
      expect(await store.pending(), isEmpty);
    },
  );

  test(
    'SQLite filters exact conversation before limit despite unrelated and malformed newer journals',
    () async {
      await store.commit('older-pending');
      final template = await store.journal('older-pending');
      for (var index = 0; index < 180; index++) {
        await store.seedJournal('unrelated-$index', template, (value) {
          (value[_metadata] as Map)['conversationId'] = 'another-conversation';
        });
      }
      for (final value in <Object?>[
        null,
        false,
        [],
        'false',
        {'conversationId': _conversation, 'receiptAcknowledged': 'false'},
        {'conversationId': _conversation, 'receiptAcknowledged': 0},
      ]) {
        await store.seedJournal(
          'bad-metadata-${value.hashCode.abs()}',
          template,
          (json) => json[_metadata] = value,
        );
      }
      await store.preferences.set(
        store.key('malformed-json'),
        '{"healthReceiptRecovery":',
      );
      await store.seedJournal(
        'wrong-json-owner',
        template,
        (value) => value['ownerScope'] = 'guest',
      );
      await store.seedJournal('wrong-operation-identity', template, (value) {
        (value['command'] as Map)['operationId'] = 'some-other-operation';
      });
      await store.seedJournal('already-acknowledged', template, (value) {
        (value[_metadata] as Map)['receiptAcknowledged'] = true;
      });
      await store.preferences.set(
        'coachNativeOperationV1.guest.foreign-key',
        jsonEncode(template),
      );
      final before = await store.preferencesRows();
      expect(await store.pending(limit: 1), ['older-pending']);
      expect(
        await store.pending(conversationId: 'missing-conversation'),
        isEmpty,
      );
      expect(await store.preferencesRows(), before);
    },
  );

  test('valid metadata cannot admit a corrupt immutable journal', () async {
    await store.commit('valid-operation');
    final template = await store.journal('valid-operation');
    await store.seedJournal(
      'bad-digest',
      template,
      (value) => value['argumentsDigest'] = 'corrupt',
    );
    await store.seedJournal(
      'bad-schema',
      template,
      (value) => value['schema'] = 999,
    );
    await store.seedJournal('bad-command', template, (value) {
      ((value['command'] as Map)['resolved'] as Map)['healthToolId'] =
          'stop_fasting';
    });
    expect(await store.pending(), ['valid-operation']);
  });

  test(
    'pending IDs are newest first with a default of 16 and a maximum of 32',
    () async {
      await store.commit('operation-0');
      final template = await store.journal('operation-0');
      for (var index = 1; index < 40; index++) {
        await store.seedJournal('operation-$index', template);
      }
      expect(
        await store.pending(),
        List.generate(16, (index) => 'operation-${39 - index}'),
      );
      expect(
        await store.pending(limit: 32),
        List.generate(32, (index) => 'operation-${39 - index}'),
      );
      expect(await store.pending(limit: 1), ['operation-39']);
    },
  );

  for (final limit in [-1, 0, 33, 100]) {
    test('pending limit $limit is rejected without mutation', () async {
      await expectLater(
        store.native().listPendingHealthReceiptOperationIds(
          scope: store.scope,
          conversationId: _conversation,
          limit: limit,
        ),
        throwsRangeError,
      );
      expect(await store.preferencesRows(), isEmpty);
    });
  }

  test(
    'acknowledgement changes only metadata, preserves SQLite rowid and is an idempotent UPDATE',
    () async {
      final result = await store.commit('acknowledge');
      final key = store.key(result.operationId);
      final before = await store.journal(result.operationId);
      final rowBefore = await store.journalRow(result.operationId);
      final healthBefore = await store.healthRows();
      await store.database.customStatement(
        'CREATE TABLE receipt_ack_events (journal_key TEXT NOT NULL)',
      );
      await store.database.customStatement(
        'CREATE TRIGGER receipt_ack_updates AFTER UPDATE ON preferences '
        'WHEN NEW.key = \'$key\' BEGIN INSERT INTO receipt_ack_events VALUES (NEW.key); END',
      );
      await store.ack(result.operationId);
      final after = await store.journal(result.operationId);
      final rowAfter = await store.journalRow(result.operationId);
      expect(
        rowAfter.read<int>('journal_rowid'),
        rowBefore.read<int>('journal_rowid'),
      );
      expect(
        rowAfter.read<int>('updated_at'),
        rowBefore.read<int>('updated_at'),
      );
      expect((after[_metadata] as Map)['receiptAcknowledged'], isTrue);
      final expected = Map<String, dynamic>.from(before);
      expected[_metadata] = {
        'conversationId': _conversation,
        'receiptAcknowledged': true,
      };
      expect(after, expected);
      expect(await store.healthRows(), healthBefore);
      await store.ack(result.operationId);
      expect(
        await store.journalRow(result.operationId).then((row) => row.data),
        rowAfter.data,
      );
      expect(
        await store.database
            .customSelect('SELECT * FROM receipt_ack_events')
            .get(),
        hasLength(1),
      );
      final verified = await store.native().readOperation(
        operationId: result.operationId,
        scope: store.scope,
      );
      expect(verified!.argumentsDigest, result.argumentsDigest);
      expect(verified.after.toJson(), result.after.toJson());
      expect(verified.before.toJson(), result.before.toJson());
      expect(verified.canUndo, isTrue);
      await store.restart();
      expect(await store.pending(), isEmpty);
      await store.ack(result.operationId);
      expect(
        (await store.native().readOperation(
          operationId: result.operationId,
          scope: store.scope,
        ))!.canUndo,
        isTrue,
      );
    },
  );

  for (final acknowledgedBeforeUndo in [false, true]) {
    test(
      'Undo preserves recovery metadata with acknowledgement $acknowledgedBeforeUndo',
      () async {
        final result = await store.commit('undo-recovery');
        if (acknowledgedBeforeUndo) await store.ack(result.operationId);
        final rowBefore = await store.journalRow(result.operationId);
        final undone = await store.native().undo(
          operationId: result.operationId,
          toolId: result.toolId,
          argumentsDigest: result.argumentsDigest,
          scope: store.scope,
        );
        expect(undone.state, CoachNativeResultState.undone);
        expect(await store.healthRows(), isEmpty);
        expect((await store.journal(result.operationId))[_metadata], {
          'conversationId': _conversation,
          'receiptAcknowledged': acknowledgedBeforeUndo,
        });
        expect(
          (await store.journalRow(
            result.operationId,
          )).read<int>('journal_rowid'),
          rowBefore.read<int>('journal_rowid'),
        );
        await store.restart();
        expect(
          await store.pending(),
          acknowledgedBeforeUndo ? isEmpty : [result.operationId],
        );
        final recovered = await store.native().readOperation(
          operationId: result.operationId,
          scope: store.scope,
        );
        expect(recovered!.state, CoachNativeResultState.undone);
        expect(recovered.canUndo, isFalse);
        await store.ack(result.operationId);
        expect(await store.pending(), isEmpty);
      },
    );
  }

  test(
    'acknowledging an earlier journal cannot reorder or reauthorize superseded Undo',
    () async {
      final first = await store.commit('first');
      final laterCommand = await store.prepare(
        'later',
        toolId: 'adjust_fasting',
        arguments: {'targetHours': 18},
      );
      final later = await store.native().commit(
        command: laterCommand,
        scope: store.scope,
        healthRecoveryConversationId: _conversation,
      );
      final firstRow = await store.journalRow(first.operationId);
      final laterRow = await store.journalRow(later.operationId);
      await store.ack(first.operationId);
      expect(
        (await store.journalRow(first.operationId)).read<int>('journal_rowid'),
        firstRow.read<int>('journal_rowid'),
      );
      expect(
        firstRow.read<int>('journal_rowid'),
        lessThan(laterRow.read<int>('journal_rowid')),
      );
      final old = await store.native().readOperation(
        operationId: first.operationId,
        scope: store.scope,
      );
      expect(old!.state, CoachNativeResultState.modified);
      expect(old.canUndo, isFalse);
      expect(
        (await store.native().readOperation(
          operationId: later.operationId,
          scope: store.scope,
        ))!.canUndo,
        isTrue,
      );
    },
  );

  test(
    'replay preserves acknowledgement and cannot move an operation into another conversation',
    () async {
      final result = await store.commit('replay');
      await store.ack(result.operationId);
      final before = await store.preferencesRows();
      final replayed = await store.native().commit(
        command: result.command,
        scope: store.scope,
        healthRecoveryConversationId: _conversation,
      );
      expect(replayed.replayed, isTrue);
      expect(await store.pending(), isEmpty);
      await expectLater(
        store.native().commit(
          command: result.command,
          scope: store.scope,
          healthRecoveryConversationId: 'another-conversation',
        ),
        _conflict(CoachNativeConflictReason.operationMismatch),
      );
      expect(await store.preferencesRows(), before);
    },
  );

  test(
    'owner and conversation mismatches grant no recovery or acknowledgement authority',
    () async {
      await store.commit('scoped');
      final before = await store.preferencesRows();
      final wrongOwner = CoachNativeOwnerScope(
        ownerId: 'another-owner',
        isCurrent: () => true,
      );
      await expectLater(
        store.native().listPendingHealthReceiptOperationIds(
          scope: wrongOwner,
          conversationId: _conversation,
        ),
        _conflict(CoachNativeConflictReason.ownerChanged),
      );
      await expectLater(
        store.native().markHealthReceiptPersisted(
          operationId: 'scoped',
          scope: wrongOwner,
          conversationId: _conversation,
        ),
        _conflict(CoachNativeConflictReason.ownerChanged),
      );
      expect(
        await store.pending(conversationId: 'another-conversation'),
        isEmpty,
      );
      await expectLater(
        store.ack('scoped', conversationId: 'another-conversation'),
        _conflict(CoachNativeConflictReason.operationMismatch),
      );
      await expectLater(
        store.ack('missing'),
        _conflict(CoachNativeConflictReason.operationMismatch),
      );
      expect(await store.preferencesRows(), before);
    },
  );

  test(
    'owner revocation observed during acknowledgement read prevents its UPDATE',
    () async {
      await store.commit('revoke-owner');
      final before = await store.preferencesRows();
      final preferences = _RevokeOnJournalRead(
        store.database,
        store.scope.cancel,
      );
      await expectLater(
        store
            .native(journalPreferences: preferences)
            .markHealthReceiptPersisted(
              operationId: 'revoke-owner',
              scope: store.scope,
              conversationId: _conversation,
            ),
        _conflict(CoachNativeConflictReason.ownerChanged),
      );
      expect(await store.preferencesRows(), before);
    },
  );

  test(
    'malformed recovery metadata cannot be acknowledged or silently repaired',
    () async {
      await store.commit('corrupt-metadata');
      final json = await store.journal('corrupt-metadata');
      (json[_metadata] as Map)['receiptAcknowledged'] = 'false';
      await store.preferences.set(
        store.key('corrupt-metadata'),
        jsonEncode(json),
      );
      final before = await store.preferencesRows();
      expect(await store.pending(), isEmpty);
      await expectLater(
        store.ack('corrupt-metadata'),
        _conflict(CoachNativeConflictReason.invalidJournal),
      );
      expect(await store.preferencesRows(), before);
    },
  );

  test(
    'legacy native and health journal bytes omit all optional recovery metadata',
    () async {
      for (final tool in ['log_water', 'start_fasting']) {
        final repository = store.native();
        final command = await store.prepare(
          'legacy-$tool',
          toolId: tool,
          arguments: tool == 'log_water'
              ? {'amountMl': 250}
              : {'targetHours': 16},
        );
        final result = await repository.commit(
          command: command,
          scope: store.scope,
        );
        final raw = (await store.preferences.get(
          store.key(result.operationId),
        ))!;
        final expected = jsonEncode({
          'schema': 1,
          'command': command.toJson(),
          'ownerScope': LocalDatabaseScope.keyForOwner(_owner),
          'committedAt': result.committedAt.toIso8601String(),
          'after': result.after.toJson(),
          'undoneAt': null,
          'undoAfter': null,
          'argumentsDigest': command.argumentsDigest,
        });
        expect(
          raw,
          expected,
          reason: 'The legacy serialization is byte-for-byte unchanged',
        );
        await expectLater(
          store.ack(result.operationId),
          _conflict(CoachNativeConflictReason.operationMismatch),
        );
        expect(await store.preferences.get(store.key(result.operationId)), raw);
        final replay = await repository.commit(
          command: command,
          scope: store.scope,
        );
        expect(replay.replayed, isTrue);
        expect(await store.preferences.get(store.key(result.operationId)), raw);
        final undone = await repository.undo(
          operationId: result.operationId,
          toolId: tool,
          argumentsDigest: result.argumentsDigest,
          scope: store.scope,
        );
        final undoJson = await store.journal(result.operationId);
        expect(undoJson.containsKey(_metadata), isFalse);
        expect(
          undoJson.keys.toList(),
          (jsonDecode(expected) as Map).keys.toList(),
        );
        expect(undone.state, CoachNativeResultState.undone);
      }
      expect(await store.pending(), isEmpty);
    },
  );

  test(
    'recovery locator is rejected for a non-health commit before any write',
    () async {
      final command = await store.prepare(
        'water-with-locator',
        toolId: 'log_water',
        arguments: {'amountMl': 250},
      );
      await expectLater(
        store.native().commit(
          command: command,
          scope: store.scope,
          healthRecoveryConversationId: _conversation,
        ),
        throwsArgumentError,
      );
      expect(await store.preferencesRows(), isEmpty);
      expect(
        await store.database.select(store.database.waterEntries).get(),
        isEmpty,
      );
    },
  );

  test(
    'invalid conversation identities are rejected before mutation',
    () async {
      final command = await store.prepare('invalid-conversation');
      for (final conversationId in ['', ' ', ' leading-space', 'x' * 257]) {
        await expectLater(
          store.pending(conversationId: conversationId),
          throwsArgumentError,
        );
        await expectLater(
          store.ack(command.operationId, conversationId: conversationId),
          throwsArgumentError,
        );
        await expectLater(
          store.native().commit(
            command: command,
            scope: store.scope,
            healthRecoveryConversationId: conversationId,
          ),
          throwsArgumentError,
        );
      }
      expect(await store.preferencesRows(), isEmpty);
    },
  );
}

Matcher _conflict(CoachNativeConflictReason reason) => throwsA(
  isA<CoachNativeConflict>().having((error) => error.reason, 'reason', reason),
);

class _Store {
  _Store(this.directory) {
    _open();
  }
  static Future<_Store> create() async =>
      _Store(await Directory.systemTemp.createTemp('bil04-health-receipt-'));
  final Directory directory;
  late AppDatabase database;
  late PreferencesRepository preferences;
  late CoachNativeOwnerScope scope;
  void _open() {
    database = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/local.sqlite')),
      localOwnerId: _owner,
    );
    preferences = PreferencesRepository(database);
    scope = CoachNativeOwnerScope(ownerId: _owner, isCurrent: () => true);
  }

  Future<void> restart() async {
    await database.close();
    _open();
  }

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }

  String key(String operationId) =>
      'coachNativeOperationV1.${LocalDatabaseScope.keyForOwner(_owner)}.$operationId';
  CoachNativeCommandRepository native({
    PreferencesRepository? journalPreferences,
  }) => CoachNativeCommandRepository(
    database,
    preferences: journalPreferences ?? preferences,
    healthCommands: CoachFastingCommandAdapter(preferences),
  );
  Future<CoachNativeCommand> prepare(
    String operationId, {
    CoachNativeCommandRepository? repository,
    String toolId = 'start_fasting',
    Map<String, Object?> arguments = const {'targetHours': 16},
  }) => (repository ?? native()).prepare(
    toolId: toolId,
    operationId: operationId,
    arguments: arguments,
    scope: scope,
    now: _now.toLocal(),
  );
  Future<CoachNativeCommit> commit(String operationId) async => native().commit(
    command: await prepare(operationId),
    scope: scope,
    healthRecoveryConversationId: _conversation,
  );
  Future<List<String>> pending({
    String conversationId = _conversation,
    int limit = 16,
  }) => native().listPendingHealthReceiptOperationIds(
    scope: scope,
    conversationId: conversationId,
    limit: limit,
  );
  Future<void> ack(
    String operationId, {
    String conversationId = _conversation,
  }) => native().markHealthReceiptPersisted(
    operationId: operationId,
    scope: scope,
    conversationId: conversationId,
  );
  Future<Map<String, dynamic>> journal(String operationId) async =>
      jsonDecode((await preferences.get(key(operationId)))!)
          as Map<String, dynamic>;
  Future<QueryRow> journalRow(String operationId) => database
      .customSelect(
        'SELECT rowid AS journal_rowid, key, value, updated_at FROM preferences WHERE key = ?',
        variables: [Variable<String>(key(operationId))],
        readsFrom: {database.preferences},
      )
      .getSingle();
  Future<List<Preference>> preferencesRows() => (database.select(
    database.preferences,
  )..orderBy([(row) => OrderingTerm.asc(row.key)])).get();
  Future<List<Preference>> healthRows() async => (await preferencesRows())
      .where((row) => !row.key.startsWith('coachNativeOperationV1.'))
      .toList();
  Future<void> seedJournal(
    String operationId,
    Map<String, dynamic> template, [
    void Function(Map<String, dynamic>)? mutate,
  ]) async {
    final value = jsonDecode(jsonEncode(template)) as Map<String, dynamic>;
    (value['command'] as Map)['operationId'] = operationId;
    mutate?.call(value);
    await preferences.set(key(operationId), jsonEncode(value));
  }
}

class _LostReadbackPreferences extends PreferencesRepository {
  _LostReadbackPreferences(super.database);
  var armed = false;
  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    if (values.keys.any((key) => key.startsWith('coachNativeOperationV1.'))) {
      armed = true;
    }
  }

  @override
  Future<String?> get(String key) {
    if (armed && key.startsWith('coachNativeOperationV1.')) {
      throw StateError('Synthetic postcommit journal readback loss');
    }
    return super.get(key);
  }
}

class _AfterJournalPreferences extends PreferencesRepository {
  _AfterJournalPreferences(super.database, this.afterWrite);
  final void Function() afterWrite;
  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    if (values.keys.any((key) => key.startsWith('coachNativeOperationV1.'))) {
      afterWrite();
    }
  }
}

class _RevokeOnJournalRead extends PreferencesRepository {
  _RevokeOnJournalRead(super.database, this.revoke);
  final void Function() revoke;
  @override
  Future<String?> get(String key) async {
    final value = await super.get(key);
    if (key.startsWith('coachNativeOperationV1.')) revoke();
    return value;
  }
}
