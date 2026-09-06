final class BilIntegrityException implements Exception {
  const BilIntegrityException(this.code);

  final String code;

  @override
  String toString() => 'BilIntegrityException($code)';
}
