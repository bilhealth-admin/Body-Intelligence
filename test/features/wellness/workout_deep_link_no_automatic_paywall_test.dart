import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial workout deep link opens details without Plans navigation', () {
    final source = File(
      'lib/features/wellness/presentation/bil_workout_routines_page.dart',
    ).readAsStringSync();
    final wrapperStart = source.indexOf(
      '  Future<void> _openInitialItemDetails(',
    );
    final scheduleStart = source.indexOf('  void _scheduleInitialItem(');
    final end = source.indexOf('  bool _isLocked(', scheduleStart);
    expect(wrapperStart, greaterThanOrEqualTo(0));
    expect(scheduleStart, greaterThan(wrapperStart));
    expect(end, greaterThan(scheduleStart));

    final wrapper = source.substring(wrapperStart, scheduleStart);
    // The new session-return wrapper must still open the protected details;
    // closing details may dismiss ONLY the session-owned library route.
    expect(wrapper, contains('await _openDetails(item);'));
    expect(wrapper, contains('!widget.returnToCallerAfterInitialItem'));
    expect(wrapper, contains('ModalRoute.of(context)?.isCurrent == true'));
    expect(wrapper, contains('context.canPop()'));
    expect(wrapper, isNot(contains("'/plans")));
    expect(wrapper, isNot(contains('context.push(')));

    final scheduling = source.substring(scheduleStart, end);
    expect(scheduling, contains('unawaited(_openInitialItemDetails(item))'));
    expect(scheduling, contains('EntitlementAuthority.verifiedServer'));
    expect(scheduling, contains('WorkoutFreePreviewPolicy.isPreview(item)'));
    expect(scheduling, isNot(contains("'/plans")));
    expect(scheduling, isNot(contains('context.push(')));
    // Existing paid-content enforcement remains independent from navigation.
    expect(source.substring(end), contains('workoutItemAccessGranted'));
  });
}
