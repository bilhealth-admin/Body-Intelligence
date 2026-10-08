import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_fasting_commands.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/nutrition_plans/data/diet_plan_repository.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/diet_macro_plan.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart'
    show fastingNotificationServiceProvider;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

part 'health_coach_ui_fixture.dart';

const _healthUiInputs = {
  'log_sleep': 'I slept 7 hours on 2026-10-06',
  'log_exercise': 'log exercise walk 20 minutes on 2026-10-06',
};

void main() {
  _healthCoachAccessibilityCases();
  _healthCoachFastingDeviceCases();
  _healthCoachLostReceiptRecoveryCases();
  for (final input in _healthUiInputs.entries) {
    testWidgets('${input.key} requires fresh confirmation in writeAllowed', (
      tester,
    ) async {
      await _withHealthCoach(tester, (fixture) async {
        final original = await fixture.healthSnapshot();
        await _sendHealthPrompt(tester, input.value);
        await _expectHealthDialog(tester);
        expect(await fixture.healthSnapshot(), original);
        expect(await fixture.receipts(), isEmpty);

        await _confirmHealthDialog(tester);
        await _waitHealthReceipts(tester, fixture, 1);
        await _expectSavedDailyValue(fixture, input.key);
        final saved = await fixture.healthSnapshot();

        await _sendHealthPrompt(tester, input.value);
        await _expectHealthDialog(tester);
        expect(await fixture.healthSnapshot(), saved);
        await _cancelHealthDialog(tester);
        expect(await fixture.healthSnapshot(), saved);
        expect(await fixture.receipts(), hasLength(1));
        expect(fixture.gateway.calls, 0);
        expect(fixture.fullContextCalls, 0);
      }, seed: _seedHealthDaily);
    });
  }

  testWidgets(
    'cancelling model sleep and exercise proposals changes no health data',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final original = await fixture.healthSnapshot();
          for (final toolId in _healthUiInputs.keys) {
            await _openModelHealthAction(tester, toolId);
            expect(await fixture.healthSnapshot(), original);
            await _cancelHealthDialog(tester);
            expect(await fixture.healthSnapshot(), original);
            expect(await fixture.receipts(), isEmpty);
          }
          expect(fixture.gateway.calls, 2);
        },
        tools: [
          _healthTool('log_sleep', {'date': '2026-10-06', 'hours': 7}),
          _healthTool('log_exercise', {
            'date': '2026-10-06',
            'workoutId': 'walk',
            'minutes': 20,
          }),
        ],
        forbidFullContext: false,
        seed: _seedHealthDaily,
      );
    },
  );

  for (final input in _healthUiInputs.entries) {
    testWidgets(
      '${input.key} saved in the real page can Undo after route recreation',
      (tester) async {
        await _withHealthCoach(tester, (fixture) async {
          final original = (await fixture.daily.getForDay(
            _healthDay,
          ))!.toJson();
          await _sendHealthPrompt(tester, input.value);
          await _expectHealthDialog(tester);
          await _confirmHealthDialog(tester);
          await _waitHealthReceipts(tester, fixture, 1);
          await _expectSavedDailyValue(fixture, input.key);
          final receipt = (await fixture.receipts()).single;
          expect(receipt['verified'], isTrue);
          expect(receipt['tool_id'], input.key);
          expect(receipt['undoable'], isTrue);
          expect(receipt['after'], isNot(contains('dailyLog')));
          expect(receipt['after'], isNot(contains('record')));
          expect(jsonEncode(receipt), isNot(contains(_privateHealthNote)));

          await _remountHealthCoach(tester, fixture);
          await _undoHealthAction(tester);
          await _waitHealthReceipts(tester, fixture, 2);
          expect(
            (await fixture.daily.getForDay(_healthDay))!.toJson(),
            original,
          );
          final undo = (await fixture.receipts()).last;
          expect(undo['undone_at'], isNotNull);
          expect(undo['operation_id'], receipt['operation_id']);
          expect(undo['verified'], isTrue);
          expect(fixture.gateway.calls, 0);
        }, seed: _seedHealthDaily);
      },
    );
  }

  testWidgets(
    'local plan preview reads saved draft without activation or entitlement calls',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final original = await fixture.healthSnapshot();
          await _sendHealthPrompt(tester, 'preview plan high-protein');
          await _waitHealthReads(tester, fixture, 1);
          expect(find.byType(AlertDialog), findsNothing);
          final read = (await fixture.healthReads()).single;
          expect(read['tool_id'], 'preview_plan');
          expect(read['mutationsPerformed'], 0);
          final preview = read['result'] as Map;
          expect(preview['pathwayId'], 'high-protein');
          expect(preview['active'], isFalse);
          expect(preview['confirmationRequired'], isTrue);
          expect(
            (preview['draftWeekTargets'] as Map)['1'],
            containsPair('caloriesKcal', 1750),
          );
          expect(
            preview['activationRequirements'],
            containsPair('verifiedPremiumPrograms', true),
          );
          expect(await fixture.healthSnapshot(), original);
          expect(await fixture.planRepository.readActivePathway(), isNull);
          expect(await fixture.receipts(), isEmpty);
          expect(fixture.subscriptionCalls, 0);
          expect(fixture.gateway.calls, 0);
          expect(fixture.fullContextCalls, 0);
        },
        seed: (fixture) => fixture.planRepository.saveDraft(
          DietDraft(
            pathwayId: 'high-protein',
            calories: 1750,
            fatLevel: DietFatLevel.medium,
            carbsByWeekday: uniformWeeklyCarbs(100),
          ),
        ),
      );
    },
  );

  testWidgets(
    'model clinical flag leaves checkbox unchecked until user reviews plan',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final original = await fixture.healthSnapshot();
          await _openModelHealthAction(tester, 'activate_plan');
          final checkbox = find.byType(CheckboxListTile);
          expect(checkbox, findsOneWidget);
          expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
          final confirm = find.widgetWithText(FilledButton, 'Continue');
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          expect(await fixture.healthSnapshot(), original);
          expect(fixture.subscriptionCalls, 0);

          await Scrollable.ensureVisible(
            tester.element(checkbox),
            alignment: .5,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(checkbox);
          await tester.pump();
          expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          await _confirmHealthDialog(tester);
          await _waitHealthReceipts(tester, fixture, 1);
          expect(await fixture.planRepository.readActivePathway(), 'keto');
          expect((await fixture.schedule.read()).dayTargets, hasLength(7));
          final receipt = (await fixture.receipts()).single;
          expect(receipt['tool_id'], 'activate_plan');
          expect(receipt['verified'], isTrue);
          expect(
            receipt['after'],
            containsPair('clinicianReviewConfirmed', true),
          );
          expect(fixture.subscriptionCalls, 1);
          expect(fixture.gateway.calls, 1);
        },
        tools: [
          _healthTool('activate_plan', {
            'pathwayId': 'keto',
            'clinicianReviewConfirmed': true,
          }),
        ],
        forbidFullContext: false,
      );
    },
  );

  testWidgets(
    'checking clinical review cannot adopt a draft edited during the dialog',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          await _openModelHealthAction(tester, 'activate_plan');
          final changedDraft = DietDraft(
            pathwayId: 'keto',
            calories: 1750,
            fatLevel: DietFatLevel.medium,
            carbsByWeekday: uniformWeeklyCarbs(40),
          );
          await fixture.planRepository.saveDraft(changedDraft);
          final changed = await fixture.healthSnapshot();
          final checkbox = find.byType(CheckboxListTile);
          expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
          await Scrollable.ensureVisible(
            tester.element(checkbox),
            alignment: .5,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(checkbox);
          await tester.pump();
          await _confirmHealthDialog(tester);
          expect(await fixture.healthSnapshot(), changed);
          expect(await fixture.planRepository.readActivePathway(), isNull);
          expect(
            (await fixture.planRepository.read('keto')).encode(),
            changedDraft.encode(),
          );
          expect(await fixture.receipts(), isEmpty);
          expect(fixture.subscriptionCalls, 0);
          expect(fixture.gateway.calls, 1);
        },
        tools: [
          _healthTool('activate_plan', {'pathwayId': 'keto'}),
        ],
        forbidFullContext: false,
      );
    },
  );

  final mutations = {
    ..._healthUiInputs,
    'activate_plan': 'activate plan carb-cycling',
  };
  for (final input in mutations.entries) {
    final restorePermission = input.key != 'log_sleep';
    testWidgets(
      '${input.key} rejects permission revoked during dialog, restored=$restorePermission',
      (tester) async {
        await _withHealthCoach(tester, (fixture) async {
          final original = await fixture.healthSnapshot();
          await _sendHealthPrompt(tester, input.value);
          await _expectHealthDialog(tester);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(IntelligenceCenterPage)),
          );
          container.read(coachActionPermissionModeProvider.notifier).state =
              CoachActionPermissionMode.readOnly;
          if (restorePermission) {
            container.read(coachActionPermissionModeProvider.notifier).state =
                CoachActionPermissionMode.writeAllowed;
          }
          await _confirmHealthDialog(tester);
          expect(await fixture.healthSnapshot(), original);
          expect(await fixture.receipts(), isEmpty);
          expect(fixture.subscriptionCalls, 0);
          expect(fixture.gateway.calls, 0);
        }, seed: _seedHealthDaily);
      },
    );

    testWidgets('${input.key} rejects delivered owner A B A during dialog', (
      tester,
    ) async {
      await _withHealthCoach(tester, (fixture) async {
        final original = await fixture.healthSnapshot();
        await _sendHealthPrompt(tester, input.value);
        await _expectHealthDialog(tester);
        fixture.owner = 'owner-b';
        fixture.owners.add('owner-b');
        fixture.owner = 'owner-a';
        fixture.owners.add('owner-a');
        await _confirmHealthDialog(tester);
        expect(await fixture.healthSnapshot(), original);
        expect(await fixture.receipts(), isEmpty);
        expect(fixture.subscriptionCalls, 0);
        expect(fixture.gateway.calls, 0);
      }, seed: _seedHealthDaily);
    });
  }

  testWidgets(
    'sleep read uses only requested days and never builds full context or calls model',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          expect(fixture.fullContextCalls, 0);
          final original = await fixture.healthSnapshot();
          fixture.daily.requestedDays.clear();
          await _sendHealthPrompt(tester, 'show sleep history 2 days');
          await _waitHealthReads(tester, fixture, 1);
          expect(find.byType(AlertDialog), findsNothing);
          final read = (await fixture.healthReads()).single;
          final result = read['result'] as Map;
          expect(read['tool_id'], 'read_health_history');
          expect(read['mutationsPerformed'], 0);
          expect(result['topic'], 'sleep');
          expect(result['from'], '2026-10-06');
          expect(result['through'], '2026-10-07');
          expect(result['queriedDays'], 2);
          expect((result['rows'] as List).map((row) => (row as Map)['day']), [
            '2026-10-07',
            '2026-10-06',
          ]);
          // The query uses civil days and the chat may refresh its bounded
          // current-day brief after conversation persistence. Neither path
          // should read an older day or assemble the full history.
          expect(
            fixture.daily.requestedDays
                .map((day) => DateTime(day.year, day.month, day.day))
                .toSet(),
            {DateTime(2026, 10, 7), DateTime(2026, 10, 6)},
          );
          expect(fixture.daily.requestedDays.length, lessThanOrEqualTo(4));
          expect(jsonEncode(read), isNot(contains(_privateHealthNote)));
          expect(jsonEncode(read), isNot(contains('2026-10-05')));
          expect(fixture.daily.fullHistoryCalls, 0);
          expect(fixture.fullContextCalls, 0);
          expect(fixture.gateway.calls, 0);
          expect(await fixture.healthSnapshot(), original);
        },
        seed: (fixture) async {
          await fixture.preferences.set(
            CoachContextPreferences.storageKey,
            const CoachContextPreferences(
              focuses: {CoachContextFocus.habits},
            ).encode(),
          );
          for (final day in [5, 6, 7]) {
            await fixture.daily.save(
              date: DateTime(2026, 10, day),
              sleepHours: day.toDouble(),
              notes: _privateHealthNote,
            );
          }
        },
      );
    },
  );

  testWidgets(
    'disabled habits focus blocks sleep read before any daily query',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final original = await fixture.healthSnapshot();
          fixture.daily.requestedDays.clear();
          await _sendHealthPrompt(tester, 'show sleep history 2 days');
          await tester.pumpAndSettle();
          final messages = await fixture.messages();
          expect(
            messages.any(
              (message) => message['text'].toString().contains(
                'This category is disabled in Coach context settings',
              ),
            ),
            isTrue,
          );
          expect(await fixture.healthReads(), isEmpty);
          expect(fixture.daily.requestedDays, isEmpty);
          expect(fixture.daily.fullHistoryCalls, 0);
          expect(fixture.fullContextCalls, 0);
          expect(fixture.gateway.calls, 0);
          expect(await fixture.healthSnapshot(), original);
        },
        seed: (fixture) async {
          await _seedHealthDaily(fixture);
          await fixture.preferences.set(
            CoachContextPreferences.storageKey,
            const CoachContextPreferences(focuses: {}).encode(),
          );
        },
      );
    },
  );

  testWidgets(
    'ambiguous local sleep request clarifies without model or mutation',
    (tester) async {
      await _withHealthCoach(tester, (fixture) async {
        final original = await fixture.healthSnapshot();
        await _sendHealthPrompt(tester, 'I slept 7 or 8 hours yesterday');
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          (await fixture.messages()).any(
            (message) => message['text'].toString().contains(
              'Please give one clear health action',
            ),
          ),
          isTrue,
        );
        expect(await fixture.healthSnapshot(), original);
        expect(await fixture.receipts(), isEmpty);
        expect(await fixture.healthReads(), isEmpty);
        expect(fixture.gateway.calls, 0);
        expect(fixture.fullContextCalls, 0);
      }, seed: _seedHealthDaily);
    },
  );

  testWidgets(
    'silent database write failure cannot show successful sleep save',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final original = await fixture.healthSnapshot();
          await _sendHealthPrompt(tester, _healthUiInputs['log_sleep']!);
          await _expectHealthDialog(tester);
          await _confirmHealthDialog(tester);
          expect(await fixture.healthSnapshot(), original);
          expect(await fixture.receipts(), isEmpty);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          expect(
            (await fixture.messages()).any(
              (message) => message['text'].toString().contains(
                'Saved 7 hours of manual sleep',
              ),
            ),
            isFalse,
          );
          expect(fixture.gateway.calls, 0);
          expect(fixture.fullContextCalls, 0);
        },
        seed: (fixture) async {
          await _seedHealthDaily(fixture);
          await fixture.database.customStatement('''
CREATE TRIGGER ignore_health_sleep_write BEFORE UPDATE ON daily_logs
BEGIN
  SELECT RAISE(IGNORE);
END
''');
        },
      );
    },
  );
}

