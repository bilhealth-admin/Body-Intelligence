import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('privacy publication gate requires real external evidence', () {
    final doc = read(
      'docs/external_launch/BIL_V1_EXTERNAL_LAUNCH_003_PRIVACY_PUBLICATION.md',
    );
    expect(doc, contains('Public stable `https://` URL'));
    expect(doc, contains('BLOCKED_EXTERNAL'));
    expect(doc, contains('not a published policy'));
  });

  test(
    'auditor records gaps without claiming publication or legal approval',
    () {
      final tool = read(
        'tool/external_launch/audit_privacy_publication_readiness.ps1',
      );
      expect(tool, contains('PUBLISHED_URL=NOT_CLAIMED'));
      expect(tool, contains('LEGAL_APPROVAL=NOT_CLAIMED'));
      expect(tool, contains('REVISION_REQUIRED_BEFORE_PUBLICATION'));
    },
  );
}
