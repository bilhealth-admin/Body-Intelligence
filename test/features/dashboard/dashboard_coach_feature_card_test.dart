import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_header.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:body_intelligence_log/shared/widgets/bil_coach_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';
import 'support/dashboard_coach_legacy_geometry.dart';

const _bodyEn =
    'Discuss your goals, prepare training and nutrition plans, and review your progress.';
const _bodyAr = 'ناقش أهدافك، جهّز خطط التدريب والتغذية، وراجع تقدّمك.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      '393px ${locale.languageCode} keeps old normal footprint and large portrait',
      (tester) async {
        final h = _Harness(locale: locale);
        try {
          await h.mount(tester, const LegacyDashboardHeader());
          final oldSize = tester.getSize(find.byType(LegacyDashboardHeader));
          final original = _portraitDecoration(tester);
          await h.mount(tester, const DashboardHeader());
          final surface = find.byKey(const Key('dashboard-coach-card-surface'));
          expect(surface, findsOneWidget);
          final size = tester.getSize(surface);
          expect(size.width, oldSize.width);
          expect(size.height, 140);
          expect((size.height - oldSize.height).abs(), lessThanOrEqualTo(16));
          expect(_portraitDecoration(tester).image, original.image);
          expect(_portraitDecoration(tester).gradient, original.gradient);
          expect(find.byType(BilCoachPortrait), findsNothing);
          expect(find.byType(EditableText), findsNothing);
          expect(find.byType(FilledButton), findsNothing);
          expect(find.byType(TextButton), findsNothing);
          final body = tester.widget<Text>(
            find.byKey(const Key('dashboard-coach-description')),
          );
          expect(body.data, locale.languageCode == 'ar' ? _bodyAr : _bodyEn);
          expect(body.maxLines, isNull);
          if (locale.languageCode == 'en') {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.byKey(const Key('dashboard-coach-description')),
            );
            expect(paragraph.size.height, lessThanOrEqualTo(34));
          }
          expect(tester.takeException(), isNull);
        } finally {
          await h.close(tester);
        }
      },
    );

    testWidgets(
      '320px ${locale.languageCode} 2x grows without clipping content or actions',
      (tester) async {
        final h = _Harness(locale: locale, width: 320, scale: 2);
        try {
          await h.mount(tester, const DashboardHeader());
          final surface = tester.getRect(
            find.byKey(const Key('dashboard-coach-card-surface')),
          );
          final paragraph = tester.getRect(
            find.byKey(const Key('dashboard-coach-description')),
          );
          final action = tester.getRect(
            find.byKey(const Key('dashboard-ai-coach-entry')),
          );
          expect(surface.height, greaterThan(148));
          expect(paragraph.left, greaterThanOrEqualTo(surface.left));
          expect(paragraph.right, lessThanOrEqualTo(surface.right));
          expect(action.bottom, lessThanOrEqualTo(surface.bottom));
          expect(action.height, greaterThanOrEqualTo(44));
          expect(find.byType(EditableText), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const Key('dashboard-ai-coach-entry')),
          );
          await tester.tap(find.byKey(const Key('dashboard-ai-coach-entry')));
          await tester.pumpAndSettle();
          expect(h.path, '/intelligence-center');
          expect(h.coachPushes, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await h.close(tester);
        }
      },
    );
  }

  for (final fallback in [false, true]) {
    for (final target in ['body', 'portrait', 'card']) {
      testWidgets(
        '${fallback ? 'fallback' : 'main'} $target opens one existing coach route without keyboard',
        (tester) async {
          final h = _Harness();
          try {
            await h.mount(
              tester,
              fallback ? _fallback() : const DashboardHeader(),
            );
            expect(find.byType(DashboardHeader), findsOneWidget);
            expect(find.byType(EditableText), findsNothing);
            expect(find.byType(TextField), findsNothing);
            expect(find.byType(BilCoachPortrait), findsNothing);
            if (fallback) {
              expect(
                find.byKey(const Key('dashboard-mobile-ai-coach-entry')),
                findsOneWidget,
              );
            }
            if (target == 'body') {
              await tester.tap(
                find.byKey(const Key('dashboard-coach-description')),
              );
            } else if (target == 'card') {
              await tester.tap(
                find.byKey(const Key('dashboard-ai-coach-entry')),
              );
            } else {
              final rect = tester.getRect(
                find.byKey(const Key('dashboard-coach-card-surface')),
              );
              await tester.tapAt(Offset(rect.right - 10, rect.top + 20));
            }
            await tester.pumpAndSettle();
            expect(h.path, '/intelligence-center');
            expect(h.coachPushes, 1);
            expect(tester.testTextInput.isVisible, isFalse);
            expect(tester.takeException(), isNull);
          } finally {
            await h.close(tester);
          }
        },
      );
    }
  }

  testWidgets(
    'card is keyboard actionable without creating an editable focus',
    (tester) async {
      final h = _Harness();
      try {
        await h.mount(tester, const DashboardHeader());
        expect(find.byType(EditableText), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(h.path, '/intelligence-center');
        expect(h.coachPushes, 1);
        expect(tester.testTextInput.isVisible, isFalse);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets('desktop keeps same card, large portrait and coach action', (
    tester,
  ) async {
    final h = _Harness(width: 1000);
    try {
      await h.mount(tester, const DashboardHeader());
      expect(find.text('BIL AI Coach'), findsOneWidget);
      expect(find.text(_bodyEn), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      final image = _portraitDecoration(tester).image!;
      expect(image.fit, BoxFit.contain);
      expect(image.opacity, .66);
      expect(image.alignment, AlignmentDirectional.centerEnd);
      await tester.tap(find.byKey(const Key('dashboard-ai-coach-entry')));
      await tester.pumpAndSettle();
      expect(h.path, '/intelligence-center');
      expect(h.coachPushes, 1);
    } finally {
      await h.close(tester);
    }
  });
}

BoxDecoration _portraitDecoration(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  return containers
      .map((value) => value.decoration)
      .whereType<BoxDecoration>()
      .singleWhere((value) {
        final image = value.image?.image;
        return image is AssetImage &&
            image.assetName == bilApprovedAiCoachAsset;
      });
}

Widget _fallback() => const PremiumDashboardBenchmark(
  arabic: false,
  actionTitle: '',
  actionReason: '',
  actionEvidence: '',
  confidence: '',
  onAction: null,
  dailyIntelligence: SizedBox.shrink(),
  bodyTwinSummary: '',
  bodyTwinEvidence: '',
  nutritionSummary: '',
  nutritionEvidence: '',
  trendSummary: '',
  trendEvidence: '',
  loggingItems: [],
  visibleSections: {DashboardSectionIds.aiCoach},
);

class _Harness {
  _Harness({
    this.locale = const Locale('en'),
    this.width = 393,
    this.scale = 1,
  });
  final Locale locale;
  final double width, scale;
  int coachPushes = 0;
  late GoRouter router;
  Widget subject = const SizedBox.shrink();
  bool _created = false;
  String get path =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  Future<void> mount(WidgetTester tester, Widget value) async {
    subject = value;
    await tester.binding.setSurfaceSize(Size(width, 900));
    if (_created) {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
    _created = true;
    router = GoRouter(
      initialLocation: '/dashboard',
      observers: [_CoachObserver(() => coachPushes++)],
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: subject),
            ),
          ),
        ),
        GoRoute(
          path: '/intelligence-center',
          name: 'coach',
          builder: (_, _) {
            return const Scaffold(body: Text('Existing coach destination'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: ThemeData(
          fontFamily: locale.languageCode == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await tester.binding.setSurfaceSize(null);
  }
}

class _CoachObserver extends NavigatorObserver {
  _CoachObserver(this.onPush);
  final VoidCallback onPush;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == 'coach') onPush();
  }
}
