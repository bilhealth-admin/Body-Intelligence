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

    // BIL-04 adds 15 health commands while preserving the original 25 tools.
    // The local system prompt interpolates the shared Health tool protocol.
    // Audit that source too so we verify its actual instructions, not merely
    // the shorter top-level list after the BIL-04 source split.
    final healthProtocol = File(
      'lib/features/intelligence_center/app_commands/coach_health_tools.dart',
    ).readAsStringSync();
    expect(localGateway, contains(r'$coachHealthToolProtocol'));
    final localPromptSources = '$localGateway\n$healthProtocol';
    expect(BilToolRegistry.tools, hasLength(40));
    // The cloud must admit exactly the same finite allow-list the device
    // validates. A free-form prompt alone cannot authorize a new action.
    final cloudAllowList = RegExp(
      r'const allowedActions = new Set\(\[([\s\S]*?)\]\);',
    ).firstMatch(server)?.group(1);
    expect(cloudAllowList, isNotNull);
    final allowed = RegExp(
      r'"([a-z_]+)"',
    ).allMatches(cloudAllowList!).map((match) => match.group(1)!).toSet();
    expect(allowed, BilToolRegistry.tools.keys.toSet());
    for (final name in BilToolRegistry.tools.keys) {
      expect(server, contains(name), reason: 'server missing $name');
      expect(
        localPromptSources,
        contains(name),
        reason: 'local prompt missing $name',
      );
    }
    expect(server, contains('allowedActions.has(type)'));
    expect(server, contains('requires_confirmation: true'));
  });

  test(
    'language tool executes through the same 25-locale policy it validates',
    () {
      final page =
          ['intelligence_center_page.dart', 'intelligence_action_flow.dart']
              .map(
                (name) => File(
                  'lib/features/intelligence_center/presentation/$name',
                ).readAsStringSync(),
              )
              .join('\n');
      expect(
        page,
        contains(
          "final locale = BilLocalePolicy.canonicalSupportedTag(\n"
          "            action.payload['locale']?.toString(),",
        ),
      );
      expect(
        page,
        isNot(contains("{'ar', 'en', 'fr', 'es', 'tr'}.contains(locale)")),
      );
    },
  );

  test('AI Coach deep-link barcode uses the canonical validator', () {
    final page = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    expect(page, contains('final identity = BarcodeIdentity.parse(barcode);'));
    expect(page, contains('if (!identity.isValid)'));
    expect(page, contains("text: tr('Invalid barcode', 'باركود غير صالح')"));
    expect(page, contains('final canonicalBarcode = identity.digits;'));
    expect(page, isNot(contains("final evidenceKey = 'barcode:\$barcode';")));
  });
}
