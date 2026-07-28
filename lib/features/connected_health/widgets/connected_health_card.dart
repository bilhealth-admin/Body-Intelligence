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
      label: tr('Health Hub', 'المركز الصحي'),
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

  bool get _hasConnectedSource =>
      snapshot.availableSources.isNotEmpty ||
      snapshot.signals.isNotEmpty ||
      snapshot.status == ConnectedHealthStatus.ready ||
      snapshot.status == ConnectedHealthStatus.syncing ||
      snapshot.status == ConnectedHealthStatus.synchronized ||
      snapshot.status == ConnectedHealthStatus.degraded;

  @override
  Widget build(BuildContext context) {
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
          _HealthHubEmptyState(
            arabic: arabic,
            compact: compact,
            onConnect: onManage,
          )
        else ...[
          DashboardCarousel(
            key: const Key('connected-health-carousel'),
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
    _HealthSlide(
      title: tr('Smart-watch reading', 'قراءة الساعة الذكية'),
      result: _statusLabel(snapshot.status),
      explanation: _statusExplanation(snapshot.status),
      footer: _displaySource(snapshot.platformSource),
      icon: Icons.watch_outlined,
    ),
    _HealthSlide(
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
    for (final signal in snapshot.signals.take(4))
      _HealthSlide(
        title: _signalTitle(signal.key),
        result: '${_formatValue(signal.value)} ${signal.unit}',
        explanation: tr(
          'Measured health signal with ${(signal.confidence * 100).round()}% source confidence.',
          'إشارة صحية مقاسة بثقة مصدر ${(signal.confidence * 100).round()}٪.',
        ),
        footer: _displaySource(signal.source),
        icon: _signalIcon(signal.key),
      ),
  ];

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
    ConnectedHealthStatus.permissionRequired => tr('Not connected', 'غير متصل'),
    ConnectedHealthStatus.ready => tr('Ready', 'جاهز'),
    ConnectedHealthStatus.syncing => tr('Synchronizing', 'تتم المزامنة'),
    ConnectedHealthStatus.synchronized => tr('Connected', 'متصل'),
    ConnectedHealthStatus.degraded => tr('Needs attention', 'يحتاج مراجعة'),
  };

  String _statusExplanation(ConnectedHealthStatus status) => switch (status) {
    ConnectedHealthStatus.unavailable => tr(
      'Connect a supported iOS or Android health source to begin.',
      'اربط مصدرًا صحيًا مدعومًا على iOS أو Android للبدء.',
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
    'heartRate' => tr('Heart rate', 'معدل القلب'),
    'restingHeartRate' => tr('Resting heart rate', 'نبض الراحة'),
    'activeEnergy' => tr('Active energy', 'الطاقة النشطة'),
    'oxygen' => tr('Blood oxygen', 'أكسجين الدم'),
    'weight' => tr('Weight', 'الوزن'),
    'glucose' => tr('Glucose', 'السكر'),
    'bloodPressureSystolic' => tr('Blood pressure', 'ضغط الدم'),
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

class _HealthHubEmptyState extends StatelessWidget {
  const _HealthHubEmptyState({
    required this.arabic,
    required this.compact,
    required this.onConnect,
  });

  final bool arabic;
  final bool compact;
  final VoidCallback onConnect;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('health-hub-empty-state'),
      constraints: BoxConstraints(minHeight: compact ? 300 : 250),
      padding: EdgeInsets.all(
        compact ? PremiumDesignTokens.spaceSm : PremiumDesignTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .11),
            scheme.primary.withValues(alpha: .06),
            Colors.white.withValues(alpha: .035),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .15)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = !compact && constraints.maxWidth >= 760;
          final illustration = SizedBox(
            width: horizontal ? 300 : double.infinity,
            height: compact ? 138 : 168,
            child: const _HealthHubIllustration(),
          );
          final message = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: horizontal
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                tr(
                  'No health source is connected yet',
                  'لم يتم ربط أي مصدر صحي بعد',
                ),
                textAlign: horizontal ? TextAlign.start : TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceXs),
              Text(
                tr(
                  'Connect your smart watch,  Health, or Health Connect so BIL can build a more complete health picture.',
                  'اربط ساعتك الذكية أو  Health أو Health Connect ليبني BIL صورة صحية أكثر اكتمالًا.',
                ),
                textAlign: horizontal ? TextAlign.start : TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              FilledButton.icon(
                key: const Key('health-hub-connect-button'),
                onPressed: onConnect,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(tr('Connect', 'اتصال')),
              ),
            ],
          );

          if (!horizontal) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                illustration,
                const SizedBox(height: PremiumDesignTokens.spaceSm),
                message,
              ],
            );
          }
          return Row(
            children: [
              illustration,
              const SizedBox(width: PremiumDesignTokens.spaceLg),
              Expanded(child: message),
            ],
          );
        },
      ),
    );
  }
}

class _HealthHubIllustration extends StatelessWidget {
  const _HealthHubIllustration();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 126,
          height: 126,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: .10),
            border: Border.all(color: scheme.primary.withValues(alpha: .24)),
          ),
        ),
        Container(
          width: 78,
          height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: scheme.surface.withValues(alpha: .82),
            border: Border.all(
              color: scheme.primary.withValues(alpha: .54),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .18),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_rounded, color: scheme.error, size: 28),
              const SizedBox(height: 6),
              SizedBox(
                width: 48,
                height: 18,
                child: CustomPaint(
                  painter: _PulseLinePainter(color: scheme.primary),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 2,
          bottom: 8,
          child: _SourceChip(
            label: ' Health',
            icon: Icons.favorite_outline_rounded,
          ),
        ),
        Positioned(
          right: 0,
          top: 8,
          child: _SourceChip(label: 'Health Connect', icon: Icons.hub_outlined),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PulseLinePainter extends CustomPainter {
  const _PulseLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * .58)
      ..lineTo(size.width * .20, size.height * .58)
      ..lineTo(size.width * .31, size.height * .30)
      ..lineTo(size.width * .43, size.height * .82)
      ..lineTo(size.width * .57, size.height * .12)
      ..lineTo(size.width * .68, size.height * .58)
      ..lineTo(size.width, size.height * .58);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseLinePainter oldDelegate) =>
      oldDelegate.color != color;
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
        arabic ? 'المركز الصحي' : 'Health Hub',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: PremiumDesignTokens.spaceSm),
      Text(
        arabic
            ? 'تعذر قراءة حالة المركز الصحي. لم تُحذف أو تُرفع أي بيانات.'
            : 'Health Hub status could not be read. No data was deleted or uploaded.',
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
