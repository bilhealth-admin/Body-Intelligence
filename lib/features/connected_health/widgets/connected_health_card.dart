import 'dart:async';
import 'dart:math' as math;

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
            snapshot: snapshot,
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
    required this.snapshot,
    required this.arabic,
    required this.compact,
    required this.onConnect,
  });

  final ConnectedHealthSnapshot snapshot;
  final bool arabic;
  final bool compact;
  final VoidCallback onConnect;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final watchSize = compact ? 300.0 : 330.0;
    final shellHeight = compact ? 438.0 : 390.0;
    return SizedBox(
      key: const Key('health-hub-empty-state'),
      height: shellHeight,
      child: Container(
        padding: EdgeInsets.all(
          compact ? PremiumDesignTokens.spaceSm : PremiumDesignTokens.spaceLg,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .36),
              const Color(0xFFDDEEFF).withValues(alpha: .30),
              Colors.white.withValues(alpha: .14),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: .72),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF76B8E8).withValues(alpha: .12),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = !compact && constraints.maxWidth >= 760;
            final illustration = Center(
              child: SizedBox.square(
                key: const Key('health-hub-fixed-square-watch'),
                dimension: watchSize,
                child: _LiveHealthWatch(snapshot: snapshot, arabic: arabic),
              ),
            );
            final connectButton = FilledButton.icon(
              key: const Key('health-hub-connect-button'),
              onPressed: onConnect,
              icon: const Icon(Icons.link_rounded),
              label: Text(tr('Connect now', 'ربط الآن')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(250, 58),
                backgroundColor: Colors.white.withValues(alpha: .34),
                foregroundColor: const Color(0xFF0A3153),
                elevation: 0,
                side: BorderSide(color: Colors.white.withValues(alpha: .86)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                textStyle: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            );

            if (!horizontal) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  illustration,
                  const SizedBox(height: PremiumDesignTokens.spaceMd),
                  connectButton,
                ],
              );
            }
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(dimension: watchSize, child: illustration),
                  const SizedBox(width: PremiumDesignTokens.spaceXl),
                  SizedBox(width: 330, child: connectButton),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiveHealthWatch extends StatefulWidget {
  const _LiveHealthWatch({required this.snapshot, required this.arabic});

  final ConnectedHealthSnapshot snapshot;
  final bool arabic;

  @override
  State<_LiveHealthWatch> createState() => _LiveHealthWatchState();
}

class _LiveHealthWatchState extends State<_LiveHealthWatch> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  ConnectedHealthSignalView? _signal(String key) {
    for (final signal in widget.snapshot.signals) {
      if (signal.key == key) return signal;
    }
    return null;
  }

  String _value(String key, {int decimals = 0}) {
    final signal = _signal(key);
    if (signal == null) return '—';
    return decimals == 0
        ? signal.value.round().toString()
        : signal.value.toStringAsFixed(decimals);
  }

  String get _weekday {
    const ar = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return widget.arabic ? ar[_now.weekday - 1] : en[_now.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour % 12;
    final minute = _now.minute;
    final second = _now.second;
    return Semantics(
      image: true,
      label: widget.arabic
          ? 'ساعة صحية حية تعرض الوقت والبيانات الصحية الحقيقية المتاحة'
          : 'Live health watch showing current time and available measured data',
      child: SizedBox.expand(
        child: CustomPaint(
          key: const Key('bil-live-health-watch'),
          painter: _WatchPainter(hour: hour, minute: minute, second: second),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 24,
                top: 42,
                width: 82,
                child: _WatchMetric(
                  icon: Icons.directions_walk_rounded,
                  color: const Color(0xFF55D66B),
                  value: _value('steps'),
                  label: widget.arabic ? 'خطوة' : 'steps',
                ),
              ),
              Positioned(
                right: 24,
                top: 42,
                width: 90,
                child: _WatchMetric(
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFFF5B68),
                  value: _value('heartRate'),
                  label: widget.arabic ? 'نبضة/دقيقة' : 'bpm',
                ),
              ),
              Positioned(
                left: 24,
                bottom: 48,
                width: 82,
                child: _WatchMetric(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF7C43),
                  value: _value('activeEnergy'),
                  label: widget.arabic ? 'سعرة' : 'kcal',
                ),
              ),
              Positioned(
                right: 24,
                bottom: 48,
                width: 82,
                child: _WatchMetric(
                  icon: Icons.bedtime_rounded,
                  color: const Color(0xFFA56BFF),
                  value: _value('sleep', decimals: 1),
                  label: widget.arabic ? 'ساعة نوم' : 'sleep',
                ),
              ),
              Positioned(
                left: 112,
                right: 112,
                top: 30,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _weekday,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFEAF7FF),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.arabic ? '${_now.day} يوليو' : 'July ${_now.day}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFCFE8F7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _WatchMetric extends StatelessWidget {
  const _WatchMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        Text(
          value,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: const Color(0xFFD9EAF4)),
        ),
      ],
    );
  }
}

class _WatchPainter extends CustomPainter {
  const _WatchPainter({
    required this.hour,
    required this.minute,
    required this.second,
  });

  final int hour;
  final int minute;
  final int second;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final unit = size.shortestSide;

