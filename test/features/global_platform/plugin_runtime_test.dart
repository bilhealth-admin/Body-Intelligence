import 'global_platform_test_support.dart';

void main() {
  test('versioned plugin lifecycle is durable and safely unloads', () async {
    final life = TestLifecycle();
    final registry = PluginRegistry(
      store: InMemoryGlobalStore(),
      audit: InMemoryGlobalAuditSink(),
      coreVersion: '1.0.0',
    );
    await registry.register(
      const PluginManifest(
        id: 'p',
        version: '1.0.0',
        minCoreVersion: '1.0.0',
        maxCoreVersion: '2.0.0',
        capabilities: {'health'},
        permissions: {'read'},
        dependencies: {},
        securityReview: 'approved',
      ),
      life,
      DateTime.utc(2026),
    );
    await registry.activate('p', DateTime.utc(2026));
    expect(registry.active.length, 1);
    await registry.uninstall('p', DateTime.utc(2026));
    expect(registry.active, isEmpty);
  });
}
