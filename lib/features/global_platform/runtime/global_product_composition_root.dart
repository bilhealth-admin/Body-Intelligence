import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../cloud_ai/optional_cloud_ai_platform.dart';
import '../commerce/commerce_platform.dart';
import '../core/global_platform_core.dart';
import '../globalization/globalization_accessibility_platform.dart';
import '../health_data/android_health_connect_platform.dart';
import '../health_data/apple_health_platform.dart';
import '../medical_devices/ble_medical_device_platform.dart';
import '../medical_devices/medical_device_platform.dart';
import '../medical_devices/native_ble_medical_bridge.dart';
import '../persistence/global_platform_sqlite_store.dart';
import '../plugins/plugin_platform.dart';
import '../product/global_product_coordinators.dart';
import '../professional/professional_platform.dart';
import '../reports/arabic_vector_pdf_renderer.dart';
import '../reports/world_class_report_platform.dart';
import '../vision/computer_vision_platform.dart';
import '../wearables/platform_wearable_transports.dart';
import '../wearables/provider_specific_wearable_apis.dart';
import '../wearables/provider_wearable_adapters.dart';
import '../wearables/wearables_platform.dart';

final class GlobalProductRuntimeConfiguration {
  const GlobalProductRuntimeConfiguration({
    this.visionProviders = const <VisionProvider>[],
    this.cloudAiProviders = const <CloudAiProvider>[],
    this.cloudAiMonthlyTokenBudget,
    this.commerceVerifiers = const <StoreReceiptVerifier>[],
    this.productFeatures = const <String, Set<String>>{},
    this.additionalWearableProviders = const <WearableProvider>[],
    this.localeCatalogs,
  });

  final List<VisionProvider> visionProviders;
  final List<CloudAiProvider> cloudAiProviders;
  final int? cloudAiMonthlyTokenBudget;
  final List<StoreReceiptVerifier> commerceVerifiers;
  final Map<String, Set<String>> productFeatures;
  final List<WearableProvider> additionalWearableProviders;
  final List<GlobalLocaleCatalog>? localeCatalogs;
}

final class GlobalNativeIntegrationHost {
  GlobalNativeIntegrationHost._();

  static final GlobalNativeIntegrationHost instance =
      GlobalNativeIntegrationHost._();

  SqliteGlobalPlatformStore? _store;
  AppleHealthRuntime? appleHealth;
  HealthConnectRuntime? healthConnect;
  GlobalProductFlows? productFlows;
  PluginRegistry? plugins;
  GlobalizationRuntime? globalization;
  final InMemoryGlobalAuditSink audit = InMemoryGlobalAuditSink();

