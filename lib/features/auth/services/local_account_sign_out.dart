import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// An explicit local exit belongs to one delivered authenticated visit.
/// The preparation may save a draft or flush an existing consented queue.
/// It never authorizes a replacement account to be signed out.
Future<void> signOutMatchingAccount(
  GoTrueClient auth,
  String expectedOwnerId, {
  required Future<void> Function(bool Function() isCurrent) prepare,
  bool Function()? isCurrentVisit,
}) async {
  var retired = false;
  var signOutStarted = false;
  var deliveredOwner = auth.currentUser?.id;
  bool current() =>
      !retired &&
      expectedOwnerId.isNotEmpty &&
      auth.currentUser?.id == expectedOwnerId &&
      (isCurrentVisit?.call() ?? true);
  void check() {
    if (!current()) throw StateError('The active account changed');
  }

  check();
  final subscription = auth.onAuthStateChange.listen((state) {
    final next = state.session?.user.id;
    if (next != deliveredOwner) {
      // The null event from this local sign-out is expected. Any new
      // session, including A after A -> B -> A, retires the old action.
      if (!signOutStarted || next != null) retired = true;
      deliveredOwner = next;
    }
  }, onError: (Object _, StackTrace _) => retired = true);
  try {
    await prepare(current);
    check();
    signOutStarted = true;
    try {
      // GoTrue clears the local session synchronously before HTTP logout.
      await auth.signOut(scope: SignOutScope.local);
    } on Object {
      if (auth.currentUser != null || retired) rethrow;
    }
    if (retired ||
        auth.currentUser != null ||
        isCurrentVisit?.call() == false) {
      throw StateError('The active account changed');
    }
  } finally {
    unawaited(subscription.cancel());
  }
}
