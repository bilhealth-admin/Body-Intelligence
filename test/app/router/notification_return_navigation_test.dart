import 'dart:io';

import 'package:body_intelligence_log/app/router/bil_external_route_navigator.dart';
import 'package:body_intelligence_log/app/router/bil_safe_return_button.dart';
import 'package:body_intelligence_log/features/community/presentation/community_return_button.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _peer = '8c2d80b2-266c-4a7c-820e-a36b4ef9ac28';

Future<GoRouter> _mount(WidgetTester tester, String initial) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/startup',
        builder: (_, _) =>
            const Scaffold(body: Text('Startup', key: Key('startup'))),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) =>
            const Scaffold(body: Text('Home', key: Key('home'))),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) =>
            const Scaffold(body: Text('Settings', key: Key('settings'))),
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) =>
            const Scaffold(body: Text('Community', key: Key('community'))),
      ),
      for (final path in <String>[
        '/community/messages',
        '/community/connections',
        '/community/notifications',
      ])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(
            appBar: AppBar(leading: const CommunityReturnButton()),
            body: Text(state.uri.path, key: const Key('destination')),
          ),
        ),
      GoRoute(
        path: '/community/chat/:userId',
        builder: (_, state) => Scaffold(
          appBar: AppBar(
            leading: const CommunityReturnButton(
              fallbackLocation: '/community/messages',
            ),
          ),
          body: Text(state.uri.path, key: const Key('destination')),
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => Scaffold(
          appBar: AppBar(
            leading: const BilSafeReturnButton(
              fallbackLocation: '/settings',
            ),
          ),
          body: const Text('Privacy'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('cold private message notification goes Back to Inbox', (
    tester,
  ) async {
    final router = await _mount(tester, '/startup');
    final raw = 'bil://community/chat/$_peer';
    final destination = BilNotificationNavigation.routeForPayload(raw);
    expect(destination, '/community/chat/$_peer');

    BilExternalRouteNavigator(router).open(destination!);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, destination);
    expect(find.byKey(const Key('community-safe-return')), findsOneWidget);

    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/community/messages',
    );

    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
  });

  testWidgets('cold friend acceptance goes Back to Community', (
    tester,
  ) async {
    final router = await _mount(tester, '/startup');
    final route = CommunityDeepLink.routeFor(
      Uri.parse('bil://community/connections'),
    );
    expect(route, '/community/connections');
    BilExternalRouteNavigator(router).open(route!);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
  });

  testWidgets('cold Community activity opens with a working Back action', (
    tester,
  ) async {
    final router = await _mount(tester, '/startup');
    BilExternalRouteNavigator(router).open('/community/notifications');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-safe-return')), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
  });

  testWidgets('warm notification returns to the actual prior screen', (
    tester,
  ) async {
    final router = await _mount(tester, '/settings');
    BilExternalRouteNavigator(router).open('/community/connections');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/community/connections',
    );
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
  });

  testWidgets('warm private message returns to Community updates', (
    tester,
  ) async {
    final router = await _mount(tester, '/community/notifications');
    BilExternalRouteNavigator(router).open('/community/chat/$_peer');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/community/notifications',
    );
  });

  testWidgets('root Inbox, without any history, returns to Home', (
    tester,
  ) async {
    final router = await _mount(tester, '/community/messages');
    expect(router.canPop(), isFalse);
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
  });

  testWidgets('direct legal link has a safe Back destination', (tester) async {
    final router = await _mount(tester, '/startup');
    BilExternalRouteNavigator(router).open('/legal/privacy');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bil-safe-return')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
  });

  testWidgets('root legal page returns to Settings even without history', (
    tester,
  ) async {
    final router = await _mount(tester, '/legal/privacy');
    expect(router.canPop(), isFalse);
    await tester.tap(find.byKey(const Key('bil-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
  });

  testWidgets('invalid external paths and duplicate taps do not navigate', (
    tester,
  ) async {
    final router = await _mount(tester, '/settings');
    final nav = BilExternalRouteNavigator(router);
    for (final path in <String>[
      'https://bad.invalid/steal',
      '//bad.invalid/steal',
      'bil://community/messages',
      '/settings#untrusted',
    ]) {
      nav.open(path);
    }
    nav.open('/settings');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(router.canPop(), isFalse);
  });

  testWidgets('all declared external screen aliases have a cold-launch return path', (
    tester,
  ) async {
    final links = File(
      'lib/features/notifications/domain/community_deep_link.dart',
    ).readAsStringSync();
    final start = links.indexOf('static const _appAliases');
    final end = links.indexOf('  };', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final aliases = <String>{
      for (final match in RegExp(
        r"'[^']+':\s*'([^']+)'",
      ).allMatches(links.substring(start, end)))
        match.group(1)!,
    };
    expect(aliases.length, greaterThanOrEqualTo(45));

    final destinations = <String>{
      '/startup',
      '/dashboard',
      '/community',
      '/community/messages',
      ...aliases,
    };
    final router = GoRouter(
      initialLocation: '/startup',
      routes: [
        for (final route in destinations)
          GoRoute(
            path: route,
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text(state.uri.path),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    for (final route in aliases) {
      router.go('/startup');
      await tester.pumpAndSettle();
      BilExternalRouteNavigator(router).open(route);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        route,
        reason: 'External destination failed: $route',
      );
      if (route != '/dashboard' && route != '/community') {
        expect(
          router.canPop(),
          isTrue,
          reason: 'No previous screen after cold external link: $route',
        );
        router.pop();
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          route.startsWith('/community/') ? '/community' : '/dashboard',
          reason: 'Wrong return destination for external link: $route',
        );
      }
    }
  });
}
