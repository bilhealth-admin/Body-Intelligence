import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_header.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard header hides local errors behind a safe retry state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestWeightProvider.overrideWith(
            (ref) => Stream.error(Exception('sensitive database detail')),
          ),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.value(MeasurementSystem.metric),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: DashboardHeader()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل أحدث بيانات جسمك.'), findsOneWidget);
    expect(find.text('حاول مرة أخرى'), findsOneWidget);
    expect(find.textContaining('sensitive database detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
