import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260908182400_harden_friendship_write_contract.sql',
  ).readAsStringSync();
  final rollbackTest = File(
    'supabase/tests/friendship_write_hardening_test.sql',
  ).readAsStringSync();

  test('friendship write migration narrows direct client columns', () {
    expect(migration, contains('grant insert (requester_id, addressee_id)'));
    expect(migration, contains('grant update (status, responded_at)'));
    expect(migration, contains("and status = 'pending'"));
    expect(migration, contains("and status in ('accepted', 'declined')"));
    expect(migration, contains('responded_at is null'));
    expect(migration, contains('responded_at is not null'));
  });

  test('friendship identity and transition checks are server enforced', () {
    expect(migration, contains('bil_enforce_friendship_write_contract'));
    expect(migration, contains('new.id is distinct from old.id'));
    expect(
      migration,
      contains('new.requester_id is distinct from old.requester_id'),
    );
    expect(
      migration,
      contains('new.addressee_id is distinct from old.addressee_id'),
    );
    expect(
      migration,
      contains('new.created_at is distinct from old.created_at'),
    );
    expect(migration, contains("old.status <> 'pending'"));
    expect(migration, contains('pg_catalog.clock_timestamp()'));
  });

  test('rollback probe covers exploit, authorized response, and RPC', () {
    expect(rollbackTest.trimLeft(), startsWith('-- Transactional'));
    expect(rollbackTest, contains('begin;'));
    expect(rollbackTest.trimRight(), endsWith('rollback;'));
    expect(rollbackTest, contains(r'$test_direct_accepted_insert_denied$'));
    expect(rollbackTest, contains(r'$test_requester_cannot_accept$'));
    expect(
      rollbackTest,
      contains(r'$test_identity_columns_are_not_client_writable$'),
    );
    expect(rollbackTest, contains('set requester_id ='));
    expect(rollbackTest, contains('set addressee_id ='));
    expect(
      rollbackTest,
      contains(r'$test_recipient_transition_and_server_timestamp$'),
    );
    expect(
      rollbackTest,
      contains(r'$test_terminal_status_cannot_transition_again$'),
    );
    expect(
      rollbackTest,
      contains(r'$test_social_request_rpc_remains_pending$'),
    );
    expect(rollbackTest, contains(r'$test_non_party_cannot_delete$'));
    expect(rollbackTest, contains(r'$test_addressee_can_delete$'));
    expect(rollbackTest, contains(r'$test_requester_can_delete$'));
    expect(rollbackTest, contains(r'$test_declined_cannot_become_accepted$'));
    expect(rollbackTest, contains('set local role authenticated'));
  });
}
