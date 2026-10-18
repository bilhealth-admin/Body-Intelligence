import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile app has no hidden admin route', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final more = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    expect(router, isNot(contains("path: '/admin/ai-coach'")));
    expect(router, isNot(contains('ai_coach_admin_page.dart')));
    expect(more, isNot(contains("'/admin/ai-coach'")));
    expect(more, isNot(contains('aiCoachAdminAccessProvider')));
    expect(more, isNot(contains('settings-ai-coach-admin-entry')));
  });

  test('shipping entrypoint cannot import any administration screen', () {
    final root = Directory('lib').absolute.uri;
    final pending = [root.resolve('main.dart')];
    final reached = <Uri>{};
    final directives = RegExp(r'''(?:import|export|part)\s+['"]([^'"]+)['"]''');
    while (pending.isNotEmpty) {
      final current = pending.removeLast().normalizePath();
      if (!reached.add(current)) continue;
      final source = File.fromUri(current).readAsStringSync();
      for (final match in directives.allMatches(source)) {
        final path = match.group(1)!;
        if (path.startsWith('dart:')) continue;
        if (path.startsWith('package:') &&
            !path.startsWith('package:body_intelligence_log/')) {
          continue;
        }
        final target = path.startsWith('package:')
            ? root.resolve(
                path.substring('package:body_intelligence_log/'.length),
              )
            : current.resolve(path);
        if (target.toString().startsWith(root.toString())) pending.add(target);
      }
    }
    for (final file in reached) {
      final path = file.path;
      expect(path, isNot(contains('/features/admin/presentation/')));
      expect(path, isNot(endsWith('/community_post_moderation_page.dart')));
      expect(path, isNot(endsWith('/community_food_review_page.dart')));
    }
    // Removing mobile presentation must not delete its server-side services.
    expect(
      File(
        'lib/features/admin/services/ai_coach_admin_service.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        'lib/features/community/data/community_repository.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
