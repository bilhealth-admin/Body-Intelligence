import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../app/localization/runtime_copy_connected_health.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import '../../dashboard/widgets/dashboard_carousel.dart';
import '../../global_platform/health_data/unified_health_data_integration.dart';
import '../../global_platform/fitness_devices/ble_fitness_device_platform.dart';
import '../connected_health_model.dart';
import '../connected_health_copy.dart';
import '../providers/connected_health_provider.dart';
import '../providers/fitness_device_provider.dart';
import 'connected_health_primitives.dart';
import 'health_hub_empty_state.dart';
import 'live_health_watch.dart';

@visibleForTesting
ConnectedHealthSnapshot dashboardWatchSnapshot(
  ConnectedHealthSnapshot snapshot,
  FitnessDeviceSnapshot fitnessDevices,
) {
  final connected =
      fitnessDevices.status == FitnessDeviceConnectionStatus.connected &&
      fitnessDevices.connectedDeviceId?.trim().isNotEmpty == true;
  if (!connected) return snapshot;

  ConnectedHealthSignalView? latestHeartRate;
  for (final packet in fitnessDevices.measurements) {
    if (packet['kind'] != 'heart_rate' || packet['unit'] != 'bpm') continue;
    final value = packet['value'];
    final observedAt = DateTime.tryParse('${packet['observedAt'] ?? ''}');
    if (value is! num ||
        !value.toDouble().isFinite ||
        observedAt == null ||
        value < BleMeasurementPolicy.supported['heart_rate']!.minimum ||
        value > BleMeasurementPolicy.supported['heart_rate']!.maximum) {
      continue;
    }
    final candidate = ConnectedHealthSignalView(
      key: 'heartRate',
      value: value.toDouble(),
      unit: 'bpm',
      source: 'ble:${fitnessDevices.connectedDeviceId}',
      observedAt: observedAt.toUtc(),
      confidence: 1,
      attributes: const <String, Object?>{
        'transport': 'ble',
        'wearableKind': 'ble_fitness_sensor',
      },
    );
    if (latestHeartRate == null ||
        candidate.observedAt.isAfter(latestHeartRate.observedAt)) {
      latestHeartRate = candidate;
    }
  }
  const bleSource = 'Bluetooth fitness device';
  final baseUsable = liveHealthWatchCanShowMetrics(snapshot);
  final availableSources = <String>{
    if (baseUsable)
      ...snapshot.availableSources.where((source) => source.trim().isNotEmpty),
    bleSource,
  }.toList(growable: false);
  final baseLastSync = baseUsable ? snapshot.lastSyncAt : null;
  final latestSync = latestHeartRate == null
      ? baseLastSync
      : baseLastSync == null || latestHeartRate.observedAt.isAfter(baseLastSync)
      ? latestHeartRate.observedAt
      : baseLastSync;
  return ConnectedHealthSnapshot(
    status: latestHeartRate == null
        ? baseUsable
              ? snapshot.status
              : ConnectedHealthStatus.ready
        : ConnectedHealthStatus.synchronized,
    platformSource:
        baseUsable && snapshot.platformSource?.trim().isNotEmpty == true
        ? snapshot.platformSource
        : bleSource,
    availableSources: availableSources,
    signals: <ConnectedHealthSignalView>[
      if (baseUsable) ...snapshot.signals,
      ?latestHeartRate,
    ],
    importedCount: baseUsable ? snapshot.importedCount : 0,
    lastSyncAt: latestSync,
    failureCode: null,
    availabilityStatus: null,
    deviceVerified: true,
    stepHistory: baseUsable
        ? snapshot.stepHistory
        : const <ConnectedHealthSignalView>[],
  );
}

class ConnectedHealthCard extends ConsumerStatefulWidget {
  const ConnectedHealthCard({
    super.key,
    required this.languageCode,
    this.compact = false,
    this.dashboardCompact = false,
    this.hiddenSignalKeys = const <String>{},
  });

  final String languageCode;
  final bool compact;
  final bool dashboardCompact;
  final Set<String> hiddenSignalKeys;

