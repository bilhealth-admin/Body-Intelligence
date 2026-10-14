import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/community_repository.dart';
import '../services/community_owner_operation.dart';

/// Every delivered account boundary retires earlier callbacks, including ABA.
/// This local fence complements, and never replaces, server authorization.
class CommunityAccountVisit extends ChangeNotifier {
  CommunityAccountVisit({
    required this.repository,
    required this.client,
    required this.onChanged,
  }) {
    final auth = client?.auth;
    _deliveredOwner = auth?.currentUser?.id;
    _auth = auth?.onAuthStateChange.listen(
      (state) {
        if (_disposed) return;
        final next = state.session?.user.id;
        if (next == _deliveredOwner) return;
        _deliveredOwner = next;
        _epoch++;
        notifyListeners();
        onChanged();
      },
      onError: (Object _, StackTrace _) {
        if (_disposed) return;
        _epoch++;
        notifyListeners();
        onChanged();
      },
    );
  }

  final CommunityRepository? repository;
  final SupabaseClient? client;
  final VoidCallback onChanged;
  StreamSubscription<AuthState>? _auth;
  String? _deliveredOwner;
  int _epoch = 0;
  bool _disposed = false;

  int get epoch => _epoch;

  String? get owner {
    if (_disposed) return null;
    try {
      return repository?.currentUserId;
    } on Object {
      return null;
    }
  }

  CommunityAccountTicket? capture() {
    final value = owner;
    if (value == null) return null;
    final ticket = CommunityAccountTicket._(this, _epoch, value);
    return ticket.isCurrent ? ticket : null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    unawaited(_auth?.cancel());
    super.dispose();
  }
}

class CommunityAccountTicket {
  const CommunityAccountTicket._(this.visit, this.epoch, this.owner);
  final CommunityAccountVisit visit;
  final int epoch;
  final String owner;

  bool get isCurrent =>
      !visit._disposed &&
      epoch == visit._epoch &&
      visit.owner == owner &&
      // Injected local repositories may have no SDK session. A production
      // repository cannot supply an owner without an authenticated session.
      (visit.client?.auth.currentUser == null ||
          (visit.client!.auth.currentUser!.id == owner &&
              visit._deliveredOwner == owner));

  void check() {
    if (!isCurrent) throw const CommunityOwnerOperationCancelled();
    CommunityOwnerOperation.checkCurrent();
  }

  Future<T> run<T>(Future<T> Function() action) {
    check();
    return visit.repository!.runForCommunityOwner(
      action,
      ownerId: owner,
      isCurrentOwner: () => isCurrent,
    );
  }
}
