import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_restore_conflict_controls.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_restore_conflict_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_restore_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_conflict_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_engine.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/nutrition/domain/macro_goal_editor.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (language, scale) in [('en', 1.0), ('ar', 2.5)]) {
    testWidgets(
      'equal-calorie conflict exposes changed macros: $language/$scale',
      (tester) async {
        final a = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'owner',
        );
        final b = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'owner',
        );
        final pa = PreferencesRepository(a), pb = PreferencesRepository(b);
        final server = _GoalServer();
        CloudRestoreV2Engine engine(AppDatabase db, String device) =>
            CloudRestoreV2Engine(
              database: db,
              ownerId: 'owner',
              deviceId: device,
              keyId: 'summary-test-key',
              cipher: const _ClearTestCipher(),
              transport: server,
              ownerIsCurrent: () => true,
            );
        final ea = engine(a, 'a'), eb = engine(b, 'b');
        Future<void> save(
          PreferencesRepository preferences,
          double grams,
        ) async {
          final allocation = const MacroGoalAllocation(
            1941,
            50,
            25,
            25,
          ).edit(MacroGoal.protein, grams, inGrams: true);
          await preferences.setMany({
            ...allocation.toPreferences(),
            'goal.macroEditor.v2': 'true',
            for (final key in NutritionGoalSnapshot.macroKeys)
              'goal.origin.$key': 'manual_override',
          });
          final values = await preferences
              .watchSnapshot(NutritionGoalSnapshot.storageKeys)
              .first;
          final goals = NutritionGoalSnapshot.resolve(values, {});
          expect(
            NutritionGoalSnapshot.macroKeys.every(
              (key) =>
                  goals.goals[key]!.value != null &&
                  !goals.goals[key]!.needsReview,
            ),
            isTrue,
          );
        }

        try {
          await tester.runAsync(() async {
            await LocalDataAccountBoundary(a).bindAuthenticatedOwner('owner');
            await LocalDataAccountBoundary(b).bindAuthenticatedOwner('owner');
            await save(pa, 125);
            expect((await ea.run({'goals'})).completed, isTrue);
            expect((await eb.run({'goals'})).completed, isTrue);
            await save(pa, 130);
            expect((await ea.run({'goals'})).completed, isTrue);
            await save(pb, 140);
            expect((await eb.run({'goals'})).conflicts, 1);
          });
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                cloudRestoreBaseConsentOffProvider.overrideWithValue(false),
                cloudRestoreConsentStateProvider.overrideWith(
                  (ref) async => const CloudRestoreConsentState(
                    availability: CloudRestoreConsentAvailability.available,
                    ownerId: 'owner',
                    grantedScopes: {CloudRestoreScope.goals},
                  ),
                ),
                cloudRestoreConflictServiceProvider.overrideWithValue(
                  CloudRestoreConflictService(() async => eb),
                ),
                cloudManualSyncStatusProvider.overrideWith(
                  (ref) => CloudManualSyncStatusController(
                    preferences: pb,
                    cloudAvailable: true,
                    ownerId: 'owner',
                    runSync: () async => const CloudManualSyncResult(
                      disposition: CloudManualSyncDisposition.unavailable,
                    ),
                  ),
                ),
              ],
              child: MaterialApp(
                locale: Locale(language),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ListView(
                    children: const [CloudRestoreConflictControls()],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          Future<void> open() async {
            final review = find.byKey(
              const Key('cloud-restore-review-conflicts'),
            );
            await tester.ensureVisible(review);
            expect(review.hitTestable(), findsOneWidget);
            await tester.tap(review);
            await _drain(
              tester,
              () => find.bySubtype<AlertDialog>().evaluate().isNotEmpty,
            );
            expect(find.bySubtype<AlertDialog>(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          await open();
          final protein = language == 'ar' ? 'البروتين' : 'Protein';
          final fat = language == 'ar' ? 'الدهون' : 'Fat';
          final gram = language == 'ar' ? 'غ' : 'g';
          final cloud = language == 'ar' ? 'السحابة: ' : 'Cloud: ';
          final localSummary = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data?.contains('$protein: 140 $gram') ?? false),
          );
          final cloudSummary = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data?.startsWith(cloud) ?? false) &&
                (widget.data?.contains('$protein: 130 $gram') ?? false),
          );
          expect(localSummary, findsOneWidget);
          expect(cloudSummary, findsOneWidget);
          expect(tester.widget<Text>(localSummary).data, contains('1941 kcal'));
          expect(tester.widget<Text>(cloudSummary).data, contains('1941 kcal'));
          expect(tester.widget<Text>(localSummary).data, contains('$fat:'));
          expect(tester.widget<Text>(cloudSummary).data, contains('$fat:'));
          // Carbohydrate is identical: show the actual differing macros only.
          expect(
            tester.widget<Text>(localSummary).data,
            isNot(
              contains(language == 'ar' ? 'الكربوهيدرات:' : 'Carbohydrate:'),
            ),
          );
          expect(find.textContaining('nutrition-goals'), findsNothing);
          expect(find.textContaining('server_revision'), findsNothing);
          expect(tester.takeException(), isNull);
          final before = server.accepted;
          final cancel = find.text(language == 'ar' ? 'إلغاء' : 'Cancel');
          await tester.ensureVisible(cancel);
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            expect(
              double.parse((await pb.get('goal.proteinGrams'))!),
              closeTo(140, 1e-9),
            );
            expect((await eb.conflicts({'goals'})), hasLength(1));
          });
          expect(server.accepted, before);
          if (language == 'en') {
            await open();
            final useCloud = find.byKey(const Key('restore-use-cloud'));
            await tester.ensureVisible(useCloud);
            await tester.tap(useCloud);
            await _drain(
              tester,
              () => find.text('Saved versions verified.').evaluate().isNotEmpty,
            );
            await tester.runAsync(() async {
              expect(
                double.parse((await pb.get('goal.proteinGrams'))!),
                closeTo(130, 1e-9),
              );
              expect(double.parse((await pb.get('goal.calories'))!), 1941);
              expect(await eb.conflicts({'goals'}), isEmpty);
              expect(
                (await eb.journal.entries('goals')).single.recovery,
                isNotNull,
              );
            });
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.runAsync(() async {
            await a.close();
            await b.close();
          });
        }
      },
    );
  }
}

