import 'package:body_intelligence_log/app/analytics/analytics_consent_repository.dart';
import 'package:body_intelligence_log/app/launch/bil_global_launch_readiness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'analytics consent is explicit, persistent and independently clearable',
    () async {
      const repository = LocalAnalyticsConsentRepository();
      expect(await repository.read(), BilAnalyticsConsent.unknown);
      await repository.write(BilAnalyticsConsent.granted);
      expect(await repository.read(), BilAnalyticsConsent.granted);
      await repository.write(BilAnalyticsConsent.declined);
      expect(await repository.read(), BilAnalyticsConsent.declined);
      await repository.clear();
      expect(await repository.read(), BilAnalyticsConsent.unknown);
    },
  );

  test('global launch readiness reports missing owner inputs fail closed', () {
    final readiness = BilGlobalLaunchReadiness.current();
    expect(readiness.productionReady, isFalse);
    expect(readiness.blockers, contains('android_verified_links'));
    expect(readiness.blockers, contains('ios_verified_links'));
    expect(readiness.blockers, contains('android_admob'));
    expect(readiness.blockers, contains('ios_admob'));
    expect(readiness.storeProducts, isTrue);
    expect(readiness.blockers, isNot(contains('store_products')));
    expect(readiness.blockers, contains('analytics_provider'));
  });
}
