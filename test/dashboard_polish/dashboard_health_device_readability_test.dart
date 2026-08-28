import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
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
        ('oxygen', 98.0, '%'),
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

Widget _subject({required Locale locale, required double textScale}) {
  final premium = SubscriptionState(
    plan: CommercePlan.pro,
    entitlements: const {CommerceEntitlement.advancedIntelligence},
    authority: EntitlementAuthority.verifiedServer,
    isPurchasable: true,
    canRestorePurchases: true,
  );
  return ProviderScope(
    overrides: [
      connectedHealthGatewayProvider.overrideWithValue(
        const _ReadableHealthGateway(),
      ),
      verifiedSubscriptionStateProvider.overrideWithValue(AsyncData(premium)),
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
  testWidgets(
    'all 25 locales keep both dashboard watch pages contained at 160%',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(_subject(locale: locale, textScale: 1.6));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          find.byKey(const Key('dashboard-live-health-watch-slot')),
          findsOneWidget,
          reason: locale.toLanguageTag(),
        );
        expect(tester.takeException(), isNull, reason: locale.toLanguageTag());

        await tester.fling(
          find.byType(PageView),
          Offset(
            Directionality.of(tester.element(find.byType(PageView))) ==
                    TextDirection.rtl
                ? 360
                : -360,
            0,
          ),
          1200,
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(
          find.byKey(const Key('dashboard-medical-device-slot')),
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
      '${configuration.locale.languageCode} keeps watch and fitness-device art readable at ${configuration.scale}x',
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
          const Key('dashboard-live-health-watch-slot'),
        );
        final medicalSlot = find.byKey(
          const Key('dashboard-medical-device-slot'),
        );
        expect(watchSlot, findsOneWidget);
        expect(medicalSlot, findsOneWidget);
        for (final artwork in [
          find.byKey(const Key('bil-live-health-watch')),
          find.byKey(const Key('bil-live-medical-monitor')),
        ]) {
          expect(artwork, findsOneWidget);
          final size = tester.getSize(artwork);
          expect(size.width, inInclusiveRange(176, 188));
          expect(size.height, inInclusiveRange(176, 188));
        }
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
          find.text(
            configuration.locale.languageCode == 'ar'
                ? 'مصدر الصحة متصل'
                : 'Health source connected',
          ),
          findsOneWidget,
        );

        await tester.fling(
          find.byType(PageView),
          Offset(configuration.locale.languageCode == 'ar' ? 360 : -360, 0),
          1200,
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(
          find.byKey(const Key('bil-live-medical-monitor')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Connected'), findsNothing);
        expect(
          find.byKey(const Key('dashboard-medical-status-label')),
          findsOneWidget,
        );
        expect(
          find.text(
            configuration.locale.languageCode == 'ar'
                ? 'غير متصل'
                : 'Not connected',
          ),
          findsOneWidget,
        );
        final medicalDot = tester.widget<Container>(
          find.byKey(const Key('dashboard-medical-status-dot')),
        );
        final medicalDecoration = medicalDot.decoration! as BoxDecoration;
        expect(medicalDecoration.color, const Color(0xFF9CA3AF));
        expect(tester.takeException(), isNull);
        if (configuration.locale.languageCode == 'en' &&
            configuration.scale == 1) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/dashboard_health_medical_readable_390.png',
            ),
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
