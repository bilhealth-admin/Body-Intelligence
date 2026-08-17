import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    final artifactTag = tag.replaceAll('-', '_');
    testWidgets('locale golden $tag', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData.light(useMaterial3: true),
          home: Builder(
            builder: (context) => RepaintBoundary(
              key: const Key('epic11-locale-golden'),
              child: Scaffold(
                appBar: AppBar(
                  centerTitle: true,
                  title: Text(AppLocalizations.of(context).get('settings')),
                ),
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      Text(
                        AppLocalizations.of(context).get('welcome_back'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      Text(AppLocalizations.of(context).get('empty_state')),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {},
                        child: Text(AppLocalizations.of(context).get('save')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Material localization delegates may complete after the first frame.
      // Wait until the localized home route is mounted before capturing it.
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('epic11-locale-golden')),
        matchesGoldenFile('goldens/epic11_${artifactTag}_phone.png'),
      );
    });
  }
}
