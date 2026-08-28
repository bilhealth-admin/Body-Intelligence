import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connected_health_model.dart';
import '../connected_health_copy.dart';
import '../../../shared/widgets/bil_wordmark.dart';

final liveHealthNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

class LiveHealthWatch extends ConsumerStatefulWidget {
  const LiveHealthWatch({
    super.key,
    required this.snapshot,
    required this.languageCode,
    this.compact = false,
    this.onConnectTap,
    this.onStepsTap,
    this.onHeartTap,
    this.onActiveEnergyTap,
    this.onSleepTap,
    this.showConnectControl = true,
    this.showMetrics = true,
  });

  final ConnectedHealthSnapshot snapshot;
  final String languageCode;
  final bool compact;
  final VoidCallback? onConnectTap;
  final VoidCallback? onStepsTap;
  final VoidCallback? onHeartTap;
  final VoidCallback? onActiveEnergyTap;
  final VoidCallback? onSleepTap;
  final bool showConnectControl;
  final bool showMetrics;

  @override
  ConsumerState<LiveHealthWatch> createState() => _LiveHealthWatchState();
}

class _LiveHealthWatchState extends ConsumerState<LiveHealthWatch> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = ref.read(liveHealthNowProvider)();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = ref.read(liveHealthNowProvider)());
      }
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
    const weekdays = <String, List<String>>{
      'ar': [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ],
      'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      'fr': ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'],
      'es': ['lun.', 'mar.', 'mié.', 'jue.', 'vie.', 'sáb.', 'dom.'],
      'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    };
    return (weekdays[widget.languageCode] ?? weekdays['en']!)[_now.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour % 12;
    final minute = _now.minute;
    final second = _now.second;
    final hasMeasuredData =
        widget.snapshot.deviceVerified && widget.snapshot.signals.isNotEmpty;
    final showMeasuredMetrics = hasMeasuredData && widget.showMetrics;
    final compactConnectOnly = widget.compact && !showMeasuredMetrics;
    final digitalHour = _now.hour.toString().padLeft(2, '0');
    final digitalMinute = _now.minute.toString().padLeft(2, '0');
    final digitalSecond = _now.second.toString().padLeft(2, '0');
    return Semantics(
      image: true,
      label: connectedHealthTextForLanguage(
        widget.languageCode,
        'Live health watch showing current time and available measured data',
        'ساعة صحية حية تعرض الوقت والبيانات الصحية الحقيقية المتاحة',
      ),
      child: SizedBox.expand(
        child: CustomPaint(
          key: const Key('bil-live-health-watch'),
          painter: _WatchPainter(hour: hour, minute: minute, second: second),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: widget.compact ? 28 : 54,
                right: widget.compact ? 28 : 54,
                top: widget.compact ? 20 : 36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BilWordmark(height: widget.compact ? 15 : 12),
                    const SizedBox(height: 3),
                    Text(
                      '$_weekday  •  ${_now.day}/${_now.month}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF91AEC0),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: widget.compact ? 38 : 50,
                right: widget.compact ? 38 : 50,
                top: widget.compact ? 60 : 92,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$digitalHour:$digitalMinute'),
                      TextSpan(
                        text: '  $digitalSecond',
                        style: TextStyle(
                          color: const Color(0xFF55DFF2),
                          fontSize: widget.compact ? 11 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.compact ? 32 : 42,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -1.8,
                  ),
                ),
              ),
              Positioned(
                left: widget.compact ? 26 : 40,
                right: widget.compact ? 26 : 40,
                bottom: widget.compact ? 25 : 44,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: compactConnectOnly
                        ? 0
                        : widget.compact
                        ? 6
                        : 10,
                  ),
                  decoration: BoxDecoration(
                    color: compactConnectOnly
                        ? Colors.transparent
                        : const Color(0xFF06131F).withValues(alpha: .68),
                    borderRadius: BorderRadius.circular(24),
                    border: compactConnectOnly
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                  ),
                  child: showMeasuredMetrics
                      ? Row(
                          children: [
                            Expanded(
                              child: _WatchMetricButton(
                                onTap: _signal('steps') == null
                                    ? null
                                    : widget.onStepsTap,
                                child: _WatchMetric(
                                  icon: Icons.directions_walk_rounded,
                                  color: const Color(0xFF55D66B),
                                  value: _value('steps'),
                                  compact: widget.compact,
                                  label: connectedHealthTextForLanguage(
                                    widget.languageCode,
                                    'steps',
                                    'خطوات',
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _WatchMetricButton(
                                onTap:
                                    _signal('heartRate') == null &&
                                        _signal('restingHeartRate') == null
                                    ? null
                                    : widget.onHeartTap,
                                child: _WatchMetric(
                                  icon: Icons.favorite_outline_rounded,
                                  color: const Color(0xFFFF6472),
                                  value: _signal('heartRate') == null
                                      ? _value('restingHeartRate')
                                      : _value('heartRate'),
                                  compact: widget.compact,
                                  label: connectedHealthTextForLanguage(
                                    widget.languageCode,
                                    'bpm',
                                    'نبض',
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _WatchMetricButton(
                                onTap: _signal('activeEnergy') == null
                                    ? null
                                    : widget.onActiveEnergyTap,
                                child: _WatchMetric(
                                  icon: Icons.local_fire_department_outlined,
                                  color: const Color(0xFFFFA24A),
                                  value: _value('activeEnergy'),
                                  compact: widget.compact,
                                  label: connectedHealthTextForLanguage(
                                    widget.languageCode,
                                    'kcal',
                                    'طاقة',
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _WatchMetricButton(
                                onTap: _signal('sleep') == null
                                    ? null
                                    : widget.onSleepTap,
                                child: _WatchMetric(
                                  icon: Icons.bedtime_outlined,
                                  color: const Color(0xFFA982FF),
                                  value: _value('sleep', decimals: 1),
                                  compact: widget.compact,
                                  label: connectedHealthTextForLanguage(
                                    widget.languageCode,
                                    'sleep',
                                    'نوم',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : !widget.showConnectControl
                      ? const SizedBox.shrink()
                      : widget.compact
                      ? Center(
                          child: _CompactWatchConnectButton(
                            onPressed: widget.onConnectTap,
                            semanticLabel: connectedHealthTextForLanguage(
                              widget.languageCode,
                              'Link fitness',
                              'ربط اللياقة',
                            ),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            key: const Key('watch-connect-health-cta'),
                            onPressed: widget.onConnectTap,
                            icon: const Icon(Icons.link_rounded, size: 15),
                            label: Text(
                              connectedHealthTextForLanguage(
                                widget.languageCode,
                                'Connect fitness',
                                'ربط اللياقة',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactWatchConnectButton extends StatelessWidget {
  const _CompactWatchConnectButton({
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('watch-connect-health-semantics'),
    button: true,
    enabled: onPressed != null,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          key: const Key('watch-connect-health-cta'),
          onTap: onPressed,
          radius: 24,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                key: const Key('watch-connect-health-icon-disc'),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .92),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .20),
                  ),
                ),
                child: Icon(
                  Icons.link_rounded,
                  key: const Key('watch-connect-health-icon'),
                  size: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WatchMetricButton extends StatelessWidget {
  const _WatchMetricButton({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    ),
  );
}

class _WatchMetric extends StatelessWidget {
  const _WatchMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: compact ? 13 : 16),
        Text(
          value,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: compact ? 11 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFFD9EAF4),
            fontSize: compact ? 9 : null,
          ),
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
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102D42), Color(0xFF081A29), Color(0xFF030B12)],
          stops: [0, .52, 1],
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
