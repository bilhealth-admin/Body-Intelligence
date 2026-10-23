import 'dart:io';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_sync.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_modal_bottom_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'bil_smart_plan_engine_test.dart' show buildRequest;

class _Remote implements BilSmartPlanRemote {
  _Remote(this.state);
  BilSmartPlanRemoteState state;
  @override
  Future<BilSmartPlanRemoteState> read() async => state;
  @override
  Future<BilSmartPlanRemoteState> compareAndSwap(
    int revision,
    String? plan,
  ) async {
    if (revision != state.revision) throw StateError('conflict');
    return state = BilSmartPlanRemoteState(revision + 1, plan);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  late AppDatabase db;
  late BilSmartPlanSync sync;
  late BilSmartPlanSyncConflict reviewed;
  var allowed = true;
  setUp(() async {
    allowed = true;
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-123',
    );
    final repository = BilSmartPlanRepository(
      preferences: PreferencesRepository(db),
      currentOwnerId: () => 'owner-123',
    );
    final now = DateTime(2026, 10, 23, 10);
    final draft = await repository.save(
      const BilSmartPlanEngine().generate(buildRequest(), now),
      expectedRevision: 0,
    );
    final cloud = await repository.save(
      draft.withStatus(BilPlanStatus.active, now),
      expectedRevision: 1,
    );
    await repository.save(
      cloud.withStatus(
        BilPlanStatus.paused,
        now.add(const Duration(minutes: 5)),
      ),
      expectedRevision: 2,
    );
    sync = BilSmartPlanSync(
      local: repository,
      preferences: repository.preferences,
      remote: _Remote(BilSmartPlanRemoteState(7, cloud.encode())),
      checkConsentAndAccess: () {
        if (!allowed) throw StateError('retired_owner_visit');
      },
    );
    reviewed = await sync.reviewConflict('owner-123');
  });
  tearDown(() => db.close());
  Future<void> pump(
    WidgetTester tester,
    String language,
    bool dark,
    double width,
    double scale,
    ValueChanged<bool?> onResult,
  ) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ar = language == 'ar';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-123'),
        ],
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
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
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  onResult(
                    await showBilModalBottomSheet<bool>(
                      context: context,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (_) => BilSmartPlanConflictReviewPanel(
                        reviewed: reviewed,
                        checkAccess: () {
                          if (!allowed) throw StateError('retired_owner_visit');
                        },
                        horizonName: (_) => ar ? 'أسبوع' : 'One week',
                        statusName: (status) => status == BilPlanStatus.active
                            ? (ar ? 'نشطة' : 'Active')
                            : (ar ? 'متوقفة مؤقتًا' : 'Paused'),
                      ),
                    ),
                  );
                },
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'conflict $language ${dark ? 'dark' : 'light'} real review and selected cloud readback',
        (tester) async {
          bool? selected;
          await pump(
            tester,
            language,
            dark,
            390,
            1,
            (value) => selected = value,
          );
          expect(find.byType(BilSmartPlanConflictReviewPanel), findsOneWidget);
          final semantics = tester.ensureSemantics();
          try {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          } finally {
            semantics.dispose();
          }

          if (Platform.environment['BIL_CAPTURE_SMART_PLAN_GOLDENS'] != '0') {
            await expectLater(
              find.byType(BilSmartPlanConflictReviewPanel),
              matchesGoldenFile(
                'goldens/smart_plan_conflict_${language}_${dark ? 'dark' : 'light'}.png',
              ),
            );
          }
          final choose = find.text(
            language == 'ar' ? 'استخدام الإصدار السحابي' : 'Use cloud version',
          );
          await tester.ensureVisible(choose);
          await tester.tap(choose);
          await tester.pumpAndSettle();
          expect(selected, isFalse);
          await tester.runAsync(
            () => sync.resolveConflict(reviewed, keepLocal: selected!),
          );
          expect(
            (await tester.runAsync(
              () => sync.local.readFor('owner-123'),
            ))!.encode(),
            reviewed.cloud.plan,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    testWidgets(
      'conflict $language 320px 200 percent and retired owner cannot approve',
      (tester) async {
        await pump(tester, language, true, 320, 2, (_) {});
        final choose = find.text(
          language == 'ar' ? 'استخدام إصدار الجهاز' : 'Use device version',
        );
        await tester.ensureVisible(choose);
        expect(tester.takeException(), isNull);
        allowed = false;
        await tester.tap(choose);
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(
            () => sync.local.readFor('owner-123'),
          ))!.encode(),
          reviewed.localPlan,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
