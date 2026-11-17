import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
// Integration-proposal dependency: run only on the declared BIL-02 validation
// overlay containing intelligence_media_confirmation.dart and page wiring.
// These are real Flutter page + isolated Drift tests with synthetic catalog and
// recognition inputs. They are not device, live-provider, or BIL-01 composition
// evidence. No model, production service, camera, or paid quota is used.
import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/recoverable_image_picker.dart';
import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_catalog_entry.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_food_bridge.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/unified_food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_receipt_card.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_review_card.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:body_intelligence_log/shared/widgets/bil_camera_capture_page.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/intelligence_center/coach_review_actions_regression_test.dart'
    as base;
import '../../features/nutrition/food_basis_fixtures.dart';

const _barcode = '4006381333931';
const _owner = 'bil02-synthetic-page-owner';
final _ownerKey = LocalDatabaseScope.keyForOwner(_owner);
final _day = DateTime(2026, 10, 7);

final class _PageFixture {
  _PageFixture(this.database);

  final AppDatabase database;
  final owners = StreamController<String?>.broadcast(sync: true);
  final gateway = base.Gateway();
  final rows = <Food>[];
  String? currentOwner = _owner;
  GoRouter? router;

  List<CoachMediaCatalogEntry> get entries => [
    for (final row in rows)
      CoachMediaCatalogEntry.fromLocalFood(row, ownerKey: _ownerKey)!,
  ];

  void switchAwayAndBack() {
    currentOwner = 'another-synthetic-owner';
    owners.add(currentOwner);
    currentOwner = _owner;
    owners.add(currentOwner);
  }
}

Future<_PageFixture> _fixture(WidgetTester tester, {int foodCount = 1}) async {
  final fixture = (await tester.runAsync(() async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: _owner,
    );
    final result = _PageFixture(database);
    await database.customSelect('SELECT 1').get();
    for (var index = 1; index <= foodCount; index++) {
      final snapshot = CoachFoodSnapshot(
        identity: 'synthetic-media-identity-$index',
        name: 'Synthetic media food $index',
        preparedState: 'cooked',
        basisGrams: 100,
        nutrients: CoachFoodNutrients(const {
          FoodNutrient.calories: 200,
          FoodNutrient.protein: null,
          FoodNutrient.carbohydrates: 20,
          FoodNutrient.fat: 7,
          FoodNutrient.fiber: 0,
          FoodNutrient.sodium: null,
        }),
        source: CoachFoodSourceEvidence(
          kind: CoachFoodSourceKind.label,
          ref: 'synthetic-reviewed-label-$index',
          revision: 'synthetic-label-revision-1',
        ),
      );
      final row = basisFood(snapshot: snapshot).copyWith(
        id: index,
        uuid: 'synthetic-media-local-row-$index',
        barcode: const Value(_barcode),
      );
      await database.into(database.foods).insert(row);
      result.rows.add(row);
    }
    return result;
  }))!;
  addTearDown(() async {
    fixture.router?.dispose();
    await fixture.owners.close();
    await fixture.database.close();
  });
  return fixture;
}

