import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_health_device_status.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_health_devices_review.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_copy.dart';
import 'package:flutter_test/flutter_test.dart';

// Every changed watch/control/reading label is exercised for the production
// locale set, including distinct Portuguese regions and Chinese scripts.
void main() {
  test('health device review copy covers all 25 production locales', () {
    const sources = [
      'Apps & Devices',
      'Unavailable on this device.',
      'The health provider must be installed or updated.',
      'BIL needs explicit permission before reading health data.',
      'Permission was denied. You can grant it later in system settings.',
      'The Health access request completed. Apple does not reveal read permission status; only records it provides will appear.',
      'Ready to synchronize.',
      'Synchronizing now.',
      'Connected and synchronized.',
      'The native source could not be reached. Local data was not affected.',
      'Fitness snapshot',
      'Fitness readings',
      'Sync now',
      'Synchronizing…',
      'Last sync',
      'Manage fitness sources',
      'Connection status',
      'Grant health access',
      'Open system settings',
      'Allow weight export',
      'Allow weight and nutrition export',
      'Refresh status',
      'Disconnect health source',
      'Recent synchronized signals',
      'Steps',
      'steps',
      'Heart rate',
      'Resting heart rate',
      'Active energy',
      'Weight',
      'Distance',
      'Heart-rate variability',
      'Sleep',
      'sleep',
      'bpm',
      'Live fitness watch showing current time and available measured data',
    ];
    final missing = <String, List<String>>{};
    final tags = AppLocalizations.supportedLocales
        .map(BilLocalePolicy.canonicalTag)
        .toSet();
    expect(tags.length, 25);
    expect(HealthDevicesReviewCopy.rows.keys.toSet(), tags);
    expect(HealthDevicesReviewCopy.balanced, isTrue);
    expect(HealthDeviceStatusCopy.rows.keys.toSet(), tags);
    expect(HealthDeviceStatusCopy.balanced, isTrue);
    for (final tag in tags) {
      for (var i = 0; i < HealthDeviceStatusCopy.sources.length; i++) {
        final key = HealthDeviceStatusCopy.sources[i];
        expect(
          connectedHealthTextForLanguage(tag, key, 'not used'),
          HealthDeviceStatusCopy.rows[tag]![i],
          reason: '$tag :: $key',
        );
      }
      for (var i = 0; i < HealthDevicesReviewCopy.sources.length; i++) {
        final key = HealthDevicesReviewCopy.sources[i];
        expect(
          connectedHealthTextForLanguage(tag, key, 'not used'),
          HealthDevicesReviewCopy.rows[tag]![i],
          reason: '$tag :: $key',
        );
      }
    }
    for (final tag in tags.where((tag) => tag != 'en' && tag != 'ar')) {
      for (final source in sources) {
        if (connectedHealthTextForLanguage(tag, source, 'عربي') == source &&
            !HealthDevicesReviewCopy.sources.contains(source)) {
          missing.putIfAbsent(source, () => []).add(tag);
        }
      }
    }
    expect(missing, isEmpty, reason: '$missing');
  });
}
