import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../dashboard/widgets/dashboard_carousel.dart';
import '../../dashboard/widgets/premium_dashboard_card_lock.dart';
import '../../global_platform/health_data/unified_health_data_integration.dart';
import '../connected_health_model.dart';
import '../connected_health_copy.dart';
import '../providers/connected_health_provider.dart';
import '../providers/medical_device_provider.dart';
import 'connected_health_primitives.dart';
import 'health_device_pager.dart';
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
    final verifiedPlan = ref
        .watch(verifiedSubscriptionStateProvider)
        .value
        ?.plan;
    final medicalDevicesUnlocked =
        verifiedPlan != null && verifiedPlan != CommercePlan.free;
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
            medicalDevicesUnlocked: medicalDevicesUnlocked,
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
        constraints: const BoxConstraints(maxWidth: 188, maxHeight: 188),
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
    required this.medicalDevicesUnlocked,
    required this.languageCode,
    required this.compact,
    required this.dashboardCompact,
    required this.onManage,
    required this.onSync,
  });

  final ConnectedHealthSnapshot snapshot;
  final MedicalDeviceSnapshot medical;
  final bool medicalDevicesUnlocked;
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
            medicalDevicesUnlocked: medicalDevicesUnlocked,
            languageCode: languageCode,
            onOpenPlans: () => context.push('/plans?focus=subscription'),
            onManage: onManage,
            watchStatus: _hasConnectedSource
                ? _statusLabel(snapshot.status)
                : tr(
                    'Live time · connect health to add measured data',
                    'الوقت مباشر · اربط الصحة لإضافة القياسات',
                  ),
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

class _DashboardHealthDeviceSection extends StatefulWidget {
  const _DashboardHealthDeviceSection({
    required this.snapshot,
    required this.medical,
    required this.medicalDevicesUnlocked,
    required this.languageCode,
    required this.onOpenPlans,
    required this.onManage,
    required this.watchStatus,
  });

  final ConnectedHealthSnapshot snapshot;
  final MedicalDeviceSnapshot medical;
  final bool medicalDevicesUnlocked;
  final String languageCode;
  final VoidCallback onOpenPlans;
  final VoidCallback onManage;
  final String watchStatus;

  @override
  State<_DashboardHealthDeviceSection> createState() =>
      _DashboardHealthDeviceSectionState();
}

class _DashboardHealthDeviceSectionState
    extends State<_DashboardHealthDeviceSection> {
  int _page = 0;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(widget.languageCode, en, ar);

  String get _medicalStatus => switch (widget.medical.status) {
    MedicalDeviceConnectionStatus.connected => tr('Connected', 'متصل'),
    MedicalDeviceConnectionStatus.requestingPermission => tr(
      'Waiting for Bluetooth permission…',
      'بانتظار إذن البلوتوث…',
    ),
    MedicalDeviceConnectionStatus.scanning => tr(
      'Searching nearby…',
      'جارٍ البحث عن الأجهزة القريبة…',
    ),
    MedicalDeviceConnectionStatus.connecting => tr(
      'Connecting securely…',
      'جارٍ الاتصال الآمن…',
    ),
    MedicalDeviceConnectionStatus.failed => tr(
      'Needs attention',
      'يحتاج مراجعة',
    ),
    MedicalDeviceConnectionStatus.unavailable ||
    MedicalDeviceConnectionStatus.idle => tr('Not connected', 'غير متصل'),
  };

  @override
  Widget build(BuildContext context) {
    final showingMedical = _page == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                showingMedical
                    ? tr(
                        'Compatible fitness devices',
                        'أجهزة اللياقة المتوافقة',
                      )
                    : tr('Smart-watch reading', 'قراءة الساعة الذكية'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (showingMedical)
              Container(
                key: const Key('dashboard-medical-status-dot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      widget.medical.status ==
                          MedicalDeviceConnectionStatus.connected
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF9CA3AF),
                ),
              )
            else
              ConnectedHealthStatusDot(status: widget.snapshot.status),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 21),
          ],
        ),
        const SizedBox(height: 8),
        HealthDevicePager(
          key: const Key('dashboard-health-device-pager'),
          height: 188,
          onPageChanged: (value) => setState(() => _page = value),
          pages: [
            _DashboardDevicePreview(
              key: const Key('dashboard-live-health-watch-slot'),
              child: LiveHealthWatch(
                snapshot: widget.snapshot,
                languageCode: widget.languageCode,
                compact: true,
                onConnectTap: widget.onManage,
                onStepsTap: () => context.push('/connected-health/steps'),
                onHeartTap: () => context.push('/connected-health/heart'),
                onActiveEnergyTap: () =>
                    context.push('/settings/exercise-calories'),
                onSleepTap: () => context.push('/wellness/sleep'),
              ),
            ),
            _DashboardDevicePreview(
              key: const Key('dashboard-medical-device-slot'),
              child: PremiumDashboardCardLock(
                key: const Key('dashboard-medical-device-preview'),
                locked: !widget.medicalDevicesUnlocked,
                title: tr(
                  'Premium fitness device connections',
                  'اتصال أجهزة اللياقة ضمن Premium',
                ),
                detail: tr(
                  'Weight, body composition, and heart rate',
                  'الوزن وتركيب الجسم ومعدل ضربات القلب',
                ),
                onTap: widget.onOpenPlans,
                revealPreview: true,
                child: BilMedicalMonitor(
                  snapshot: widget.medical,
                  languageCode: widget.languageCode,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          showingMedical ? _medicalStatus : widget.watchStatus,
          key: ValueKey(
            showingMedical
                ? 'dashboard-medical-status-label'
                : 'dashboard-watch-status-label',
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
