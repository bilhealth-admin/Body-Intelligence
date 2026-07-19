import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('local onboarding load failure is safe and retryable in Arabic', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          preferencesRepositoryProvider.overrideWithValue(
            _FailingPreferencesRepository(database),
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
          home: OnboardingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذرت استعادة إعدادك المحلي'), findsOneWidget);
    expect(find.textContaining('لم يتم حذف أي شيء'), findsOneWidget);
    expect(find.text('حاول مرة أخرى'), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}

class _FailingPreferencesRepository extends PreferencesRepository {
  _FailingPreferencesRepository(super.database);

  @override
  Future<String?> get(String key) => Future.error(StateError('private detail'));
}