  @override
  ConsumerState<ConnectedHealthCard> createState() =>
      _ConnectedHealthCardState();
}

class _ConnectedHealthCardState extends ConsumerState<ConnectedHealthCard> {
  bool _refreshing = false;

  Future<void> _synchronizeSnapshot() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final health = ref.read(connectedHealthProvider).value;
    final devices = ref.read(fitnessDeviceProvider);
    final hasBle = devices.status == FitnessDeviceConnectionStatus.connected;
    // The refresh control follows the source actually represented on the
    // face. A BLE-only user must not silently get an unrelated HealthKit call.
    try {
      if (hasBle) {
        await ref.read(fitnessDeviceProvider.notifier).refreshMeasurements();
      }
      if (!hasBle || health?.deviceVerified == true) {
        await ref.read(connectedHealthProvider.notifier).synchronize();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(widget.languageCode, en, ar);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectedHealthProvider);
    final fitnessDevices = ref.watch(fitnessDeviceProvider);
    return Semantics(
      container: true,
      label: tr('Health Hub', 'المركز الصحي'),
      child: PremiumSurface(
        key: const Key('connected-health-card'),
        dashboardGlass: true,
        padding: widget.compact
            ? const EdgeInsets.all(PremiumDesignTokens.spaceSm)
            : PremiumDesignTokens.cardPaddingLarge,
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ConnectedHealthErrorContent(
            languageCode: Localizations.localeOf(context).toLanguageTag(),
            onRetry: () => ref.read(connectedHealthProvider.notifier).refresh(),
          ),
          data: (snapshot) => _ConnectedHealthContent(
            snapshot: snapshot.copyWith(isBusy: snapshot.isBusy || _refreshing),
            fitnessDevices: fitnessDevices,
            languageCode: Localizations.localeOf(context).toLanguageTag(),
            compact: widget.compact,
            dashboardCompact: widget.dashboardCompact,
            hiddenSignalKeys: widget.hiddenSignalKeys,
            onManage: () => context.push('/connected-health'),
            onSync:
                _refreshing ||
                    snapshot.isBusy ||
                    snapshot.status == ConnectedHealthStatus.syncing
                ? null
                : _synchronizeSnapshot,
          ),
        ),
      ),
    );
  }
}

/// A compact, readable Today-only window onto the device artwork.
class _DashboardDevicePreview extends StatelessWidget {
  const _DashboardDevicePreview({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inherited = MediaQuery.of(context);
    final scale = inherited.textScaler.scale(1).clamp(1.0, 2.0).toDouble();
    final previewSide = 248 + ((scale - 1) * 68);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: previewSide,
          maxHeight: previewSide,
        ),
        child: AspectRatio(aspectRatio: 1, child: child),
      ),
    );
  }
}

class _ConnectedHealthContent extends StatelessWidget {
  const _ConnectedHealthContent({
    required this.snapshot,
    required this.fitnessDevices,
    required this.languageCode,
    required this.compact,
    required this.dashboardCompact,
    required this.hiddenSignalKeys,
    required this.onManage,
    required this.onSync,
  });

  final ConnectedHealthSnapshot snapshot;
  final FitnessDeviceSnapshot fitnessDevices;
  final String languageCode;
  final bool compact;
  final bool dashboardCompact;
  final Set<String> hiddenSignalKeys;
  final VoidCallback onManage;
  final VoidCallback? onSync;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(languageCode, en, ar);

  bool get _hasConnectedSource =>
      snapshot.deviceVerified ||
      snapshot.signals.isNotEmpty ||
      snapshot.status == ConnectedHealthStatus.ready ||
      snapshot.status == ConnectedHealthStatus.syncing ||
      snapshot.status == ConnectedHealthStatus.synchronized ||
      (snapshot.status == ConnectedHealthStatus.degraded &&
          snapshot.lastSyncAt != null);

