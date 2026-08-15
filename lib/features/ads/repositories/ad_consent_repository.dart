import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ad_policy.dart';

abstract interface class AdConsentRepository {
  Future<AdConsentStatus> read();
  Future<void> write(AdConsentStatus status);
  Future<void> clear();
}

/// Stores only the user's advertising choice, never a health or profile fact.
final class LocalAdConsentRepository implements AdConsentRepository {
  const LocalAdConsentRepository();

  static const _key = 'bil.advertising.contextual_consent.v1';

  @override
  Future<AdConsentStatus> read() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return switch (value) {
      'contextual_only' => AdConsentStatus.contextualOnly,
      'declined' => AdConsentStatus.declined,
      _ => AdConsentStatus.unknown,
    };
  }

  @override
  Future<void> write(AdConsentStatus status) async {
    final preferences = await SharedPreferences.getInstance();
    if (status == AdConsentStatus.unknown) {
      await preferences.remove(_key);
      return;
    }
    await preferences.setString(
      _key,
      status == AdConsentStatus.contextualOnly ? 'contextual_only' : 'declined',
    );
  }

  @override
  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}

final class LocalAdAudienceRepository {
  const LocalAdAudienceRepository();
  static const _adultKey = 'bil.advertising.adult_confirmation.v1';

  Future<bool> readAdultConfirmation() async =>
      (await SharedPreferences.getInstance()).getBool(_adultKey) ?? false;

  Future<void> writeAdultConfirmation(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    if (value) {
      await preferences.setBool(_adultKey, true);
    } else {
      await preferences.remove(_adultKey);
    }
  }
}
