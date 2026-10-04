import 'package:body_intelligence_log/shared/widgets/bil_premium_trust_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
          testWidgets(
            'real consent decisions ${arabic ? 'ar RTL' : 'en LTR'} '
            '${dark ? 'dark' : 'light'} ${scale}x ${platform.name}',
            (tester) async {
              tester.view.physicalSize = const Size(320, 568);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final decisions = <bool?>[];
              final locale = Locale(arabic ? 'ar' : 'en');
              await tester.pumpWidget(
                MaterialApp(
                  locale: locale,
                  supportedLocales: const [Locale('en'), Locale('ar')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                    platform: platform,
                    useMaterial3: true,
                  ),
                  // Above the Navigator: the actual modal must inherit these
                  // metrics, not only the button used to open the modal.
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(top: 24, bottom: 24),
                      viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: FilledButton(
                          key: const Key('open-consent'),
                          onPressed: () async {
                            final decision = await showBilPremiumAiConsentSheet(
                              context: context,
                              title: arabic
                                  ? 'إرسال بيانات شخصية محددة إلى Google Gemini؟'
                                  : 'Send selected personal data to Google Gemini?',
                              intro: arabic
                                  ? 'يستخدم BIL خدمة Google Gemini، وهي خدمة ذكاء اصطناعي تابعة لجهة خارجية وتديرها Google، فقط لإنشاء الإجابة التي تطلبها.'
                                  : 'BIL uses Google Gemini, a third-party AI service operated by Google, only to generate the answer you request.',
                              points: [
                                BilPremiumAiConsentPoint(
                                  icon: Icons.tune_rounded,
                                  title: arabic
                                      ? 'فقط السياق الذي تختاره'
                                      : 'Only the context you choose',
                                  body: arabic
                                      ? 'سؤالك؛ وما تختاره من الوزن والأهداف والقياسات؛ والوجبات والتغذية والماء والتفضيلات؛ والنشاط والتدريب؛ والنوم والعادات؛ إضافة إلى ما يصل إلى آخر 12 رسالة.'
                                      : 'Your question; selected weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns.',
                                ),
                                BilPremiumAiConsentPoint(
                                  icon: Icons.mic_off_rounded,
                                  title: arabic
                                      ? 'لا يتم إرسال صوت الميكروفون الخام'
                                      : 'Raw microphone audio is not sent',
                                  body: arabic
                                      ? 'يبقى التعرف على الصوت منفصلًا عن موافقة الذكاء الاصطناعي عن بُعد.'
                                      : 'Voice recognition stays separate from this Remote AI consent.',
                                ),
                                BilPremiumAiConsentPoint(
                                  icon: Icons.verified_user_outlined,
                                  title: arabic
                                      ? 'التحكم يبقى بيدك'
                                      : 'You stay in control',
                                  body: arabic
                                      ? 'يمكنك الرفض ومتابعة استخدام ميزات BIL المحلية، أو سحب هذه الموافقة لاحقًا من إعدادات AI Coach.'
                                      : 'You can decline and keep using local BIL features, or withdraw this consent later in AI Coach settings.',
                                ),
                              ],
                              allowLabel: arabic
                                  ? 'السماح والمتابعة'
                                  : 'Allow & Continue',
                              declineLabel: arabic ? 'عدم السماح' : "Don't Allow",
                              allowKey: const Key('allow'),
                              declineKey: const Key('decline'),
                            );
                            decisions.add(decision);
                          },
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ),
                ),
              );

              for (final decision in [false, true]) {
                final before = decisions.length;
                await tester.tap(find.byKey(const Key('open-consent')));
                await tester.pumpAndSettle();
                final allow = find.byKey(const Key('allow'));
                final decline = find.byKey(const Key('decline'));
                expect(allow, findsOneWidget);
                expect(decline, findsOneWidget);
                final sheetContext = tester.element(allow);
                expect(Localizations.localeOf(sheetContext), locale);
                expect(
                  Directionality.of(sheetContext),
                  arabic ? TextDirection.rtl : TextDirection.ltr,
                );
                expect(
                  MediaQuery.textScalerOf(sheetContext).scale(12),
                  closeTo(12 * scale, .001),
                );
                expect(decisions.length, before,
                    reason: 'Opening and reading is not consent.');
                final allowRect = tester.getRect(allow);
                final declineRect = tester.getRect(decline);
                expect(allowRect.width, closeTo(declineRect.width, .1));
                expect(allowRect.width, greaterThan(240));
                expect(allowRect.height, greaterThanOrEqualTo(48));
                expect(declineRect.height, greaterThanOrEqualTo(48));
                final action = decision ? allow : decline;
                await tester.ensureVisible(action);
                await tester.pumpAndSettle();
                expect(action.hitTestable(), findsOneWidget);
                final rect = tester.getRect(action);
                expect(rect.left, greaterThanOrEqualTo(0));
                expect(rect.right, lessThanOrEqualTo(320));
                expect(rect.top, greaterThanOrEqualTo(24));
                expect(rect.bottom, lessThanOrEqualTo(544));
                expect(tester.takeException(), isNull);
                await tester.tap(action);
                await tester.pumpAndSettle();
                expect(decisions, hasLength(before + 1));
                expect(decisions.last, decision);
                expect(find.byKey(const Key('allow')), findsNothing);
              }

              await tester.tap(find.byKey(const Key('open-consent')));
              await tester.pumpAndSettle();
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
              expect(decisions, [false, true, null],
                  reason: 'Dismissal must never become an affirmative choice.');
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
