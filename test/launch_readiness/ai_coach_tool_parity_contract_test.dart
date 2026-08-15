import 'dart:io';

import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server proposals and trusted client registry cover the same tools', () {
    final server = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    final localGateway = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();

    expect(BilToolRegistry.tools, hasLength(21));
    for (final name in BilToolRegistry.tools.keys) {
      expect(server, contains("'$name'"), reason: 'server missing $name');
      expect(
        localGateway,
        contains(name),
        reason: 'local prompt missing $name',
      );
    }
    expect(server, contains('allowedActions.has(type)'));
    expect(server, contains('requires_confirmation: true'));
  });
}
