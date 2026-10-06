import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_presenter.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _targets = [
  ('quick-add-primary-0', '/daily-log', {'foodLog': '1', 'from': '/community'}),
  (
    'quick-add-primary-1',
    '/daily-log',
    {'foodLog': '1', 'action': 'barcode', 'from': '/dashboard'},
  ),
  (
    'quick-add-primary-2',
    '/daily-log',
    {'foodLog': '1', 'action': 'voice', 'from': '/dashboard'},
  ),
  ('quick-add-primary-3', '/quick-add/meal-camera', {'from': '/community'}),
  ('quick-add-secondary-0', '/wellness/workouts', <String, String>{}),
  ('quick-add-secondary-1', '/daily-log/body-context', {'from': '/community'}),
  ('quick-add-secondary-2', '/nutrition', <String, String>{}),
];

Widget _app(GoRouter router) => MaterialApp.router(
  routerConfig: router,
  theme: visualEvidenceTheme(ThemeData()),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
);

GoRouter _router({
  String initial = '/community',
  String origin = '/community',
  void Function(Uri)? arrived,
}) => GoRouter(
  initialLocation: initial,
  routes: [
    for (final path in {
      '/community',
      '/intelligence-center',
      '/community/notifications',
      '/settings',
      '/dashboard',
      '/daily-log',
      '/quick-add/meal-camera',
      '/wellness/workouts',
      '/daily-log/body-context',
      '/nutrition',
    })
      GoRoute(
        path: path,
        builder: (context, state) {
          arrived?.call(state.uri);
          return Scaffold(
            body: Column(
              children: [
                Text(state.uri.toString(), key: const Key('route')),
                FilledButton(
                  key: const Key('open-quick-add'),
                  onPressed: () => showBilQuickAdd(context, originPath: origin),
                  child: const Text('Open'),
                ),
              ],
            ),
          );
        },
      ),
  ],
);

void main() {
  setUpAll(loadVisualEvidenceFont);
  test(
    'return destinations are the exact known roots, never a redirect or prefix',
    () {
      expect(bilQuickAddReturnPaths, {
        '/dashboard',
        '/daily-log',
        '/nutrition',
        '/history',
        '/analytics',
        '/settings',
        '/intelligence-center',
        '/community',
        '/community/notifications',
      });
      for (final allowed in bilQuickAddReturnPaths) {
        expect(safeBilQuickAddReturnPath(allowed), allowed);
      }
      for (final invalid in [
        null,
        '',
        '//example.test',
        'https://example.test',
        '/community/profile/id',
        '/community?next=evil',
        '/community/notifications/extra',
        '/admin',
        '/intelligence-center/history',
        '/community/',
        '/settings/account',
      ]) {
        expect(safeBilQuickAddReturnPath(invalid), isNull);
      }
    },
  );

  for (final target in _targets) {
    testWidgets(
      'shared Quick Add invokes ${target.$1} after the sheet closes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var destinationBuiltWhileSheetPresent = false;
        final router = _router(
          arrived: (uri) {
            if (uri.path != '/community' &&
                find.byType(BilQuickAddSheet).evaluate().isNotEmpty) {
              destinationBuiltWhileSheetPresent = true;
            }
          },
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-quick-add')));
        await tester.pumpAndSettle();
        expect(find.byType(BilQuickAddSheet), findsOneWidget);
        await tester.tap(find.byKey(Key(target.$1)));
        await tester.pumpAndSettle();
        expect(find.byType(BilQuickAddSheet), findsNothing);
        expect(destinationBuiltWhileSheetPresent, isFalse);
        final uri = GoRouterState.of(
          tester.element(find.byKey(const Key('route'))),
        ).uri;
        expect(uri.path, target.$2);
        expect(uri.queryParameters, target.$3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final origin in [
    '/intelligence-center',
    '/community/notifications',
    '/settings',
  ]) {
    testWidgets('Quick Add dismiss keeps the originating page $origin', (
      tester,
    ) async {
      final router = _router(initial: origin, origin: origin);
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-quick-add')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(12, 30));
      await tester.pumpAndSettle();
      expect(find.byType(BilQuickAddSheet), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, origin);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Search does not duplicate Nutrition when its return context is More',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = _router(initial: '/nutrition', origin: '/settings');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-quick-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-add-secondary-2')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/nutrition');
      expect(router.canPop(), isFalse);
      expect(find.byType(BilQuickAddSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
