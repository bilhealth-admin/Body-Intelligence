import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_conversation_titles.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_conversation_rename_dialog.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';

class _FaultablePreferences extends PreferencesRepository {
  _FaultablePreferences(super.database);
  bool rejectWrite = false;
  @override
  Future<void> set(String key, String value) {
    if (rejectWrite) throw StateError('host_storage_full');
    return super.set(key, value);
  }
}

Map<String, Object?> _message(String id) => {
  'id': id,
  'role': 'user',
  'kind': 'freeQuestion',
  'text': 'Question $id',
  'createdAt': '2026-10-11T09:00:00Z',
  'evidence': <String>[],
  'missingData': <String>[],
};

class _PendingRenameReply implements LocalModelGateway {
  final pending = Completer<LocalModelResult>();
  int calls = 0;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) {
    calls++;
    return pending.future;
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 150 && !ready(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(ready(), isTrue);
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('bil/tts'), (call) async {
          expect(
            call.method,
            'stop',
            reason: 'Renaming must not synthesize or resend a reply',
          );
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('bil/tts'), null),
  );
  for (final options in [
    for (final mode in [
      'current',
      'past',
      'cancel',
      'failure',
      'ownerABA',
      'deleted',
      'reply',
    ])
      (mode, false, const Size(430, 932), 1.0, 'en'),
    ('current', true, const Size(320, 844), 2.0, 'ar'),
    ('current', false, const Size(320, 844), 2.0, 'en'),
    ('current', true, const Size(768, 1024), 1.0, 'en'),
  ]) {
    final mode = options.$1,
        dark = options.$2,
        size = options.$3,
        scale = options.$4,
        language = options.$5;
    final ar = language == 'ar';
    final settingsLabel = ar ? 'إعدادات المدرب' : 'Coach settings';
    final renameLabel = ar ? 'إعادة تسمية المحادثة' : 'Rename conversation';
    final frameName =
        '${dark ? 'dark' : 'light'}-$language-${size.width.toInt()}-${scale}x';
    testWidgets(
      'actual Coach rename $mode $frameName preserves local identity receipts and messages',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'A',
        );
        addTearDown(database.close);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
        });
        final preferences = _FaultablePreferences(database);
        final gateway = _PendingRenameReply();
        var replyHeld = false;
        Future<void> settle() async {
          // A held request has an animated progress indicator. Advancing a
          // fake clock with pumpAndSettle would expire its real 30s guard.
          if (replyHeld && !gateway.pending.isCompleted) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          } else {
            await tester.pumpAndSettle();
          }
        }

        final owners = StreamController<String?>.broadcast(sync: true);
        addTearDown(owners.close);
        var owner = 'A';
        final raw = jsonEncode({
          'version': 2,
          'activeConversationId': 'current',
          'unknownArchive': {'future': 1},
          'conversations': [
            {
              'id': 'current',
              'title': 'Original current',
              'createdAt': '2026-10-11',
              'messages': [
                {
                  ..._message('m1'),
                  'futureReceipt': {'id': 'r1'},
                },
              ],
            },
            {
              'id': 'past',
              'title': 'Original past',
              'messages': [_message('p1')],
              'futureEntry': ['keep'],
            },
            {'unknownEntry': true},
          ],
        });
        await preferences.setMany({
          coachConversationHistoryKey: raw,
          'intelligenceConversationV1': jsonEncode([_message('m1')]),
          'intelligenceConversationActiveIdV1': 'current',
        });
        Widget app() => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
            preferencesRepositoryProvider.overrideWithValue(preferences),
            coachNativeOwnerWitnessProvider.overrideWithValue(
              CoachNativeOwnerWitness(
                readOwner: () => owner,
                changes: owners.stream,
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
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: visualEvidenceTheme(
              dark
                  ? BilFlagshipTheme.dark(isArabic: ar)
                  : BilFlagshipTheme.light(isArabic: ar),
              fontFamily: ar ? 'NotoArabicEvidence' : 'RobotoEvidence',
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const IntelligenceCenterPage(),
          ),
        );
        await tester.pumpWidget(app());
        await settle();
        await _until(
          tester,
          () => find
              .byKey(const Key('ai-coach-question-field'))
              .evaluate()
              .isNotEmpty,
        );
        if (mode == 'current') {
          await settleVisualAssetImages(tester);
          await tester.pump();
          await captureClosureSurface(
            tester,
            find.byKey(const Key('ai-coach-hero')),
            'coach-chat-real-route-$frameName',
          );
        }
        if (mode == 'reply') {
          await tester.enterText(
            find.byKey(const Key('ai-coach-question-field')),
            'A question held while naming',
          );
          await tester.pump();
          await tester.tap(find.byKey(const Key('ai-coach-send-button')));
          await _until(tester, () => gateway.calls == 1);
          replyHeld = true;
        }
        if (mode == 'past') {
          await _until(
            tester,
            () => find
                .byKey(const Key('ai-coach-conversation-history-button'))
                .evaluate()
                .isNotEmpty,
          );
          await tester.tap(
            find.byKey(const Key('ai-coach-conversation-history-button')),
          );
          await settle();
          await _until(
            tester,
            () => find
                .byKey(const Key('ai-coach-conversation-actions-past'))
                .evaluate()
                .isNotEmpty,
          );
          await settle();
          await tester.ensureVisible(
            find.byKey(const Key('ai-coach-conversation-actions-past')),
          );
          await tester.tap(
            find.byKey(const Key('ai-coach-conversation-actions-past')),
          );
          await settle();
          if (mode == 'current') {
            await captureClosureSurface(
              tester,
              find.text(settingsLabel),
              'coach-menu-real-route-$frameName',
            );
          }
          await tester.ensureVisible(find.text(renameLabel));
          await tester.tap(find.text(renameLabel));
          await settle();
        } else {
          await tester.tap(
            find.byTooltip(ar ? 'أدوات المدرب' : 'Coach controls'),
          );
          await settle();
          if (mode == 'current') {
            await captureClosureSurface(
              tester,
              find.text(settingsLabel),
              'coach-menu-real-route-$frameName',
            );
          }
          await tester.ensureVisible(find.text(renameLabel));
          await tester.tap(find.text(renameLabel));
          await settle();
        }
        for (
          var attempt = 0;
          attempt < 100 &&
              find.byType(CoachConversationRenameDialog).evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(CoachConversationRenameDialog), findsOneWidget);
        final before = await preferences.get(coachConversationHistoryKey);
        if (mode == 'reply') {
          gateway.pending.complete(
            LocalModelResult.answer(
              LocalModelAnswer(
                text:
                    'The reply arrives while the editor is open. Every part must survive.',
                action: null,
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 5));
        }
        await tester.enterText(
          find.byKey(const Key('ai-coach-conversation-name')),
          'My 🥗 خطة',
        );
        if (mode == 'cancel') {
          await tester.tap(find.byKey(const Key('ai-coach-rename-cancel')));
          await settle();
          expect(await preferences.get(coachConversationHistoryKey), before);
        } else {
          if (mode == 'failure') preferences.rejectWrite = true;
          if (mode == 'ownerABA') {
            owner = 'B';
            owners.add(owner);
            owner = 'A';
            owners.add(owner);
          }
          if (mode == 'deleted') {
            await preferences.update(
              coachConversationHistoryKey,
              (raw) => deleteCoachConversationFromArchive(raw, 'current'),
            );
          }
          await tester.tap(find.byKey(const Key('ai-coach-rename-save')));
          await settle();
          if (['failure', 'ownerABA', 'deleted'].contains(mode)) {
            await _until(
              tester,
              () => find
                  .text('Could not save the name. Try again.')
                  .evaluate()
                  .isNotEmpty,
            );
            expect(
              find.text('Could not save the name. Try again.'),
              findsOneWidget,
            );
            if (mode != 'deleted') {
              expect(
                await preferences.get(coachConversationHistoryKey),
                before,
              );
            } else {
              expect(
                decodeCoachConversationHistory(
                  await preferences.get(coachConversationHistoryKey),
                ).conversations.any((row) => row['id'] == 'current'),
                isFalse,
              );
            }
            if (mode == 'failure') {
              preferences.rejectWrite = false;
              await tester.tap(find.byKey(const Key('ai-coach-rename-save')));
              await settle();
            } else {
              await tester.tap(find.byKey(const Key('ai-coach-rename-cancel')));
              await settle();
            }
          }
          if (['current', 'past', 'failure', 'reply'].contains(mode)) {
            await _until(
              tester,
              () =>
                  find.byType(CoachConversationRenameDialog).evaluate().isEmpty,
            );
            final stored =
                jsonDecode(
                      (await preferences.get(coachConversationHistoryKey))!,
                    )
                    as Map;
            final rows = stored['conversations'] as List;
            final changed = rows.firstWhere(
              (row) =>
                  row is Map &&
                  row['id'] == (mode == 'past' ? 'past' : 'current'),
            );
            expect(changed['title'], 'My 🥗 خطة');
            expect(changed['titleSource'], 'manual');
            expect(stored['unknownArchive'], {'future': 1});
            expect(rows.last, {'unknownEntry': true});
            final current = rows.firstWhere(
              (row) => row is Map && row['id'] == 'current',
            );
            expect(current['messages'], hasLength(mode == 'reply' ? 3 : 1));
            if (mode == 'reply') {
              expect(
                (current['messages'] as List).any(
                  (m) =>
                      m['text'] ==
                      'The reply arrives while the editor is open. Every part must survive.',
                ),
                isTrue,
                reason: jsonEncode(current['messages']),
              );
              expect(
                gateway.calls,
                1,
                reason: 'Naming cannot resend or interrupt the reply',
              );
            } else {
              expect(gateway.calls, 0);
            }
            expect(current['messages'].first['futureReceipt'], {'id': 'r1'});
            expect(
              await preferences.get('intelligenceConversationActiveIdV1'),
              'current',
            );
            if (mode == 'past') {
              await tester.binding.handlePopRoute();
              await settle();
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await settle();
            await tester.pumpWidget(app());
            await settle();
            await _until(
              tester,
              () =>
                  find
                      .byKey(const Key('ai-coach-conversation-history-button'))
                      .evaluate()
                      .isNotEmpty &&
                  tester
                          .widget<InkWell>(
                            find.byKey(
                              const Key('ai-coach-conversation-history-button'),
                            ),
                          )
                          .onTap !=
                      null,
            );
            await tester.tap(
              find.byKey(const Key('ai-coach-conversation-history-button')),
            );
            await settle();
            for (
              var attempt = 0;
              attempt < 100 && find.text('My 🥗 خطة').evaluate().isEmpty;
              attempt++
            ) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)),
              );
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(find.text('My 🥗 خطة'), findsOneWidget);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await settle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'rename editor Arabic 320 keyboard 2x validates empty name and uses real reachable actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      String? saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: ThemeData(fontFamily: 'NotoArabicEvidence'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (_) => CoachConversationRenameDialog(
                    title: '',
                    onSave: (name) async {
                      saved = name;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('ai-coach-rename-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('اكتب اسمًا للمحادثة.'), findsOneWidget);
      expect(saved, isNull);
      final field = find.byKey(const Key('ai-coach-conversation-name'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'خطة 🧑🏽‍💻 غذائي');
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await captureClosureSurface(
        tester,
        find.byType(CoachConversationRenameDialog),
        'rename-ar-320-keyboard-2x',
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, 'خطة 🧑🏽‍💻 غذائي');
      expect(tester.takeException(), isNull);
    },
  );
}
