import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/plugins/plugin_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'built-in evidence plugin executes durable lifecycle through production registry',
    () async {
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      final registry = PluginRegistry(
        store: store,
        audit: audit,
        coreVersion: '1.0.0',
      );
      final plugin = BilCoreEvidencePlugin(store: store, audit: audit);
      await registry.register(
        const PluginManifest(
          id: 'bil.core.evidence',
          version: '1.0.0',
          minCoreVersion: '1.0.0',
          maxCoreVersion: '1.99.99',
          capabilities: <String>{'evidence.graph'},
          permissions: <String>{'local.read'},
          dependencies: <String>{},
          securityReview: 'approved',
        ),
        plugin,
        DateTime.utc(2026),
      );
      await registry.activate('bil.core.evidence', DateTime.utc(2026));
      expect(
        (await store.get('plugin_runtime', 'bil.core.evidence'))?['active'],
        isTrue,
      );
      await registry.deactivate('bil.core.evidence', DateTime.utc(2026));
      expect(
        (await store.get('plugin_runtime', 'bil.core.evidence'))?['active'],
        isFalse,
      );
    },
  );
}
