import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_runtime_copy.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/modern_onboarding_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _capture = Key('compact-onboarding-capture');
const _lastChoice = Key('compact-onboarding-last-choice');
const _photo =
    'assets/images/onboarding_2026/bil_onboarding_goals_activity_photo_v1.webp';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);

  for (final size in const [Size(360, 800), Size(430, 932)]) {
    for (final scale in const [1.0, 1.15, 2.0]) {
      for (final language in const ['en', 'ar']) {
        final id = '${size.width.toInt()}_${language}_${(scale * 100).round()}';
        testWidgets('compact onboarding actions fit and remain usable $id', (
          tester,
        ) async {
          final fixture = await _mount(tester, size, scale, Locale(language));
          final back = find.byKey(const Key('onboarding-back'));
          final next = find.byKey(const Key('onboarding-next'));
          _expectReachable(tester, back, size);
          _expectReachable(tester, next, size);
          // All short current labels fit together, including the actual OPPO
          // viewport. Do not reserve a second row solely for a width/scale cut-off.
          expect(
            tester.getCenter(back).dy,
            closeTo(tester.getCenter(next).dy, 1),
          );
          if (scale <= 1.15) {
            expect(
              tester.getSize(find.byKey(const Key('onboarding-footer'))).height,
              lessThan(100),
            );
          }
          if (language == 'ar') {
            expect(
              tester.getCenter(back).dx,
              greaterThan(tester.getCenter(next).dx),
            );
          } else {
            expect(
              tester.getCenter(back).dx,
              lessThan(tester.getCenter(next).dx),
            );
          }
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(const Key('onboarding-step-title')),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.textScaler.scale(16), closeTo(16 * scale, .001));
          final footerBeforeScroll = tester.getRect(
            find.byKey(const Key('onboarding-footer')),
          );
          await tester.ensureVisible(find.byKey(_lastChoice));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(_lastChoice));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<OnboardingChoiceCard>(find.byKey(_lastChoice))
                .selected,
            isTrue,
          );
          expect(
            tester.getRect(find.byKey(const Key('onboarding-footer'))),
            footerBeforeScroll,
          );
          await tester.tap(next);
          await tester.pumpAndSettle();
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(fixture.currentState!.nextCalls, 1);
          expect(fixture.currentState!.backCalls, 1);
          expect(tester.takeException(), isNull);
        });

        testWidgets('compact onboarding new visual $id', (tester) async {
          await _mount(tester, size, scale, Locale(language));
          await expectLater(
            find.byKey(_capture),
            matchesGoldenFile('goldens/onboarding_compact_footer/$id.png'),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'long label and Skip stack by actual fit without losing any action',
    (tester) async {
      const size = Size(360, 800);
      final fixture = await _mount(
        tester,
        size,
        2,
        const Locale('en'),
        longLabel: true,
      );
      final back = find.byKey(const Key('onboarding-back'));
      final skip = find.byKey(const Key('onboarding-skip'));
      final next = find.byKey(const Key('onboarding-next'));
      for (final action in [back, skip, next]) {
        _expectReachable(tester, action, size);
      }
      expect(tester.getCenter(back).dy, closeTo(tester.getCenter(skip).dy, 1));
      expect(
        tester.getRect(next).top,
        greaterThanOrEqualTo(tester.getRect(back).bottom + 8),
      );
      final label = find.text(_longLabel);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(paragraph.textScaler.scale(16), 32);
      await tester.tap(skip);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(fixture.currentState!.skipCalls, 1);
      expect(fixture.currentState!.nextCalls, 1);
      expect(fixture.currentState!.backCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectReachable(WidgetTester tester, Finder action, Size size) {
  expect(action.hitTestable(), findsOneWidget);
  final rect = tester.getRect(action);
  expect(rect.width, greaterThanOrEqualTo(48));
  expect(rect.height, greaterThanOrEqualTo(48));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.top, greaterThanOrEqualTo(24));
  expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
}

const _longLabel =
    'Continue and review all selected personal setup preferences';

Future<GlobalKey<_ScaffoldFixtureState>> _mount(
  WidgetTester tester,
  Size size,
  double scale,
  Locale locale, {
  bool longLabel = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final key = GlobalKey<_ScaffoldFixtureState>();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: visualEvidenceTheme(
        BilFlagshipTheme.light(isArabic: locale.languageCode == 'ar'),
        fontFamily: locale.languageCode == 'ar'
            ? 'NotoArabicEvidence'
            : 'RobotoEvidence',
      ).copyWith(platform: TargetPlatform.android),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.symmetric(vertical: 24),
          viewPadding: const EdgeInsets.symmetric(vertical: 24),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: _capture, child: child!),
      ),
      home: _ScaffoldFixture(key: key, locale: locale, longLabel: longLabel),
    ),
  );
  await tester.pumpAndSettle();
  await settleVisualAssetImages(tester);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return key;
}

class _ScaffoldFixture extends StatefulWidget {
  const _ScaffoldFixture({
    super.key,
    required this.locale,
    required this.longLabel,
  });
  final Locale locale;
  final bool longLabel;
  @override
  State<_ScaffoldFixture> createState() => _ScaffoldFixtureState();
}

class _ScaffoldFixtureState extends State<_ScaffoldFixture> {
  int backCalls = 0;
  int nextCalls = 0;
  int skipCalls = 0;
  bool selected = false;
  String copy(String source) =>
      OnboardingRuntimeCopy.resolve(source, widget.locale);

  @override
  Widget build(BuildContext context) => ModernOnboardingScaffold(
    step: 1,
    totalSteps: 8,
    title: copy('What would you like to work on?'),
    subtitle: copy(
      'Choose more than one. You can change these priorities later.',
    ),
    artwork: const ModernOnboardingPhotoHero(
      image: AssetImage(_photo),
      height: 224,
    ),
    onBack: () => backCalls++,
    onNext: () => nextCalls++,
    onSkip: widget.longLabel ? () => skipCalls++ : null,
    nextLabel: widget.longLabel ? _longLabel : null,
    body: Column(
      children: [
        for (final title in const [
          'Lose weight',
          'Maintain weight',
          'Plan meals',
        ]) ...[
          OnboardingChoiceCard(
            title: copy(title),
            subtitle: copy(
              'Make recipes and meal planning part of your routine.',
            ),
            selected: false,
            icon: Icons.calendar_month_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 10),
        ],
        OnboardingChoiceCard(
          key: _lastChoice,
          title: copy('Activity and fitness'),
          subtitle: copy(
            'Use workouts and verified activity as separate evidence.',
          ),
          icon: Icons.directions_run_rounded,
          selected: selected,
          onTap: () => setState(() => selected = !selected),
        ),
      ],
    ),
  );
}
