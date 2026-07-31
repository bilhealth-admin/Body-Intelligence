import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secure and real document dependencies are declared', () {
    final p = File('pubspec.yaml').readAsStringSync();
    expect(p, contains('crypto:'));
    expect(p, contains('archive:'));
  });
}
