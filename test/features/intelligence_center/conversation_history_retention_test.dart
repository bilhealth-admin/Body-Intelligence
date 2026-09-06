import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _conversation(int index) => <String, Object?>{
  'id': 'conversation-$index',
  'title': 'Conversation $index',
  'createdAt': DateTime.utc(
    2026,
    9,
    1,
  ).add(Duration(days: index)).toIso8601String(),
  'messages': <Object?>[
    <String, Object?>{'role': 'user', 'text': 'Question $index'},
  ],
};

Map<String, Object?> _message(int index) => <String, Object?>{
  'id': 'message-$index',
  'role': 'user',
  'kind': 'freeQuestion',
  'text': 'Question $index',
  'createdAt': DateTime.utc(2026, 9, 1, 8, index).toIso8601String(),
  'evidence': <String>[],
  'missingData': <String>[],
};

Widget _app(AppDatabase database) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    coachContextSnapshotProvider.overrideWith(
      (ref) async => CoachContextSnapshot.empty(),
    ),
    intelligenceHealthContextProvider.overrideWith(
      (ref) async => const IntelligenceHealthContext(
        primaryMessage: '',
        explanation: <String>[],
        confidence: 1,
        evidence: <String>[],
        missingData: <String>[],
      ),
    ),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: IntelligenceCenterPage(),
  ),
);

void main() {
  test('legacy V1 list migrates in place without losing conversations', () {
    final legacy = <Map<String, Object?>>[
      for (var index = 0; index < 27; index++) _conversation(index),
    ];

    final decoded = decodeCoachConversationHistory(jsonEncode(legacy));

    expect(decoded.needsMigration, isTrue);
    expect(decoded.conversations, hasLength(27));
    expect(decoded.conversations.last['id'], 'conversation-26');

    final migrated = decodeCoachConversationHistory(
      encodeCoachConversationHistory(
        conversations: decoded.conversations,
        activeConversationId: 'conversation-23',
      ),
    );

    expect(migrated.needsMigration, isFalse);
    expect(migrated.conversations, hasLength(27));
    expect(migrated.activeConversationId, 'conversation-23');
  });

  test('history keeps every conversation beyond the former 20 item cap', () {
    var history = <Map<String, Object?>>[];
    for (var index = 0; index < 35; index++) {
      history = upsertCoachConversationHistory(
        history: history,
        id: 'conversation-$index',
        title: 'Conversation $index',
        createdAt: DateTime.utc(
          2026,
          9,
          1,
        ).add(Duration(days: index)).toIso8601String(),
        messages: <Object?>[
          <String, Object?>{'role': 'user', 'text': 'Question $index'},
        ],
      );
    }

    expect(history, hasLength(35));
    expect(history.map((entry) => entry['id']).toSet(), hasLength(35));
    expect(history.last['id'], 'conversation-0');
  });

  test('saved current selection wins instead of defaulting to newest chat', () {
    final conversations = <Map<String, Object?>>[
      for (var index = 0; index < 32; index++) _conversation(index),
    ];
    final archive = decodeCoachConversationHistory(
      encodeCoachConversationHistory(
        conversations: conversations,
        activeConversationId: 'conversation-27',
      ),
    );

    expect(
      resolveCoachActiveConversationId(
        storedActiveConversationId: null,
        archive: archive,
        currentMessages: const <Object?>[],
      ),
      'conversation-27',
    );
    expect(
      resolveCoachActiveConversationId(
        storedActiveConversationId: 'conversation-30',
        archive: archive,
        currentMessages: conversations[27]['messages']! as List<Object?>,
      ),
      'conversation-30',
    );
  });

  test('legacy transcript match restores its identity without a new chat', () {
    final conversations = <Map<String, Object?>>[
      for (var index = 0; index < 24; index++) _conversation(index),
    ];
    final legacyArchive = decodeCoachConversationHistory(
      jsonEncode(conversations),
    );

    expect(
      resolveCoachActiveConversationId(
        storedActiveConversationId: null,
        archive: legacyArchive,
        currentMessages: conversations[22]['messages']! as List<Object?>,
      ),
      'conversation-22',
    );
    const orphanedLegacyTranscript = <Object?>[
      <String, Object?>{'role': 'user', 'text': 'Pre-history question'},
    ];
    final migratedId = resolveCoachActiveConversationId(
      storedActiveConversationId: null,
      archive: legacyArchive,
      currentMessages: orphanedLegacyTranscript,
    );
    expect(migratedId, startsWith('conversation-legacy-'));
    expect(
      migratedId,
      migratedCoachConversationIdForMessages(orphanedLegacyTranscript),
      reason: 'migration identity must be stable rather than minting a chat',
    );
    expect(
      resolveCoachActiveConversationId(
        storedActiveConversationId: null,
        archive: legacyArchive,
        currentMessages: const <Object?>[],
      ),
      isNull,
      reason: 'an empty session must not silently create or select a chat',
    );
  });

  testWidgets(
    'legacy archive migration keeps the selected conversation across restart',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      final conversations = <Map<String, Object?>>[
        for (var index = 0; index < 26; index++)
          <String, Object?>{
            ..._conversation(index),
            'messages': <Object?>[_message(index)],
          },
      ];
      final selectedMessages = conversations[23]['messages']! as List<Object?>;
      await preferences.setMany(<String, String>{
        'intelligenceConversationHistoryV1': jsonEncode(conversations),
        'intelligenceConversationActiveIdV1': 'conversation-23',
        'intelligenceConversationV1': jsonEncode(selectedMessages),
      });

      await tester.pumpWidget(_app(database));
      await tester.pumpAndSettle();
      expect(find.text('Question 23'), findsOneWidget);

      var migrated = decodeCoachConversationHistory(
        await preferences.get('intelligenceConversationHistoryV1'),
      );
      expect(migrated.needsMigration, isFalse);
      expect(migrated.conversations, hasLength(26));
      expect(migrated.activeConversationId, 'conversation-23');

      await tester.tap(
        find.byKey(const Key('ai-coach-conversation-history-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Conversation history is stored locally on this device.'),
        findsOneWidget,
      );
      final selectedTile = tester.widget<ListTile>(
        find.byKey(const Key('ai-coach-conversation-conversation-23')),
      );
      expect(selectedTile.selected, isTrue);

      await tester.tap(
        find.byKey(const Key('ai-coach-conversation-conversation-23')),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(database));
      await tester.pumpAndSettle();

      expect(find.text('Question 23'), findsOneWidget);
      expect(
        await preferences.get('intelligenceConversationActiveIdV1'),
        'conversation-23',
      );
      migrated = decodeCoachConversationHistory(
        await preferences.get('intelligenceConversationHistoryV1'),
      );
      expect(migrated.conversations, hasLength(26));
      expect(migrated.activeConversationId, 'conversation-23');
    },
  );

  testWidgets('opening history does not create a conversation implicitly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    final conversations = <Map<String, Object?>>[
      for (var index = 0; index < 25; index++)
        <String, Object?>{
          ..._conversation(index),
          'messages': <Object?>[_message(index)],
        },
    ];
    await preferences.set(
      'intelligenceConversationHistoryV1',
      encodeCoachConversationHistory(
        conversations: conversations,
        activeConversationId: null,
      ),
    );

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('ai-coach-conversation-history-button')),
    );
    await tester.pumpAndSettle();

    final persisted = decodeCoachConversationHistory(
      await preferences.get('intelligenceConversationHistoryV1'),
    );
    expect(persisted.conversations, hasLength(25));
    expect(persisted.activeConversationId, isNull);
    expect(await preferences.get('intelligenceConversationActiveIdV1'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
