import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/profile_summary_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('weight change reacts to canonical weight-history updates', (
    tester,
  ) async {
    final weightUpdates = StreamController<List<WeightEntry>>();
    final now = DateTime.utc(2026, 8, 1);
    final profile = UserProfileData(
      id: 1,
      uuid: 'profile-1',
      gender: 'male',
      age: 30,
      height: 175,
      currentWeight: 120,
      targetWeight: 90,
      activityLevel: 'moderate',
      exercises: true,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      syncStatus: 'local',
    );
    final baseline = _weight(id: 1, day: 1, kilograms: 100);
    final second = _weight(id: 2, day: 2, kilograms: 95);
    final latest = _weight(id: 3, day: 3, kilograms: 92);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((_) => Stream.value(profile)),
          weightHistoryProvider.overrideWith((_) async* {
            yield [second, baseline];
            yield* weightUpdates.stream;
          }),
          measurementSystemProvider.overrideWith(
            (_) => Stream.value(MeasurementSystem.metric),
          ),
          profileMemberSinceProvider.overrideWithValue(now),
          profileFriendsCountProvider.overrideWith((_) async => 1),
          displayNameProvider.overrideWith((_) => Stream.value('BIL member')),
          profilePhotoProvider.overrideWith((_) => Stream.value(null)),
          profilePhotoPublicUrlProvider.overrideWith((_) async => null),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: ProfileSummaryPage(),
        ),
      ),
    );
    await _pumpUntilFound(tester, '-5.0 kg');

    expect(find.text('-5.0 kg'), findsOneWidget);
    expect(find.bySemanticsLabel('Weight change, -5.0 kg'), findsOneWidget);

    weightUpdates.add([latest, second, baseline]);
    await _pumpUntilFound(tester, '-8.0 kg');

    expect(find.text('-8.0 kg'), findsOneWidget);
    expect(find.text('-5.0 kg'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(weightUpdates.close());
    await tester.pump();
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, String text) async {
  for (
    var attempt = 0;
    attempt < 20 && find.text(text).evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

WeightEntry _weight({
  required int id,
  required int day,
  required double kilograms,
}) {
  final date = DateTime.utc(2026, 8, day);
  return WeightEntry(
    id: id,
    uuid: 'weight-$id',
    date: date,
    dayKey: '2026-08-${day.toString().padLeft(2, '0')}',
    weight: kilograms,
    measurementContext: 'morning',
    createdAt: date,
    updatedAt: date,
    revision: 1,
    syncStatus: 'local',
  );
}
