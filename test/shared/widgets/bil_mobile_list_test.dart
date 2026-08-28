import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/profile/profile_locale_copy.dart';
import 'package:body_intelligence_log/shared/widgets/bil_mobile_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile list keeps label and value to one polished line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: BilMobileListRow(
            label: 'Calories and macro plan with recommendations',
            value: 'Update weight, nutrition, and fitness goals',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(
      find.text('Calories and macro plan with recommendations'),
    );
    final value = tester.widget<Text>(
      find.text('Update weight, nutrition, and fitness goals'),
    );
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(value.maxLines, 1);
    expect(value.softWrap, isFalse);
    expect(value.overflow, TextOverflow.ellipsis);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      '${locale.toLanguageTag()} keeps long profile rows on one line at 160%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
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
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: ListView(
                  children: [
                    BilMobileListRow(
                      label: profileLocaleText(
                        context,
                        'Email address',
                        'البريد الإلكتروني',
                      ),
                      value: 'play-review@bilhealth.com',
                      onTap: () {},
                    ),
                    BilMobileListRow(
                      label: profileLocaleText(context, 'Goals', 'الأهداف'),
                      value: profileLocaleText(
                        context,
                        'Update weight, nutrition, and fitness goals',
                        'حدّث أهداف الوزن والتغذية واللياقة',
                      ),
                      onTap: () {},
                    ),
                    BilMobileListRow(
                      label: profileLocaleText(
                        context,
                        'Calories & macro plan',
                        'خطة السعرات والماكروز',
                      ),
                      value: profileLocaleText(
                        context,
                        'Plan details & recommendations',
                        'تفاصيل الخطة والتوصيات',
                      ),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final row in find.byType(BilMobileListRow).evaluate()) {
          final texts = find
              .descendant(
                of: find.byElementPredicate((element) => element == row),
                matching: find.byType(Text),
              )
              .evaluate()
              .map((element) => element.widget as Text);
          expect(texts, hasLength(2));
          for (final text in texts) {
            expect(text.maxLines, 1);
            expect(text.overflow, TextOverflow.ellipsis);
          }
        }
      },
    );
  }
}
