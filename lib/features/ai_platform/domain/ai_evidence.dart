/// A deterministic reference to evidence produced by BIL-owned engines.
///
/// This type contains no provider payloads and performs no network access.
final class AiEvidence {
  AiEvidence({
    required this.key,
    required this.description,
    required this.source,
    this.value,
  }) {
    _requireText(key, 'key');
    _requireText(description, 'description');
    _requireText(source, 'source');
  }

  final String key;
  final String description;
  final String source;
  final Object? value;

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
  }
}
