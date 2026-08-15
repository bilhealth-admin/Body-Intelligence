import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(AppDatabase database, {Locale locale = const Locale('en')}) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const IntelligenceCenterPage(),
    ),
  );
}

void main() {
  Future<AppDatabase> database(WidgetTester tester) async {
    final value = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(value.close);
    return value;
  }

  testWidgets('keyboard send submits text and renders the latest reply', (
    tester,
  ) async {
    final db = await database(tester);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    final fieldFinder = find.byKey(const Key('ai-coach-question-field'));
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.textInputAction, TextInputAction.send);

    await tester.enterText(fieldFinder, 'hello');
    tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
    expect(
      find.textContaining('I am ready').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('restored technical failure is localized and latest is visible', (
    tester,
  ) async {
    final db = await database(tester);
    final stored = <Map<String, Object?>>[
      for (var index = 0; index < 18; index++)
        {
          'id': 'old-$index',
          'role': 'user',
          'kind': 'freeQuestion',
          'text': 'رسالة $index',
          'createdAt': DateTime(2026, 8, 9, 12, index).toIso8601String(),
          'evidence': <String>[],
          'missingData': <String>[],
        },
      {
        'id': 'technical-error',
        'role': 'bil',
        'kind': 'safety',
        'text': 'BIL did not expose an action because the safety boundary did not approve one. AI Context is not accepted.',
        'createdAt': DateTime(2026, 8, 9, 13).toIso8601String(),
        'evidence': <String>['local-coach-runtime'],
        'missingData': <String>[],
      },
    ];
    await PreferencesRepository(db).set(
      'intelligenceConversationV1',
      jsonEncode(stored),
    );

    await tester.pumpWidget(_app(db, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('BIL did not expose'), findsNothing);
    expect(find.textContaining('AI Context is not accepted'), findsNothing);
    expect(
      find.textContaining('تعذر إكمال هذا الرد الآن').hitTestable(),
      findsOneWidget,
    );
  });
}
