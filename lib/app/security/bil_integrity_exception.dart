final class BilIntegrityException implements Exception {
  const BilIntegrityException(
    this.code, {
    this.recoveryHandle,
    this.recoveryOwner,
  });

  final String code;
  // Opaque, memory-only native token lease. Never serialize or display it.
  final String? recoveryHandle;
  final String? recoveryOwner;

  @override
  String toString() => 'BilIntegrityException($code)';
}
