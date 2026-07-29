import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9-R13 consolidated approved dashboard contracts are present', () {
    final root = Directory.current.path;
    String read(String relative) =>
        File('$root${Platform.pathSeparator}$relative').readAsStringSync();

    final health = read(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    );
    final grid = read('lib/features/dashboard/widgets/dashboard_grid.dart');
    final analytics = read('lib/features/analytics/analytics_page.dart');
    final header = read('lib/features/dashboard/widgets/dashboard_header.dart');

    expect(health, contains('top: 30'));
    expect(health, contains('Offset(size.width * .500, size.height * .535)'));
    expect(health, contains('Color(0xFF2D3439)'));
    expect(health, contains('crownCenter'));

    expect(grid, contains("'kcal/day'"));
    expect(grid, contains("? 'BMI' : ''"));
    expect(grid, contains("unit: ' kg'"));
    expect(grid, contains('textDirection: TextDirection.ltr'));
    expect(grid, contains('mainAxisAlignment: MainAxisAlignment.center'));
    expect(grid, contains('textAlign: TextAlign.center'));

    expect(analytics, contains("arabic ? 'البداية' : 'Start'"));
    expect(analytics, contains("arabic ? 'الحالي' : 'Current'"));
    expect(analytics, contains("arabic ? 'تغير النطاق' : 'Range change'"));
    expect(
      analytics,
      contains('for (var index = 0; index < values.length; index++)'),
    );
    expect(analytics, contains('index == values.length - 1 ? 12 : 9'));

    expect(header, contains('Color(0xFFDDE6EC)'));
    expect(header, contains('Color(0xFFBFCBD3)'));
    expect(header, contains('Color(0xFFEFF3F5)'));
    expect(header, contains('Color(0xFF53616A)'));
  });
}
