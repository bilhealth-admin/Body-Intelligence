import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/wellness/presentation/sleep_stage_copy.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sourceId = 'com.apple.health.7D45981D-2E64-49B7-B40B-97FAB08A7E3B';
const _unspecifiedSleep = <String, String>{
  'en': 'Sleep (stage unspecified)',
  'ar': 'نوم (المرحلة غير محددة)',
  'fr': 'Sommeil (phase non précisée)',
  'es': 'Sueño (fase no especificada)',
  'tr': 'Uyku (evre belirtilmemiş)',
  'de': 'Schlaf (Phase nicht angegeben)',
  'it': 'Sonno (fase non specificata)',
  'pt-BR': 'Sono (fase não especificada)',
  'pt-PT': 'Sono (fase não especificada)',
  'ur': 'نیند (مرحلہ غیر متعین)',
  'fa': 'خواب (مرحله نامشخص)',
  'hi': 'नींद (चरण निर्दिष्ट नहीं)',
  'id': 'Tidur (tahap tidak ditentukan)',
  'ms': 'Tidur (peringkat tidak dinyatakan)',
  'ja': '睡眠（段階の指定なし）',
  'ko': '수면 (단계 미지정)',
  'zh-Hans': '睡眠（阶段未指定）',
  'zh-Hant': '睡眠（階段未指定）',
  'ru': 'Сон (стадия не указана)',
  'bn': 'ঘুম (পর্যায় অনির্দিষ্ট)',
  'vi': 'Ngủ (chưa xác định giai đoạn)',
  'th': 'การนอนหลับ (ไม่ระบุระยะ)',
  'pl': 'Sen (faza nieokreślona)',
  'nl': 'Slaap (fase niet gespecificeerd)',
  'uk': 'Сон (стадію не вказано)',
};

