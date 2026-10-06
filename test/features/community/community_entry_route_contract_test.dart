import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ordinary social deep links cannot bypass profile and code confirmation',
    () {
      final source = File(
        'lib/app/router/app_community_routes.dart',
      ).readAsStringSync();
      final blocks = source.split('GoRoute(');
      for (final path in [
        '/community',
        '/community/people',
        '/community/code',
        '/community/code/scan',
        '/community/member/:code',
        '/community/notifications',
        '/community/rewards',
        '/community/connections',
        '/community/food-review',
        '/community/profile/:userId',
        '/community/chat/:userId',
        '/community/messages',
        '/community/messages/new',
      ]) {
        final route = blocks.singleWhere((b) => b.contains("path: '$path',"));
        expect(route, contains('CommunityEntryGate('), reason: path);
        expect(
          route,
          contains('PremiumRouteGlassGate('),
          reason: 'existing entitlement: $path',
        );
      }
      final root = blocks.singleWhere((b) => b.contains("path: '/community',"));
      expect(root, contains('showWelcome: true'));
      expect(root, contains('entryWelcomeHandled: true'));
      for (final path in [
        '/community/moderation',
        '/community/invite/:token',
        '/community/safety',
        '/community/profile',
      ]) {
        final route = blocks.singleWhere((b) => b.contains("path: '$path',"));
        expect(
          route,
          isNot(contains('CommunityEntryGate(')),
          reason: 'recovery/policy/moderation: $path',
        );
      }
      final moderator = blocks.singleWhere(
        (b) => b.contains("path: '/community/moderation',"),
      );
      expect(moderator, isNot(contains('PremiumRouteGlassGate(')));
    },
  );
}
