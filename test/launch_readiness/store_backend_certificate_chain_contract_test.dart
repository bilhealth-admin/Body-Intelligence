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
      expect(backend, contains('verifyCertificateSignature('));
      expect(backend, contains('certificateIsCurrent('));
      expect(backend, contains('intermediate.certificate.issuer'));
      expect(backend, contains('candidate.certificate.subject'));
      expect(backend, contains('digestBytes(certificateChain[2].der)'));
      expect(backend, contains('if (!pinnedRoots.has(rootDigest))'));
      expect(backend, matches(RegExp(r'''\.split\(["'],["']\)''')));
    },
  );
}