GlobalHealthSignal _nativeSleep({Map<String, Object?> attributes = const {}}) =>
    GlobalHealthSignal(
      key: 'sleep',
      canonicalValue: 2.7,
      canonicalUnit: 'h',
      provenance: GlobalProvenance(
        providerId: 'apple-health',
        sourceId: _sourceId,
        recordId: 'native-sleep-1',
        observedAt: DateTime(2026, 10, 4, 1),
        confidence: 1,
      ),
      attributes: {
        ...attributes,
        'sleepStage': 'asleepUnspecified',
        'endedAt': DateTime(2026, 10, 4, 3, 42).toIso8601String(),
      },
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'sleep projection preserves genuine native provenance and raw stage',
    () {
      final native = _nativeSleep(
        attributes: const {
          'wearableKind': 'apple_watch',
          'sourceProductType': 'Watch6,2',
          'sourceName': 'Apple Watch',
        },
      );
      final aggregated = aggregateConnectedSleepSignals([native]).single;
      final display = ConnectedHealthSignalView.fromSignal(aggregated);
      expect(aggregated.provenance.sourceId, _sourceId);
      expect(native.attributes['sleepStage'], 'asleepUnspecified');
      expect(aggregated.attributes['wearableKind'], 'apple_watch');
      expect(aggregated.attributes['sourceProductType'], 'Watch6,2');
      expect(aggregated.attributes['measuredStages'], ['asleepUnspecified']);
      expect(display.value, closeTo(2.7, 0.00001));
      expect(display.source, _sourceId);
      expect(connectedHealthDisplaySource(display), 'Apple Watch');
    },
  );

  for (final sample in const [
    (
      attributes: <String, Object?>{},
      source: _sourceId,
      expected: 'Apple Health',
    ),
    (
      attributes: <String, Object?>{'sourceProductType': 'iPhone14,2'},
      source: _sourceId,
      expected: 'Apple Health',
    ),
    (
      attributes: <String, Object?>{'sourceProductType': 'Watch6,2'},
      source: _sourceId,
      expected: 'Apple Watch',
    ),
    (
      attributes: <String, Object?>{'wearableKind': 'wear_os_watch'},
      source: 'Health Connect',
      expected: 'Health Connect',
    ),
    (
      attributes: <String, Object?>{'wearableKind': 'ble_fitness_sensor'},
      source: 'Polar H10',
      expected: 'Polar H10',
    ),
    (
      attributes: <String, Object?>{},
      source: 'Galaxy Watch',
      expected: 'Galaxy Watch',
    ),
    (
      attributes: <String, Object?>{},
      source: 'Owner Apple Watch Series 9',
      expected: 'Apple Watch',
    ),
  ]) {
    test(
      'source display requires Apple-specific evidence ${sample.source} ${sample.attributes}',
      () {
        final signal = ConnectedHealthSignalView(
          key: 'sleep',
          value: 2.7,
          unit: 'h',
          source: sample.source,
          observedAt: DateTime(2026, 10, 4),
          confidence: 1,
          attributes: sample.attributes,
        );
        expect(connectedHealthDisplaySource(signal), sample.expected);
        expect(signal.source, sample.source);
        expect(signal.attributes, sample.attributes);
      },
    );
  }

  test('sleep stage translations cover the supported locale set', () {
    expect(
      _unspecifiedSleep.keys.toSet(),
      AppLocalizations.supportedLocales
          .map(BilLocalePolicy.canonicalTag)
          .toSet(),
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('Sleep uses evidenced Apple Watch and localized stage $tag', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await database.close();
      });
      final native = _nativeSleep(
        attributes: const {
          'wearableKind': 'apple_watch',
          'sourceProductType': 'Watch6,2',
        },
      );
      final projection = ConnectedHealthSignalView.fromSignal(
        aggregateConnectedSleepSignals([native]).single,
      );
      final snapshot = const ConnectedHealthSnapshot.unavailable().copyWith(
        status: ConnectedHealthStatus.synchronized,
        platformSource: 'Apple Health',
        deviceVerified: true,
        signals: [projection],
        lastSyncAt: DateTime(2026, 10, 4, 9),
      );
      final stageLabels = <String, String>{};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            connectedHealthGatewayProvider.overrideWithValue(
              _SleepGateway(snapshot),
            ),
            sleepNowProvider.overrideWithValue(() => DateTime(2026, 10, 4, 10)),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            builder: (context, child) {
              for (final stage in const [
                'core',
                'deep',
                'rem',
                'asleepUnspecified',
                'future-provider-stage',
              ]) {
                stageLabels[stage] = wellnessSleepStageLabel(context, stage);
              }
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              );
            },
            home: const SleepTrackerPage(),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container.read(connectedHealthProvider.notifier).refresh();
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('sleep-log-tab')),
            matching: find.byType(Scrollable),
          )
          .first;
      final source = find.byKey(const Key('sleep-connected-source'));
      await tester.scrollUntilVisible(source, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(find.textContaining('Apple Watch'), findsOneWidget);
      expect(find.textContaining(_sourceId), findsNothing);
      if (tag != 'en') {
        expect(find.textContaining('Measured by'), findsNothing);
      }
      final stages = find.byKey(const Key('sleep-measured-stages'));
      await tester.scrollUntilVisible(stages, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(find.text(_unspecifiedSleep[tag]!), findsOneWidget);
      expect(find.text('asleepUnspecified'), findsNothing);
      for (final entry in stageLabels.entries) {
        expect(entry.value, isNotEmpty, reason: '$tag ${entry.key}');
        expect(entry.value, isNot(entry.key));
        if (tag != 'en') {
          expect(
            entry.value,
            isNot(
              isIn(const [
                'Core sleep',
                'Deep sleep',
                'REM sleep',
                'Sleep (stage unspecified)',
                'Sleep stage unavailable',
              ]),
            ),
          );
        }
      }
      expect(
        stageLabels['future-provider-stage'],
        isNot(
          isIn(
            stageLabels.entries
                .where((entry) => entry.key != 'future-provider-stage')
                .map((entry) => entry.value),
          ),
        ),
      );
      expect(native.provenance.sourceId, _sourceId);
      expect(native.attributes['sleepStage'], 'asleepUnspecified');
      expect(projection.value, closeTo(2.7, 0.00001));
      expect(tester.takeException(), isNull, reason: tag);
    });
  }
}

final class _SleepGateway implements ConnectedHealthGateway {
  const _SleepGateway(this.snapshot);
  final ConnectedHealthSnapshot snapshot;
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
