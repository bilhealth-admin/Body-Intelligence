import 'dart:collection';

import 'body_twin_outcome.dart';
import 'body_twin_snapshot.dart';
import 'body_twin_trend_state.dart';

/// Stable closure classifications for the complete local Body Twin Engine.
enum BodyTwinEngineStatus { accepted, incomplete, rejected }

/// Immutable result exposed by the complete deterministic Body Twin Engine.
///
/// The trusted snapshot outcome and trend-ready factual history remain
/// inspectable. Downstream use is allowed only when the trusted snapshot is
/// accepted and its latest observations exactly match the trend state.
final class BodyTwinEngineResult {
  BodyTwinEngineResult({
    required this.outcome,
    required this.trendState,
    required Iterable<String> integrityIssues,
  }) : integrityIssues = UnmodifiableListView<String>(
         (integrityIssues.toList(growable: false)..sort()),
       );

  final BodyTwinOutcome outcome;
  final BodyTwinTrendState trendState;
  final List<String> integrityIssues;

  BodyTwinEngineStatus get status {
    if (outcome.isIncomplete) {
      return BodyTwinEngineStatus.incomplete;
    }
    if (!outcome.isAccepted || integrityIssues.isNotEmpty) {
      return BodyTwinEngineStatus.rejected;
    }
    return BodyTwinEngineStatus.accepted;
  }

  bool get canProceed => status == BodyTwinEngineStatus.accepted;

  BodyTwinSnapshot? get acceptedSnapshot =>
      canProceed ? outcome.acceptedSnapshot : null;
}
