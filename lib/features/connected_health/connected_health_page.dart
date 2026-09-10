import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/premium_design_tokens.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../app/localization/runtime_copy_connected_health.dart';
import '../../shared/widgets/premium_surface.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/providers/commerce_providers.dart';
import '../dashboard/widgets/premium_dashboard_card_lock.dart';
import '../global_platform/fitness_devices/ble_fitness_device_platform.dart';
import 'connected_health_model.dart';
import 'connected_health_copy.dart';
import 'device_compatibility.dart';
import 'providers/connected_health_provider.dart';
import 'providers/fitness_device_provider.dart';
import 'widgets/food_name_health_sync_card.dart';
import 'widgets/live_health_watch.dart';
import 'widgets/apple_health_permission_review.dart';

part 'connected_health_components.dart';
part 'connected_health_source_card.dart';
part 'connected_health_page_search.dart';

@visibleForTesting
bool connectedHealthCanRequestPermissions(ConnectedHealthStatus status) =>
    status == ConnectedHealthStatus.permissionRequired ||
    status == ConnectedHealthStatus.permissionDenied;

String connectedHealthStatusText(
  BuildContext context,
  ConnectedHealthStatus status,
) {
  String tr(String en, String ar) => connectedHealthText(context, en, ar);
  return switch (status) {
    ConnectedHealthStatus.unavailable => tr(
      'Unavailable on this device.',
      'غير متاح على هذا الجهاز.',
    ),
    ConnectedHealthStatus.updateRequired => tr(
      'The health provider must be installed or updated.',
      'يلزم تثبيت مصدر الصحة أو تحديثه.',
    ),
    ConnectedHealthStatus.permissionRequired => tr(
      'BIL needs explicit permission before reading health data.',
      'يحتاج BIL إلى إذن صريح قبل قراءة البيانات الصحية.',
    ),
    ConnectedHealthStatus.permissionDenied => tr(
      'Permission was denied. You can grant it later in system settings.',
      'تم رفض الإذن. يمكنك منحه لاحقًا من إعدادات النظام.',
    ),
    ConnectedHealthStatus.authorizationRequested => tr(
      'The Health access request completed. Apple does not reveal read permission status; only records it provides will appear.',
      'اكتمل طلب الوصول إلى الصحة. لا تكشف Apple حالة إذن القراءة؛ لن تظهر إلا السجلات التي يوفرها النظام.',
    ),
    ConnectedHealthStatus.ready => tr(
      'Ready to synchronize.',
      'جاهز للمزامنة.',
    ),
    ConnectedHealthStatus.syncing => tr(
      'Synchronizing now.',
      'تتم المزامنة الآن.',
    ),
    ConnectedHealthStatus.synchronized => tr(
      'Connected and synchronized.',
      'متصل ومتزامن.',
    ),
    ConnectedHealthStatus.degraded => tr(
      'The native source could not be reached. Local data was not affected.',
      'تعذر الوصول إلى المصدر الأصلي. البيانات المحلية لم تتأثر.',
    ),
  };
}

class ConnectedHealthPage extends ConsumerStatefulWidget {
  const ConnectedHealthPage({super.key});

  @override
  ConsumerState<ConnectedHealthPage> createState() =>
      _ConnectedHealthPageState();
}

