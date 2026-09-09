import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/challenges/challenges_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared challenge locks expose state and all supported audience copy',
    () {
      final source = File(
        'lib/features/challenges/challenges_page.dart',
      ).readAsStringSync();

      for (final label in const [
        'الأصدقاء',
        'بإشراف مدرب',
        'الفريق',
        'Amis',
        'Créés par un coach',
        'Équipe',
        'Amigos',
        'Creados por un entrenador',
        'Equipo',
        'Arkadaşlar',
        'Antrenör tarafından',
        'Takım',
      ]) {
        expect(source, contains(label), reason: label);
      }
      expect(source, contains('_SharedChallengesUnavailableCard'));
      expect(source, isNot(contains('_LockedSharedChallengeTile')));
      expect(source, contains("Key('shared-challenges-unavailable')"));
    },
  );

  testWidgets('shared audiences are one explanatory state, not locked tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          challengesProvider.overrideWith(
            (ref) => Stream.value(const <Challenge>[]),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ChallengesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('shared-challenges-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(Chip), findsNWidgets(4));
    expect(find.byIcon(Icons.lock_clock_outlined), findsOneWidget);
  });
}
