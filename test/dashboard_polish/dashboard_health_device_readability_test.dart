import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/connected_health_card.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ReadableHealthGateway implements ConnectedHealthGateway {
  const _ReadableHealthGateway();

  static final snapshot = ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.synchronized,
    platformSource: 'Health Connect',
    availableSources: const ['Health Connect'],
    signals: [
      for (final signal in const [
        ('steps', 6842.0, 'steps'),
        ('heartRate', 72.0, 'bpm'),
        ('weight', 80.0, 'kg'),
        ('sleep', 7.4, 'h'),
      ])
        ConnectedHealthSignalView(
          key: signal.$1,
          value: signal.$2,
          unit: signal.$3,
          source: 'QA watch',
          observedAt: DateTime(2026, 8, 21, 10, 19),
          confidence: .98,
        ),
    ],
    importedCount: 4,
    lastSyncAt: DateTime(2026, 8, 21, 10, 19),
    failureCode: null,
  );

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
}

final class _EmptyHealthGateway implements ConnectedHealthGateway {
  const _EmptyHealthGateway();

  static final snapshot = ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.permissionRequired,
    platformSource: null,
    availableSources: const [],
    signals: const [],
    importedCount: 0,
    lastSyncAt: null,
    failureCode: null,
  );

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;
  @override
  Future<void> openSystemSettings() async {}
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
}

Widget _subject({
  required Locale locale,
  required double textScale,
  bool empty = false,
}) {
  return ProviderScope(
    overrides: [
      connectedHealthGatewayProvider.overrideWithValue(
        empty ? const _EmptyHealthGateway() : const _ReadableHealthGateway(),
      ),
      liveHealthNowProvider.overrideWithValue(
        () => DateTime(2026, 8, 21, 10, 19, 42),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConnectedHealthCard(
            languageCode: locale.languageCode,
            compact: true,
            dashboardCompact: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty dashboard widget shows only the external link control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _subject(locale: const Locale('ar'), textScale: 1.6, empty: true),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-fitness-link-action')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-fitness-last-sync')), findsNothing);
    expect(find.text('غير متصل'), findsNothing);
    expect(find.text('Not connected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all 25 locales keep the unified dashboard fitness widget contained at 160%',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(_subject(locale: locale, textScale: 1.6));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          find.byKey(const Key('dashboard-live-fitness-watch-slot')),
          findsOneWidget,
          reason: locale.toLanguageTag(),
        );
        expect(tester.takeException(), isNull, reason: locale.toLanguageTag());

        expect(
          find.byKey(const Key('dashboard-fitness-link-action')),
          findsOneWidget,
          reason: locale.toLanguageTag(),
        );
        expect(tester.takeException(), isNull, reason: locale.toLanguageTag());

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  for (final configuration in const [
    (locale: Locale('en'), scale: 1.0),
    (locale: Locale('ar'), scale: 1.6),
  ]) {
    testWidgets(
      '${configuration.locale.languageCode} keeps the unified fitness widget readable at ${configuration.scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _subject(
            locale: configuration.locale,
            textScale: configuration.scale,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final watchSlot = find.byKey(
          const Key('dashboard-live-fitness-watch-slot'),
        );
        expect(watchSlot, findsOneWidget);
        final artwork = find.byKey(const Key('bil-live-health-watch'));
        expect(artwork, findsOneWidget);
        final size = tester.getSize(artwork);
        expect(size.width, inInclusiveRange(190, 212));
        expect(size.height, inInclusiveRange(190, 212));
        expect(
          Directionality.of(tester.element(watchSlot)),
          configuration.locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
        );
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byKey(const Key('bil-live-health-watch'))),
          ).scale(1),
          lessThanOrEqualTo(1.15),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('dashboard-fitness-last-sync')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('dashboard-fitness-reading-weight')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('dashboard-fitness-link-action')),
          findsOneWidget,
        );
        expect(find.text('Connected'), findsNothing);
        expect(
          find.text(
            configuration.locale.languageCode == 'ar'
                ? 'غير متصل'
                : 'Not connected',
          ),
          findsNothing,
        );
        expect(
          find.byKey(const Key('dashboard-medical-device-slot')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
