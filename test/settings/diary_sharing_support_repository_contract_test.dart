import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client repository uses only the four reviewed server RPCs', () {
    final source = File(
      'lib/features/settings/data/diary_sharing_support_repository.dart',
    ).readAsStringSync();
    for (final rpc in const [
      'bil_set_diary_share_settings',
      'bil_publish_diary_snapshot',
      'bil_read_shared_diary',
      'bil_create_support_request',
    ]) {
      expect(source, contains("'$rpc'"));
    }
    expect(source, isNot(contains('_client.from(')));
    expect(source, contains("'p_access_key_sha256'"));
    expect(source, contains("'p_source_revision'"));
  });
}
