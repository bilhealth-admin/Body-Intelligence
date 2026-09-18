import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post soft-delete does not select the row after hiding it', () {
    final source = File(
      'lib/features/community/data/community_post_cloud_store.dart',
    ).readAsStringSync();
    final classStart = source.indexOf('final class CommunityPostCloudStore');
    final start = source.indexOf(
      'Future<void> delete(String postId)',
      classStart,
    );
    final end = source.indexOf('static String? _validatedBody', start);
    final method = source.substring(start, end);
    final updateStart = method.indexOf(".update({");
    final updateMethod = method.substring(updateStart);

    expect(method, contains("'deleted_at'"));
    expect(method, contains(".eq('author_id', _user.id)"));
    expect(updateMethod, isNot(contains(".select('id')")));
  });
}
