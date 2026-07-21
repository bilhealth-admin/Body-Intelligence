import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile setup advances by purpose and preserves back state', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          appSettingsServiceProvider.overrideWithValue(_SettingsService()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
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
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();

    expect(find.text('Let’s start with you'), findsOneWidget);
    expect(find.text('Current weight'), findsNothing);
    expect(find.text('Goal'), findsNothing);

    // حقن القيمة داخل الحقل الـ readOnly مباشرة لتجاوز فتح الـ Picker
    final dobFinder = find.widgetWithText(TextFormField, 'Date of Birth');
    final TextFormField dobWidget = tester.widget(dobFinder);
    dobWidget.controller?.text = '1992-07-20'; 
    await tester.pumpAndSettle();

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    
    // عمل سكرول للأسفل للوصول لاتفاقية السلامة الطبية (Disclaimer) لتجنب خطأ خارج الشاشة
    final disclaimerFinder = find.byType(CheckboxListTile);
    await tester.scrollUntilVisible(
      disclaimerFinder,
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // تفعيل الاتفاقية لتفعيل زر المتابعة
    await tester.tap(disclaimerFinder);
    await tester.pumpAndSettle();

    // البحث عن زر Continue وعمل سكرول إضافي لضمان ظهوره كاملاً
    final continueButtonFinder = find.widgetWithText(FilledButton, 'Continue');
    await tester.scrollUntilVisible(
      continueButtonFinder,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(continueButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Your starting point'), findsOneWidget);
    expect(find.text('Date of Birth'), findsNothing);
    
    final draft = await OnboardingDraftRepository(
      PreferencesRepository(database),
    ).load();
    expect(draft?.step, 2);
    expect(draft?.age, '34');
    expect(draft?.gender, 'female');

    await tester.tap(find.widgetWithText(TextButton, 'Back'));
    await tester.pumpAndSettle();
    
    expect(find.text('Let’s start with you'), findsOneWidget);
    
    final dobFinderBack = find.widgetWithText(TextFormField, 'Date of Birth');
    final TextFormField dobWidgetBack = tester.widget(dobFinderBack);
    expect(dobWidgetBack.controller?.text, '1992-07-20');
    
    expect(tester.takeException(), isNull);
  });
}

class _SettingsService extends AppSettingsService {
  AppSettings value = AppSettings(localeCode: 'en', themeMode: 'system');

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}