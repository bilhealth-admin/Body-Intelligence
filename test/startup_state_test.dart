import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/startup/startup_page.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup failure is safe, localized, and retryable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => Stream.error(StateError('private database detail')),
          ),
          dailyCheckInDueProvider.overrideWith((ref) async => false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر فتح بياناتك المحلية'), findsOneWidget);
    expect(find.text('حاول مرة أخرى'), findsOneWidget);
    expect(find.textContaining('private database detail'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('Arabic startup progress has localized semantics', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      _app(
        overrides: [
          userProfileProvider.overrideWith((ref) => const Stream.empty()),
          dailyCheckInDueProvider.overrideWith((ref) => pending.future),
        ],
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp('يُجهّز BIL')), findsOneWidget);
  });
}

Widget _app({required dynamic overrides}) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    locale: Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: StartupPage(),
  ),
);
