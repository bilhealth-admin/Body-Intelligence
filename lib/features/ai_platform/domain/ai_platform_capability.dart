/// Delivery state used by the AI Platform closure plan.
enum AiPlatformCapabilityStatus { completed, partial, remaining }

/// Testable closure definition for one AI Platform capability.
final class AiPlatformCapability {
  AiPlatformCapability({
    required this.key,
    required this.title,
    required this.status,
    required Iterable<String> exitCriteria,
    required this.nextPackage,
  }) : exitCriteria = List<String>.unmodifiable(exitCriteria) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (this.exitCriteria.isEmpty ||
        this.exitCriteria.any((criterion) => criterion.trim().isEmpty)) {
      throw ArgumentError.value(
        exitCriteria,
        'exitCriteria',
        'must contain non-empty testable criteria',
      );
    }
    if (nextPackage.trim().isEmpty) {
      throw ArgumentError.value(
        nextPackage,
        'nextPackage',
        'must not be empty',
      );
    }
  }

  final String key;
  final String title;
  final AiPlatformCapabilityStatus status;
  final List<String> exitCriteria;
  final String nextPackage;
}
