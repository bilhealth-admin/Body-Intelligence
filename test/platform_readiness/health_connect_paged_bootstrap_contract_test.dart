import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Health Connect bootstrap is bounded and restart-resumable', () {
    final source = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/'
      'BILGlobalHealthBridge.kt',
    ).readAsStringSync();

    expect(
      source,
      contains('BOOTSTRAP_ANCHOR_PREFIX = "bil_hc_bootstrap_v1:"'),
    );
    expect(source, contains('NATIVE_SYNC_PAGE_SIZE = 250'));
    expect(source, contains('pageSize = NATIVE_SYNC_PAGE_SIZE'));
    expect(source, contains('client.getChanges(token)'));
    expect(source, contains('encodeBootstrapCursor(cursor)'));
    expect(
      source,
      contains('val asOf = bootstrapCursor?.asOf ?: requestedAsOf'),
    );
    expect(source, contains('recordIndex = nextIndex'));
    expect(source, contains('withContext(Dispatchers.IO)'));
  });
}
