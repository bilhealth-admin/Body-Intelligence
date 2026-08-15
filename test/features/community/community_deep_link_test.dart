import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps allowlisted community notification links to app routes', () {
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://community/connections')),
      '/community/connections',
    );
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse('bil://community/chat/8c2d80b2-266c-4a7c-820e-a36b4ef9ac28'),
      ),
      '/community/chat/8c2d80b2-266c-4a7c-820e-a36b4ef9ac28',
    );
  });

  test('rejects external and unknown schemes', () {
    expect(
      CommunityDeepLink.routeFor(Uri.parse('https://example.com/community')),
      isNull,
    );
    expect(CommunityDeepLink.routeFor(Uri.parse('bil://unknown/path')), isNull);
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://community/admin')),
      isNull,
    );
    expect(
      CommunityDeepLink.routeFor(
        Uri.parse('bil://community/connections/unexpected'),
      ),
      isNull,
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://settings/unknown')),
      isNull,
    );
  });
}
