import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both final build commands include the runtime push defines', () {
    for (final path in [
      '.github/workflows/bil_android_release_candidate.yml',
      '.github/workflows/bil_ios_signed_release.yml',
    ]) {
      final source = File(path).readAsStringSync();
      final start = source.indexOf(
        path.contains('android')
            ? 'flutter build appbundle --release'
            : 'flutter build ipa --release',
      );
      expect(start, greaterThan(-1));
      final end = source.indexOf('\n      - name:', start);
      final command = source.substring(start, end);
      expect(command, contains('--dart-define=BIL_PUSH_ENABLED=true'));
      expect(command, contains('--dart-define=BIL_PUSH_PROVIDER_READY=true'));
    }
  });
  test('new cloud receipts target IDs and preserve legacy clients', () {
    final sql = File(
      'supabase/migrations/20260929074359_community_attention_and_visible_reads.sql',
    ).readAsStringSync();
    expect(sql.replaceAll(RegExp(r'\s+'), ''), contains('m.id=any('));
    expect(
      sql.replaceAll(RegExp(r'\s+'), ''),
      contains('m.recipient_id=auth.uid()'),
    );
    expect(
      sql,
      isNot(
        contains(
          'create or replace function public.bil_mark_conversation_read',
        ),
      ),
    );
    expect(sql, contains('bil_friendships'));
    expect(sql, contains('revoke all'));
  });
  test('community navigation exposes messages and unified requests', () {
    final sheet = File(
      'lib/features/community/presentation/community_navigation_sheet.dart',
    ).readAsStringSync();
    expect(sheet, contains("'/community/messages'"));
    expect(sheet, contains("'/community/connections'"));
    expect(sheet, contains('CommunityUnreadBadge'));
  });
}