void _healthCoachLostReceiptRecoveryCases() {
  testWidgets(
    'failed postcommit readback recovers exact receipt and Undo after reopening Coach',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final fault = fixture.preferences as _HealthUiPostCommitPreferences;
          final prior = (await fixture.daily.getForDay(_healthDay))!.toJson();
          await _sendHealthPrompt(tester, _healthUiInputs['log_exercise']!);
          await _expectHealthDialog(tester);
          await _confirmHealthDialog(tester);
          await _waitForHealthPostCommitReadback(tester, fault);
          expect(fault.interceptions, greaterThan(0));
          await _expectSavedDailyValue(fixture, 'log_exercise');
          final saved = (await fixture.daily.getForDay(_healthDay))!.toJson();
          final journal = (await fixture.nativeJournals()).single;
          final conversationId = (await fixture.preferences.get(
            'intelligenceConversationActiveIdV1',
          ))!;
          _expectHealthRecoveryMetadata(
            journal,
            acknowledged: false,
            conversationId: conversationId,
          );
          expect(await fixture.receipts(), isEmpty);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);

          await _unmountHealthCoach(tester);
          fault.release();
          fault.pauseReceiptSave();
          try {
            await tester.pumpWidget(_healthCoachApp(fixture));
            for (
              var attempt = 0;
              attempt < 30 && !fault.reachedReceiptSave.isCompleted;
              attempt++
            ) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(fault.reachedReceiptSave.isCompleted, isTrue);
            expect(await fixture.receipts(), isEmpty);
            _expectHealthRecoveryMetadata(
              (await fixture.nativeJournals()).single,
              acknowledged: false,
              conversationId: conversationId,
            );
          } finally {
            fault.releaseReceiptSave();
          }
          await _waitHealthReceipts(tester, fixture, 1);
          final recovered = (await fixture.receipts()).single;
          _expectRecoveredHealthReceipt(recovered, journal);
          await _waitHealthReceiptAcknowledged(
            tester,
            fixture,
            conversationId: conversationId,
            receipt: recovered,
          );
          expect((await fixture.daily.getForDay(_healthDay))!.toJson(), saved);
          expect(await fixture.nativeJournals(), hasLength(1));

          await _remountHealthCoach(tester, fixture);
          expect(await fixture.receipts(), hasLength(1));
          expect((await fixture.daily.getForDay(_healthDay))!.toJson(), saved);
          await _undoHealthAction(tester);
          await _waitHealthReceipts(tester, fixture, 2);
          expect((await fixture.daily.getForDay(_healthDay))!.toJson(), prior);
          expect(
            (await fixture.receipts()).last['operation_id'],
            recovered['operation_id'],
          );
          expect((await fixture.receipts()).last['undone_at'], isNotNull);
          expect(await fixture.nativeJournals(), hasLength(1));
          expect(fixture.gateway.calls, 0);
          expect(fixture.fullContextCalls, 0);
        },
        seed: _seedHealthDaily,
        preferencesFactory: (database) => _HealthUiPostCommitPreferences(
          database,
          mode: _HealthUiReadbackFault.unavailable,
        ),
      );
    },
  );

  testWidgets(
    'approved health commit finishing after route close recovers one receipt and Undo',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final fault = fixture.preferences as _HealthUiPostCommitPreferences;
          final prior = (await fixture.daily.getForDay(_healthDay))!.toJson();
          try {
            await _sendHealthPrompt(tester, _healthUiInputs['log_exercise']!);
            await _expectHealthDialog(tester);
            await _confirmHealthDialog(tester);
            await _waitForHealthPostCommitReadback(tester, fault);
            // The original health transaction has committed. Its separate
            // readback holds a DB read transaction until this controlled gate
            // opens, so external DB reads intentionally wait until after close.
            expect(
              (fault.observedJournal!['command'] as Map)['toolId'],
              'log_exercise',
            );
            expect(
              (fault.observedJournal!['healthReceiptRecovery']
                  as Map)['receiptAcknowledged'],
              isFalse,
            );
            expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
            await _unmountHealthCoach(tester);
          } finally {
            fault.release();
          }
          await tester.pump();
          await tester.pump(Duration.zero);
          await _expectSavedDailyValue(fixture, 'log_exercise');
          final saved = (await fixture.daily.getForDay(_healthDay))!.toJson();
          final journal = (await fixture.nativeJournals()).single;
          final conversationId = (await fixture.preferences.get(
            'intelligenceConversationActiveIdV1',
          ))!;
          _expectHealthRecoveryMetadata(
            journal,
            acknowledged: false,
            conversationId: conversationId,
          );
          expect(await fixture.receipts(), isEmpty);

          await tester.pumpWidget(_healthCoachApp(fixture));
          await tester.pumpAndSettle();
          await _waitHealthReceipts(tester, fixture, 1);
          final recovered = (await fixture.receipts()).single;
          _expectRecoveredHealthReceipt(recovered, journal);
          await _waitHealthReceiptAcknowledged(
            tester,
            fixture,
            conversationId: conversationId,
            receipt: recovered,
          );
          expect((await fixture.daily.getForDay(_healthDay))!.toJson(), saved);
          expect(await fixture.nativeJournals(), hasLength(1));
          await _remountHealthCoach(tester, fixture);
          expect(await fixture.receipts(), hasLength(1));
          expect((await fixture.daily.getForDay(_healthDay))!.toJson(), saved);
          expect(await fixture.nativeJournals(), hasLength(1));
          await _undoHealthAction(tester);
          await _waitHealthReceipts(tester, fixture, 2);
          expect((await fixture.daily.getForDay(_healthDay))!.toJson(), prior);
          expect(
            (await fixture.receipts()).last['operation_id'],
            recovered['operation_id'],
          );
          expect((await fixture.receipts()).last['undone_at'], isNotNull);
          expect(fixture.gateway.calls, 0);
          expect(fixture.fullContextCalls, 0);
        },
        seed: _seedHealthDaily,
        preferencesFactory: (database) => _HealthUiPostCommitPreferences(
          database,
          mode: _HealthUiReadbackFault.paused,
        ),
      );
    },
  );
}

