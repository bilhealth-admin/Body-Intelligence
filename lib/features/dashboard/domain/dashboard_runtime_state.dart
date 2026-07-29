import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardRuntimePhase { loading, failed, ready }

/// Describes whether the dashboard's required local inputs are safe to render.
///
/// This object deliberately contains no health or recommendation logic. It is
/// the single presentation boundary for asynchronous readiness only.
class DashboardRuntimeState {
  const DashboardRuntimeState._({required this.phase});

  const DashboardRuntimeState.loading()
      : this._(phase: DashboardRuntimePhase.loading);

  const DashboardRuntimeState.failed()
      : this._(phase: DashboardRuntimePhase.failed);

  const DashboardRuntimeState.ready()
      : this._(phase: DashboardRuntimePhase.ready);

  factory DashboardRuntimeState.fromRequired(
    Iterable<AsyncValue<Object?>> requiredInputs,
  ) {
    final inputs = requiredInputs.toList(growable: false);
    if (inputs.any((value) => value.isLoading)) {
      return const DashboardRuntimeState.loading();
    }
    if (inputs.any((value) => value.hasError)) {
      return const DashboardRuntimeState.failed();
    }
    return const DashboardRuntimeState.ready();
  }

  final DashboardRuntimePhase phase;

  bool get isLoading => phase == DashboardRuntimePhase.loading;
  bool get hasFailure => phase == DashboardRuntimePhase.failed;
  bool get isReady => phase == DashboardRuntimePhase.ready;
}
