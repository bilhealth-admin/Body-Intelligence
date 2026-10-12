import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_restore_scope_controls.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_restore_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'cloud_restore_consent_fixture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);

  Future<(RestoreConsentFixture, CloudRestoreConsentRepository)> mount(
    WidgetTester tester, {
    String locale = 'en',
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool unsupported = false,
    bool baseGranted = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = RestoreConsentFixture()
      ..unsupported = unsupported
      ..baseGranted = baseGranted;
    final repository = CloudRestoreConsentRepository.withBackend(
      backend: backend,
    );
    addTearDown(() async {
      repository.dispose();
      await backend.owners.close();
    });
    final family = locale == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudRestoreConsentRepositoryProvider.overrideWithValue(repository),
          cloudRestoreConsentStateProvider.overrideWith(
            (ref) => repository.read(),
          ),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(
            ThemeData(brightness: brightness),
            fontFamily: family,
          ),
          builder: (context, child) => visualEvidenceTextSurface(
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            fontFamily: family,
          ),
          home: const Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(child: CloudRestoreScopeControls()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (backend, repository);
  }

  for (final language in ['en', 'ar']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        '$language ${brightness.name} 320px 2x explicit consent controls remain reachable',
        (tester) async {
          final (backend, _) = await mount(
            tester,
            locale: language,
            scale: 2,
            brightness: brightness,
          );
          final semantics = tester.ensureSemantics();
          try {
            final nutrition = find.byKey(
              const Key('cloud-restore-nutrition-consent'),
            );
            expect(tester.widget<SwitchListTile>(nutrition).value, isFalse);
            await tester.ensureVisible(nutrition);
            await tester.tap(nutrition);
            await tester.pumpAndSettle();
            expect(backend.writes, isEmpty);
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(find.textContaining('AI Coach'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await captureClosureSurface(
              tester,
              find.byType(AlertDialog),
              'restore-consent-$language-${brightness.name}-320-2x',
            );
            final cancel = find.byKey(
              const Key('cloud-restore-consent-cancel'),
            );
            await tester.ensureVisible(cancel);
            await tester.tap(cancel);
            await tester.pumpAndSettle();
            expect(backend.writes, isEmpty);
            expect(tester.widget<SwitchListTile>(nutrition).value, isFalse);
            await tester.tap(nutrition);
            await tester.pumpAndSettle();
            final confirm = find.byKey(
              const Key('cloud-restore-consent-confirm'),
            );
            await tester.ensureVisible(confirm);
            await tester.tap(confirm);
            await tester.pumpAndSettle();
            expect(backend.writes, [
              ('owner-a', CloudRestoreScope.nutrition, true),
            ]);
            expect(tester.widget<SwitchListTile>(nutrition).value, isTrue);
            final goals = find.byKey(const Key('cloud-restore-goals-consent'));
            await tester.ensureVisible(goals);
            expect(tester.widget<SwitchListTile>(goals).value, isFalse);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets('missing server capability stays local and offers retry', (
    tester,
  ) async {
    final (backend, _) = await mount(tester, unsupported: true);
    final nutrition = find.byKey(const Key('cloud-restore-nutrition-consent'));
    expect(tester.widget<SwitchListTile>(nutrition).onChanged, isNull);
    expect(
      find.textContaining('cannot currently confirm support'),
      findsNWidgets(2),
    );
    backend.unsupported = false;
    final retry = find.byKey(const Key('cloud-restore-refresh'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(nutrition).onChanged, isNotNull);
    expect(backend.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('base grant prerequisite cannot be enabled implicitly', (
    tester,
  ) async {
    final (backend, _) = await mount(tester, baseGranted: false);
    for (final tile in tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    )) {
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
    }
    expect(find.text('Enable Progress backup first.'), findsNWidgets(2));
    expect(backend.baseGranted, isFalse);
    expect(backend.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('A B A while confirmation open cannot authorize a new visit', (
    tester,
  ) async {
    final (backend, _) = await mount(tester);
    await tester.tap(find.byKey(const Key('cloud-restore-nutrition-consent')));
    await tester.pumpAndSettle();
    backend.switchOwner('owner-b');
    backend.switchOwner('owner-a');
    await tester.tap(find.byKey(const Key('cloud-restore-consent-confirm')));
    await tester.pumpAndSettle();
    expect(backend.writes, isEmpty);
    expect(
      find.text('Could not confirm the change. Try again.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
