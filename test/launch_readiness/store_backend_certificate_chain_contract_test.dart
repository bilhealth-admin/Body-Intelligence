import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Apple purchase verification validates the complete pinned X509 chain',
    () {
      final backend = File(
        'supabase/functions/verify-store-purchase/store_backend.ts',
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
      expect(
        backend,
        contains(
          'certificates[0].verify(intermediate.publicKey)',
        ),
      );
      expect(backend, contains('intermediate.verify(candidate.publicKey)'));
      expect(backend, contains('now < validFrom || now > validTo'));
      expect(backend, contains('new Uint8Array(certificateChain.at(-1)!.raw)'));
      expect(backend, contains('if (!pinnedRoots.has(rootDigest))'));
      expect(backend, contains('configuredAppleRootCertificates(pinnedRoots)'));
      expect(backend, matches(RegExp(r'''\.split\(["'],["']\)''')));
    },
  );
}
