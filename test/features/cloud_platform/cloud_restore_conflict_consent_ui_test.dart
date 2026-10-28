import 'dart:async';

import 'package:body_intelligence_log/app/localization/runtime_copy_cloud_restore.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_restore_conflict_controls.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_restore_conflict_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_restore_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_conflict_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  for (final scopes in [
    <CloudRestoreScope>{},
    {CloudRestoreScope.goals},
    {CloudRestoreScope.nutrition},
  ]) {
    testWidgets('review requires actual optional consent scopes: $scopes', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      var engineReads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudRestoreConsentStateProvider.overrideWith(
              (ref) async => CloudRestoreConsentState(
                availability: CloudRestoreConsentAvailability.available,
                ownerId: 'fixture-owner',
                grantedScopes: scopes,
              ),
            ),
            cloudRestoreConflictServiceProvider.overrideWithValue(
              CloudRestoreConflictService(() async {
                engineReads++;
                throw StateError(
                  'Only checking availability; no server operation',
                );
              }),
            ),
            cloudManualSyncStatusProvider.overrideWith(
              (ref) => CloudManualSyncStatusController(
                preferences: PreferencesRepository(db),
                cloudAvailable: true,
                ownerId: 'fixture-owner',
                runSync: () async => const CloudManualSyncResult(
                  disposition: CloudManualSyncDisposition.unavailable,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CloudRestoreConflictControls()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tile = tester.widget<ListTile>(
        find.byKey(const Key('cloud-restore-review-conflicts')),
      );
      expect(tile.onTap == null, scopes.isEmpty);
      if (scopes.isEmpty) {
        expect(
          find.text(
            'Enable Nutrition backup or Goal backup before reviewing backup conflicts.',
          ),
          findsOneWidget,
        );
      } else {
        await tester.tap(
          find.byKey(const Key('cloud-restore-review-conflicts')),
        );
        await tester.pumpAndSettle();
      }
      expect(engineReads, scopes.isEmpty ? 0 : 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (availability, expected, arabic) in [
    (
      CloudRestoreConsentAvailability.unavailable,
      CloudRestoreCopy.unavailable,
      'تعذر تأكيد دعم الخادم حاليًا. تبقى هذه السجلات على هذا الجهاز.',
    ),
    (
      CloudRestoreConsentAvailability.signedOut,
      CloudRestoreCopy.signIn,
      'سجّل الدخول لإدارة هذه الخيارات.',
    ),
    (
      CloudRestoreConsentAvailability.baseConsentRequired,
      CloudRestoreCopy.baseRequired,
      'فعّل «نسخ التقدّم احتياطيًا» أولًا.',
    ),
  ]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        'disabled conflict review explains $availability in ${locale.languageCode}',
        (tester) async {
          final readCount = await _pumpConsentState(
            tester,
            locale: locale,
            loadConsent: () async => CloudRestoreConsentState(
              availability: availability,
              // A stale scope cannot make an unavailable state actionable.
              grantedScopes: const {CloudRestoreScope.nutrition},
            ),
          );
          await tester.pumpAndSettle();
          final tile = find.byKey(const Key('cloud-restore-review-conflicts'));
          expect(tester.widget<ListTile>(tile).onTap, isNull);
          expect(
            find.text(locale.languageCode == 'ar' ? arabic : expected),
            findsOneWidget,
          );
          expect(
            find.text(
              'Enable Nutrition backup or Goal backup before reviewing backup conflicts.',
            ),
            findsNothing,
          );
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(readCount(), 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'loading conflict consent explains checking before enabling review',
    (tester) async {
      final consent = Completer<CloudRestoreConsentState>();
      final readCount = await _pumpConsentState(
        tester,
        loadConsent: () => consent.future,
      );
      final tile = find.byKey(const Key('cloud-restore-review-conflicts'));
      expect(tester.widget<ListTile>(tile).onTap, isNull);
      expect(find.text(CloudRestoreCopy.checking), findsOneWidget);
      expect(readCount(), 0);
      consent.complete(
        const CloudRestoreConsentState(
          availability: CloudRestoreConsentAvailability.available,
          grantedScopes: {CloudRestoreScope.goals},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(tile).onTap, isNotNull);
      expect(
        find.text(
          'Choose a version; local changes remain saved until your decision.',
        ),
        findsOneWidget,
      );
      expect(find.text(CloudRestoreCopy.checking), findsNothing);
      expect(readCount(), 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'refresh and error never reuse a previously granted review action',
    (tester) async {
      final pending = Completer<CloudRestoreConsentState>();
      var reads = 0;
      const granted = CloudRestoreConsentState(
        availability: CloudRestoreConsentAvailability.available,
        grantedScopes: {CloudRestoreScope.goals},
      );
      addTearDown(() {
        if (!pending.isCompleted) pending.complete(granted);
      });
      final engineReads = await _pumpConsentState(
        tester,
        loadConsent: () =>
            ++reads == 1 ? Future.value(granted) : pending.future,
      );
      await tester.pumpAndSettle();
      final tile = find.byKey(const Key('cloud-restore-review-conflicts'));
      final container = ProviderScope.containerOf(tester.element(tile));
      expect(tester.widget<ListTile>(tile).onTap, isNotNull);
      container.invalidate(cloudRestoreConsentStateProvider);
      await tester.pump();
      final loading = container.read(cloudRestoreConsentStateProvider);
      expect(loading.isLoading, isTrue);
      expect(loading.hasValue, isTrue);
      expect(loading.value?.grantedScopes, {CloudRestoreScope.goals});
      expect(tester.widget<ListTile>(tile).onTap, isNull);
      expect(find.text(CloudRestoreCopy.checking), findsOneWidget);
      await tester.tap(tile);
      expect(engineReads(), 0);

      pending.completeError(StateError('Consent refresh unavailable'));
      await tester.pumpAndSettle();
      final failed = container.read(cloudRestoreConsentStateProvider);
      expect(failed.hasError, isTrue);
      expect(failed.hasValue, isTrue);
      expect(tester.widget<ListTile>(tile).onTap, isNull);
      expect(find.text(CloudRestoreCopy.unavailable), findsOneWidget);
      await tester.tap(tile);
      expect(engineReads(), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed consent read stays disabled with truthful unavailable state',
    (tester) async {
      final readCount = await _pumpConsentState(
        tester,
        loadConsent: () async =>
            throw StateError('Isolated consent transport failure'),
      );
      await tester.pumpAndSettle();
      final tile = find.byKey(const Key('cloud-restore-review-conflicts'));
      expect(tester.widget<ListTile>(tile).onTap, isNull);
      expect(find.text(CloudRestoreCopy.unavailable), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(readCount(), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<int Function()> _pumpConsentState(
  WidgetTester tester, {
  required Future<CloudRestoreConsentState> Function() loadConsent,
  Locale locale = const Locale('en'),
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  var engineReads = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cloudRestoreConsentStateProvider.overrideWith((ref) => loadConsent()),
        cloudRestoreConflictServiceProvider.overrideWithValue(
          CloudRestoreConflictService(() async {
            engineReads++;
            throw StateError('Only checking availability; no server operation');
          }),
        ),
        cloudManualSyncStatusProvider.overrideWith(
          (ref) => CloudManualSyncStatusController(
            preferences: PreferencesRepository(db),
            cloudAvailable: true,
            ownerId: 'fixture-owner',
            runSync: () async => const CloudManualSyncResult(
              disposition: CloudManualSyncDisposition.unavailable,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: CloudRestoreConflictControls()),
      ),
    ),
  );
  return () => engineReads;
}
