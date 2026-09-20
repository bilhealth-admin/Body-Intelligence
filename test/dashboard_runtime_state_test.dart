import 'package:body_intelligence_log/features/dashboard/domain/dashboard_runtime_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardRuntimeState', () {
    test('loading wins while any required input is loading', () {
      final state = DashboardRuntimeState.fromRequired(const [
        AsyncData<Object?>(1),
        AsyncLoading<Object?>(),
      ]);

      expect(state.phase, DashboardRuntimePhase.loading);
      expect(state.isReady, isFalse);
    });

    test('failure is reported when inputs completed with an error', () {
      final state = DashboardRuntimeState.fromRequired([
        const AsyncData<Object?>(1),
        AsyncError<Object?>(StateError('storage'), StackTrace.empty),
      ]);

      expect(state.phase, DashboardRuntimePhase.failed);
      expect(state.hasFailure, isTrue);
    });

    test('ready requires every input to contain data', () {
      final state = DashboardRuntimeState.fromRequired(const [
        AsyncData<Object?>(1),
        AsyncData<Object?>(null),
      ]);

      expect(state.phase, DashboardRuntimePhase.ready);
      expect(state.isReady, isTrue);
    });
  });
}
