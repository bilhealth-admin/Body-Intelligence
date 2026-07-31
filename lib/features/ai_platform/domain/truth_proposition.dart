import 'dart:collection';

/// Typed proposition assessed by deterministic BIL-owned rules.
///
/// A proposition carries identity and evidence requirements only. It performs
/// no inference, persistence, network access, or user-state mutation.
final class TruthProposition<T> {
  TruthProposition({
    required String key,
    required String description,
    Iterable<String> requiredEvidenceKeys = const [],
  }) : key = _validatedText(key, 'key'),
       description = _validatedText(description, 'description'),
       requiredEvidenceKeys = UnmodifiableListView<String>(
         _normalizedUnique(requiredEvidenceKeys, 'requiredEvidenceKeys'),
       );

  final String key;
  final String description;
  final List<String> requiredEvidenceKeys;

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }

  static List<String> _normalizedUnique(Iterable<String> values, String field) {
    final normalized =
        values
            .map((value) => _validatedText(value, field))
            .toSet()
            .toList(growable: false)
          ..sort();
    return normalized;
  }
}
