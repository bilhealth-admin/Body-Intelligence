import 'dart:collection';

final class DashboardDecisionExplanation {
  DashboardDecisionExplanation({
    required this.actionType,
    required this.title,
    required this.reason,
    required Iterable<String> evidence,
    required this.confidence,
    required Iterable<String> missingEvidence,
    required this.engineVersion,
    required Iterable<String> inputSources,
  }) : evidence = UnmodifiableListView<String>(
         _normalized(evidence, fallback: 'No evidence was exposed.'),
       ),
       missingEvidence = UnmodifiableListView<String>(
         _normalized(missingEvidence),
       ),
       inputSources = UnmodifiableListView<String>(_normalized(inputSources)) {
    _requireText(actionType, 'actionType');
    _requireText(title, 'title');
    _requireText(reason, 'reason');
    _requireText(confidence, 'confidence');
    _requireText(engineVersion, 'engineVersion');
  }

  final String actionType;
  final String title;
  final String reason;
  final List<String> evidence;
  final String confidence;
  final List<String> missingEvidence;
  final String engineVersion;
  final List<String> inputSources;

  bool get hasEvidenceGap => missingEvidence.isNotEmpty;

  static List<String> _normalized(Iterable<String> values, {String? fallback}) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty && fallback != null) return [fallback];
    return normalized;
  }

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
  }
}