Future<void> _drain(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

final class _ClearTestCipher implements CloudPayloadCipher {
  const _ClearTestCipher();
  @override
  bool get isAvailable => true;
  @override
  Future<Map<String, Object?>> encrypt(Map<String, Object?> value) async => {
    'clear': jsonEncode(value),
  };
  @override
  Future<Map<String, Object?>> decrypt(Map<String, Object?> value) async =>
      Map<String, Object?>.from(jsonDecode(value['clear']! as String) as Map);
}

// This is a deterministic revision fixture, not hosted SQL/RLS/crypto proof.
final class _GoalServer implements CloudRestoreV2Transport {
  int sequence = 0, accepted = 0;
  Map<String, Object?>? record;
  @override
  Future<Map<String, Object?>> capabilities() async => {
    'protocol_version': 2,
    'scopes': ['goals'],
  };
  @override
  Future<Map<String, Object?>> consent() async => {
    'goals': {'granted': true, 'policy_version': '1'},
  };
  @override
  Future<Map<String, Object?>> exchange({
    required String deviceId,
    required String scope,
    required int cursor,
    required List<Map<String, Object?>> operations,
    required int limit,
  }) async {
    final receipts = <Map<String, Object?>>[];
    for (final operation in operations) {
      final revision = record?['server_revision'] as int? ?? 0;
      final conflict = operation['expected_revision'] != revision;
      receipts.add({
        'operation_id': operation['operation_id'],
        'outcome': conflict ? 'conflict' : 'accepted',
        'server_revision': conflict ? revision : revision + 1,
        'replayed': false,
        if (conflict) 'current_record': record,
      });
      if (!conflict) {
        accepted++;
        sequence++;
        record = {
          'owner_id': 'owner',
          'scope': scope,
          'record_type': operation['record_type'],
          'record_id': operation['record_id'],
          'server_revision': revision + 1,
          'change_sequence': sequence,
          'deleted': false,
          'payload_version': operation['payload_version'],
          'payload': operation['payload'],
        };
      }
    }
    return {
      'protocol_version': 2,
      'scope': scope,
      'receipts': receipts,
      'records': record != null && sequence > cursor ? [record!] : [],
      'cursor': sequence > cursor ? sequence : cursor,
      'has_more': false,
    };
  }
}