Future<void> _mount(
  WidgetTester tester,
  _PageFixture fixture, {
  String? barcode = _barcode,
  CoachActionPermissionMode permission =
      CoachActionPermissionMode.askBeforeWrite,
  CoachMediaCatalogLookup? lookup,
  Future<UnifiedFoodRepository?> Function()? installedCatalog,
  ImagePicker? picker,
  MealImageAnalysisService Function(String)? analysis,
  Future<BilRuntimePermissionState> Function(BilRuntimeCapability)?
  runtimePermission,
  bool arabic = false,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  // The page stops local TTS/speech during teardown even in a barcode-only
  // visit. Keep those native cleanup calls local and deterministic.
  for (final name in ['bil/tts', 'bil/speech', 'bil/mic_sound']) {
    final channel = MethodChannel(name);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    // Asynchronous native speech stop can complete after the current page
    // unmounts. Keep the isolated mock for the entire test file, clearing it
    // in tearDownAll rather than racing a late platform cleanup.
  }
  final router = GoRouter(
    initialLocation: '/intelligence-center',
    routes: [
      GoRoute(
        path: '/intelligence-center',
        builder: (_, _) => IntelligenceCenterPage(initialBarcode: barcode),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Synthetic dashboard')),
      ),
      GoRoute(
        path: '/daily-log',
        builder: (_, _) => const Scaffold(body: Text('Synthetic daily log')),
      ),
    ],
  );
  fixture.router = router;
  addTearDown(() => _unmount(tester));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        coachNativeOwnerWitnessProvider.overrideWithValue(
          CoachNativeOwnerWitness(
            readOwner: () => fixture.currentOwner,
            changes: fixture.owners.stream,
          ),
        ),
        coachActionPermissionModeProvider.overrideWith((ref) => permission),
        selectedLogDateProvider.overrideWith((ref) => _day),
        intelligenceConversationClockProvider.overrideWithValue(
          () => DateTime(2026, 10, 7, 12),
        ),
        intelligenceCenterModelGatewayProvider.overrideWithValue(
          fixture.gateway,
        ),
        intelligenceCoachMealVisionConsentProvider.overrideWithValue(
          (_) async => true,
        ),
        if (lookup != null)
          intelligenceCoachMediaCatalogProvider.overrideWithValue(
            (_) => lookup,
          ),
        // Keep existing local-only fixtures hermetic. The dedicated installed
        // catalog case below injects the real immutable bundled USDA catalog.
        intelligenceCoachInstalledCatalogProvider.overrideWithValue(
          (ownerKey) => CoachMediaInstalledCatalogLookup(
            ownerKey: ownerKey,
            openCatalog: installedCatalog ?? () async => null,
          ),
        ),
        if (picker != null)
          intelligenceCoachImagePickerProvider.overrideWithValue(
            BilRecoverableImagePicker(picker: picker, isAndroid: false),
          ),
        if (analysis != null)
          intelligenceCoachImageAnalysisProvider.overrideWithValue(analysis),
        if (runtimePermission != null)
          intelligenceCoachMediaRuntimePermissionProvider.overrideWithValue(
            runtimePermission,
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
      child: MaterialApp.router(
        locale: Locale(arabic ? 'ar' : 'en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  // The default Coach entry is Overview. The media bridge explicitly enters
  // the conversation before testing its original barcode/photo contract.
  final chatEntry = find.byKey(const Key('coach-workspace-tab-coach'));
  final field = find.byKey(
    const Key('ai-coach-question-field'),
    skipOffstage: false,
  );
  // Route mounting is asynchronous. Wait for the actual Overview or Chat,
  // rather than assuming the first router frame already contains either.
  for (var turn = 0; turn < 30; turn++) {
    await _drain(tester);
    if (chatEntry.evaluate().isNotEmpty || field.evaluate().isNotEmpty) {
      break;
    }
  }
  if (chatEntry.evaluate().isNotEmpty) {
    expect(find.byKey(const Key('coach-reference-workspace')), findsOneWidget);
    await tester.tap(chatEntry);
    await _drain(tester);
  }
  for (var turn = 0; turn < 30; turn++) {
    await _drain(tester);
    if (field.evaluate().length == 1 &&
        tester.widget<TextField>(field).enabled == true) {
      break;
    }
  }
  expect(tester.widget<TextField>(field).enabled, isTrue);
}

Future<void> _drain(WidgetTester tester) async {
  // Let actual Drift futures complete outside the widget fake clock.
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  await tester.pump();
  // Matching deliberately stays busy while its child picker is open. Wait
  // for its route transition without trying to settle the indefinite status.
  if (find
      .byKey(const Key('premium-vision-matching-status'))
      .evaluate()
      .isNotEmpty) {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
    return;
  }
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var turn = 0; turn < 30 && finder.evaluate().isEmpty; turn++) {
    await _drain(tester);
  }
  expect(finder, findsOneWidget);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _drain(tester);
}

// Premium Vision uses a Dialog rather than the legacy AlertDialog. Both
// flows must retain an initially disabled action and a verified-food check.
Finder get _matchUse {
  final premium = find.byKey(const Key('premium-vision-use-food'));
  if (premium.evaluate().isNotEmpty) return premium;
  return find.descendant(
    of: find.bySubtype<AlertDialog>(),
    matching: find.byType(FilledButton),
  );
}

Future<void> _chooseMatch(WidgetTester tester, String name) async {
  // Premium repeats the recognized name in its heading. Select the actual
  // catalog row, not a text matcher that also sees the recognition heading.
  final row = find.widgetWithText(ListTile, name);
  await _until(tester, row);
  expect(tester.widget<FilledButton>(_matchUse).onPressed, isNull);
  await tester.tap(row);
  await tester.pump();
  expect(tester.widget<FilledButton>(_matchUse).onPressed, isNotNull);
  await tester.tap(_matchUse);
  await _drain(tester);
}

Future<CoachFoodReviewCard> _enterGrams(
  WidgetTester tester, {
  String grams = '150',
}) async {
  await _until(tester, find.byKey(const Key('bil02-media-grams')));
  await tester.enterText(find.byKey(const Key('bil02-media-grams')), grams);
  await tester.tap(find.byKey(const Key('bil02-media-grams-continue')));
  await _until(tester, find.byType(CoachFoodReviewCard));
  return tester.widget<CoachFoodReviewCard>(find.byType(CoachFoodReviewCard));
}

Future<void> _expectNoMeal(WidgetTester tester, _PageFixture fixture) async {
  await tester.runAsync(() async {
    expect(
      await fixture.database.select(fixture.database.mealItems).get(),
      isEmpty,
    );
    expect(
      await fixture.database.select(fixture.database.meals).get(),
      isEmpty,
    );
    expect(
      await (fixture.database.select(
        fixture.database.preferences,
      )..where((row) => row.key.like('coachMealOperationV1.%'))).get(),
      isEmpty,
    );
  });
  expect(find.byType(CoachFoodReceiptCard), findsNothing);
  expect(fixture.gateway.questions, isEmpty);
}

final class _SyntheticPicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile('synthetic-photo-not-read-by-test-provider.jpg');
}

final class _SyntheticAnalysis extends MealImageAnalysisService {
  _SyntheticAnalysis(String locale) : super(requestedLocale: locale);

  @override
  Future<MealImageAnalysis> analyze(XFile image) async =>
      const MealImageAnalysis(
        requestId: 'synthetic-provider-request',
        notice: 'Synthetic analysis: review the identity and amount.',
        candidates: [
          MealImageCandidate(
            name: 'Synthetic media food 1',
            confidence: .87,
            evidence: 'Synthetic shape evidence.',
            identificationProvider: 'synthetic-test-provider',
            modelRevision: 'synthetic-revision-1',
            nutritionResolution: MealNutritionResolution.verifiedFoodRecord,
            verifiedFoodRecordId: 'model-claimed-USDA-999999',
            amount: 100,
            unit: 'g',
          ),
        ],
      );
}

final class _CountingPhotoAnalysis extends MealImageAnalysisService {
  _CountingPhotoAnalysis(String locale, {this.name = 'Synthetic media food 1'})
    : super(requestedLocale: locale);
  final String name;
  int calls = 0;
  @override
  Future<MealImageAnalysis> analyze(XFile image) {
    calls++;
    return Future.value(
      MealImageAnalysis(
        requestId: 'synthetic-photo-request',
        notice: 'Synthetic identity only. Match a trusted local food.',
        candidates: [
          MealImageCandidate(
            name: name,
            confidence: .99,
            evidence: 'Synthetic photo shape.',
            identificationProvider: 'synthetic-test',
            modelRevision: 'test-1',
            nutritionResolution:
                MealNutritionResolution.requiresVerifiedFoodMatch,
            amount: 100,
            unit: 'g',
          ),
        ],
      ),
    );
  }
}

Future<void> _selectPhotoDraft(
  WidgetTester tester, {
  String amount = '100',
}) async {
  final stage = find.byKey(const Key('premium-vision-stage-before'));
  await _until(tester, stage);
  await tester.ensureVisible(stage);
  await tester.tap(stage);
  await tester.pump();
  final selection = find.byKey(const Key('premium-vision-select-0'));
  await tester.ensureVisible(selection);
  await tester.tap(selection);
  await tester.pump();
  final eaten = find.byKey(const Key('premium-vision-eaten-0'));
  await tester.ensureVisible(eaten);
  await tester.tap(eaten);
  await tester.pump();
  await tester.enterText(
    find.byKey(const Key('premium-vision-amount-0')),
    amount,
  );
  final next = find.byKey(const Key('premium-vision-continue'));
  await tester.ensureVisible(next);
  await tester.pump();
  expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  await tester.tap(next);
}

Future<void> _pumpPendingPhoto(
  WidgetTester tester,
  bool Function() settled,
) async {
  for (var turn = 0; turn < 40 && !settled(); turn++) {
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 25));
  }
  await tester.pump();
  expect(settled(), isTrue);
}

