import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/security/bil_integrity_exception.dart';

/// Safe classification for admin failures; response bodies and identifiers
/// never cross into user-facing copy.
enum AdminOperationFailureKind {
  timedOut,
  serviceUnavailable,
  authorization,
  integrity,
  rejected,
  unknown,
}

AdminOperationFailureKind classifyAdminOperationFailure(Object error) {
  if (error is TimeoutException) {
    return AdminOperationFailureKind.timedOut;
  }
  if (error is BilIntegrityException) {
    return AdminOperationFailureKind.integrity;
  }
  if (error is FunctionException) {
    final code = _functionErrorCode(error);
    if (code.contains('integrity')) {
      return AdminOperationFailureKind.integrity;
    }
    if (code == 'not_found' ||
        code == 'invalid_session' ||
        code == 'authentication_required' ||
        error.status == 401 ||
        error.status == 403) {
      return AdminOperationFailureKind.authorization;
    }
    if (error.status == 404 ||
        code == 'function_not_found' ||
        code == 'service_unavailable' ||
        code == 'server_not_configured') {
      return AdminOperationFailureKind.serviceUnavailable;
    }
    if (error.status >= 400 && error.status < 500) {
      return AdminOperationFailureKind.rejected;
    }
  }
  return AdminOperationFailureKind.unknown;
}

String _functionErrorCode(FunctionException error) {
  final details = error.details;
  if (details is Map) {
    return '${details['error'] ?? ''}'.trim().toLowerCase();
  }
  return '';
}
