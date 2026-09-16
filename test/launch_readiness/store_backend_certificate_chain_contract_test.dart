import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple purchase verification validates the complete pinned X509 chain', () {
    final backend = File(
      'supabase/functions/verify-store-purchase/store_backend.ts',
    ).readAsStringSync();
    final verifier = File(
      'supabase/functions/verify-store-purchase/apple_certificate_verifier.ts',
    ).readAsStringSync();

    expect(
      backend,
      matches(
        RegExp(
          r'''import\s*\{\s*X509Certificate\s*\}\s*from\s*["']node:crypto["']''',
        ),
      ),
    );
    expect(backend, contains('verifiedAppleCertificateChain('));
    expect(backend, contains('await verifiedAppleCertificateChain('));
    expect(backend, contains('verifyCertificateSignature('));
    expect(backend, contains('certificateChain[2].der'));
    expect(backend, contains('certificateChain[0].pem'));
    expect(backend, isNot(contains('.verify(')));
    expect(
      backend,
      isNot(matches(RegExp(r'certificateChain\.at\(-1\).*\.raw'))),
    );
    expect(
      backend,
      isNot(matches(RegExp(r'certificateChain\[0\]\.toString\('))),
    );
    expect(backend, contains('now >= validFrom && now <= validTo'));
    expect(backend, contains('if (!pinnedRoots.has(rootDigest))'));
    expect(backend, contains('configuredAppleRootCertificates(pinnedRoots)'));
    expect(backend, matches(RegExp(r'''\.split\(["'],["']\)''')));
    expect(backend, contains('error_stage'));
    expect(verifier, contains('crypto.subtle.verify('));
    expect(verifier, contains('RSASSA-PKCS1-v1_5'));
    expect(verifier, contains('name: "ECDSA"'));
    expect(
      verifier,
      isNot(
        matches(
          RegExp(
            r'''import\s*\{\s*X509Certificate\s*\}\s*from\s*["']node:crypto["']''',
          ),
        ),
      ),
    );
    expect(verifier, isNot(matches(RegExp(r'new\s+X509Certificate\s*\('))));
  });
}
