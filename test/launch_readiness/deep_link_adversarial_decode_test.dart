import 'dart:math';

import 'package:body_intelligence_log/app/analytics/bil_launch_deep_link.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const routes = <String>[
    'login',
    'settings/language',
    'daily-log',
    'community/rewards',
    'community/content/00000000-0000-4000-8000-000000000001',
    'intelligence-center',
  ];

  test('malformed UTF-8 never escapes either external navigation parser', () {
    var cases = 0;
    for (final route in routes) {
      for (final prefix in ['bil://', 'https://www.bilhealth.com/']) {
        for (final field in [
          'utm_source',
          'comment',
          'barcode',
          'from',
          'owner',
          'action',
        ]) {
          for (final invalid in [
            '%FF',
            '%FE',
            '%C0%AF',
            '%ED%A0%80',
            '%E0%80%80',
            '%F4%90%80%80',
            '%80',
          ]) {
            final uri = Uri.parse('$prefix$route?$field=$invalid');
            expect(
              BilLaunchDeepLink.parse(uri),
              isNull,
              reason: '$route:$field:$invalid',
            );
            expect(
              CommunityDeepLink.routeFor(uri),
              isNull,
              reason: '$route:$field:$invalid',
            );
            cases++;
          }
        }
      }
    }
    expect(cases, 504);
    for (final path in [
      'settings/%FF',
      'community/%ED%A0%80',
      'community/profile/%C0%AF',
    ]) {
      final uri = Uri.parse('bil://$path');
      expect(BilLaunchDeepLink.parse(uri), isNull);
      expect(CommunityDeepLink.routeFor(uri), isNull);
    }
  });

  test(
    'generated hostile links remain bounded and cannot create external routes',
    () {
      final random = Random(38);
      const atoms = [
        'a',
        '%FF',
        '%00',
        '%2F',
        '%252F',
        '..',
        '@',
        '#',
        '&',
        '=',
        '%ED%A0%80',
        'ع',
        '😀',
        '\\',
        '%GG',
      ];
      const hosts = [
        'www.bilhealth.com',
        'bilhealth.com',
        'www.bilhealth.com.attacker.invalid',
        'attacker.invalid',
        '127.0.0.1',
      ];
      for (var n = 0; n < 10000; n++) {
        final body = List.generate(
          1 + random.nextInt(12),
          (_) => atoms[random.nextInt(atoms.length)],
        ).join();
        final path = routes[random.nextInt(routes.length)];
        final prefix = n.isEven
            ? 'bil://'
            : 'https://${hosts[random.nextInt(hosts.length)]}/';
        final address =
            '$prefix$path?${n.isEven ? 'utm_source' : 'comment'}=$body';
        final uri = Uri.tryParse(address);
        if (uri == null) continue;
        final launch = BilLaunchDeepLink.parse(uri);
        final community = CommunityDeepLink.routeFor(uri);
        for (final route in [launch?.route, community].whereType<String>()) {
          final target = Uri.parse(route);
          expect(target.scheme, isEmpty, reason: address);
          expect(target.hasAuthority, isFalse, reason: address);
          expect(target.path, startsWith('/'), reason: address);
          expect(target.path, isNot(startsWith('//')), reason: address);
          expect(target.fragment, isEmpty, reason: address);
        }
        if (launch != null) {
          expect(launch.attribution.length, lessThanOrEqualTo(4));
          expect(
            launch.attribution.values.every((value) => value.length <= 80),
            isTrue,
          );
        }
      }
    },
  );

  test('untrusted authorities and private action fields cannot gain authority', () {
    for (final host in [
      'www.bilhealth.com.attacker.invalid',
      'bilhealth.com.attacker.invalid',
      'www.bіlhealth.com',
      'localhost',
      '127.0.0.1',
    ]) {
      for (final route in routes) {
        final uri = Uri.parse('https://$host/$route');
        expect(BilLaunchDeepLink.parse(uri), isNull);
        expect(CommunityDeepLink.routeFor(uri), isNull);
      }
    }
    for (final authority in [
      'attacker@www.bilhealth.com',
      'www.bilhealth.com:8443',
      'www.bilhealth.com:1',
    ]) {
      expect(
        BilLaunchDeepLink.parse(Uri.parse('https://$authority/login')),
        isNull,
      );
    }
    final injected = Uri.parse(
      'bil://daily-log?meal=lunch&owner=foreign&confirmed=true&premium=true&sql=drop&redirect=https://attacker.invalid',
    );
    expect(CommunityDeepLink.routeFor(injected), '/daily-log?meal=lunch');
    expect(BilLaunchDeepLink.parse(injected)?.route, '/daily-log?meal=lunch');
    expect(BilLaunchDeepLink.parse(injected)?.attribution, isEmpty);
    final duplicate = Uri.parse(
      'https://www.bilhealth.com/download?member=${'a' * 32}&member=${'b' * 32}',
    );
    expect(BilLaunchDeepLink.parse(duplicate), isNull);
    expect(CommunityDeepLink.routeFor(duplicate), isNull);
  });

  test(
    'oversized links fail closed while ordinary launch links still work',
    () {
      final oversized = Uri.parse('bil://daily-log?note=${'x' * 1000000}');
      expect(BilLaunchDeepLink.parse(oversized), isNull);
      expect(CommunityDeepLink.routeFor(oversized), isNull);
      expect(
        BilLaunchDeepLink.parse(
          Uri.parse('bil://login?utm_source=owner-test'),
        )?.route,
        '/login',
      );
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://settings/language')),
        '/settings/language',
      );
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://community/rewards')),
        '/community/rewards',
      );
    },
  );
}
