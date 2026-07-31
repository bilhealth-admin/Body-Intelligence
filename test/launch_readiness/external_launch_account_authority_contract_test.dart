import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'Missing required file: $path');
    return file.readAsStringSync();
  }

  test('account authority preparation makes no false completion claim', () {
    final document = read(
      'docs/external_launch/BIL_V1_EXTERNAL_LAUNCH_002_ACCOUNT_AUTHORITY.md',
    );
    expect(document, contains('Gate 2 remains `BLOCKED_EXTERNAL`'));
    expect(document, contains('not completion evidence'));
    expect(document, contains('individual'));
    expect(document, contains('organization'));
  });

  test('evidence template contains no credentials and requires both stores', () {
    final source = read(
      'tool/external_launch/templates/account_authority_evidence.template.json',
    );
    final template = jsonDecode(source) as Map<String, dynamic>;
    expect(template['secrets_included'], isFalse);
    expect(template, containsPair('google_play', isA<Map<String, dynamic>>()));
    expect(
      template,
      containsPair('apple_developer', isA<Map<String, dynamic>>()),
    );
    expect(source.toLowerCase(), isNot(contains('password')));
    expect(source.toLowerCase(), isNot(contains('private_key')));
  });

  test(
    'verifier requires real authority and rejects secret-bearing evidence',
    () {
      final verifier = read(
        'tool/external_launch/verify_account_authority_evidence.ps1',
      );
      for (final marker in <String>[
        'account_status -ne "active"',
        'identity_verification -ne "verified"',
        'membership_status -ne "active"',
        'account_holder_authority -ne "verified"',
        'agreements_status -ne "accepted"',
        r'secrets_included -ne $false',
      ]) {
        expect(verifier, contains(marker));
      }
    },
  );
}