void _healthCoachAccessibilityCases() {
  testWidgets(
    'Arabic sleep review has RTL and an accessible tappable Continue label',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          await _sendHealthPrompt(tester, 'نمت 7 ساعات أمس');
          await _expectHealthDialog(tester);
          expect(
            Directionality.of(tester.element(find.byType(AlertDialog))),
            TextDirection.rtl,
          );
          expect(find.textContaining('نوم مسجلة يدويًا'), findsOneWidget);
          final button = find.widgetWithText(FilledButton, 'متابعة');
          expect(tester.getSemantics(button).label, 'متابعة');
          final accessible = find.bySemanticsLabel('متابعة');
          expect(accessible.hitTestable(), findsOneWidget);
          await tester.tap(accessible);
          await tester.pumpAndSettle();
          await _waitHealthReceipts(tester, fixture, 1);
          await _expectSavedDailyValue(fixture, 'log_sleep');
          expect(
            (await fixture.messages()).any(
              (message) =>
                  message['text'].toString().contains('ساعات نوم يدويًا'),
            ),
            isTrue,
          );
          expect((await fixture.receipts()).single['tool_id'], 'log_sleep');
          expect(fixture.gateway.calls, 0);
          expect(fixture.fullContextCalls, 0);
        },
        seed: _seedHealthDaily,
        locale: const Locale('ar'),
        enableSemantics: true,
      );
    },
  );

  testWidgets(
    'Arabic exercise review uses trusted Arabic name and accessible cancel',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          final original = await fixture.healthSnapshot();
          await _sendHealthPrompt(tester, 'سجل تمرين مشي 20 دقيقة أمس');
          await _expectHealthDialog(tester);
          expect(
            Directionality.of(tester.element(find.byType(AlertDialog))),
            TextDirection.rtl,
          );
          expect(find.textContaining('مشي سريع'), findsOneWidget);
          expect(
            tester
                .getSemantics(find.widgetWithText(FilledButton, 'متابعة'))
                .label,
            'متابعة',
          );
          final cancel = find.bySemanticsLabel('إلغاء');
          expect(cancel.hitTestable(), findsOneWidget);
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(await fixture.healthSnapshot(), original);
          expect(await fixture.receipts(), isEmpty);
          expect(fixture.gateway.calls, 0);
          expect(fixture.fullContextCalls, 0);
        },
        seed: _seedHealthDaily,
        locale: const Locale('ar'),
        enableSemantics: true,
      );
    },
  );

  testWidgets(
    '320px health review at text scale 2 has no overflow and keeps Continue accessible',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          expect(tester.getSize(find.byType(Scaffold)).width, 320);
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(IntelligenceCenterPage)),
            ).scale(10),
            20,
          );
          await _sendHealthPrompt(tester, _healthUiInputs['log_exercise']!);
          await _expectHealthDialog(tester);
          expect(tester.takeException(), isNull);
          final button = find.widgetWithText(FilledButton, 'Continue');
          await Scrollable.ensureVisible(tester.element(button), alignment: .5);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.getSemantics(button).label, 'Continue');
          final accessible = find.bySemanticsLabel('Continue');
          expect(accessible.hitTestable(), findsOneWidget);
          await tester.tap(accessible);
          await tester.pumpAndSettle();
          await _waitHealthReceipts(tester, fixture, 1);
          await _expectSavedDailyValue(fixture, 'log_exercise');
          expect(tester.takeException(), isNull);
          expect(fixture.gateway.calls, 0);
        },
        seed: _seedHealthDaily,
        surfaceSize: const Size(320, 932),
        textScale: 2,
        enableSemantics: true,
      );
    },
  );
}

