import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

part 'coach_native_command_behavior_cases.dart';
part 'coach_native_command_recovery_cases.dart';
part 'coach_native_recovery_lifecycle_cases.dart';
part 'coach_native_undo_permission_cases.dart';

void main() {
  _nativeCommandCases();
  _nativeRecoveryCases();
  _nativeRecoveryLifecycleCases();
  _nativeUndoPermissionCases();
}

final _day = DateTime(2026, 10, 6);

Future<void> _withCoach(
  WidgetTester tester,
  List<Map<String, Object?>> tools,
  Future<void> Function(_NativeFixture fixture) body, {
  Future<void> Function(_NativeFixture fixture)? seed,
  String? ownerId,
}) async {
  final fixture = _NativeFixture(tools, ownerId: ownerId);
  addTearDown(fixture.database.close);
  addTearDown(fixture.owners.close);
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  if (seed != null) await seed(fixture);
  try {
    await tester.pumpWidget(_nativeCoachApp(fixture));
    await tester.pumpAndSettle();
    await body(fixture);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
  }
}

Widget _nativeCoachApp(_NativeFixture fixture) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(fixture.database),
    if (fixture.recoveryPreferences case final preferences?)
      preferencesRepositoryProvider.overrideWithValue(preferences),
    appSettingsServiceProvider.overrideWithValue(fixture.settings),
    intelligenceCenterModelGatewayProvider.overrideWithValue(fixture.gateway),
    coachActionPermissionModeProvider.overrideWith(
      (ref) => CoachActionPermissionMode.askBeforeWrite,
    ),
    coachNativeOwnerWitnessProvider.overrideWithValue(
      fixture.database.localOwnerId == null
          ? null
          : CoachNativeOwnerWitness(
              readOwner: () => fixture.owner,
              changes: fixture.owners.stream,
            ),
    ),
    coachContextSnapshotProvider.overrideWith(
      (ref) async => CoachContextSnapshot.empty(),
    ),
    intelligenceHealthContextProvider.overrideWith(
      (ref) async => const IntelligenceHealthContext(
        primaryMessage: '',
        explanation: [],
        confidence: 1,
        evidence: [],
        missingData: [],
      ),
    ),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: IntelligenceCenterPage(),
  ),
);

Map<String, Object?> _tool(String name, Map<String, Object?> arguments) => {
  'name': name,
  'arguments': arguments,
};

Future<void> _openNativeAction(
  WidgetTester tester,
  String type,
  String tool,
) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(IntelligenceCenterPage)),
  ).clearSnackBars();
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    'Execute the prepared BIL operation',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  final action = find.byKey(Key('ai-coach-action-sheet-$type-$tool'));
  for (var attempt = 0; attempt < 80 && action.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(action, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pump(const Duration(milliseconds: 350));
  expect(action.hitTestable(), findsOneWidget);
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

Future<void> _confirmNative(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

Future<void> _undoNative(WidgetTester tester) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(IntelligenceCenterPage)),
  ).clearSnackBars();
  final undo = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        ((widget.key! as ValueKey<String>).value).startsWith('ai-coach-undo-'),
  );
  for (var attempt = 0; attempt < 80 && undo.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(undo, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(undo), alignment: .5);
  await tester.pump(const Duration(milliseconds: 350));
  expect(undo.hitTestable(), findsOneWidget);
  await tester.tap(undo);
  await tester.pumpAndSettle();
}

class _NativeFixture {
  _NativeFixture(List<Map<String, Object?>> tools, {String? ownerId})
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: ownerId,
      ),
      gateway = _NativeGateway(tools),
      owner = ownerId;

  final AppDatabase database;
  final _NativeGateway gateway;
  final settings = AppSettingsService(store: _NativeSettings());
  final owners = StreamController<String?>.broadcast(sync: true);
  String? owner;
  PreferencesRepository? recoveryPreferences;

  Future<void> seedProfile({double target = 82, double? waist}) =>
      UserProfileRepository(database).save(
        gender: 'male',
        age: 35,
        height: 180,
        currentWeight: 88,
        targetWeight: target,
        activityLevel: 'moderate',
        exercises: true,
        waist: waist,
      );

  Future<List<Map<String, Object?>>> receipts() async {
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    if (raw == null) return [];
    final result = <Map<String, Object?>>[];
    for (final message in (jsonDecode(raw) as List).whereType<Map>()) {
      final evidence = message['evidence'];
      if (evidence is! List) continue;
      for (final item in evidence.whereType<String>()) {
        if (!item.startsWith('{')) continue;
        final receipt = jsonDecode(item);
        if (receipt is Map && receipt['committed'] == true) {
          result.add(Map<String, Object?>.from(receipt));
        }
      }
    }
    return result;
  }
}

class _NativeGateway implements LocalModelGateway {
  _NativeGateway(this.tools);
  final List<Map<String, Object?>> tools;
  int calls = 0;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async => LocalModelResult.answer(
    LocalModelAnswer(
      text: 'The action is ready for review.',
      action: tools[calls++],
    ),
  );
}

class _NativeSettings implements SettingsStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async => value = next;
}