    final caseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        unit * .025,
        unit * .025,
        size.width - unit * .075,
        size.height - unit * .05,
      ),
      Radius.circular(unit * .22),
    );

    canvas.drawRRect(
      caseRect.shift(Offset(0, unit * .018)),
      Paint()
        ..color = Colors.black.withValues(alpha: .30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .035),
    );

    canvas.drawRRect(
      caseRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D3439),
            Color(0xFF9CA5AB),
            Color(0xFFF4F6F7),
            Color(0xFF737E84),
            Color(0xFFFFFFFF),
            Color(0xFF5B666C),
            Color(0xFFBBC2C6),
            Color(0xFF30383D),
          ],
          stops: [0, .12, .25, .40, .52, .67, .82, 1],
        ).createShader(rect),
    );

    canvas.drawRRect(
      caseRect.deflate(unit * .012),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * .010
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFF7D878D), Color(0xFF20272B)],
        ).createShader(rect),
    );

    final bezel = caseRect.deflate(unit * .050);
    canvas.drawRRect(
      bezel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10171C), Color(0xFF515C63), Color(0xFF0B1115)],
          stops: [0, .48, 1],
        ).createShader(rect),
    );

    final screen = bezel.deflate(unit * .024);
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.20, -.35),
          radius: 1.15,
          colors: [Color(0xFF244965), Color(0xFF102B42), Color(0xFF05121E)],
          stops: [0, .58, 1],
        ).createShader(screen.outerRect),
    );

    canvas.drawRRect(
      screen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * .008
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8298A8), Color(0x2216232D), Color(0xFF05090C)],
        ).createShader(rect),
    );

    final center = Offset(size.width * .500, size.height * .535);
    final radius = unit * .225;
    canvas.drawCircle(
      center + Offset(0, unit * .008),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: .22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .018),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.28, -.32),
          radius: 1.2,
          colors: [Color(0xFF243B50), Color(0xFF102638), Color(0xFF071522)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .24),
    );

    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30 - math.pi / 2;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inset = i % 5 == 0 ? unit * .026 : unit * .010;
      final inner =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - inset);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = Colors.white.withValues(alpha: i % 5 == 0 ? .90 : .42)
          ..strokeWidth = i % 5 == 0 ? 2.1 : .8
          ..strokeCap = StrokeCap.round,
      );
    }

    void hand(double angle, double length, double width, Color color) {
      final endpoint =
          center + Offset(math.sin(angle), -math.cos(angle)) * length;
      canvas.drawLine(
        center + Offset(0, unit * .004),
        endpoint + Offset(0, unit * .004),
        Paint()
          ..color = Colors.black.withValues(alpha: .30)
          ..strokeWidth = width + 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        center,
        endpoint,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand((hour + minute / 60) * math.pi / 6, radius * .53, 6.5, Colors.white);
    hand(
      (minute + second / 60) * math.pi / 30,
      radius * .77,
      5.2,
      Colors.white,
    );
    hand(second * math.pi / 30, radius * .89, 1.7, const Color(0xFF2DA7FF));
    canvas.drawCircle(center, 7.2, Paint()..color = const Color(0xFF168FF1));
    canvas.drawCircle(center, 3.1, Paint()..color = const Color(0xFFF8FCFF));

    final crownCenter = Offset(size.width - unit * .035, size.height * .37);
    final crownShadow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: crownCenter + Offset(-unit * .004, unit * .008),
        width: unit * .060,
        height: unit * .145,
      ),
      Radius.circular(unit * .025),
    );
    canvas.drawRRect(
      crownShadow,
      Paint()
        ..color = Colors.black.withValues(alpha: .34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .014),
    );

    final crown = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: crownCenter,
        width: unit * .056,
        height: unit * .138,
      ),
      Radius.circular(unit * .024),
    );
    canvas.drawRRect(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF30383D),
            Color(0xFFAAB2B7),
            Color(0xFFF7F8F8),
            Color(0xFF737D82),
            Color(0xFFD9DEE1),
            Color(0xFF353E43),
          ],
          stops: [0, .18, .36, .58, .78, 1],
        ).createShader(crown.outerRect),
    );
    canvas.drawRRect(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF1A2024),
    );

    for (var i = -5; i <= 5; i++) {
      final y = crownCenter.dy + i * unit * .0105;
      canvas.drawLine(
        Offset(crown.left + unit * .008, y),
        Offset(crown.right - unit * .007, y),
        Paint()
          ..color = i.isEven
              ? Colors.white.withValues(alpha: .62)
              : Colors.black.withValues(alpha: .44)
          ..strokeWidth = .85,
      );
    }

    final glass = Path()
      ..moveTo(screen.left + unit * .032, screen.top + unit * .018)
      ..quadraticBezierTo(
        screen.center.dx,
        screen.top - unit * .012,
        screen.right - unit * .038,
        screen.top + unit * .072,
      )
      ..lineTo(screen.right - unit * .145, screen.center.dy - unit * .020)
      ..quadraticBezierTo(
        screen.center.dx,
        screen.top + unit * .065,
        screen.left + unit * .040,
        screen.top + unit * .145,
      )
      ..close();
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .24),
            Colors.white.withValues(alpha: .055),
            Colors.white.withValues(alpha: .0),
          ],
          stops: const [0, .42, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _WatchPainter oldDelegate) =>
      oldDelegate.hour != hour ||
      oldDelegate.minute != minute ||
      oldDelegate.second != second;
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
