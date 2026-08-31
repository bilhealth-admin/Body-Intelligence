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
      expect(backend, contains('verifiedAppleCertificateChain(header.x5c)'));
      expect(
        backend,
        contains(
          'certificates[index - 1].verify(certificates[index].publicKey)',
        ),
      );
      expect(backend, contains('root.verify(root.publicKey)'));
      expect(backend, contains('now < validFrom || now > validTo'));
      expect(
        backend,
        contains('digestBytes(decodeBase64Bytes(header.x5c.at(-1)!))'),
      );
      expect(backend, contains('if (!pinnedRoots.has(rootDigest))'));
      expect(backend, matches(RegExp(r'''\.split\(["'],["']\)''')));
    },
  );
}
