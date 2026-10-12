import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/security/bil_mobile_integrity_service.dart';

/// Fences a sensitive administrative request to its original session. The
/// server independently resolves authority from this JWT, never a body actor.
abstract final class AdminOwnerOperation {
  static Future<FunctionResponse> invoke(
    SupabaseClient client, {
    required String integrityAction,
    required Map<String, Object?> body,
    Future<Map<String, Object?>> Function()? prepare,
  }) async {
    final session = client.auth.currentSession;
    final owner = session?.user.id;
    if (session == null || owner == null) {
      throw StateError('admin_session_unavailable');
    }
    var retired = false;
    String? deliveredOwner = owner;
    final subscription = client.auth.onAuthStateChange.listen((event) {
      // Session restoration can transiently emit null; a real sign-out or
      // A -> B -> A permanently retires this operation.
      if (event.session == null && event.event != AuthChangeEvent.signedOut) {
        return;
      }
      final next = event.session?.user.id;
      if (next != deliveredOwner) retired = true;
      deliveredOwner = next;
    }, onError: (Object _, StackTrace _) => retired = true);
    void check() {
      if (retired || client.auth.currentUser?.id != owner) {
        throw StateError('admin_session_changed');
      }
    }

    try {
      check();
      final payload =
          await (prepare?.call() ??
                  BilMobileIntegrityService.instance.protect(
                    action: integrityAction,
                    payload: body,
                  ))
              .timeout(const Duration(seconds: 12));
      check();
      final response = await client.functions
          .invoke(
            'ai-coach-global-reset',
            body: payload,
            // SDK auth headers may change while token resolution is awaiting I/O.
            // Binding this request prevents it from executing as a later account.
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 20));
      check();
      return response;
    } finally {
      retired = true;
      unawaited(subscription.cancel());
    }
  }
}
