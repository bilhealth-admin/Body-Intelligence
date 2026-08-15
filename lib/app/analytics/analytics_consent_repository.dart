import 'package:shared_preferences/shared_preferences.dart';

enum BilAnalyticsConsent { unknown, granted, declined }

abstract interface class AnalyticsConsentRepository {
  Future<BilAnalyticsConsent> read();
  Future<void> write(BilAnalyticsConsent consent);
  Future<void> clear();
}

/// Persists only the analytics choice. It is deliberately separate from ads,
/// health permissions and subscription state.
final class LocalAnalyticsConsentRepository
    implements AnalyticsConsentRepository {
  const LocalAnalyticsConsentRepository();

  static const storageKey = 'bil.analytics.consent.v1';

  @override
  Future<BilAnalyticsConsent> read() async {
    final value = (await SharedPreferences.getInstance()).getString(storageKey);
    return switch (value) {
      'granted' => BilAnalyticsConsent.granted,
      'declined' => BilAnalyticsConsent.declined,
      _ => BilAnalyticsConsent.unknown,
    };
  }

  @override
  Future<void> write(BilAnalyticsConsent consent) async {
    final storage = await SharedPreferences.getInstance();
    if (consent == BilAnalyticsConsent.unknown) {
      await storage.remove(storageKey);
    } else {
      await storage.setString(storageKey, consent.name);
    }
  }

  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(storageKey);
}
