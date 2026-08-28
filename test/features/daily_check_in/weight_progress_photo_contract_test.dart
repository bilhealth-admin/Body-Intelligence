import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily prompt stays minimal without deleting stored photo support', () {
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
    expect(page, isNot(contains("Key('daily-check-in-progress-photo')")));
    expect(page, isNot(contains('ImageSource.camera')));
    expect(page, isNot(contains('clearProgressPhoto: true')));
    expect(page, contains("'daily-check-in-hero'"));
    expect(page, contains("('morning', 'Morning'"));
    expect(page, contains("'afterFood',"));
    expect(page, isNot(contains("'afterBathroom',")));
  });
}
