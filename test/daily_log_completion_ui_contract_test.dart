import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diary exposes explicit complete and reopen lifecycle actions', () {
    final page = [
      'lib/features/daily_log/daily_log_page.dart',
      'lib/features/daily_log/daily_log_diary_status.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final actions = File(
      'lib/features/daily_log/daily_log_page_actions.dart',
    ).readAsStringSync();

    expect(page, contains("Key('daily-log-lifecycle-card')"));
    expect(page, contains("'daily-log-complete-day'"));
    expect(page, contains("'daily-log-reopen-day'"));
    expect(actions, contains('repository.closeDay(date)'));
    expect(actions, contains('reopenDay(date)'));
    expect(actions, contains('_ensureDiaryOpen()'));
    expect(actions, contains('_quickAddMacros()'));
    expect(actions, contains('addQuickMacroEntry'));
  });
}
