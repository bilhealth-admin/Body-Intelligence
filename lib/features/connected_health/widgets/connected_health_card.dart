import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../../dashboard/widgets/dashboard_carousel.dart';
import '../connected_health_model.dart';
import '../providers/connected_health_provider.dart';

class ConnectedHealthCard extends ConsumerWidget {
  const ConnectedHealthCard({
    super.key,
    required this.arabic,
    this.compact = false,
  });

  final bool arabic;
  final bool compact;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectedHealthProvider);
    return Semantics(
      container: true,
      label: tr('Connected Health', 'الصحة المتصلة'),
      child: PremiumSurface(
        key: const Key('connected-health-card'),
        dashboardGlass: true,
        padding: compact
            ? const EdgeInsets.all(PremiumDesignTokens.spaceSm)
            : PremiumDesignTokens.cardPaddingLarge,
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ErrorContent(
            arabic: arabic,
            onRetry: () => ref.read(connectedHealthProvider.notifier).refresh(),
          ),
          data: (snapshot) => _ConnectedHealthContent(
            snapshot: snapshot,
            arabic: arabic,
            compact: compact,
            onManage: () => context.go('/connected-health'),
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

class _ConnectedHealthContent extends StatelessWidget {
  const _ConnectedHealthContent({
    required this.snapshot,
    required this.arabic,
    required this.compact,
    required this.onManage,
    required this.onSync,
  });

  final ConnectedHealthSnapshot snapshot;
  final bool arabic;
  final bool compact;
  final VoidCallback onManage;
  final VoidCallback? onSync;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HealthSlide(
        title: tr('Connection Status', 'حالة الاتصال'),
        result: _statusLabel(snapshot.status),
        explanation: _statusExplanation(snapshot.status),
        footer:
            snapshot.platformSource ??
            tr('No supported source', 'لا يوجد مصدر مدعوم'),
        icon: Icons.monitor_heart_outlined,
      ),
      _HealthSlide(
        title: tr('Latest Synchronization', 'آخر مزامنة'),
        result: snapshot.lastSyncAt == null
            ? tr('Not synchronized yet', 'لم تتم المزامنة بعد')
            : TimeOfDay.fromDateTime(snapshot.lastSyncAt!).format(context),
        explanation: tr(
          '${snapshot.importedCount} new records were imported during the last synchronization.',
          'تم استيراد ${snapshot.importedCount} سجلًا جديدًا خلال آخر مزامنة.',
        ),
        footer: snapshot.availableSources.isEmpty
            ? tr('No connected sources', 'لا توجد مصادر متصلة')
            : snapshot.availableSources.join(' • '),
        icon: Icons.sync_rounded,
      ),
      for (final signal in snapshot.signals.take(4))
        _HealthSlide(
          title: _signalTitle(signal.key),
          result: '${_formatValue(signal.value)} ${signal.unit}',
          explanation: tr(
            'Measured health signal with ${(signal.confidence * 100).round()}% source confidence.',
            'إشارة صحية مقاسة بثقة مصدر ${(signal.confidence * 100).round()}٪.',
          ),
          footer: signal.source,
          icon: _signalIcon(signal.key),
        ),
      if (snapshot.signals.isEmpty)
        _HealthSlide(
          title: tr('Health Signals', 'الإشارات الصحية'),
          result: tr('No synchronized values yet', 'لا توجد قيم متزامنة بعد'),
          explanation: tr(
            'Grant access and synchronize to show recent measured signals here.',
            'امنح الإذن ثم نفّذ المزامنة لعرض أحدث الإشارات المقاسة هنا.',
          ),
          footer: snapshot.platformSource ?? tr('Unavailable', 'غير متاح'),
          icon: Icons.insights_outlined,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Connected Health', 'الصحة المتصلة'),
                style: compact
                    ? Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      )
                    : Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            _StatusDot(status: snapshot.status),
          ],
        ),
        const SizedBox(height: PremiumDesignTokens.spaceXs),
        Text(
          tr(
            'Your verified health sources and their latest measured signals.',
            'مصادرك الصحية الموثقة وأحدث الإشارات المقاسة منها.',
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
        DashboardCarousel(
          key: const Key('connected-health-carousel'),
          height: MediaQuery.textScalerOf(context)
              .scale(compact ? 280 : 218)
              .clamp(compact ? 280.0 : 218.0, compact ? 300.0 : 280.0),
          viewportFraction: .88,
          compactControls: compact,
          semanticLabel: tr('Connected Health', 'الصحة المتصلة'),
          pages: pages,
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
              label: Text(tr('Manage Connected Health', 'إدارة الصحة المتصلة')),
            ),
          ],
        ),
      ],
    );
  }

  String _statusLabel(ConnectedHealthStatus status) => switch (status) {
    ConnectedHealthStatus.unavailable => tr('Unavailable', 'غير متاح'),
    ConnectedHealthStatus.permissionRequired => tr(
      'Permission required',
      'يحتاج إذنًا',
    ),
    ConnectedHealthStatus.ready => tr('Ready', 'جاهز'),
    ConnectedHealthStatus.syncing => tr('Synchronizing', 'تتم المزامنة'),
    ConnectedHealthStatus.synchronized => tr('Connected', 'متصل'),
    ConnectedHealthStatus.degraded => tr('Needs attention', 'يحتاج مراجعة'),
  };

  String _statusExplanation(ConnectedHealthStatus status) => switch (status) {
    ConnectedHealthStatus.unavailable => tr(
      'Connected Health is available on supported iOS and Android devices.',
      'الصحة المتصلة متاحة على أجهزة iOS وAndroid المدعومة.',
    ),
    ConnectedHealthStatus.permissionRequired => tr(
      'Health permission is required before BIL can read measured signals.',
      'يلزم منح إذن الصحة قبل أن يتمكن BIL من قراءة الإشارات المقاسة.',
    ),
    ConnectedHealthStatus.ready => tr(
      'The source is authorized and ready for a local synchronization.',
      'المصدر مصرح له وجاهز للمزامنة المحلية.',
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
    'sleep' => tr('Sleep', 'النوم'),
    'heartRate' => tr('Heart Rate', 'معدل القلب'),
    'restingHeartRate' => tr('Resting Heart Rate', 'نبض الراحة'),
    'activeEnergy' => tr('Active Energy', 'الطاقة النشطة'),
    'oxygen' => tr('Blood Oxygen', 'أكسجين الدم'),
    'weight' => tr('Weight', 'الوزن'),
    'glucose' => tr('Glucose', 'السكر'),
    'bloodPressureSystolic' => tr('Blood Pressure', 'ضغط الدم'),
    _ => key,
  };

  IconData _signalIcon(String key) => switch (key) {
    'steps' => Icons.directions_walk_rounded,
    'sleep' => Icons.bedtime_outlined,
    'heartRate' || 'restingHeartRate' => Icons.favorite_outline_rounded,
    'activeEnergy' => Icons.local_fire_department_outlined,
    'oxygen' => Icons.air_rounded,
    'weight' => Icons.monitor_weight_outlined,
    'glucose' => Icons.bloodtype_outlined,
    'bloodPressureSystolic' => Icons.speed_rounded,
    _ => Icons.monitor_heart_outlined,
  };

  String _formatValue(double value) => value.abs() >= 100
      ? value.round().toString()
      : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}

