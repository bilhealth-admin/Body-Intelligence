/// Produces a JSON-encodable Coach payload without inventing replacement
/// health values. Non-finite measurements are represented as unavailable.
Map<String, Object?> sanitizeCoachCloudObject(Map<Object?, Object?> source) {
  return <String, Object?>{
    for (final entry in source.entries)
      entry.key.toString(): _sanitizeCoachCloudValue(entry.value),
  };
}

Object? _sanitizeCoachCloudValue(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) return value.isFinite ? value : null;
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) return sanitizeCoachCloudObject(value);
  if (value is Iterable) {
    return value.map(_sanitizeCoachCloudValue).toList(growable: false);
  }
  // Unexpected repository objects must never break the whole voice request or
  // be serialized as an uncontrolled implementation string.
  return null;
}
