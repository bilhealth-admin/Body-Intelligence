import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/modern_onboarding_scaffold.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pinned_header_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  for (final largeRtl in [false, true]) {
    testWidgets('onboarding title and intro stay fixed while choices scroll '
        '${largeRtl ? 'RTL 220% keyboard' : 'LTR 100%'}', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var selected = false;
      var nextCalls = 0;
      final title = largeRtl
          ? 'ما الذي ترغب في العمل عليه؟'
          : 'Your priorities';
      final subtitle = largeRtl
          ? 'اختر أكثر من هدف. يمكنك تغيير هذه الأولويات لاحقًا.'
          : 'Choose more than one. You can change these priorities later.';
      await tester.pumpWidget(
        MaterialApp(
          theme: visualEvidenceTheme(
            BilFlagshipTheme.light(isArabic: largeRtl),
            fontFamily: largeRtl ? 'NotoArabicEvidence' : 'RobotoEvidence',
          ),
          locale: Locale(largeRtl ? 'ar' : 'en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(largeRtl ? 2.2 : 1),
              viewInsets: EdgeInsets.only(bottom: largeRtl ? 240 : 0),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => ModernOnboardingScaffold(
              step: 1,
              totalSteps: 8,
              title: title,
              subtitle: subtitle,
              onBack: () {},
              onNext: () => nextCalls++,
              body: Column(
                children: [
                  const TextField(key: Key('onboarding-scroll-field')),
                  for (var index = 0; index < 7; index++)
                    OnboardingChoiceCard(
                      title: 'Goal $index',
                      selected: false,
                      icon: Icons.favorite_outline,
                      onTap: () {},
                    ),
                  OnboardingChoiceCard(
                    key: const Key('onboarding-scroll-last-choice'),
                    title: largeRtl
                        ? 'النشاط واللياقة'
                        : 'Activity and fitness',
                    selected: selected,
                    icon: Icons.directions_run,
                    onTap: () => setState(() => selected = !selected),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final split = tester.widget<BilPinnedHeaderBody>(
        find.byType(BilPinnedHeaderBody),
      );
      final header = find.byWidget(split.header);
      final headerRect = tester.getRect(header);
      final titleRect = tester.getRect(find.text(title));
      final subtitleRect = tester.getRect(find.text(subtitle));
      final footer = find.byKey(const Key('onboarding-footer'));
      final footerRect = tester.getRect(footer);
      final titleParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(title), matching: find.byType(RichText)),
      );
      final heading = tester.widget<Text>(find.text(title));
      final canonical = Theme.of(
        tester.element(find.text(title)),
      ).textTheme.titleLarge!;
      expect(heading.style?.fontSize, canonical.fontSize);
      expect(heading.style?.fontFamily, canonical.fontFamily);
      expect(heading.style?.fontWeight, FontWeight.w800);
      expect(titleParagraph.textScaler.scale(16), largeRtl ? 35.2 : 16);
      final body = find.byKey(const ValueKey<String>('onboarding-scroll-1'));
      final scrollState = Scrollable.of(
        tester.element(find.byKey(const Key('onboarding-step-input-content'))),
      );
      expect(scrollState.position.maxScrollExtent, greaterThan(0));
      await tester.drag(body, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(scrollState.position.pixels, greaterThan(0));
      expect(tester.getRect(header), headerRect);
      expect(tester.getRect(find.text(title)), titleRect);
      expect(tester.getRect(find.text(subtitle)), subtitleRect);
      final choice = find.byKey(const Key('onboarding-scroll-last-choice'));
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(tester.getRect(footer), footerRect);
      expect(tester.getRect(find.text(title)), titleRect);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(nextCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
