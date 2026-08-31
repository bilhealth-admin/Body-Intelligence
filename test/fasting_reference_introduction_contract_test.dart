import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fasting route includes reference introduction and working timer', () {
    final wellnessLibrary = File(
      'lib/features/wellness/presentation/wellness_tools_pages.dart',
    );
    final entrypoint = wellnessLibrary.readAsStringSync();
    final source = <String>[
      entrypoint,
      for (final part in RegExp(r"part '([^']+)';").allMatches(entrypoint))
        File(
          '${wellnessLibrary.parent.path}/${part.group(1)!}',
        ).readAsStringSync(),
    ].join('\n');
    expect(
      source,
      contains("key: const Key('fasting-reference-introduction')"),
    );
    expect(
      source,
      contains('Choose a standard or custom intermittent fasting window'),
    );
    for (final window in const ['13:11', '14:10', '16:8', '18:6', '20:4']) {
      expect(source, contains(window));
    }
    expect(source, contains("Key('fasting-custom-window')"));
    expect(source, contains('permissionState()'));
    expect(source, contains('pendingNotificationIds()'));
    expect(source, contains('fasting-open-notification-settings'));
    expect(source, contains('The local timer survives app restarts'));
    expect(
      source,
      contains('Review completed intermittent fasting sessions here'),
    );
    expect(source, contains('(active ? _stop : _start)'));
    expect(source, contains('prefs.mutate('));
    expect(source, contains('canPop: !busy'));
    expect(
      source,
      contains("tr('Intermittent fasting history', 'سجل الصيام المتقطع')"),
    );
  });
}
