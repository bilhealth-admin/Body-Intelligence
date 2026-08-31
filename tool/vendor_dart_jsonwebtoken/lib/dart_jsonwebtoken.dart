/// Minimal, fail-closed compatibility surface required by the current
/// Supabase Auth dependency.
///
/// BIL does not use Supabase's optional `getClaims` local JWT verification
/// path. Authentication and session validation continue through Supabase's
/// server APIs. Keeping this surface deliberately unable to verify prevents an
/// accidental insecure fallback while avoiding bundling a second, pure-Dart
/// cryptographic provider solely for an unused SDK method.
library;

import 'dart:typed_data';

typedef Audience = List<String>;

abstract class JWTKey {
  const JWTKey();
}

final class RSAPublicKey extends JWTKey {
  RSAPublicKey.bytes(Uint8List bytes)
    : bytes = Uint8List.fromList(bytes),
      super();

  final Uint8List bytes;
}

final class JWT {
  JWT._();

  static JWT verify(
    String token,
    JWTKey key, {
    bool checkHeaderType = true,
    bool checkExpiresIn = true,
    bool checkNotBefore = true,
    Duration? issueAt,
    bool issueAtUtc = true,
    Audience? audience,
    String? subject,
    String? issuer,
    String? jwtId,
  }) {
    throw UnsupportedError(
      'Local JWT verification is intentionally unavailable. '
      'Use the Supabase server-verified auth path.',
    );
  }

  static JWT? tryVerify(
    String token,
    JWTKey key, {
    bool checkHeaderType = true,
    bool checkExpiresIn = true,
    bool checkNotBefore = true,
    Duration? issueAt,
    bool issueAtUtc = true,
    Audience? audience,
    String? subject,
    String? issuer,
    String? jwtId,
  }) => null;
}
