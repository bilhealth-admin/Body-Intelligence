import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fasting route includes reference introduction and working timer', () {
    final source = File(
      'lib/features/wellness/presentation/fasting_timer_page.dart',
    ).readAsStringSync();
    expect(
      source,
      contains("key: const Key('fasting-reference-introduction')"),
    );
    expect(source, contains('Choose from three fasting windows'));
    expect(source, contains('The local timer survives app restarts'));
    expect(source, contains('Review completed fasting sessions here'));
    expect(source, contains('(active ? _stop : _start)'));
    expect(source, contains('prefs.mutate('));
    expect(source, contains('canPop: !busy'));
    expect(source, contains("tr('Fasting history', 'سجل الصيام')"));
  });
}
