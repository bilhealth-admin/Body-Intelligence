import 'dart:async';

import 'package:body_intelligence_log/features/dashboard/domain/dashboard_runtime_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardRuntimeState', () {
    test(
      'refresh and dependency reload preserve already available data',
      () async {
        for (final isRefresh in [true, false]) {
          final first = Completer<Object?>();
          final next = Completer<Object?>();
          var reads = 0;
          var revision = 0;
          final dependency = Provider<int>((ref) => revision);
          final input = FutureProvider<Object?>((ref) {
            ref.watch(dependency);
            return reads++ == 0 ? first.future : next.future;
          });
          final container = ProviderContainer();
          try {
            container.listen(input, (_, _) {});
            first.complete(1);
            await container.read(input.future);
            if (isRefresh) {
              container.invalidate(input);
            } else {
              revision++;
              container.invalidate(dependency);
            }
            final reloading = container.read(input);
            expect(reloading.isLoading, isTrue);
            expect(
              DashboardRuntimeState.fromRequired([
                reloading,
                const AsyncData<Object?>(null),
              ]).isReady,
              isTrue,
            );
            next.complete(2);
            await container.read(input.future);
          } finally {
            container.dispose();
          }
        }
      },
    );

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
