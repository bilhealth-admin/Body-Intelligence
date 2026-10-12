import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Captures an authenticated visit, not just a UID. Delivered A -> B -> A
/// transitions retire pending work from the earlier A visit.
final class StoreAccountSnapshot {
  const StoreAccountSnapshot(this.ownerId, this.epoch);
  final String? ownerId;
  final int epoch;
}

final class StoreAccountVisit {
  StoreAccountVisit({
    required String? Function() readOwner,
    Stream<String?>? changes,
    void Function()? onChanged,
  }) : _readOwner = readOwner,
       _deliveredOwner = readOwner() {
    _subscription = changes?.listen(
      (next) {
        if (next == _deliveredOwner) return;
        _deliveredOwner = next;
        _epoch++;
        onChanged?.call();
      },
      onError: (Object _, StackTrace _) {
        _epoch++;
        onChanged?.call();
      },
    );
  }
  final String? Function() _readOwner;
  String? _deliveredOwner;
  int _epoch = 0;
  bool _disposed = false;
  StreamSubscription<String?>? _subscription;
  StoreAccountSnapshot capture() => StoreAccountSnapshot(_readOwner(), _epoch);
  bool isCurrent(StoreAccountSnapshot visit) =>
      !_disposed && visit.epoch == _epoch && visit.ownerId == _readOwner();
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
  }
}

Stream<String?>? storeAccountOwnerChanges() {
  try {
    return Supabase.instance.client.auth.onAuthStateChange
        .where(
          (state) =>
              state.session != null || state.event == AuthChangeEvent.signedOut,
        )
        .map((state) => state.session?.user.id);
  } on Object {
    return null;
  }
}
