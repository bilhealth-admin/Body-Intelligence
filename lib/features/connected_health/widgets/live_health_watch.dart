import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connected_health_model.dart';
import '../connected_health_copy.dart';

final liveHealthNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

const _watchMetricKeys = <String>{
  'steps',
  'heartRate',
  'restingHeartRate',
  'activeEnergy',
  'sleep',
};

/// Metrics are visible only while a real, authorized source is currently in a
/// usable state. Stale readings retained after disconnect/revocation never
/// make the watch look connected.
bool liveHealthWatchCanShowMetrics(ConnectedHealthSnapshot snapshot) {
  final usableStatus = switch (snapshot.status) {
    ConnectedHealthStatus.ready ||
    ConnectedHealthStatus.syncing ||
    ConnectedHealthStatus.synchronized => true,
    _ => false,
  };
  final hasCurrentSource =
      snapshot.platformSource?.trim().isNotEmpty == true ||
      snapshot.availableSources.any((source) => source.trim().isNotEmpty);
  return usableStatus && snapshot.deviceVerified && hasCurrentSource;
}

bool liveHealthWatchSignalIsActual(ConnectedHealthSignalView signal) =>
    _watchMetricKeys.contains(signal.key) &&
    signal.value.isFinite &&
    signal.source.trim().isNotEmpty &&
    signal.confidence > 0;

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
    if (!liveHealthWatchCanShowMetrics(widget.snapshot)) return null;
    ConnectedHealthSignalView? latest;
    for (final signal in widget.snapshot.signals) {
      if (signal.key != key || !liveHealthWatchSignalIsActual(signal)) {
        continue;
      }
      if (latest == null || signal.observedAt.isAfter(latest.observedAt)) {
        latest = signal;
      }
    }
    return latest;
  }

  String _value(ConnectedHealthSignalView signal, {int decimals = 0}) {
    return decimals == 0
        ? signal.value.round().toString()
        : signal.value.toStringAsFixed(decimals);
  }

  String _dateLine(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final weekday = localizations.narrowWeekdays[_now.weekday % 7];
    return '$weekday  •  ${localizations.formatShortDate(_now)}';
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour % 12;
    final minute = _now.minute;
    final second = _now.second;
    final steps = _signal('steps');
    final heart = _signal('heartRate') ?? _signal('restingHeartRate');
    final activeEnergy = _signal('activeEnergy');
    final sleep = _signal('sleep');
    final showMeasuredMetrics =
        widget.showMetrics &&
        <ConnectedHealthSignalView?>[
          steps,
          heart,
          activeEnergy,
          sleep,
        ].any((signal) => signal != null);
    final compactConnectOnly = widget.compact && !showMeasuredMetrics;
    final digitalHour = _now.hour.toString().padLeft(2, '0');
    final digitalMinute = _now.minute.toString().padLeft(2, '0');
    final digitalSecond = _now.second.toString().padLeft(2, '0');
    return Semantics(
      image: true,
      label: connectedHealthText(
        context,
        'Live fitness watch showing current time and available measured data',
        'ساعة لياقة حية تعرض الوقت الحالي والبيانات المقاسة المتاحة',
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
                top: widget.compact ? 25 : 42,
                child: Text(
                  _dateLine(context),
                  key: const Key('watch-date-line'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF91AEC0),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                left: widget.compact ? 38 : 50,
                right: widget.compact ? 38 : 50,
                top: widget.compact ? 58 : 82,
                child: Text.rich(
                  key: const Key('watch-digital-time'),
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
                            if (steps != null)
                              Expanded(
                                child: _WatchMetricButton(
                                  key: const Key('watch-metric-steps'),
                                  onTap: widget.onStepsTap,
                                  child: _WatchMetric(
                                    icon: Icons.directions_walk_rounded,
                                    color: const Color(0xFF55D66B),
                                    value: _value(steps),
                                    compact: widget.compact,
                                    label: connectedHealthText(
                                      context,
                                      'steps',
                                      'خطوات',
                                    ),
                                    semanticLabel: connectedHealthText(
                                      context,
                                      'Steps',
                                      'الخطوات',
                                    ),
                                  ),
                                ),
                              ),
                            if (heart != null)
                              Expanded(
                                child: _WatchMetricButton(
                                  key: const Key('watch-metric-heart-rate'),
                                  onTap: widget.onHeartTap,
                                  child: _WatchMetric(
                                    icon: Icons.favorite_outline_rounded,
                                    color: const Color(0xFFFF6472),
                                    value: _value(heart),
                                    compact: widget.compact,
                                    label: connectedHealthText(
                                      context,
                                      'bpm',
                                      'نبض',
                                    ),
                                    semanticLabel: connectedHealthText(
                                      context,
                                      'Heart rate',
                                      'معدل نبض القلب',
                                    ),
                                  ),
                                ),
                              ),
                            if (activeEnergy != null)
                              Expanded(
                                child: _WatchMetricButton(
                                  key: const Key('watch-metric-active-energy'),
                                  onTap: widget.onActiveEnergyTap,
                                  child: _WatchMetric(
                                    icon: Icons.local_fire_department_outlined,
                                    color: const Color(0xFFFFA24A),
                                    value: _value(activeEnergy),
                                    compact: widget.compact,
                                    label: connectedHealthText(
                                      context,
                                      'kcal',
                                      'سعرة',
                                    ),
                                    semanticLabel: connectedHealthText(
                                      context,
                                      'Active energy',
                                      'الطاقة النشطة',
                                    ),
                                  ),
                                ),
                              ),
                            if (sleep != null)
                              Expanded(
                                child: _WatchMetricButton(
                                  key: const Key('watch-metric-sleep'),
                                  onTap: widget.onSleepTap,
                                  child: _WatchMetric(
                                    icon: Icons.bedtime_outlined,
                                    color: const Color(0xFFA982FF),
                                    value: _value(sleep, decimals: 1),
                                    compact: widget.compact,
                                    label: connectedHealthText(
                                      context,
                                      'sleep',
                                      'نوم',
                                    ),
                                    semanticLabel: connectedHealthText(
                                      context,
                                      'Sleep',
                                      'النوم',
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
                            semanticLabel: connectedHealthText(
                              context,
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
                              connectedHealthText(
                                context,
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
  const _WatchMetricButton({super.key, required this.child, this.onTap});

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
    required this.semanticLabel,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String semanticLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticLabel, $value $label',
      child: ExcludeSemantics(
        child: Column(
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
        ),
      ),
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

    final shell = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        unit * .032,
        unit * .032,
        size.width - unit * .086,
        size.height - unit * .064,
      ),
      Radius.circular(unit * .22),
    );

    canvas.drawRRect(
      shell.shift(Offset(0, unit * .018)),
      Paint()
        ..color = Colors.black.withValues(alpha: .34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .035),
    );

    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07131B),
            Color(0xFF163442),
            Color(0xFF0B202C),
            Color(0xFF050D13),
          ],
          stops: [0, .33, .68, 1],
        ).createShader(rect),
    );

    final bezel = shell.deflate(unit * .018);
    canvas.drawRRect(
      bezel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071017), Color(0xFF142A35), Color(0xFF050A0F)],
          stops: [0, .48, 1],
        ).createShader(rect),
    );

    final screen = bezel.deflate(unit * .021);
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
          colors: [Color(0xCC2A586A), Color(0x332E6678), Color(0xFF05090C)],
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
            Color(0xFF0B161D),
            Color(0xFF294653),
            Color(0xFF4F7481),
            Color(0xFF1B323D),
            Color(0xFF355764),
            Color(0xFF091219),
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
              ? const Color(0xFF527786).withValues(alpha: .72)
              : Colors.black.withValues(alpha: .48)
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
            const Color(0xFF65CDE2).withValues(alpha: .18),
            const Color(0xFF65CDE2).withValues(alpha: .045),
            const Color(0xFF65CDE2).withValues(alpha: 0),
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
