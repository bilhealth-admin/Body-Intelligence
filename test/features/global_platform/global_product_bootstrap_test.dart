import 'package:body_intelligence_log/features/global_platform/cloud_ai/optional_cloud_ai_platform.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/globalization/globalization_accessibility_platform.dart';
import 'package:body_intelligence_log/features/global_platform/product/global_product_access.dart';
import 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production composition bootstraps real product use cases', () async {
    final host = GlobalNativeIntegrationHost.instance;
    await host.close();
    await host.initialize(
      database: sqlite3.openInMemory(),
      configuration: const GlobalProductRuntimeConfiguration(
        localeCatalogs: <GlobalLocaleCatalog>[
          GlobalLocaleCatalog('en', <String, String>{'status': 'Status'}),
          GlobalLocaleCatalog('ar', <String, String>{'status': 'الحالة'}),
        ],
      ),
    );
    final container = ProviderContainer();
    addTearDown(() async {
      container.dispose();
      await host.close();
    });

    final flows = container.read(globalProductFlowsProvider);
    final report = await flows.generateReport(
      ScientificReport(
        id: 'bootstrap',
        locale: 'ar',
        sections: const <ReportSection>[
          ReportSection(
            id: 'summary',
            title: 'الملخص',
            facts: <String>['دليل محلي'],
            estimates: <String>[],
            confidence: .9,
            provenance: 'local-runtime',
          ),
        ],
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 1, 7),
      ),
      rtl: true,
    );
    expect(report.pdf, isNotEmpty);
    expect(flows.hasActiveBuiltInPlugin, isTrue);
    expect(flows.localize('ar', 'status'), 'الحالة');
    expect(flows.appleHealth, isNotNull);
    expect(flows.healthConnect, isNotNull);
    expect(
      await flows.optionalAssistant(
        request: const CloudAiRequest(
          id: 'local-only',
          capability: 'summary',
          redactedPayload: <String, Object?>{},
          maxTokens: 10,
          timeout: Duration(seconds: 1),
        ),
        consent: GlobalConsentGrant(
          scope: 'cloud-ai',
          state: GlobalConsentState.denied,
          updatedAt: DateTime.utc(2026),
        ),
        localOnly: true,
        at: DateTime.utc(2026),
      ),
      isNull,
    );
    expect(flows.capabilities['vision']!.code, 'vision_provider_required');
    expect(
      flows.capabilities['commerce']!.code,
      'commerce_verifier_and_catalog_required',
    );
    expect(
      flows.capabilities['samsung']!.code,
      'samsung_adapter_not_implemented',
    );
  });
}
