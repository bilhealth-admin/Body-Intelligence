import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

/// Verify both deploy entry points really delegate to the same implementation.
String readPushDispatcherImplementation(String entryPath) {
  final entry = File(entryPath).readAsStringSync();
  final import = RegExp(
    r'import \{ handler \} from "([^"]+)";',
  ).firstMatch(entry);
  expect(import, isNotNull, reason: entryPath);
  expect(entry, contains('Deno.serve((request) => handler(request))'));
  expect(entry, isNot(contains('bil_push_outbox')));
  final implementation = path.normalize(
    path.join(path.dirname(entryPath), import!.group(1)!),
  );
  expect(
    implementation,
    path.normalize('supabase/functions/community-push-dispatch/server.ts'),
  );
  return File(implementation).readAsStringSync();
}
