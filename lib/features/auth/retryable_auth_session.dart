import 'package:supabase_flutter/supabase_flutter.dart';

/// A transport failure is not a new identity or a verified entitlement.
/// GoTrue retains its session for this exact retryable exception. Callers may
/// retain that same identity, but still enforce their own authority and expiry.
bool isSameOwnerRetryableAuthReadFailure(
  Object error, {
  required GoTrueClient auth,
  required String? previousOwnerId,
}) =>
    error is AuthRetryableFetchException &&
    error.statusCode != '401' &&
    error.statusCode != '403' &&
    previousOwnerId != null &&
    auth.currentUser?.id == previousOwnerId &&
    auth.currentSession?.user.id == previousOwnerId;
