import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';
import 'package:body_intelligence_log/features/global_platform/commerce/commerce_platform.dart';
import 'package:body_intelligence_log/features/global_platform/plugins/plugin_platform.dart';
import 'package:body_intelligence_log/features/global_platform/globalization/globalization_accessibility_platform.dart';

final class _Verifier implements StoreReceiptVerifier {
  @override
  String get providerId => 'test-store';
  @override
  Future<List<List<int>>> restore(String accountId) async => const [];
  @override
  Future<ReceiptVerificationResult> verify(List<int> receipt) async =>
      ReceiptVerificationResult(
        valid: receipt.isNotEmpty,
        transactionId: 'transaction',
        accountId: 'account',
        productId: 'premium',
        expiresAt: DateTime.utc(2027),
        revoked: false,
      );
}

final class _Lifecycle implements PluginLifecycle {
  @override
  String get pluginId => 'p';
  @override
  Future<void> migrate(String fromVersion, String toVersion) async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

void main() {
  test('real PDF/XLSX signatures and deterministic exports', () {
    final r = ScientificReport(
      id: 'weekly',
      locale: 'ar',
      from: DateTime.utc(2026),
      to: DateTime.utc(2026, 1, 7),
      sections: const [
        ReportSection(
          id: 'weight',
          title: 'Weight',
          facts: ['95 kg'],
          estimates: ['water noise'],
          confidence: .8,
          provenance: 'local',
        ),
      ],
    );
    final e = ScientificReportRuntime();
    expect(utf8.decode(e.pdf(r).take(8).toList()), startsWith('%PDF'));
    expect(e.xlsx(r).take(4), [0x50, 0x4b, 0x03, 0x04]);
    expect(e.json(r), e.json(r));
  });
  test('secure receipt replay protection and durable entitlement', () async {
    final s = InMemoryGlobalStore();
    final c = CommerceRuntime(
      store: s,
      audit: InMemoryGlobalAuditSink(),
      verifiers: [_Verifier()],
      productFeatures: const {
        'premium': {'premium'},
      },
    );
    expect(
      await c.validate(receipt: [1, 2, 3], at: DateTime.utc(2026)),
      isNotNull,
    );
    expect(
      await c.validate(receipt: [1, 2, 3], at: DateTime.utc(2026)),
      isNull,
    );
    expect(await c.has('account', 'premium', DateTime.utc(2026)), isTrue);
  });
  test('versioned plugin lifecycle is durable and safe', () async {
    final r = PluginRegistry(
      store: InMemoryGlobalStore(),
      audit: InMemoryGlobalAuditSink(),
      coreVersion: '1.2.0',
    );
    await r.register(
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
      _Lifecycle(),
      DateTime.utc(2026),
    );
    await r.activate('p', DateTime.utc(2026));
    expect(r.active.length, 1);
    await r.deactivate('p', DateTime.utc(2026));
    expect(r.active, isEmpty);
    await r.uninstall('p', DateTime.utc(2026));
  });
  test('localization validation, fallback, accessibility and units', () {
    final g = GlobalizationRuntime(
      catalogs: const [
        GlobalLocaleCatalog('en', {'hello': 'Hello'}),
        GlobalLocaleCatalog('ar', {'hello': 'مرحبا'}),
      ],
      requiredKeys: const {'hello'},
    );
    expect(g.validate(), isEmpty);
    expect(g.text('ar', 'hello'), 'مرحبا');
    expect(
      g.displayToKg(g.kgToDisplay(90, imperial: true), imperial: true),
      closeTo(90, 1e-9),
    );
    expect(
      const AccessibilityPolicy().validate(touchTarget: 48, textScale: 1.8),
      isTrue,
    );
  });
}
