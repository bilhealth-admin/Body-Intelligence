import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sleep UI prefers verified connected evidence with source and sync', () {
    final page = File(
      'lib/features/wellness/presentation/sleep_tracker_experience.dart',
    ).readAsStringSync();
    expect(page, contains('connectedHealthProvider'));
    expect(page, contains('snapshot.deviceVerified'));
    expect(page, contains("signal.key != 'sleep'"));
    expect(page, contains("Key('sleep-connected-source')"));
    expect(page, contains("tr('Measured by'"));
    expect(page, contains("tr('Last sync'"));
    expect(page, contains("Key('sleep-measured-stages')"));
    expect(page, contains("signal.attributes['measuredStages']"));
    expect(page, contains("signal.attributes['stages']"));
    for (final excluded in const ['awake', 'inBed', 'unknown', 'unspecified']) {
      expect(page, contains("'$excluded'"));
    }
    expect(
      page,
      contains(
        'Sleep stages appear only when a connected device supplies measured stage records.',
      ),
    );
  });

  test('connected signal view preserves native stage evidence', () {
    final model = File(
      'lib/features/connected_health/connected_health_model.dart',
    ).readAsStringSync();
    expect(model, contains('this.attributes = const <String, Object?>{}'));
    expect(
      model,
      contains('Map<String, Object?>.unmodifiable(signal.attributes)'),
    );
  });

  test('Coach context dedupes connected sleep over same-night manual data', () {
    final provider = File(
      'lib/features/intelligence_center/services/coach_context_provider.dart',
    ).readAsStringSync();
    expect(provider, contains('connectedHealthProvider'));
    expect(provider, contains("'sleepSource'] = 'connected_health'"));
    expect(provider, contains("'sleepDeviceSource'] = signal.source"));
    expect(provider, contains("'sleepLastSyncAt']"));
    expect(provider, contains('signal.observedAt.isAfter(previousAt)'));
  });
}
