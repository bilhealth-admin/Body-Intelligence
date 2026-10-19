import 'package:body_intelligence_log/app/analytics/bil_launch_deep_link.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external navigation rejects credentials ports and fragments', () {
    for (final address in [
      'https://attacker@www.bilhealth.com/login',
      'https://www.bilhealth.com:8443/login',
      'https://www.bilhealth.com/login#access_token=secret',
      'bil://attacker@connected-health',
      'bil://connected-health:8443',
      'bil://connected-health#access_token=secret',
    ]) {
      expect(
        BilLaunchDeepLink.parse(Uri.parse(address)),
        isNull,
        reason: address,
      );
    }
    for (final address in [
      'bil://attacker@settings/language',
      'bil://settings:8443/language',
      'bil://settings/language#secret',
    ]) {
      expect(
        CommunityDeepLink.routeFor(Uri.parse(address)),
        isNull,
        reason: address,
      );
    }
  });

  test('lookalike web authorities and removed operator URLs never route', () {
    for (final host in [
      'www.bilhealth.com.attacker.invalid',
      'bilhealth-com.invalid',
      'bilhealth-secure-admin.bilhealth-app.workers.dev',
      'localhost',
      '127.0.0.1',
    ]) {
      for (final path in [
        'login',
        'connected-health',
        'admin/ai-coach',
        'community/moderation',
      ]) {
        expect(BilLaunchDeepLink.parse(Uri.https(host, path)), isNull);
      }
    }
    for (final path in [
      'admin/ai-coach',
      'community/moderation',
      'community/food-review',
    ]) {
      for (final prefix in ['bil://', 'https://www.bilhealth.com/']) {
        final uri = Uri.parse('$prefix$path');
        expect(BilLaunchDeepLink.parse(uri), isNull);
        expect(CommunityDeepLink.routeFor(uri), isNull);
      }
    }
  });

  test('ordinary cold launch navigation remains available', () {
    expect(BilLaunchDeepLink.parse(Uri.parse('bil://login'))?.route, '/login');
    expect(
      BilLaunchDeepLink.parse(Uri.parse('bil://connected-health'))?.route,
      '/connected-health',
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://settings/language')),
      '/settings/language',
    );
  });
}
