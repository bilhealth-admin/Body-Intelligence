import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edit quantity dialog pops its own dialog route', () {
    final source = File(
      'lib/features/daily_log/daily_log_mutation_actions.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(
      source,
      contains(
        'showDialog<double>(\n'
        '      context: context,\n'
        '      builder: (dialogContext) => AlertDialog(',
      ),
    );

    expect(source, contains('onPressed: () => Navigator.pop(dialogContext)'));

    expect(
      source,
      contains(
        'onPressed: () => Navigator.pop(\n'
        '              dialogContext,\n'
        "              double.tryParse(controller.text.replaceAll(',', '.')),",
      ),
    );
  });

  test('edit quantity dialog never pops the page context', () {
    final source = File(
      'lib/features/daily_log/daily_log_mutation_actions.dart',
    ).readAsStringSync();

    final editStart = source.indexOf(
      'Future<void> _editMealItem(MealItem item, Food food)',
    );
    final nextMethod = source.indexOf(
      'Future<void> _showItemActions',
      editStart,
    );

    expect(editStart, greaterThanOrEqualTo(0));
    expect(nextMethod, greaterThan(editStart));

    final editMethod = source.substring(editStart, nextMethod);

    expect(editMethod, isNot(contains('Navigator.pop(context')));
    expect(editMethod, contains('Navigator.pop(dialogContext'));
  });
}