  Future<void> initialize({
    Database? database,
    GlobalProductRuntimeConfiguration configuration =
        const GlobalProductRuntimeConfiguration(),
  }) async {
    if (_store != null) {
      return;
    }

    final Database opened;
    if (database != null) {
      opened = database;
    } else {
      final supportDirectory = await getApplicationSupportDirectory();
      final databasePath = path.join(
        supportDirectory.path,
        'bil_global_platform.sqlite3',
      );
      opened = sqlite3.open(databasePath);
    }

    final store = SqliteGlobalPlatformStore(opened);
    _store = store;
    appleHealth = AppleHealthRuntime.methodChannel(store: store, audit: audit);
    healthConnect = HealthConnectRuntime.methodChannel(
      store: store,
      audit: audit,
    );

    final platformTransport = PlatformAwareWearableTransport(
      remote: const _UnavailableRemoteWearableTransport(),
    );
    const nativeCredentials = NativeWearableCredentialBroker();
    final nativeWearables = <WearableProvider>[
      ProviderWearableAdapter(
        vendor: WearableVendor.appleWatch,
        credentials: nativeCredentials,
        api: AppleWatchWearableApi(platformTransport),
        store: store,
        audit: audit,
      ),
      ProviderWearableAdapter(
        vendor: WearableVendor.wearOs,
        credentials: nativeCredentials,
        api: WearOsWearableApi(platformTransport),
        store: store,
        audit: audit,
      ),
      ...configuration.additionalWearableProviders,
    ];

    final medicalProvider = BleMedicalDeviceProvider(
      bridge: MethodChannelBleMedicalBridge(),
      store: store,
      audit: audit,
    );

    final pluginRegistry = PluginRegistry(
      store: store,
      audit: audit,
      coreVersion: '1.0.0',
    );
    await pluginRegistry.restore();
    final builtInPlugin = BilCoreEvidencePlugin(store: store, audit: audit);
    if (!pluginRegistry.contains('bil.core.evidence')) {
      await pluginRegistry.register(
        const PluginManifest(
          id: 'bil.core.evidence',
          version: '1.0.0',
          minCoreVersion: '1.0.0',
          maxCoreVersion: '1.99.99',
          capabilities: <String>{'evidence.graph', 'timeline.provenance'},
          permissions: <String>{'local.read', 'local.write'},
          dependencies: <String>{},
          securityReview: 'approved',
        ),
        builtInPlugin,
        DateTime.now().toUtc(),
      );
    } else {
      pluginRegistry.attachLifecycle(builtInPlugin);
    }
    await pluginRegistry.activate('bil.core.evidence', DateTime.now().toUtc());
    plugins = pluginRegistry;

    final catalogs =
        configuration.localeCatalogs ??
        await Future.wait(<Future<GlobalLocaleCatalog>>[
          const ArbCatalogLoader().load('lib/l10n/app_en.arb', 'en'),
          const ArbCatalogLoader().load('lib/l10n/app_ar.arb', 'ar'),
          const ArbCatalogLoader().load('lib/l10n/app_fr.arb', 'fr'),
          const ArbCatalogLoader().load('lib/l10n/app_es.arb', 'es'),
          const ArbCatalogLoader().load('lib/l10n/app_tr.arb', 'tr'),
        ]);
    globalization = GlobalizationRuntime(
      catalogs: catalogs,
      requiredKeys: catalogs.expand((catalog) => catalog.messages.keys).toSet(),
    );

    final vision = configuration.visionProviders.isEmpty
        ? null
        : VisionRuntime(
            providers: configuration.visionProviders,
            store: store,
            audit: audit,
          );
    final cloudAi =
        configuration.cloudAiProviders.isEmpty ||
            configuration.cloudAiMonthlyTokenBudget == null ||
            configuration.cloudAiMonthlyTokenBudget! <= 0
        ? null
        : OptionalCloudAiRuntime(
            providers: configuration.cloudAiProviders,
            store: store,
            audit: audit,
            monthlyTokenBudget: configuration.cloudAiMonthlyTokenBudget!,
          );
    final commerce =
        configuration.commerceVerifiers.isEmpty ||
            configuration.productFeatures.isEmpty
        ? null
        : CommerceRuntime(
            store: store,
            audit: audit,
            verifiers: configuration.commerceVerifiers,
            productFeatures: configuration.productFeatures,
          );

    final regularFont = (await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    )).buffer.asUint8List();
    final boldFont = (await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    )).buffer.asUint8List();

    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isMobileNative = isIos || isAndroid;

    productFlows = GlobalProductFlows(
      appleHealth: appleHealth!,
      healthConnect: healthConnect!,
      plugins: pluginRegistry,
      globalization: globalization!,
      vision: vision,
      cloudAi: cloudAi,
      wearables: WearableRuntime(
        providers: nativeWearables,
        store: store,
        audit: audit,
      ),
      medical: MedicalDeviceRuntime(
        providers: <MedicalDeviceProvider>[medicalProvider],
        store: store,
        audit: audit,
      ),
      reports: WorldClassReportRuntime(
        pdfRenderer: ArabicVectorPdfRenderer(
          regularFont: regularFont,
          boldFont: boldFont,
        ),
      ),
      professional: ProfessionalRuntime(store: store, audit: audit),
      commerce: commerce,
      store: store,
      audit: audit,
      capabilities: <String, GlobalProductCapabilityState>{
        'appleWatch': GlobalProductCapabilityState(
          status: isIos
              ? GlobalProductCapabilityStatus.available
              : GlobalProductCapabilityStatus.unavailable,
          code: isIos ? 'native_healthkit_available' : 'ios_platform_required',
        ),
        'wearOs': GlobalProductCapabilityState(
          status: isAndroid
              ? GlobalProductCapabilityStatus.available
              : GlobalProductCapabilityStatus.unavailable,
          code: isAndroid
              ? 'native_health_connect_available'
              : 'android_platform_required',
        ),
        'medical': GlobalProductCapabilityState(
          status: isMobileNative
              ? GlobalProductCapabilityStatus.available
              : GlobalProductCapabilityStatus.unavailable,
          code: isMobileNative
              ? 'native_ble_available'
              : 'mobile_bluetooth_platform_required',
        ),
        'reports': const GlobalProductCapabilityState(
          status: GlobalProductCapabilityStatus.available,
          code: 'local_reports_ready',
        ),
        'professional': const GlobalProductCapabilityState(
          status: GlobalProductCapabilityStatus.available,
          code: 'local_professional_ready',
        ),
        'plugins': const GlobalProductCapabilityState(
          status: GlobalProductCapabilityStatus.available,
          code: 'local_plugin_registry_ready',
        ),
        'globalization': const GlobalProductCapabilityState(
          status: GlobalProductCapabilityStatus.available,
          code: 'localized_catalogs_ready',
        ),
        'vision': GlobalProductCapabilityState(
          status: vision == null
              ? GlobalProductCapabilityStatus.configurationRequired
              : GlobalProductCapabilityStatus.available,
          code: vision == null ? 'vision_provider_required' : 'vision_ready',
        ),
        'cloudAi': GlobalProductCapabilityState(
          status: cloudAi == null
              ? GlobalProductCapabilityStatus.configurationRequired
              : GlobalProductCapabilityStatus.available,
          code: cloudAi == null
              ? 'cloud_ai_provider_and_budget_required'
              : 'cloud_ai_ready',
        ),
        'commerce': GlobalProductCapabilityState(
          status: commerce == null
              ? GlobalProductCapabilityStatus.configurationRequired
              : GlobalProductCapabilityStatus.available,
          code: commerce == null
              ? 'commerce_verifier_and_catalog_required'
              : 'commerce_ready',
        ),
        'samsung': const GlobalProductCapabilityState(
          status: GlobalProductCapabilityStatus.unavailable,
          code: 'samsung_adapter_not_implemented',
        ),
      },
    );

    if (kDebugMode) {
      debugPrint('BIL global product composition initialized.');
    }
  }

  Future<void> close() async {
    _store?.close();
    _store = null;
    appleHealth = null;
    healthConnect = null;
    productFlows = null;
    plugins = null;
    globalization = null;
  }
}

final class _UnavailableRemoteWearableTransport
    implements WearableHttpTransport {
  const _UnavailableRemoteWearableTransport();

  @override
  Future<WearableHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) {
    throw StateError('remote_wearable_transport_not_configured:${uri.host}');
  }
}