void _healthCoachFastingDeviceCases() {
  testWidgets(
    'fasting save stays verified while UI reports denied device notifications',
    (tester) async {
      await _withHealthCoach(
        tester,
        (fixture) async {
          await _waitForInitialFastingReconciliation(tester, fixture);
          await _sendHealthPrompt(tester, 'start fasting 16 hours now');
          await _expectHealthDialog(tester);
          await _confirmHealthDialog(tester);
          await _waitHealthReceipts(tester, fixture, 1);
          for (var attempt = 0; attempt < 30; attempt++) {
            if ((await fixture.messages()).any(
              (message) => message['text'].toString().contains(
                'The device has not allowed notifications',
              ),
            )) {
              break;
            }
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(
            (await fixture.messages()).any(
              (message) => message['text'].toString().contains(
                'The device has not allowed notifications',
              ),
            ),
            isTrue,
          );
          final saved = await CoachFastingCommandAdapter(
            fixture.preferences,
          ).read(checkAccess: () {});
          expect(saved['active'], isTrue);
          expect(saved['targetHours'], 16);
          final receipt = (await fixture.receipts()).single;
          expect(receipt['tool_id'], 'start_fasting');
          expect(receipt['verified'], isTrue);
          expect(receipt['after'], containsPair('active', true));
          expect(receipt['after'], isNot(contains('targetReminderScheduled')));
          expect(fixture.notifications.permissionChecks, 1);
          expect(fixture.notifications.permissionRequests, 0);
          expect(fixture.notifications.schedulingCalls, 0);
          expect(
            await fixture.preferences.get(
              CoachFastingCommandAdapter.notifyTargetKey,
            ),
            'true',
          );
          await _remountHealthCoach(tester, fixture);
          expect(
            await CoachFastingCommandAdapter(
              fixture.preferences,
            ).read(checkAccess: () {}),
            saved,
          );
          expect(await fixture.receipts(), hasLength(1));
          expect(fixture.gateway.calls, 0);
        },
        seed: (fixture) => fixture.preferences.set(
          CoachFastingCommandAdapter.notifyTargetKey,
          'true',
        ),
      );
    },
  );

  testWidgets(
    'closing route cancels a hung fasting device deadline after durable save',
    (tester) async {
      await _withHealthCoach(tester, (fixture) async {
        await _waitForInitialFastingReconciliation(tester, fixture);
        final deviceGate = Completer<void>();
        fixture.notifications.cancellationGate = deviceGate;
        final deadlines = <Timer>[];
        try {
          await runZoned(
            () async {
              await _sendHealthPrompt(tester, 'start fasting 16 hours now');
              await _expectHealthDialog(tester);
              await _confirmHealthDialog(tester);
              await _waitHealthReceipts(tester, fixture, 1);
              for (
                var attempt = 0;
                attempt < 20 && !fixture.notifications.cancellationWaiting;
                attempt++
              ) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(fixture.notifications.cancellationWaiting, isTrue);
              expect(deadlines, hasLength(1));
              expect(deadlines.single.isActive, isTrue);
              final saved = await fixture.healthSnapshot();
              final receipt = (await fixture.receipts()).single;
              expect(receipt['tool_id'], 'start_fasting');
              expect(receipt['verified'], isTrue);
              expect(receipt['after'], containsPair('active', true));

              await _unmountHealthCoach(tester);
              expect(deadlines.single.isActive, isFalse);
              expect(deviceGate.isCompleted, isFalse);
              expect(await fixture.healthSnapshot(), saved);
              expect(await fixture.receipts(), hasLength(1));
            },
            zoneSpecification: ZoneSpecification(
              createTimer: (self, parent, zone, duration, callback) {
                final timer = parent.createTimer(zone, duration, callback);
                if (duration == const Duration(seconds: 5)) {
                  deadlines.add(timer);
                }
                return timer;
              },
            ),
          );
        } finally {
          deviceGate.complete();
          fixture.notifications.cancellationGate = null;
          await tester.pump();
          await tester.pump(Duration.zero);
        }
        expect(fixture.notifications.permissionChecks, 0);
        expect(fixture.notifications.schedulingCalls, 0);
        expect(fixture.gateway.calls, 0);
      });
    },
  );
}
