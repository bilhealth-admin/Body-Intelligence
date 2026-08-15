import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared challenge locks expose state and all supported audience copy', () {
    final source = File(
      'lib/features/challenges/challenges_page.dart',
    ).readAsStringSync();

    for (final label in const [
      'الأصدقاء',
      'بإشراف مدرب',
      'الفريق',
      'Amis',
      'Créés par un coach',
      'Équipe',
      'Amigos',
      'Creados por un entrenador',
      'Equipo',
      'Arkadaşlar',
      'Antrenör tarafından',
      'Takım',
    ]) {
      expect(source, contains(label), reason: label);
    }
    expect(source, contains('enabled: false'));
    expect(source, contains('Icons.lock_outline_rounded'));
    expect(source, contains('LinearGradient('));
  });
}
