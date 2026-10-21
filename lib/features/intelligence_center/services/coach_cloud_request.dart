/// One logical cloud turn. It retains identity and accounting state only;
/// questions, health context and AI output are never stored here.
enum CoachCloudRequestState {
  notSubmitted,
  pending,
  settled,
  refunded,
  unknown,
}

class CoachCloudRequest {
  CoachCloudRequest({
    required this.requestId,
    this._isCurrent,
    this.statusTimeout = const Duration(seconds: 8),
  });

  final String requestId;
  final Duration statusTimeout;
  final bool Function()? _isCurrent;
  bool _submitted = false;
  Future<Object?> Function()? _readReceipt;
  Future<CoachCloudRequestState>? _checking;

  bool get submitted => _submitted;
  bool get isCurrent => _isCurrent?.call() ?? true;

  /// Admission is synchronous, so two callers cannot start the same turn.
  bool beginSubmission({required Future<Object?> Function() readReceipt}) {
    if (_submitted || !isCurrent) return false;
    _submitted = true;
    _readReceipt = readReceipt;
    return true;
  }

  Future<CoachCloudRequestState> reconcile() {
    if (!isCurrent) return Future.value(CoachCloudRequestState.unknown);
    if (!_submitted) return Future.value(CoachCloudRequestState.notSubmitted);
    return _checking ??= _readState().whenComplete(() => _checking = null);
  }

  Future<CoachCloudRequestState> _readState() async {
    try {
      final read = _readReceipt;
      if (read == null) return CoachCloudRequestState.unknown;
      final raw = await read().timeout(statusTimeout);
      if (!isCurrent ||
          raw is! Map ||
          raw['request_id'] != requestId ||
          raw['capability'] != 'text') {
        return CoachCloudRequestState.unknown;
      }
      // An expired timestamp or an absent row does not prove that a delayed
      // invocation cannot still reserve/settle. Only terminal server state can.
      if (raw['state'] == 'reserved') return CoachCloudRequestState.pending;
      final completed = raw['completed_at'];
      final actual = raw['credit_actual'];
      final included = raw['credit_included_actual'];
      final paid = raw['credit_paid_actual'];
      if (completed is! String ||
          DateTime.tryParse(completed) == null ||
          actual is! num ||
          !actual.isFinite ||
          actual < 0) {
        return CoachCloudRequestState.unknown;
      }
      // The expiry settlement writes actual=0 and a terminal timestamp, but
      // leaves the two allocation fields null. A terminal event cannot settle
      // again; nonzero or malformed allocations still fail closed.
      bool released(Object? value) =>
          value == null || (value is num && value == 0);
      if (raw['state'] == 'refunded' &&
          actual == 0 &&
          released(included) &&
          released(paid)) {
        return CoachCloudRequestState.refunded;
      }
      if (included is! num ||
          !included.isFinite ||
          included < 0 ||
          paid is! num ||
          !paid.isFinite ||
          paid < 0 ||
          actual != included + paid) {
        return CoachCloudRequestState.unknown;
      }
      if (raw['state'] == 'succeeded') return CoachCloudRequestState.settled;
    } on Object {
      // A failed status read must never admit a second paid generation.
    }
    return CoachCloudRequestState.unknown;
  }
}
