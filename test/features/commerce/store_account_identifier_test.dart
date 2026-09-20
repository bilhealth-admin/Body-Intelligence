import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const owner = '2db07ba9-2e0d-4d78-b92b-4227d57ec525';

  test('Google keeps the existing SHA-256 account identifier', () {
    expect(
      storeAccountIdentifier(ownerId: owner, platform: TargetPlatform.android),
      sha256.convert(owner.codeUnits).toString(),
    );
  });

  test('Apple receives a deterministic RFC 4122 UUID', () {
    final first = storeAccountIdentifier(
      ownerId: owner,
      platform: TargetPlatform.iOS,
    );
    final second = storeAccountIdentifier(
      ownerId: owner,
      platform: TargetPlatform.iOS,
    );
    expect(first, second);
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(
      first,
      isNot(
        storeAccountIdentifier(
          ownerId: '$owner-other',
          platform: TargetPlatform.iOS,
        ),
      ),
    );
  });
}
