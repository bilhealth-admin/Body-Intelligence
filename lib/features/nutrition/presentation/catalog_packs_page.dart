import 'package:body_intelligence_log/shared/widgets/bil_refresh_indicator.dart';
import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/bil_pinned_header_body.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nutrition_copy.dart';

import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../domain/catalog_pack.dart';
import '../services/catalog_pack_manager.dart';

final catalogPackManagerProvider = Provider<CatalogPackManager>(
  (_) => CatalogPackManager(),
);

class CatalogPacksPage extends ConsumerStatefulWidget {
  const CatalogPacksPage({super.key});

  @override
  ConsumerState<CatalogPacksPage> createState() => _CatalogPacksPageState();
}

class _CatalogPacksPageState extends ConsumerState<CatalogPacksPage> {
  static const _catalogTestAccess = bool.fromEnvironment(
    'BIL_ENABLE_CATALOG_TEST_ACCESS',
  );

  late final CatalogPackManager _manager;
  List<CatalogPack> _available = const [];
  List<InstalledCatalogPack> _installed = const [];
  Object? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(catalogPackManagerProvider);
    _load();
  }

  Future<void> _load() async {
    try {
      final installed = await _manager.installed();
      final available = await _manager.fetchAvailable();
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _available = available;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _install(
    CatalogPack pack, {
    required String? owner,
    required int ownerVisit,
  }) async {
    if (!mounted ||
        ref.read(verifiedEntitlementOwnerIdProvider) != owner ||
        ref.read(verifiedEntitlementOwnerVisitProvider) != ownerVisit ||
        !_permits(
          pack.access,
          readAccess: () => ref.read(verifiedSubscriptionAccessProvider),
        )) {
      return;
    }
    setState(() => _busyId = pack.id);
    try {
      await _manager.install(pack);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(InstalledCatalogPack pack) async {
    setState(() => _busyId = pack.id);
    try {
      await _manager.remove(pack);
      await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(nutritionText(context, 'Food libraries', 'مكتبات الغذاء')),
      ),
      body: BilPinnedHeaderBody(
        header: _manager.downloadsConfigured
            ? Padding(
                key: const Key('catalog-packs-pinned-header'),
                padding: const EdgeInsets.all(20),
                child: Text(
                  nutritionText(
                    context,
                    'Download verified libraries when needed and search them offline.',
                    'نزّل مكتبات موثقة عند الحاجة، وابحث فيها دون إنترنت.',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              )
            : const SizedBox.shrink(),
        body: BilRefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              _manager.downloadsConfigured ? 0 : 20,
              20,
              20,
            ),
            children: [
              ListTile(
                key: const Key('catalog-core-installed'),
                leading: const Icon(Icons.verified_rounded),
                title: Text(
                  nutritionText(context, 'BIL Food Core', 'أساس BIL الغذائي'),
                ),
                subtitle: Text(
                  nutritionText(
                    context,
                    'Installed and offline-ready',
                    'مثبّت وجاهز دون إنترنت',
                  ),
                ),
                trailing: const Icon(Icons.check_circle_rounded),
              ),
              for (final pack in _available) _availableTile(pack),
              if (_manager.downloadsConfigured &&
                  _available.isEmpty &&
                  _error == null)
                _notice(
                  nutritionText(
                    context,
                    'No packs are currently published.',
                    'لا توجد حزم منشورة حاليًا.',
                  ),
                ),
              if (_error != null)
                _notice(
                  nutritionText(
                    context,
                    'The pack list could not be refreshed. Your local library still works.',
                    'تعذّر تحديث قائمة الحزم. المكتبة المحلية ما زالت تعمل.',
                  ),
                  error: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _availableTile(CatalogPack pack) {
    final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
    final ownerVisit = ref.watch(verifiedEntitlementOwnerVisitProvider);
    final installed = _installed
        .where((item) => item.id == pack.id)
        .firstOrNull;
    final busy = _busyId == pack.id;
    final permitted = _permits(pack.access);
    final size = (pack.sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return BilPearlMaterialCard(
      child: ListTile(
        title: Text(pack.title),
        subtitle: Text(
          '${pack.access.name.toUpperCase()} · $size MB · ${pack.version}',
        ),
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: BilFeatureWelcomeStatus(),
              )
            : installed == null
            ? FilledButton(
                onPressed: permitted
                    ? () => _install(pack, owner: owner, ownerVisit: ownerVisit)
                    : null,
                child: Text(
                  permitted
                      ? nutritionText(context, 'Download', 'تنزيل')
                      : nutritionText(context, 'Plan required', 'يتطلب خطة'),
                ),
              )
            : TextButton(
                onPressed: () => _remove(installed),
                child: Text(nutritionText(context, 'Remove', 'حذف')),
              ),
      ),
    );
  }

  bool _permits(
    CatalogPackAccess access, {
    AsyncValue<SubscriptionState> Function()? readAccess,
  }) {
    if (access == CatalogPackAccess.free) return true;
    if (kDebugMode && _catalogTestAccess) return true;
    final verifiedAccess = readAccess != null
        ? readAccess()
        : ref.watch(verifiedSubscriptionAccessProvider);
    final state = verifiedAccess.asData?.value;
    if (verifiedAccess.isLoading ||
        verifiedAccess.hasError ||
        state == null ||
        state.authority != EntitlementAuthority.verifiedServer) {
      return false;
    }
    return switch (access) {
      CatalogPackAccess.free => true,
      CatalogPackAccess.plus => state.plan != CommercePlan.free,
      CatalogPackAccess.pro =>
        state.plan != CommercePlan.free && state.plan != CommercePlan.plus,
      CatalogPackAccess.coach =>
        state.plan == CommercePlan.coach ||
            state.plan == CommercePlan.enterprise,
      CatalogPackAccess.clinic =>
        state.plan == CommercePlan.clinic ||
            state.plan == CommercePlan.enterprise,
      CatalogPackAccess.enterprise => state.plan == CommercePlan.enterprise,
    };
  }

  Widget _notice(String message, {bool error = false}) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(message),
  );
}
