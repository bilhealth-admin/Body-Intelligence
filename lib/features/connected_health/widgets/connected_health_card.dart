import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import '../../dashboard/widgets/dashboard_carousel.dart';
import '../../global_platform/health_data/unified_health_data_integration.dart';
import '../../global_platform/medical_devices/ble_medical_device_platform.dart';
import '../connected_health_model.dart';
import '../connected_health_copy.dart';
import '../providers/connected_health_provider.dart';
import '../providers/medical_device_provider.dart';
import 'connected_health_primitives.dart';
import 'health_hub_empty_state.dart';
import 'live_health_watch.dart';

class ConnectedHealthCard extends ConsumerWidget {
  const ConnectedHealthCard({
    super.key,
    required this.languageCode,
    this.compact = false,
    this.dashboardCompact = false,
  });

  final String languageCode;
  final bool compact;
  final bool dashboardCompact;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(languageCode, en, ar);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectedHealthProvider);
    final medical = ref.watch(medicalDeviceProvider);
    return Semantics(
      container: true,
      label: tr('Health Hub', 'المركز الصحي'),
      child: PremiumSurface(
        key: const Key('connected-health-card'),
        dashboardGlass: true,
        padding: compact
            ? const EdgeInsets.all(PremiumDesignTokens.spaceSm)
            : PremiumDesignTokens.cardPaddingLarge,
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ConnectedHealthErrorContent(
            languageCode: languageCode,
            onRetry: () => ref.read(connectedHealthProvider.notifier).refresh(),
          ),
          data: (snapshot) => _ConnectedHealthContent(
            snapshot: snapshot,
            medical: medical,
            languageCode: languageCode,
            compact: compact,
            dashboardCompact: dashboardCompact,
            onManage: () => context.push('/connected-health'),
            onSync: snapshot.status == ConnectedHealthStatus.syncing
                ? null
                : () =>
                      ref.read(connectedHealthProvider.notifier).synchronize(),
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
    final scale = inherited.textScaler.scale(1).clamp(1.0, 1.15).toDouble();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 212, maxHeight: 212),
        child: AspectRatio(
          aspectRatio: 1,
          child: MediaQuery(
            data: inherited.copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ConnectedHealthContent extends StatelessWidget {
  const _ConnectedHealthContent({
    required this.snapshot,
    required this.medical,
    required this.languageCode,
    required this.compact,
    required this.dashboardCompact,
    required this.onManage,
    required this.onSync,
  });

  final ConnectedHealthSnapshot snapshot;
  final MedicalDeviceSnapshot medical;
  final String languageCode;
  final bool compact;
  final bool dashboardCompact;
  final VoidCallback onManage;
  final VoidCallback? onSync;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(languageCode, en, ar);

  bool get _hasConnectedSource =>
      snapshot.availableSources.isNotEmpty ||
      snapshot.signals.isNotEmpty ||
      snapshot.status == ConnectedHealthStatus.ready ||
      snapshot.status == ConnectedHealthStatus.syncing ||
      snapshot.status == ConnectedHealthStatus.synchronized ||
      snapshot.status == ConnectedHealthStatus.degraded;

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
            medical: medical,
            languageCode: languageCode,
            onManage: onManage,
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
                  label: Text(tr('Sync now', 'مزامنة الآن')),
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

  List<Widget> _buildPages(BuildContext context) => <Widget>[
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
      explanation: tr(
        '${snapshot.importedCount} new records were imported during the last synchronization.',
        'تم استيراد ${snapshot.importedCount} سجلًا جديدًا خلال آخر مزامنة.',
      ),
      footer: snapshot.availableSources.isEmpty
          ? tr('No connected sources', 'لا توجد مصادر متصلة')
          : snapshot.availableSources.map(_displaySource).join(' • '),
      icon: Icons.sync_rounded,
    ),
    for (final signal
        in snapshot.signals
            .where((signal) => !BilHealthScope.excludesKey(signal.key))
            .take(4))
      _connectedSignalSlide(signal),
  ];

  Widget _connectedSignalSlide(ConnectedHealthSignalView signal) {
    final slide = HealthSlide(
      title: _signalTitle(signal.key),
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

  String _signalTitle(String key) => switch (key) {
    'steps' => tr('Steps', 'الخطوات'),
    'distance' => tr('Distance', 'المسافة'),
    'sleep' => tr('Sleep', 'النوم'),
    'heartRate' => tr('Heart rate', 'معدل القلب'),
    'restingHeartRate' => tr('Resting heart rate', 'نبض الراحة'),
    'activeEnergy' => tr('Active energy', 'الطاقة النشطة'),
    'weight' => tr('Weight', 'الوزن'),
    'bodyFat' => tr('Body fat', 'دهون الجسم'),
    'leanMass' => tr('Lean mass', 'الكتلة الخالية من الدهون'),
    'hrv' => tr('Heart-rate variability', 'تباين معدل القلب'),
    'water' => tr('Water', 'الماء'),
    'nutrition' => tr('Dietary energy', 'الطاقة الغذائية'),
    'nutritionProtein' => tr('Protein', 'البروتين'),
    'nutritionCarbohydrates' => tr('Carbohydrates', 'الكربوهيدرات'),
    'nutritionFat' => tr('Total fat', 'إجمالي الدهون'),
    'nutritionFiber' => tr('Fiber', 'الألياف'),
    'nutritionSugar' => tr('Sugar', 'السكر الغذائي'),
    'nutritionSodium' => tr('Sodium', 'الصوديوم'),
    'nutritionPotassium' => tr('Potassium', 'البوتاسيوم'),
    _ => key,
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
    required this.medical,
    required this.languageCode,
    required this.onManage,
  });

  final ConnectedHealthSnapshot snapshot;
  final MedicalDeviceSnapshot medical;
  final String languageCode;
  final VoidCallback onManage;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(languageCode, en, ar);

  List<({String kind, double value, String unit})> get _readings {
    final values = <String, ({String kind, double value, String unit})>{};
    for (final packet in medical.measurements) {
      final kind = packet['kind'] as String?;
      final value = packet['value'];
      final unit = packet['unit'] as String?;
      if (kind != null &&
          value is num &&
          unit != null &&
          bleFitnessMeasurementKinds.contains(kind)) {
        values.putIfAbsent(
          kind,
          () => (kind: kind, value: value.toDouble(), unit: unit),
        );
      }
    }
    for (final signal in snapshot.signals) {
      final kind = switch (signal.key) {
        'weight' => 'weight',
        'bodyFat' => 'body_fat',
        'heartRate' || 'restingHeartRate' => 'heart_rate',
        _ => null,
      };
      if (kind != null) {
        values.putIfAbsent(
          kind,
          () => (kind: kind, value: signal.value, unit: signal.unit),
        );
      }
    }
    return values.values.take(3).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    final hasData = readings.isNotEmpty || snapshot.lastSyncAt != null;
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
            ConnectedHealthStatusDot(status: snapshot.status),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 21),
          ],
        ),
        const SizedBox(height: 10),
        _DashboardDevicePreview(
          key: const Key('dashboard-live-fitness-watch-slot'),
          child: LiveHealthWatch(
            snapshot: snapshot,
            languageCode: languageCode,
            compact: true,
            showConnectControl: false,
            showMetrics: false,
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
              for (final reading in readings)
                _DashboardFitnessReading(
                  kind: reading.kind,
                  value: reading.value,
                  unit: reading.unit,
                  languageCode: languageCode,
                ),
              if (snapshot.lastSyncAt case final syncedAt?)
                _DashboardSyncReading(
                  syncedAt: syncedAt,
                  languageCode: languageCode,
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: hasData
              ? OutlinedButton.icon(
                  key: const Key('dashboard-fitness-link-action'),
                  onPressed: onManage,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(
                    tr('Manage fitness sources', 'إدارة مصادر اللياقة'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Semantics(
                  label: tr('Link a fitness source', 'ربط مصدر لياقة'),
                  button: true,
                  child: IconButton.outlined(
                    key: const Key('dashboard-fitness-link-action'),
                    onPressed: onManage,
                    tooltip: tr('Link fitness', 'ربط اللياقة'),
                    icon: const Icon(Icons.link_rounded),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DashboardFitnessReading extends StatelessWidget {
  const _DashboardFitnessReading({
    required this.kind,
    required this.value,
    required this.unit,
    required this.languageCode,
  });

  final String kind;
  final double value;
  final String unit;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      'weight' => connectedHealthTextForLanguage(
        languageCode,
        'Weight',
        'الوزن',
      ),
      'body_fat' => connectedHealthTextForLanguage(
        languageCode,
        'Body composition',
        'تركيب الجسم',
      ),
      'heart_rate' => connectedHealthTextForLanguage(
        languageCode,
        'Heart rate',
        'نبض القلب',
      ),
      _ => '',
    };
    final formatted = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return Chip(
      key: ValueKey('dashboard-fitness-reading-$kind'),
      avatar: Icon(switch (kind) {
        'weight' => Icons.monitor_weight_outlined,
        'body_fat' => Icons.accessibility_new_rounded,
        _ => Icons.favorite_outline_rounded,
      }, size: 17),
      label: Text('$label  $formatted $unit', textDirection: TextDirection.ltr),
    );
  }
}

class _DashboardSyncReading extends StatelessWidget {
  const _DashboardSyncReading({
    required this.syncedAt,
    required this.languageCode,
  });

  final DateTime syncedAt;
  final String languageCode;

  @override
  Widget build(BuildContext context) => Chip(
    key: const Key('dashboard-fitness-last-sync'),
    avatar: const Icon(Icons.sync_rounded, size: 17),
    label: Text(
      '${connectedHealthTextForLanguage(languageCode, 'Last sync', 'آخر مزامنة')}  ${TimeOfDay.fromDateTime(syncedAt).format(context)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
