import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global platform has one composition root and no placeholders', () {
    final root = Directory('lib/features/global_platform');
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final all = files.map((f) => f.readAsStringSync()).join('\n');
    for (final term in ['TODO', 'placeholder', 'future work', 'hashCode']) {
      expect(all, isNot(contains(term)));
    }
    expect(
      RegExp(
        r'class BilGlobalProductExpansionCompositionRoot',
      ).allMatches(all).length,
      1,
    );
    for (final module in [
      'health_data',
      'wearables',
      'medical_devices',
      'vision',
      'cloud_ai',
      'plugins',
      'reports',
      'professional',
      'commerce',
      'globalization',
    ]) {
      expect(
        files.any((f) => f.path.replaceAll('\\', '/').contains('/$module/')),
        true,
        reason: module,
      );
    }
  });
}
