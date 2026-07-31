import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one production composition root and provider-neutral core', () {
    final root = Directory('lib/features/global_platform');
    final dart = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final all = dart.map((f) => f.readAsStringSync()).join('\n');
    expect(
      RegExp(
        r'class BilGlobalProductExpansionCompositionRoot',
      ).allMatches(all).length,
      1,
    );
    expect(all, isNot(contains('supabase_flutter')));
    expect(all, isNot(contains('firebase_')));
    expect(all, isNot(contains('hashCode')));
    expect(dart.length, greaterThanOrEqualTo(13));
  });
}
