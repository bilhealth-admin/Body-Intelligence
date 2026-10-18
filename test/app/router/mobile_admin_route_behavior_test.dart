import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'mobile router cannot resolve administration or review destinations',
    () {
      final configuration = AppRouter.router.configuration;
      for (final path in [
        '/admin/ai-coach',
        '/community/moderation',
        '/community/food-review',
      ]) {
        expect(
          configuration.findMatch(Uri.parse(path)).isError,
          isTrue,
          reason: path,
        );
        expect(
          CommunityDeepLink.routeFor(Uri.parse('bil:/$path')),
          isNull,
          reason: 'Notifications cannot restore removed mobile administration',
        );
      }
    },
  );

  test('member reporting and community journeys remain routable', () {
    final configuration = AppRouter.router.configuration;
    for (final path in [
      '/community/safety',
      '/community/notifications',
      '/community/compose',
      '/community/channels',
      '/community/connections',
      '/community/rewards',
      '/intelligence-center',
      '/daily-log',
    ]) {
      expect(
        configuration.findMatch(Uri.parse(path)).isError,
        isFalse,
        reason: path,
      );
    }
  });
}
