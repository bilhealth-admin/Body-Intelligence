import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_conversation_titles.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledPreferences extends PreferencesRepository {
  _ControlledPreferences(super.database);
  bool rejectWrite = false;
  Completer<void>? readGate;
  @override
  Future<String?> get(String key) async {
    await readGate?.future;
    return super.get(key);
  }

  @override
  Future<void> set(String key, String value) {
    if (rejectWrite) throw StateError('isolated_storage_full');
    return super.set(key, value);
  }
}

Map<String, Object?> _archive() => {
  'version': 2,
  'activeConversationId': 'current',
  'futureMetadata': {'receipt': 'keep'},
  'conversations': [
    {
      'id': 'current',
      'title': 'Automatic',
      'createdAt': '2026-10-11',
      'unknown': [1, 2, 3],
      'messages': [
        {
          'id': 'm1',
          'text': 'first',
          'sources': ['source'],
          'receipt': {'operationId': 'r1'},
        },
      ],
    },
    {
      'id': 'past',
      'title': 'Previous',
      'messages': [
        {
          'id': 'p1',
          'receipt': {'x': 2},
        },
      ],
    },
    {'futureRow': true},
  ],
};

void main() {
  test(
    'Unicode names are validated by grapheme and never cut a family emoji or combining Arabic',
    () {
      const family = '👨‍👩‍👧‍👦';
      final title = List.filled(60, family).join();
      expect(validatedCoachConversationTitle(title), title);
      expect(
        () => validatedCoachConversationTitle('$title$family'),
        throwsFormatException,
      );
      expect(
        abbreviatedCoachConversationTitle('$family$family', 1),
        '$family…',
      );
      expect(
        validatedCoachConversationTitle('  خطة\nالتغذية بِل 🥗  '),
        'خطة التغذية بِل 🥗',
      );
      expect(
        () => validatedCoachConversationTitle('  \n\t '),
        throwsFormatException,
      );
    },
  );
  test(
    'rename updates one title and origin while preserving unknown rows receipts active identity and metadata',
    () {
      final original = _archive();
      final renamed =
          jsonDecode(
                renameCoachConversationInArchive(
                  jsonEncode(original),
                  'current',
                  'غذائي 🥗',
                ),
              )
              as Map;
      expect(renamed['futureMetadata'], original['futureMetadata']);
      expect(renamed['activeConversationId'], 'current');
      final rows = renamed['conversations'] as List;
      expect(rows.length, 3);
      expect(rows[1], (original['conversations'] as List)[1]);
      expect(rows[2], (original['conversations'] as List)[2]);
      expect(
        rows.first['messages'],
        (original['conversations'] as List).first['messages'],
      );
      expect(rows.first['unknown'], [1, 2, 3]);
      expect(rows.first['titleSource'], 'manual');
      expect(
        () => renameCoachConversationInArchive(
          jsonEncode(renamed),
          'deleted',
          'No',
        ),
        throwsStateError,
      );
    },
  );
  test(
    'legacy archive upgrades without dropping opaque records and later archive cannot overwrite manual title',
    () {
      final legacy = jsonEncode(_archive()['conversations']);
      final renamed = renameCoachConversationInArchive(
        legacy,
        'current',
        'Training 💪',
      );
      final saved =
          jsonDecode(
                upsertCoachConversationArchive(
                  raw: renamed,
                  id: 'current',
                  automaticTitle: 'New first message',
                  createdAt: 'later',
                  messages: [
                    {'id': 'm1'},
                    {
                      'id': 'm2',
                      'receipt': {'operationId': 'r2'},
                    },
                  ],
                  activeId: 'current',
                ),
              )
              as Map;
      expect(saved['version'], 2);
      expect(saved['conversations'].first['title'], 'Training 💪');
      expect(saved['conversations'].first['createdAt'], '2026-10-11');
      expect(saved['conversations'].first['messages'], hasLength(2));
      expect(saved['conversations'].last, {'futureRow': true});
    },
  );
  test(
    'actual SQLite simultaneous rename and snapshot merge preserve manual title and all messages',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'A',
      );
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      await preferences.set(
        coachConversationHistoryKey,
        jsonEncode(_archive()),
      );
      await Future.wait([
        preferences.update(
          coachConversationHistoryKey,
          (raw) =>
              renameCoachConversationInArchive(raw, 'current', 'My 🥗 plan'),
        ),
        preferences.update(
          coachConversationHistoryKey,
          (raw) => upsertCoachConversationArchive(
            raw: raw,
            id: 'current',
            automaticTitle: 'Changed auto title',
            createdAt: 'later',
            messages: [
              {'id': 'm1'},
              {'id': 'm2'},
              {
                'id': 'm3',
                'receipt': {'operationId': 'final'},
              },
            ],
            activeId: 'current',
          ),
        ),
      ]);
      final stored =
          jsonDecode((await preferences.get(coachConversationHistoryKey))!)
              as Map;
      expect(stored['conversations'].first['title'], 'My 🥗 plan');
      expect(stored['conversations'].first['messages'], hasLength(3));
      expect(stored['conversations'].first['messages'].last['receipt'], {
        'operationId': 'final',
      });
      expect(stored['futureMetadata'], {'receipt': 'keep'});
    },
  );
  test('storage failure rolls back title and allows a genuine retry', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = _ControlledPreferences(database);
    final original = jsonEncode(_archive());
    await preferences.set(coachConversationHistoryKey, original);
    preferences.rejectWrite = true;
    await expectLater(
      preferences.update(
        coachConversationHistoryKey,
        (raw) => renameCoachConversationInArchive(raw, 'past', 'New'),
      ),
      throwsStateError,
    );
    expect(await preferences.get(coachConversationHistoryKey), original);
    preferences.rejectWrite = false;
    await preferences.update(
      coachConversationHistoryKey,
      (raw) => renameCoachConversationInArchive(raw, 'past', 'New'),
    );
    expect(
      (jsonDecode(
            (await preferences.get(coachConversationHistoryKey))!,
          )['conversations']
          as List)[1]['title'],
      'New',
    );
  });
  test(
    'owner A B A during pending read rolls back and never resurrects a deleted conversation',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'A',
      );
      addTearDown(database.close);
      final preferences = _ControlledPreferences(database);
      final original = jsonEncode(_archive());
      await preferences.set(coachConversationHistoryKey, original);
      var retired = false;
      var owner = 'A';
      final owners = StreamController<String>.broadcast(sync: true);
      final subscription = owners.stream.listen((next) {
        if (next != 'A') retired = true;
      });
      preferences.readGate = Completer<void>();
      final attempt = preferences.update(
        coachConversationHistoryKey,
        (raw) => renameCoachConversationInArchive(raw, 'current', 'Foreign'),
        isCurrent: () => owner == 'A' && !retired,
      );
      final rejected = expectLater(attempt, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      owner = 'B';
      owners.add(owner);
      owner = 'A';
      owners.add(owner);
      preferences.readGate!.complete();
      await rejected;
      preferences.readGate = null;
      expect(await preferences.get(coachConversationHistoryKey), original);
      await subscription.cancel();
      await owners.close();
      final deleted = _archive()..['deletedConversationIds'] = ['current'];
      (deleted['conversations'] as List).removeAt(0);
      expect(
        () => renameCoachConversationInArchive(
          jsonEncode(deleted),
          'current',
          'Revive',
        ),
        throwsStateError,
      );
      expect(
        () => upsertCoachConversationArchive(
          raw: jsonEncode(deleted),
          id: 'current',
          automaticTitle: 'Revive',
          createdAt: 'now',
          messages: [],
          activeId: 'current',
        ),
        throwsStateError,
      );
    },
  );
}
