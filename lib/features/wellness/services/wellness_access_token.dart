import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

typedef WellnessAccessTokenLoader = String? Function();

const _wellnessProtectedDeliveryHost = 'workouts.bilhealth.com';

/// Reads the current signed-in session without making Wellness depend on
/// Supabase being initialized in unit tests or offline startup paths.
String? loadCurrentWellnessAccessToken() {
  try {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  } on Object {
    return null;
  }
}

void applyWellnessBearer(
  HttpClientRequest request,
  WellnessAccessTokenLoader accessTokenLoader,
  Uri destination,
) {
  // Supabase sessions are credentials for BIL's protected runtime only. A
  // licensed, SHA-pinned asset may still live elsewhere, but it must never
  // receive the user's session token.
  if (destination.scheme != 'https' ||
      destination.host.toLowerCase() != _wellnessProtectedDeliveryHost ||
      !destination.path.startsWith('/v2/objects/workouts/') ||
      destination.userInfo.isNotEmpty ||
      (destination.hasPort && destination.port != 443)) {
    return;
  }
  final token = accessTokenLoader()?.trim();
  if (token == null || token.isEmpty) return;
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
}
