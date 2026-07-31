import 'package:body_intelligence_log/features/global_platform/globalization/globalization_accessibility_platform.dart';
import 'package:body_intelligence_log/features/global_platform/product/global_product_access.dart';
import 'package:body_intelligence_log/features/global_platform/product/global_product_coordinators.dart';
import 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'official composition root exposes executable local product flows',
    () async {
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
      expect(flows, isA<GlobalProductFlows>());
      expect(flows.hasActiveBuiltInPlugin, isTrue);
      expect(flows.localize('ar', 'status'), 'الحالة');

      final report = await flows.generateReport(
        ScientificReport(
          id: 'product-wiring',
          locale: 'ar',
          from: DateTime.utc(2026, 1, 1),
          to: DateTime.utc(2026, 1, 7),
          sections: const <ReportSection>[
            ReportSection(
              id: 'summary',
              title: 'الملخص',
              facts: <String>['بيانات محلية'],
              estimates: <String>[],
              confidence: .9,
              provenance: 'local-evidence',
            ),
          ],
        ),
        rtl: true,
      );
      expect(report.pdf, isNotEmpty);

      expect(
        flows.capabilities['vision']!.status,
        GlobalProductCapabilityStatus.configurationRequired,
      );
      expect(
        flows.capabilities['cloudAi']!.status,
        GlobalProductCapabilityStatus.configurationRequired,
      );
      expect(
        flows.capabilities['commerce']!.status,
        GlobalProductCapabilityStatus.configurationRequired,
      );
      expect(
        flows.capabilities['samsung']!.status,
        GlobalProductCapabilityStatus.unavailable,
      );
      expect(
        await flows.hasEntitlement(
          account: 'local',
          feature: 'premium',
          at: DateTime.utc(2026),
        ),
        isFalse,
      );
    },
  );
}
