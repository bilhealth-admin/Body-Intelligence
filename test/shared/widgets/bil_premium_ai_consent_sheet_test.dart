import 'package:body_intelligence_log/shared/widgets/bil_premium_trust_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'premium AI consent keeps full-width actions stable at 2x ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => showBilPremiumAiConsentSheet(
                        context: context,
                        title: locale.languageCode == 'ar'
                            ? 'إرسال بيانات محددة إلى Google Gemini؟'
                            : 'Send selected data to Google Gemini?',
                        intro: locale.languageCode == 'ar'
                            ? 'خدمة ذكاء اصطناعي تابعة لجهة خارجية.'
                            : 'A third-party AI service operated by Google.',
                        points: const [
                          BilPremiumAiConsentPoint(
                            icon: Icons.tune_rounded,
                            title: 'Selected context only',
                            body:
                                'Question, selected context, and recent turns.',
                          ),
                          BilPremiumAiConsentPoint(
                            icon: Icons.mic_off_rounded,
                            title: 'Raw audio is not sent',
                            body: 'Voice recognition remains separate.',
                          ),
                          BilPremiumAiConsentPoint(
                            icon: Icons.verified_user_outlined,
                            title: 'You stay in control',
                            body: 'Decline now or withdraw later.',
                          ),
                        ],
                        allowLabel: locale.languageCode == 'ar'
                            ? 'السماح والمتابعة'
                            : 'Allow & Continue',
                        declineLabel: locale.languageCode == 'ar'
                            ? 'عدم السماح'
                            : "Don't Allow",
                        allowKey: const Key('allow'),
                        declineKey: const Key('decline'),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('allow')), findsOneWidget);
        expect(find.byKey(const Key('decline')), findsOneWidget);
        final allowRect = tester.getRect(find.byKey(const Key('allow')));
        final declineRect = tester.getRect(find.byKey(const Key('decline')));
        expect(allowRect.left, greaterThanOrEqualTo(0));
        expect(allowRect.right, lessThanOrEqualTo(320));
        expect(declineRect.left, greaterThanOrEqualTo(0));
        expect(declineRect.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