  @override
  Widget build(BuildContext context) {
    if (dashboardCompact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('dashboard-compact-health-hub'),
          onTap: onManage,
          borderRadius: BorderRadius.circular(28),
          child: _DashboardHealthDeviceSection(
            snapshot: snapshot,
            fitnessDevices: fitnessDevices,
            languageCode: languageCode,
            onSync: onSync,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Health Hub', 'المركز الصحي'),
                style: compact
                    ? Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )
                    : Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            ConnectedHealthStatusDot(status: snapshot.status),
          ],
        ),
        const SizedBox(height: PremiumDesignTokens.spaceXs),
        Text(
          tr(
            'Your verified health sources and smart-watch readings in one place.',
            'مصادرك الصحية الموثقة وقراءة الساعة الذكية في مكان واحد.',
          ),
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: compact ? Theme.of(context).textTheme.bodySmall : null,
        ),
        SizedBox(
          height: compact
              ? PremiumDesignTokens.spaceSm
              : PremiumDesignTokens.spaceMd,
        ),
        if (!_hasConnectedSource)
          HealthHubEmptyState(
            snapshot: snapshot,
            languageCode: languageCode,
            compact: compact,
            onConnect: onManage,
          )
        else ...[
          DashboardCarousel(
            key: const Key('health-hub-device-carousel'),
            height: MediaQuery.textScalerOf(context)
                .scale(compact ? 280 : 218)
                .clamp(compact ? 280.0 : 218.0, compact ? 300.0 : 280.0),
            viewportFraction: .88,
            compactControls: compact,
            semanticLabel: tr('Health Hub', 'المركز الصحي'),
            pages: _buildPages(context),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: PremiumDesignTokens.spaceXs,
            runSpacing: PremiumDesignTokens.spaceXs,
            children: [
              if (snapshot.status == ConnectedHealthStatus.ready ||
                  snapshot.status == ConnectedHealthStatus.synchronized ||
                  snapshot.status == ConnectedHealthStatus.degraded)
                OutlinedButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(tr('Sync now', 'تحديث الساعة')),
                ),
              FilledButton.tonalIcon(
                onPressed: onManage,
                icon: const Icon(Icons.tune_rounded),
                label: Text(tr('Manage sources', 'إدارة المصادر')),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _buildPages(BuildContext context) {
    final pages = <Widget>[
      HealthSlide(
        title: tr('Smart-watch reading', 'قراءة الساعة الذكية'),
        result: _statusLabel(snapshot.status),
        explanation: _statusExplanation(snapshot.status),
        footer: _displaySource(snapshot.platformSource),
        icon: Icons.watch_outlined,
      ),
      HealthSlide(
        title: tr('Latest synchronization', 'آخر مزامنة'),
        result: snapshot.lastSyncAt == null
            ? tr('Waiting for first sync', 'بانتظار أول مزامنة')
            : TimeOfDay.fromDateTime(snapshot.lastSyncAt!).format(context),
        explanation: ConnectedHealthRuntimeCopy.format(
          context,
          ConnectedHealthRuntimeCopy.importedRecords,
          count: MaterialLocalizations.of(
            context,
          ).formatDecimal(snapshot.importedCount),
        ),
        footer: snapshot.availableSources.isEmpty
            ? tr('No connected sources', 'لا توجد مصادر متصلة')
            : snapshot.availableSources.map(_displaySource).join(' • '),
        icon: Icons.sync_rounded,
      ),
    ];
    var premiumLabelAvailable = true;
    for (final signal
        in snapshot.signals
            .where(
              (signal) =>
                  !BilHealthScope.excludesKey(signal.key) &&
                  !hiddenSignalKeys.contains(signal.key),
            )
            .take(4)) {
      final nutritionSignal = signal.key.startsWith('nutrition');
      pages.add(
        _connectedSignalSlide(
          context,
          signal,
          showPremiumLabel: nutritionSignal && premiumLabelAvailable,
        ),
      );
      if (nutritionSignal) premiumLabelAvailable = false;
    }
    return pages;
  }

  Widget _connectedSignalSlide(
    BuildContext context,
    ConnectedHealthSignalView signal, {
    required bool showPremiumLabel,
  }) {
    final slide = HealthSlide(
      title: connectedHealthDataTypeText(context, signal.key),
      result: '${_formatValue(signal.value)} ${signal.unit}',
      explanation: tr(
        'Measured health signal with ${(signal.confidence * 100).round()}% source confidence.',
        'إشارة صحية مقاسة بثقة مصدر ${(signal.confidence * 100).round()}٪.',
      ),
      footer: _displaySource(signal.source),
      icon: _signalIcon(signal.key),
    );
    if (!signal.key.startsWith('nutrition')) return slide;
    return PremiumNutritionGlass(
      key: Key('connected-health-${signal.key}-premium-glass'),
      showLabel: showPremiumLabel,
      child: slide,
    );
  }

  String _displaySource(String? source) {
    if (source == null || source.trim().isEmpty) {
      return tr('Health source', 'مصدر صحي');
    }
    final normalized = source.toLowerCase();
    if (normalized.contains('apple') || normalized.contains('healthkit')) {
      return ' Health';
    }
    if (normalized.contains('health connect')) return 'Health Connect';
    return source;
  }

  String _statusLabel(ConnectedHealthStatus status) => switch (status) {
    ConnectedHealthStatus.unavailable => tr('Not connected', 'غير متصل'),
    ConnectedHealthStatus.updateRequired => tr('Update required', 'يلزم تحديث'),
    ConnectedHealthStatus.permissionRequired => tr('Not connected', 'غير متصل'),
    ConnectedHealthStatus.permissionDenied => tr(
      'Permission denied',
      'الإذن مرفوض',
    ),
    ConnectedHealthStatus.authorizationRequested => tr(
      'Access requested',
      'تم طلب الوصول',
    ),
    ConnectedHealthStatus.ready => tr('Ready', 'جاهز'),
    ConnectedHealthStatus.syncing => tr('Synchronizing', 'تتم المزامنة'),
    ConnectedHealthStatus.synchronized => tr(
      'Health source connected',
      'مصدر الصحة متصل',
    ),
    ConnectedHealthStatus.degraded => tr('Needs attention', 'يحتاج مراجعة'),
  };

  String _statusExplanation(ConnectedHealthStatus status) => switch (status) {
    ConnectedHealthStatus.unavailable => tr(
      'Connect a supported iOS or Android health source to begin.',
      'اربط مصدرًا صحيًا مدعومًا على iOS أو Android للبدء.',
    ),
    ConnectedHealthStatus.updateRequired => tr(
      'Install or update the platform health provider before connecting.',
      'ثبّت مصدر الصحة الخاص بالمنصة أو حدّثه قبل الاتصال.',
    ),
    ConnectedHealthStatus.permissionRequired => tr(
      'Health permission is required before BIL can read measured signals.',
      'يلزم منح إذن الصحة قبل أن يتمكن BIL من قراءة الإشارات المقاسة.',
    ),
    ConnectedHealthStatus.permissionDenied => tr(
      'No health data is read. Access can be granted later in system settings.',
      'لا تتم قراءة أي بيانات صحية. يمكن منح الإذن لاحقًا من إعدادات النظام.',
    ),
    ConnectedHealthStatus.authorizationRequested => tr(
      'Apple does not disclose read permission status. Only records Health provides will appear.',
      'لا تكشف Apple حالة إذن القراءة. لن تظهر إلا السجلات التي يوفرها تطبيق الصحة.',
    ),
    ConnectedHealthStatus.ready => tr(
      'The permission request completed. Only records the system actually provides will appear.',
      'اكتمل طلب الإذن. لن تظهر إلا السجلات التي يوفرها النظام فعليًا.',
    ),
    ConnectedHealthStatus.syncing => tr(
      'BIL is reading permitted changes without uploading them.',
      'يقرأ BIL التغييرات المسموح بها دون رفعها.',
    ),
    ConnectedHealthStatus.synchronized => tr(
      'The latest permitted signals are available to BIL locally.',
      'أحدث الإشارات المسموح بها متاحة محليًا لـBIL.',
    ),
    ConnectedHealthStatus.degraded => tr(
      'The native health source could not be reached. Existing local data remains intact.',
      'تعذر الوصول إلى مصدر الصحة الأصلي. تبقى البيانات المحلية الحالية سليمة.',
    ),
  };

  IconData _signalIcon(String key) => switch (key) {
    'steps' => Icons.directions_walk_rounded,
    'distance' => Icons.route_outlined,
    'sleep' => Icons.bedtime_outlined,
    'heartRate' || 'restingHeartRate' => Icons.favorite_outline_rounded,
    'activeEnergy' => Icons.local_fire_department_outlined,
    'weight' => Icons.monitor_weight_outlined,
    'bodyFat' || 'leanMass' => Icons.accessibility_new_rounded,
    'hrv' => Icons.monitor_heart_outlined,
    'water' => Icons.water_drop_outlined,
    'nutrition' ||
    'nutritionProtein' ||
    'nutritionCarbohydrates' ||
    'nutritionFat' ||
    'nutritionFiber' ||
    'nutritionSugar' ||
    'nutritionSodium' ||
    'nutritionPotassium' => Icons.restaurant_outlined,
    _ => Icons.monitor_heart_outlined,
  };

  String _formatValue(double value) => value.abs() >= 100
      ? value.round().toString()
      : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}

class _DashboardHealthDeviceSection extends StatelessWidget {
  const _DashboardHealthDeviceSection({
    required this.snapshot,
    required this.fitnessDevices,
    required this.languageCode,
    required this.onSync,
  });

  final ConnectedHealthSnapshot snapshot;
  final FitnessDeviceSnapshot fitnessDevices;
  final String languageCode;
  final VoidCallback? onSync;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(languageCode, en, ar);

  @override
  Widget build(BuildContext context) {
    final watchSnapshot = dashboardWatchSnapshot(snapshot, fitnessDevices);
    final hasMeasuredData =
        liveHealthWatchCanShowMetrics(watchSnapshot) &&
        <ConnectedHealthSignalView>[
          ...watchSnapshot.signals,
          ...watchSnapshot.stepHistory,
        ].any(liveHealthWatchSignalIsActual);
    final showLastSync =
        liveHealthWatchCanShowMetrics(watchSnapshot) &&
        watchSnapshot.lastSyncAt != null;
    final hasData = hasMeasuredData || showLastSync;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Fitness snapshot', 'ملخص اللياقة'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            ConnectedHealthStatusDot(status: watchSnapshot.status),
          ],
        ),
        const SizedBox(height: 10),
        _DashboardDevicePreview(
          key: const Key('dashboard-live-fitness-watch-slot'),
          child: LiveHealthWatch(
            snapshot: watchSnapshot,
            languageCode: languageCode,
            compact: true,
            showConnectControl: false,
            showMetrics: true,
            onStepsTap: () => context.push('/connected-health/steps'),
            onHeartTap: () => context.push('/connected-health/heart'),
            onActiveEnergyTap: () =>
                context.push('/settings/exercise-calories'),
            onSleepTap: () => context.push('/wellness/sleep'),
          ),
        ),
        if (hasData) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (watchSnapshot.lastSyncAt case final syncedAt?)
                if (showLastSync)
                  _DashboardSyncReading(
                    syncedAt: syncedAt,
                    languageCode: languageCode,
                    onSync: onSync,
                    syncing: snapshot.isBusy,
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DashboardSyncReading extends StatelessWidget {
  const _DashboardSyncReading({
    required this.syncedAt,
    required this.languageCode,
    required this.onSync,
    required this.syncing,
  });

  final DateTime syncedAt;
  final String languageCode;
  final VoidCallback? onSync;
  final bool syncing;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('dashboard-fitness-last-sync'),
    // Consume taps while busy too: they must not reach the parent card's
    // navigation gesture. The controller also coalesces repeated requests.
    onPressed: onSync ?? () {},
    icon: syncing
        ? const SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.sync_rounded, size: 17),
    label: Text(
      syncing
          ? connectedHealthTextForLanguage(
              languageCode,
              'Synchronizing…',
              'تتم المزامنة…',
            )
          : '${connectedHealthTextForLanguage(languageCode, 'Last sync', 'آخر مزامنة')}  ${TimeOfDay.fromDateTime(syncedAt.toLocal()).format(context)}',
      textAlign: TextAlign.center,
    ),
  );
}