class _HealthSlide extends StatelessWidget {
  const _HealthSlide({
    required this.title,
    required this.result,
    required this.explanation,
    required this.footer,
    required this.icon,
  });

  final String title;
  final String result;
  final String explanation;
  final String footer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .105),
            const Color(0xFF5BDAFF).withValues(alpha: .045),
            Colors.white.withValues(alpha: .035),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(
          compact ? PremiumDesignTokens.spaceXs : PremiumDesignTokens.spaceSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: PremiumDesignTokens.spaceXs),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 3 : 5),
            Text(
              result,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: compact
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )
                  : Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: compact ? 3 : 6),
            Expanded(
              child: Text(
                explanation,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            SizedBox(height: compact ? 3 : 6),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final ConnectedHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectedHealthStatus.ready ||
      ConnectedHealthStatus.synchronized => Colors.greenAccent,
      ConnectedHealthStatus.permissionRequired ||
      ConnectedHealthStatus.syncing => Colors.amberAccent,
      ConnectedHealthStatus.degraded => Colors.orangeAccent,
      ConnectedHealthStatus.unavailable => Colors.grey,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.arabic, required this.onRetry});
  final bool arabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        arabic ? 'الصحة المتصلة' : 'Connected Health',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: PremiumDesignTokens.spaceSm),
      Text(
        arabic
            ? 'تعذر قراءة حالة الصحة المتصلة. لم تُحذف أو تُرفع أي بيانات.'
            : 'Connected Health status could not be read. No data was deleted or uploaded.',
      ),
      const SizedBox(height: PremiumDesignTokens.spaceSm),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(arabic ? 'إعادة المحاولة' : 'Try again'),
        ),
      ),
    ],
  );
}