class _ConnectedHealthPageState extends ConsumerState<ConnectedHealthPage>
    with WidgetsBindingObserver {
  bool _connectedOnly = false;
  bool _refreshAfterSystemSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Apps & Devices is the explicit entry point for native health status.
    // Do not construct the dashboard/coach with a HealthKit read in flight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(connectedHealthProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_refreshAfterSystemSettings) {
      return;
    }
    _refreshAfterSystemSettings = false;
    unawaited(ref.read(connectedHealthProvider.notifier).refresh());
  }

  Future<void> _openSystemSettings() async {
    _refreshAfterSystemSettings = true;
    await ref.read(connectedHealthProvider.notifier).openSystemSettings();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    final state = ref.watch(connectedHealthProvider);
    final verifiedPlan = ref
        .watch(verifiedSubscriptionStateProvider)
        .value
        ?.plan;
    final fitnessDevicesUnlocked =
        verifiedPlan != null && verifiedPlan != CommercePlan.free;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(tr('Apps & Devices', 'التطبيقات والأجهزة')),
        ),
        actions: [
          IconButton(
            tooltip: tr('Connection capabilities', 'قدرات الاتصال'),
            onPressed: () => context.push('/connected-health/capabilities'),
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            tooltip: tr('Search connections', 'بحث في الاتصالات'),
            onPressed: () => _showConnectionSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Row(
            children: [
              Expanded(
                child: _ConnectionTab(
                  label: tr('All', 'الكل'),
                  selected: !_connectedOnly,
                  onTap: () => setState(() => _connectedOnly = false),
                ),
              ),
              Expanded(
                child: _ConnectionTab(
                  label: tr('Connected', 'المتصلة'),
                  selected: _connectedOnly,
                  onTap: () => setState(() => _connectedOnly = true),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _connectedOnly
          ? _ConnectedSourcesView(
              snapshot: state,
              onConnect: () => setState(() => _connectedOnly = false),
            )
          : SafeArea(
              child: Semantics(
                container: true,
                label: tr('Health Hub', 'المركز الصحي'),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                  children: [
                    state.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => PremiumSurface(
                        dashboardGlass: true,
                        child: Text(
                          tr(
                            'Health Hub status could not be read.',
                            'تعذر قراءة حالة المركز الصحي.',
                          ),
                        ),
                      ),
                      data: (snapshot) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A verified phone source is sufficient; a watch
                          // is an optional data producer, not an access gate.
                          if (liveHealthWatchCanShowMetrics(snapshot)) ...[
                            PremiumSurface(
                              key: const Key(
                                'connected-health-live-watch-card',
                              ),
                              dashboardGlass: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tr(
                                            'Fitness readings',
                                            'قراءات اللياقة',
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        key: const Key(
                                          'connected-health-watch-refresh',
                                        ),
                                        tooltip: tr('Sync now', 'تحديث الساعة'),
                                        onPressed: snapshot.isBusy
                                            ? null
                                            : () => ref
                                                  .read(
                                                    connectedHealthProvider
                                                        .notifier,
                                                  )
                                                  .synchronize(),
                                        icon: const Icon(Icons.sync_rounded),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: PremiumDesignTokens.spaceSm,
                                  ),
                                  Center(
                                    child: SizedBox.square(
                                      dimension:
                                          248 +
                                          ((MediaQuery.textScalerOf(
                                                    context,
                                                  ).scale(1).clamp(1.0, 2.0) -
                                                  1) *
                                              68),
                                      child: LiveHealthWatch(
                                        snapshot: snapshot,
                                        languageCode: Localizations.localeOf(
                                          context,
                                        ).toLanguageTag(),
                                        // Keep the same compact watch face used
                                        // by the external dashboard preview.
                                        compact: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: PremiumDesignTokens.spaceMd),
                          ],
                          _HealthSourceCard(
                            snapshot: snapshot,
                            title: _platformSourceTitle(context, snapshot),
                            onOpenSettings: _openSystemSettings,
                          ),
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          PremiumDashboardCardLock(
                            key: const Key('fitness-devices-premium-gate'),
                            locked: !fitnessDevicesUnlocked,
                            // A centered floating badge obscures the live BLE
                            // status/action copy on compact screens. The whole
                            // card remains a semantic Premium gate and opens
                            // the plans route when locked.
                            showLabel: false,
                            title: tr(
                              'Premium fitness device connections',
                              'اتصال أجهزة اللياقة ضمن Premium',
                            ),
                            detail: tr(
                              'Weight, body composition, and heart rate',
                              'الوزن وتركيب الجسم ومعدل ضربات القلب',
                            ),
                            onTap: () =>
                                context.push('/plans?focus=subscription'),
                            child: const _FitnessDeviceSection(),
                          ),
                          if (!kIsWeb &&
                              defaultTargetPlatform ==
                                  TargetPlatform.android) ...[
                            const SizedBox(height: PremiumDesignTokens.spaceMd),
                            const FoodNameHealthSyncCard(
                              key: Key('connected-health-food-sync-card'),
                            ),
                          ],
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          const _CompatibilitySection(),
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          PremiumSurface(
                            dashboardGlass: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  tr(
                                    'Privacy and data flow',
                                    'الخصوصية وتدفق البيانات',
                                  ),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(
                                  height: PremiumDesignTokens.spaceSm,
                                ),
                                Text(
                                  tr(
                                    'Only approved health categories are read. Sync stays local and keeps the original source of every value.',
                                    'تُقرأ فئات الصحة التي توافق عليها فقط. تبقى المزامنة محلية وتحفظ المصدر الأصلي لكل قيمة.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (snapshot.signals.isNotEmpty) ...[
                            const SizedBox(height: PremiumDesignTokens.spaceMd),
                            PremiumSurface(
                              key: const Key('connected-health-signals-card'),
                              dashboardGlass: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    tr(
                                      'Recent synchronized signals',
                                      'أحدث الإشارات المتزامنة',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(
                                    height: PremiumDesignTokens.spaceSm,
                                  ),
                                  for (final signal in snapshot.signals)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: BilSemanticIconBadge(
                                        kind:
                                            BilSemanticIcons.kindForHealthSignal(
                                              signal.key,
                                            ),
                                        size: 38,
                                        iconSize: 21,
                                        shape: BoxShape.rectangle,
                                      ),
                                      title: Text(
                                        connectedHealthDataTypeText(
                                          context,
                                          signal.key,
                                        ),
                                      ),
                                      trailing: Text(
                                        connectedHealthSignalValueText(
                                          context,
                                          signal,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
