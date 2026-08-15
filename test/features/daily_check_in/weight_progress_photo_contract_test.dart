import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weight check-in stores a private progress photo on its record', () {
    final root = Directory.current.path.replaceAll('\\', '/');
    final table = File(
      '$root/lib/data/database/weight_entries.dart',
    ).readAsStringSync();
    final repository = File(
      '$root/lib/data/repositories/weight_repository.dart',
    ).readAsStringSync();
    final page = File(
      '$root/lib/features/daily_check_in/daily_check_in_page.dart',
    ).readAsStringSync();

    expect(table, contains('progressPhotoPath'));
    expect(repository, contains('clearProgressPhoto'));
    expect(page, contains("Key('daily-check-in-progress-photo')"));
    expect(page, contains('getApplicationDocumentsDirectory'));
    expect(page, contains('ImageSource.camera'));
    expect(page, contains('ImageSource.gallery'));
  });
}
