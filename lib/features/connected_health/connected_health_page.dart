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

part 'connected_health_components.dart';

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
  bool _refreshOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshOnResume = true;
      return;
    }
    if (state != AppLifecycleState.resumed || !_refreshOnResume) return;
    _refreshOnResume = false;
    unawaited(ref.read(connectedHealthProvider.notifier).refresh());
  }

  Future<void> _openSystemSettings() async {
    _refreshOnResume = true;
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
                          // HealthKit and Health Connect also contain manual
                          // and phone-authored records. Show a watch only when
                          // native provenance actually identifies a wearable.
                          if (connectedHealthSnapshotHasWearableEvidence(
                            snapshot,
                          )) ...[
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
                                            'Smart-watch reading',
                                            'قراءة الساعة الذكية',
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.sync_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: PremiumDesignTokens.spaceSm,
                                  ),
                                  Center(
                                    child: SizedBox.square(
                                      dimension: 196,
                                      child: LiveHealthWatch(
                                        snapshot: snapshot,
                                        languageCode: Localizations.localeOf(
                                          context,
                                        ).languageCode,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: PremiumDesignTokens.spaceMd),
                          ],
                          PremiumSurface(
                            key: const Key('connected-health-source-card'),
                            dashboardGlass: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _platformSourceTitle(context, snapshot),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(
                                  height: PremiumDesignTokens.spaceSm,
                                ),
                                Semantics(
                                  label: tr(
                                    'Connection status',
                                    'حالة الاتصال',
                                  ),
                                  value: connectedHealthStatusText(
                                    context,
                                    snapshot.status,
                                  ),
                                  child: Text(
                                    connectedHealthStatusText(
                                      context,
                                      snapshot.status,
                                    ),
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                  ),
                                ),
                                if (snapshot.availableSources.isNotEmpty) ...[
                                  const SizedBox(
                                    height: PremiumDesignTokens.spaceSm,
                                  ),
                                  Text(
                                    '${tr('Available sources', 'المصادر المتاحة')}: ${snapshot.availableSources.join(' • ')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                        ),
                                  ),
                                ],
                                const SizedBox(
                                  height: PremiumDesignTokens.spaceMd,
                                ),
                                if (!kIsWeb &&
                                    defaultTargetPlatform ==
                                        TargetPlatform.iOS &&
                                    snapshot.status ==
                                        ConnectedHealthStatus
                                            .authorizationRequested &&
                                    snapshot.signals.isEmpty) ...[
                                  Text(
                                    tr(
                                      'Apple Health does not reveal read permission status. Open the Health app, check BIL under Apps, then return and tap Sync now. Only records actually provided by Apple Health will appear.',
                                      'لا تكشف Apple Health حالة إذن القراءة. افتح تطبيق الصحة، تحقق من BIL ضمن التطبيقات، ثم عد واضغط «مزامنة الآن». ستظهر فقط السجلات التي يوفرها Apple Health فعليًا.',
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(height: 1.35),
                                  ),
                                  const SizedBox(
                                    height: PremiumDesignTokens.spaceSm,
                                  ),
                                ],
                                Wrap(
                                  spacing: PremiumDesignTokens.spaceSm,
                                  runSpacing: PremiumDesignTokens.spaceSm,
                                  children: [
                                    if (connectedHealthCanRequestPermissions(
                                      snapshot.status,
                                    ))
                                      FilledButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .requestPermissions(),
                                        icon: const Icon(
                                          Icons.verified_user_outlined,
                                        ),
                                        label: Text(
                                          tr(
                                            'Grant health access',
                                            'منح إذن الصحة',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.status ==
                                            ConnectedHealthStatus
                                                .updateRequired ||
                                        snapshot.status ==
                                            ConnectedHealthStatus
                                                .permissionDenied ||
                                        snapshot.failureCode ==
                                            'revoke_in_system_settings_required')
                                      OutlinedButton.icon(
                                        onPressed: _openSystemSettings,
                                        icon: const Icon(
                                          Icons.settings_outlined,
                                        ),
                                        label: Text(
                                          tr(
                                            'Open system settings',
                                            'فتح إعدادات النظام',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.deviceVerified)
                                      OutlinedButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .requestWeightWritePermission(),
                                        icon: const Icon(
                                          Icons.monitor_weight_outlined,
                                        ),
                                        label: Text(
                                          tr(
                                            defaultTargetPlatform ==
                                                    TargetPlatform.iOS
                                                ? 'Allow weight export'
                                                : 'Allow weight and nutrition export',
                                            defaultTargetPlatform ==
                                                    TargetPlatform.iOS
                                                ? 'السماح بتصدير الوزن'
                                                : 'السماح بتصدير الوزن والتغذية',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.deviceVerified)
                                      TextButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .revokePermissions(),
                                        icon: const Icon(
                                          Icons.link_off_rounded,
                                        ),
                                        label: Text(
                                          tr(
                                            'Disconnect health source',
                                            'فصل مصدر الصحة',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.status ==
                                            ConnectedHealthStatus.ready ||
                                        snapshot.status ==
                                            ConnectedHealthStatus
                                                .synchronized ||
                                        snapshot.status ==
                                            ConnectedHealthStatus
                                                .authorizationRequested ||
                                        snapshot.status ==
                                            ConnectedHealthStatus.degraded)
                                      FilledButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .synchronize(),
                                        icon: const Icon(Icons.sync_rounded),
                                        label: Text(
                                          tr('Sync now', 'مزامنة الآن'),
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: () => ref
                                          .read(
                                            connectedHealthProvider.notifier,
                                          )
                                          .refresh(),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text(
                                        tr('Refresh status', 'تحديث الحالة'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                                      subtitle: Text(signal.source),
                                      trailing: Text(
                                        '${signal.value.toStringAsFixed(signal.value == signal.value.roundToDouble() ? 0 : 1)} ${signal.unit}',
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

  Future<void> _showConnectionSearch(BuildContext context) async {
    final nativeSource = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? 'Apple Health'
        : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'Health Connect'
        : connectedHealthText(context, 'Health source', 'مصدر صحي');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                connectedHealthText(
                  context,
                  'Available connections',
                  'الاتصالات المتاحة',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: BilSemanticIconBadge(
                  kind: BilSemanticIconKind.health,
                  size: 38,
                  iconSize: 21,
                  shape: BoxShape.rectangle,
                ),
                title: Text(nativeSource),
              ),
              ListTile(
                leading: BilSemanticIconBadge(
                  kind: BilSemanticIconKind.devices,
                  iconOverride: Icons.bluetooth_rounded,
                  appleIconOverride: CupertinoIcons.bluetooth,
                  size: 38,
                  iconSize: 21,
                  shape: BoxShape.rectangle,
                ),
                title: Text(
                  connectedHealthText(
                    context,
                    'Bluetooth fitness devices',
                    'أجهزة اللياقة عبر البلوتوث',
                  ),
                ),
              ),
              ListTile(
                key: const Key('available-connections-capabilities-link'),
                leading: BilSemanticIconBadge(
                  kind: BilSemanticIconKind.verifiedFood,
                  iconOverride: Icons.fact_check_outlined,
                  appleIconOverride: CupertinoIcons.checkmark_seal,
                  size: 38,
                  iconSize: 21,
                  shape: BoxShape.rectangle,
                ),
                title: Text(
                  connectedHealthText(
                    context,
                    'Connection capabilities',
                    'قدرات الاتصال',
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/connected-health/capabilities');
                },
              ),
              Text(
                connectedHealthText(
                  context,
                  'Only integrations implemented and verified by BIL are listed.',
                  'تظهر فقط الاتصالات المنفذة والمتحقق منها داخل BIL.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _platformSourceTitle(
    BuildContext context,
    ConnectedHealthSnapshot snapshot,
  ) {
    if (snapshot.platformSource != null) return snapshot.platformSource!;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return connectedHealthText(context, 'Apple Health', 'Apple Health');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return connectedHealthText(context, 'Health Connect', 'Health Connect');
    }
    return connectedHealthText(
      context,
      'Unsupported platform',
      'منصة غير مدعومة',
    );
  }
}