final class _PendingAnalysis extends _SyntheticAnalysis {
  _PendingAnalysis(super.locale);

  final result = Completer<MealImageAnalysis>();
  int calls = 0;
  XFile? received;

  @override
  Future<MealImageAnalysis> analyze(XFile image) {
    calls++;
    received = image;
    return result.future;
  }

  Future<void> complete() async {
    result.complete(await super.analyze(received!));
  }
}

Map<String, int> _mockCameraPermission(
  WidgetTester tester, {
  required PermissionStatus status,
}) {
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final calls = <String, int>{};
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    calls.update(call.method, (value) => value + 1, ifAbsent: () => 1);
    switch (call.method) {
      case 'checkPermissionStatus':
        expect(call.arguments, Permission.camera.value);
        return status.index;
      case 'requestPermissions':
        expect(call.arguments, [Permission.camera.value]);
        return {Permission.camera.value: status.index};
      default:
        fail('Unexpected camera permission call: ${call.method}');
    }
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return calls;
}

void main() {
  tearDownAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['bil/tts', 'bil/speech', 'bil/mic_sound']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  for (final arabic in [false, true]) {
    testWidgets(
      'barcode review commits one bound readback with unknowns, arabic=$arabic',
      (tester) async {
        final fixture = await _fixture(tester);
        await _mount(
          tester,
          fixture,
          arabic: arabic,
          textScale: arabic ? 1.5 : 1,
        );
        await _chooseMatch(tester, fixture.rows.single.name);
        await _expectNoMeal(tester, fixture);
        final review = await _enterGrams(tester, grams: arabic ? '١٥٠' : '150');
        expect(review.day, _day);
        expect(review.mealType, 'snack');
        expect(review.review.items.single.quantity.grams, 150);
        expect(
          review.review.items.single.food.nutrients[FoodNutrient.protein],
          isNull,
        );
        expect(
          review.review.items.single.quantity.evidence.kind,
          CoachFoodQuantityKind.userDeclared,
        );
        await _expectNoMeal(tester, fixture);
        final confirm = find.byKey(
          CoachFoodCardKeys.confirm(review.operationId),
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.tap(confirm);
        await _until(tester, find.byType(CoachFoodReceiptCard));
        final card = tester.widget<CoachFoodReceiptCard>(
          find.byType(CoachFoodReceiptCard),
        );
        expect(
          CoachFoodReceiptBinding.matches(card.commit, card.receipt),
          isTrue,
        );
        expect(card.commit.operationId, review.operationId);
        expect(card.commit.toolId, 'log_foods');
        await tester.runAsync(() async {
          final rows = await fixture.database
              .select(fixture.database.mealItems)
              .get();
          expect(rows, hasLength(1));
          final evidence = MealFoodEvidence.read(
            rows.single,
            ownerKey: _ownerKey,
          );
          expect(evidence.isValid, isTrue);
          expect(evidence.portion!.digest, review.review.items.single.digest);
          expect(evidence.portion!.nutrients[FoodNutrient.calories], 300);
          expect(evidence.portion!.nutrients[FoodNutrient.protein], isNull);
          expect(evidence.portion!.nutrients[FoodNutrient.sodium], isNull);
          expect(evidence.portion!.nutrients[FoodNutrient.fiber], 0);
          final journals = await (fixture.database.select(
            fixture.database.preferences,
          )..where((row) => row.key.like('coachMealOperationV1.%'))).get();
          expect(journals, hasLength(1));
          final readback = await MealRepository(fixture.database)
              .readCoachMealOperation(
                operationId: review.operationId,
                scope: CoachMealOwnerScope(
                  ownerId: _owner,
                  isCurrent: () => true,
                ),
              );
          expect(readback, isNotNull);
          expect(
            CoachFoodReceiptBinding.matches(readback!, card.receipt),
            isTrue,
          );
          expect(readback.after.single.meal.dayKey, '2026-10-07');
          expect(readback.after.single.meal.type, 'snack');
        });
        expect(fixture.gateway.questions, isEmpty);
        if (!arabic) {
          await tester.tap(
            find.byKey(CoachFoodCardKeys.menu(review.operationId)),
          );
          await _drain(tester);
          await tester.tap(
            find.byKey(CoachFoodCardKeys.undo(review.operationId)),
          );
          for (var turn = 0; turn < 30; turn++) {
            await _drain(tester);
            final current = tester.widget<CoachFoodReceiptCard>(
              find.byType(CoachFoodReceiptCard),
            );
            if (current.commit.state == CoachMealResultState.undone) {
              break;
            }
          }
          final undone = tester.widget<CoachFoodReceiptCard>(
            find.byType(CoachFoodReceiptCard),
          );
          expect(undone.commit.state, CoachMealResultState.undone);
          expect(undone.commit.operationId, review.operationId);
          expect(
            CoachFoodReceiptBinding.matches(undone.commit, undone.receipt),
            isTrue,
          );
          expect(undone.receipt.undoable, isFalse);
          final journalAfterUndo = await tester.runAsync(() async {
            final activeItems = await (fixture.database.select(
              fixture.database.mealItems,
            )..where((row) => row.deletedAt.isNull())).get();
            expect(activeItems, isEmpty);
            final readback = await MealRepository(fixture.database)
                .readCoachMealOperation(
                  operationId: review.operationId,
                  scope: CoachMealOwnerScope(
                    ownerId: _owner,
                    isCurrent: () => true,
                  ),
                );
            expect(readback!.state, CoachMealResultState.undone);
            expect(
              CoachFoodReceiptBinding.matches(readback, undone.receipt),
              isTrue,
            );
            return (await (fixture.database.select(fixture.database.preferences)
                      ..where((row) => row.key.like('coachMealOperationV1.%')))
                    .get())
                .single
                .value;
          });
          await tester.tap(find.byKey(const Key('bil02-media-close')));
          await _drain(tester);
          await tester.enterText(
            find.byKey(const Key('ai-coach-question-field')),
            'undo',
          );
          await tester.pump();
          await tester.tap(find.byKey(const Key('ai-coach-send-button')));
          await _until(
            tester,
            find.text(
              'There is no recent reversible action.',
              findRichText: true,
            ),
          );
          await tester.runAsync(() async {
            final journals = await (fixture.database.select(
              fixture.database.preferences,
            )..where((row) => row.key.like('coachMealOperationV1.%'))).get();
            expect(journals, hasLength(1));
            expect(journals.single.value, journalAfterUndo);
            expect(
              await (fixture.database.select(
                fixture.database.mealItems,
              )..where((row) => row.deletedAt.isNull())).get(),
              isEmpty,
            );
          });
          expect(fixture.gateway.questions, isEmpty);
        }
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      },
    );
  }

  testWidgets('read-only confirmation leaves review and storage untouched', (
    tester,
  ) async {
    final fixture = await _fixture(tester);
    await _mount(
      tester,
      fixture,
      permission: CoachActionPermissionMode.readOnly,
    );
    await _chooseMatch(tester, fixture.rows.single.name);
    final review = await _enterGrams(tester);
    final confirm = find.byKey(CoachFoodCardKeys.confirm(review.operationId));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await _drain(tester);
    expect(find.text('Read-only mode. No food was logged.'), findsOneWidget);
    expect(find.byType(CoachFoodReviewCard), findsOneWidget);
    await _expectNoMeal(tester, fixture);
    await _unmount(tester);
  });

  testWidgets(
    'revoking and restoring write mode cannot revive an open review',
    (tester) async {
      final fixture = await _fixture(tester);
      await _mount(tester, fixture);
      await _chooseMatch(tester, fixture.rows.single.name);
      final review = await _enterGrams(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(IntelligenceCenterPage)),
        listen: false,
      );
      container.read(coachActionPermissionModeProvider.notifier).state =
          CoachActionPermissionMode.readOnly;
      await tester.pump();
      container.read(coachActionPermissionModeProvider.notifier).state =
          CoachActionPermissionMode.askBeforeWrite;
      await tester.pump();
      expect(review.ownerIsCurrent(), isFalse);
      await review.onConfirm();
      await _drain(tester);
      await _expectNoMeal(tester, fixture);
      await _unmount(tester);
    },
  );

  for (final exit in [false, true]) {
    testWidgets(
      'late local lookup cannot open review after ${exit ? 'route exit' : 'owner A B A'}',
      (tester) async {
        final fixture = await _fixture(tester);
        final pending = Completer<List<CoachMediaCatalogEntry>>();
        var lookups = 0;
        await _mount(
          tester,
          fixture,
          lookup: (_) {
            lookups++;
            return pending.future;
          },
        );
        for (var turn = 0; turn < 30 && lookups == 0; turn++) {
          await _drain(tester);
        }
        expect(lookups, 1);
        if (exit) {
          fixture.router!.go('/dashboard');
        } else {
          fixture.switchAwayAndBack();
        }
        await _drain(tester);
        pending.complete(fixture.entries);
        await _drain(tester);
        expect(find.bySubtype<AlertDialog>(), findsNothing);
        expect(find.byType(CoachFoodReviewCard), findsNothing);
        if (exit) {
          expect(
            fixture.router!.routeInformationProvider.value.uri.path,
            '/dashboard',
          );
        }
        await _expectNoMeal(tester, fixture);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      },
    );
  }

  testWidgets(
    'a valid barcode without a local match produces no review or write',
    (tester) async {
      final fixture = await _fixture(tester, foodCount: 0);
      await _mount(tester, fixture);
      await _until(
        tester,
        find.textContaining('No verified local match was found.'),
      );
      expect(find.bySubtype<AlertDialog>(), findsNothing);
      await _expectNoMeal(tester, fixture);
      await _unmount(tester);
    },
  );

  testWidgets(
    'multiple barcode matches require explicit selection of one identity',
    (tester) async {
      final fixture = await _fixture(tester, foodCount: 2);
      await _mount(tester, fixture);
      await _until(tester, find.text(fixture.rows.first.name));
      expect(find.text(fixture.rows.last.name), findsOneWidget);
      expect(tester.widget<FilledButton>(_matchUse).onPressed, isNull);
      await _expectNoMeal(tester, fixture);
      await _chooseMatch(tester, fixture.rows.last.name);
      final review = await _enterGrams(tester);
      expect(review.review.items, hasLength(1));
      expect(
        review.review.items.single.food.identity,
        'synthetic-media-identity-2',
      );
      await _expectNoMeal(tester, fixture);
      await tester.tap(find.byKey(const Key('bil02-media-close')));
      await _drain(tester);
      await _expectNoMeal(tester, fixture);
      await _unmount(tester);
    },
  );

  testWidgets(
    'photo recognition reaches the same review with local source and labeled estimate',
    (tester) async {
      final fixture = await _fixture(tester);
      await _mount(
        tester,
        fixture,
        barcode: null,
        picker: _SyntheticPicker(),
        analysis: _SyntheticAnalysis.new,
      );
      await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
      await _drain(tester);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-gallery')));
      // Premium photo review now requires the user's photo-stage and
      // actually-eaten confirmation before matching a trusted catalog row.
      final photoStage = find.byKey(const Key('premium-vision-stage-before'));
      await _until(tester, photoStage);
      await _expectNoMeal(tester, fixture);
      await tester.ensureVisible(photoStage);
      await tester.tap(photoStage);
      await tester.pump();
      final selection = find.byKey(const Key('premium-vision-select-0'));
      await tester.ensureVisible(selection);
      await tester.tap(selection);
      await tester.pump();
      final eaten = find.byKey(const Key('premium-vision-eaten-0'));
      await tester.ensureVisible(eaten);
      await tester.tap(eaten);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('premium-vision-amount-0')),
        '100',
      );
      final next = find.byKey(const Key('premium-vision-continue'));
      await tester.ensureVisible(next);
      await tester.pump();
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      await _drain(tester);
      await _chooseMatch(tester, fixture.rows.single.name);
      await _until(tester, find.byType(CoachFoodReviewCard));
      final review = tester.widget<CoachFoodReviewCard>(
        find.byType(CoachFoodReviewCard),
      );
      final item = review.review.items.single;
      expect(item.food.source.ref, 'synthetic-reviewed-label-1');
      expect(item.food.source.kind, CoachFoodSourceKind.label);
      expect(item.quantity.evidence.kind, CoachFoodQuantityKind.estimated);
      expect(item.food.nutrients[FoodNutrient.protein], isNull);
      expect(item.quantity.evidence.description, contains('photo'));
      await _expectNoMeal(tester, fixture);
      await tester.ensureVisible(
        find.byKey(CoachFoodCardKeys.confirm(review.operationId)),
      );
      await tester.tap(
        find.byKey(CoachFoodCardKeys.confirm(review.operationId)),
      );
      await _until(tester, find.byType(CoachFoodReceiptCard));
      final card = tester.widget<CoachFoodReceiptCard>(
        find.byType(CoachFoodReceiptCard),
      );
      expect(
        CoachFoodReceiptBinding.matches(card.commit, card.receipt),
        isTrue,
      );
      expect(card.commit.after.single.item.foodVerifiedSnapshot, isFalse);
      expect(fixture.gateway.questions, isEmpty);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'photo with no local match reviews a real installed source before committing',
    (tester) async {
      final fixture = await _fixture(tester);
      final analysis = _CountingPhotoAnalysis('en', name: 'APPLE');
      await _mount(
        tester,
        fixture,
        barcode: null,
        picker: _SyntheticPicker(),
        analysis: (_) => analysis,
        lookup: (_) async => [],
        installedCatalog: () async => UsdaCoreCatalogRepository.open(
          'assets/catalogs/bil_food_core.sqlite',
        ),
      );
      await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
      await _drain(tester);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-gallery')));
      await _selectPhotoDraft(tester, amount: '100');
      await _until(tester, find.byKey(const Key('premium-vision-use-food')));
      expect(tester.widget<FilledButton>(_matchUse).onPressed, isNull);
      await _expectNoMeal(tester, fixture);
      final candidate = find
          .byWidgetPredicate(
            (widget) =>
                widget is ListTile &&
                widget.title is Text &&
                ((widget.title as Text).data ?? '').startsWith('Apples,'),
          )
          .first;
      await tester.tap(candidate);
      await tester.pump();
      await tester.tap(_matchUse);
      await _until(tester, find.byType(CoachFoodReviewCard));
      final review = tester.widget<CoachFoodReviewCard>(
        find.byType(CoachFoodReviewCard),
      );
      final portion = review.review.items.single;
      expect(portion.food.identity, startsWith('usda:'));
      expect(portion.food.name, startsWith('Apples,'));
      expect(portion.food.source.kind, CoachFoodSourceKind.reference);
      expect(portion.food.source.ref, startsWith('USDA FoodData Central'));
      expect(portion.quantity.grams, 100);
      expect(analysis.calls, 1);
      await _expectNoMeal(tester, fixture);
      await tester.ensureVisible(
        find.byKey(CoachFoodCardKeys.confirm(review.operationId)),
      );
      await tester.tap(
        find.byKey(CoachFoodCardKeys.confirm(review.operationId)),
      );
      await _until(tester, find.byType(CoachFoodReceiptCard));
      final receipt = tester.widget<CoachFoodReceiptCard>(
        find.byType(CoachFoodReceiptCard),
      );
      expect(receipt.commit.after.single.item.foodId, greaterThan(0));
      expect(
        receipt.commit.after.single.item.calories,
        portion.food.nutrients[FoodNutrient.calories],
      );
      expect(fixture.gateway.questions, isEmpty);
      expect(analysis.calls, 1);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'unmatched photo keeps editable draft and retries locally without another analysis',
    (tester) async {
      final fixture = await _fixture(tester);
      final analysis = _CountingPhotoAnalysis(
        'en',
        name: 'Unmatched red apple',
      );
      final lookedUp = <String?>[];
      await _mount(
        tester,
        fixture,
        barcode: null,
        picker: _SyntheticPicker(),
        analysis: (_) => analysis,
        lookup: (input) async {
          lookedUp.add(input.name);
          return input.name == fixture.rows.single.name ? fixture.entries : [];
        },
      );
      await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
      await _drain(tester);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-gallery')));
      await _selectPhotoDraft(tester, amount: '125');
      await _drain(tester);
      expect(find.byKey(const Key('premium-vision-continue')), findsOneWidget);
      expect(
        find.byKey(const Key('premium-vision-match-issue')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('premium-vision-amount-0')))
            .controller!
            .text,
        '125',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('premium-vision-stage-before')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('premium-vision-eaten-0')))
            .selected,
        isTrue,
      );
      expect(lookedUp, ['Unmatched red apple']);
      expect(analysis.calls, 1);
      await _expectNoMeal(tester, fixture);

      final remove = find.byKey(const Key('premium-vision-exclude-0'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pump();
      final add = find.byKey(const Key('premium-vision-add-food'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await _drain(tester);
      final addDialog = find.bySubtype<AlertDialog>();
      await tester.enterText(
        find.descendant(of: addDialog, matching: find.byType(TextField)),
        fixture.rows.single.name,
      );
      await tester.tap(
        find.descendant(of: addDialog, matching: find.text('Add')),
      );
      await _drain(tester);
      final eaten = find.byKey(const Key('premium-vision-eaten-1'));
      await tester.ensureVisible(eaten);
      await tester.tap(eaten);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('premium-vision-amount-1')),
        '100',
      );
      await tester.pump();
      final retry = find.byKey(const Key('premium-vision-continue'));
      expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
      await tester.tap(retry);
      await _drain(tester);
      await _chooseMatch(tester, fixture.rows.single.name);
      await _until(tester, find.byType(CoachFoodReviewCard));
      expect(lookedUp, ['Unmatched red apple', fixture.rows.single.name]);
      expect(analysis.calls, 1);
      await _expectNoMeal(tester, fixture);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'canceling a photo match returns to the same confirmed photo draft',
    (tester) async {
      final fixture = await _fixture(tester);
      final analysis = _CountingPhotoAnalysis('en');
      await _mount(
        tester,
        fixture,
        barcode: null,
        picker: _SyntheticPicker(),
        analysis: (_) => analysis,
      );
      await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
      await _drain(tester);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-gallery')));
      await _selectPhotoDraft(tester, amount: '127');
      await _drain(tester);
      final use = find.byKey(const Key('premium-vision-use-food'));
      await _until(tester, use);
      final dialog = find.ancestor(of: use, matching: find.bySubtype<Dialog>());
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithIcon(IconButton, Icons.close),
        ),
      );
      await _drain(tester);
      expect(find.byKey(const Key('premium-vision-continue')), findsOneWidget);
      expect(find.byKey(const Key('premium-vision-match-issue')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('premium-vision-amount-0')))
            .controller!
            .text,
        '127',
      );
      expect(analysis.calls, 1);
      await _expectNoMeal(tester, fixture);
      await _unmount(tester);
    },
  );

  for (final retire in ['owner A B A', 'route exit', 'permission revoke']) {
    testWidgets(
      'photo matching retires on $retire and repeated confirm cannot start another lookup',
      (tester) async {
        final fixture = await _fixture(tester);
        final analysis = _CountingPhotoAnalysis('en');
        final pending = Completer<List<CoachMediaCatalogEntry>>();
        var lookups = 0;
        await _mount(
          tester,
          fixture,
          barcode: null,
          picker: _SyntheticPicker(),
          analysis: (_) => analysis,
          lookup: (_) {
            lookups++;
            return pending.future;
          },
        );
        await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
        await _drain(tester);
        await tester.tap(
          find.byKey(const Key('ai-coach-image-source-gallery')),
        );
        await _selectPhotoDraft(tester);
        await _pumpPendingPhoto(tester, () => lookups == 1);
        final next = find.byKey(const Key('premium-vision-continue'));
        expect(tester.widget<FilledButton>(next).onPressed, isNull);
        await tester.tap(next);
        await tester.pump();
        expect(lookups, 1);
        if (retire == 'route exit') {
          fixture.router!.go('/dashboard');
        } else if (retire == 'permission revoke') {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(IntelligenceCenterPage)),
          );
          container.read(coachActionPermissionModeProvider.notifier).state =
              CoachActionPermissionMode.readOnly;
          await tester.pump();
          container.read(coachActionPermissionModeProvider.notifier).state =
              CoachActionPermissionMode.askBeforeWrite;
        } else {
          fixture.switchAwayAndBack();
        }
        await _pumpPendingPhoto(
          tester,
          () => find
              .byKey(const Key('premium-vision-continue'))
              .evaluate()
              .isEmpty,
        );
        pending.complete(fixture.entries);
        await _drain(tester);
        expect(find.byKey(const Key('premium-vision-use-food')), findsNothing);
        expect(find.byType(CoachFoodReviewCard), findsNothing);
        expect(analysis.calls, 1);
        await _expectNoMeal(tester, fixture);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      },
    );
  }

  testWidgets(
    'owner retirement removes only its photo and zoom routes, preserving an unrelated dialog',
    (tester) async {
      final fixture = await _fixture(tester);
      final analysis = _CountingPhotoAnalysis('en');
      await _mount(
        tester,
        fixture,
        barcode: null,
        picker: _SyntheticPicker(),
        analysis: (_) => analysis,
      );
      await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
      await _drain(tester);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-gallery')));
      final photo = find.byKey(const Key('premium-vision-photo'));
      await _until(tester, photo);
      await tester.tap(photo);
      await _drain(tester);
      expect(find.byTooltip('Close photo'), findsOneWidget);
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(IntelligenceCenterPage)),
          builder: (context) => AlertDialog(
            title: const Text('Unrelated dialog'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close unrelated'),
              ),
            ],
          ),
        ),
      );
      await _drain(tester);
      fixture.switchAwayAndBack();
      await _drain(tester);
      expect(find.text('Unrelated dialog'), findsOneWidget);
      expect(find.byTooltip('Close photo'), findsNothing);
      expect(find.byKey(const Key('premium-vision-continue')), findsNothing);
      await tester.tap(find.text('Close unrelated'));
      await _drain(tester);
      await _expectNoMeal(tester, fixture);
      expect(analysis.calls, 1);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'a delayed analysis cannot replace a newer query after the public Coach action',
    (tester) async {
      final fixture = await _fixture(tester);
      final pending = _PendingAnalysis('en');
      try {
        await _mount(
          tester,
          fixture,
          barcode: null,
          picker: _SyntheticPicker(),
          analysis: (_) => pending,
        );
        final pageState = tester.state(find.byType(IntelligenceCenterPage));
        final composer = find.byKey(const Key('ai-coach-question-field'));
        await tester.enterText(composer, 'Keep this photo draft');
        expect(tester.widget<TextField>(composer).focusNode!.hasFocus, isTrue);
        await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
        expect(tester.widget<TextField>(composer).focusNode!.hasFocus, isFalse);
        await _drain(tester);
        await tester.tap(
          find.byKey(const Key('ai-coach-image-source-gallery')),
        );
        // The intentional in-flight analysis has a spinner. Advance its local
        // futures without waiting for that animation or completing the result.
        for (var turn = 0; turn < 30 && pending.calls == 0; turn++) {
          await tester.runAsync(
            () async => Future<void>.delayed(Duration.zero),
          );
          await tester.pump();
        }
        await tester.pump();
        expect(pending.calls, 1);
        expect(find.byType(BilFeatureWelcomeStatus), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(pending.result.isCompleted, isFalse);
        await _expectNoMeal(tester, fixture);

        // Use the existing Coach tab to retire the media visit in this same
        // mounted page, then admit a newer query through the actual Send button.
        final coachTab = find
            .byKey(const Key('bil-reference-nav-1'))
            .hitTestable();
        for (var turn = 0; turn < 30 && coachTab.evaluate().isEmpty; turn++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(coachTab, findsOneWidget);
        expect(pending.result.isCompleted, isFalse);
        await tester.tap(coachTab);
        await _drain(tester);
        expect(
          tester.state(find.byType(IntelligenceCenterPage)),
          same(pageState),
        );
        const newerQuery = 'explain consistency in everyday habits';
        final field = find.byKey(const Key('ai-coach-question-field'));
        await tester.enterText(field, newerQuery);
        await tester.pump();
        await tester.tap(find.byKey(const Key('ai-coach-send-button')));
        await _until(
          tester,
          find.text('Local diagnostic reply.', findRichText: true),
        );
        expect(fixture.gateway.questions, [newerQuery]);
        const nextDraft = 'Keep this next draft after the newer reply';
        await tester.enterText(field, nextDraft);

        await pending.complete();
        await _drain(tester);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(find.byType(CoachFoodReviewCard), findsNothing);
        expect(find.byType(CoachFoodReceiptCard), findsNothing);
        expect(tester.widget<TextField>(field).controller!.text, nextDraft);
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(fixture.gateway.questions, [newerQuery]);
        expect(pending.calls, 1);
        expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.runAsync(() async {
          expect(
            await fixture.database.select(fixture.database.mealItems).get(),
            isEmpty,
          );
          expect(
            await fixture.database.select(fixture.database.meals).get(),
            isEmpty,
          );
          expect(
            await (fixture.database.select(
              fixture.database.preferences,
            )..where((row) => row.key.like('coachMealOperationV1.%'))).get(),
            isEmpty,
          );
        });
        expect(tester.takeException(), isNull);
      } finally {
        // Dispose the actual page before its teardown removes native mocks,
        // even when an assertion fails with the analysis still outstanding.
        await _unmount(tester);
        if (pending.received != null && !pending.result.isCompleted) {
          await pending.complete();
          await _drain(tester);
        }
      }
    },
  );

  for (final revokedAfterGrant in [false, true]) {
    testWidgets(
      'native camera ${revokedAfterGrant ? 'revocation after admission' : 'denial'} leaves no route or write',
      (tester) async {
        final fixture = await _fixture(tester);
        final previousPlatform = debugDefaultTargetPlatformOverride;
        try {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final nativeCalls = _mockCameraPermission(
            tester,
            status: revokedAfterGrant
                ? PermissionStatus.granted
                : PermissionStatus.denied,
          );
          var capability = BilRuntimePermissionState.denied;
          var capabilityChecks = 0;
          var analyses = 0;
          await _mount(
            tester,
            fixture,
            barcode: null,
            analysis: (locale) {
              analyses++;
              return _SyntheticAnalysis(locale);
            },
            runtimePermission: revokedAfterGrant
                ? (requested) async {
                    expect(requested, BilRuntimeCapability.camera);
                    capabilityChecks++;
                    return capability;
                  }
                : null,
          );
          final field = find.byKey(const Key('ai-coach-question-field'));
          const draft = 'Preserve my draft when the camera is unavailable';
          await tester.enterText(field, draft);
          await tester.tap(find.byKey(const Key('ai-coach-food-image-button')));
          await _drain(tester);
          await tester.tap(
            find.byKey(const Key('ai-coach-image-source-camera')),
          );
          await _drain(tester);
          expect(nativeCalls['checkPermissionStatus'], 1);
          expect(
            nativeCalls['requestPermissions'] ?? 0,
            revokedAfterGrant ? 0 : 1,
          );
          expect(capabilityChecks, revokedAfterGrant ? 1 : 0);
          expect(find.byType(BilCameraCapturePage), findsNothing);
          expect(find.byType(CheckboxListTile), findsNothing);
          expect(analyses, 0);
          expect(tester.widget<TextField>(field).controller!.text, draft);
          await _expectNoMeal(tester, fixture);

          // A capability becoming available later cannot resume the retired
          // request or open hardware without another deliberate user action.
          capability = BilRuntimePermissionState.granted;
          await _drain(tester);
          expect(find.byType(BilCameraCapturePage), findsNothing);
          expect(analyses, 0);
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(const Key('ai-coach-food-image-button')),
                )
                .onPressed,
            isNotNull,
          );
          await _expectNoMeal(tester, fixture);
          expect(tester.takeException(), isNull);
        } finally {
          try {
            await _unmount(tester);
          } finally {
            // Flutter checks this invariant before addTearDown callbacks run.
            debugDefaultTargetPlatformOverride = previousPlatform;
          }
        }
      },
    );
  }
}
