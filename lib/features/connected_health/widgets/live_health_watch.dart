import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connected_health_model.dart';
import '../connected_health_copy.dart';

part 'live_health_watch_painter.dart';

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
///
/// HealthKit and Health Connect select the authoritative source for each
/// metric. A phone is a valid HealthKit source too; owning an Apple Watch is
/// not required. Original provenance remains in storage, not in the compact
/// reading labels.
bool liveHealthWatchCanShowMetrics(ConnectedHealthSnapshot snapshot) {
  final cachePreservedAfterNativeFailure =
      snapshot.status == ConnectedHealthStatus.degraded &&
      snapshot.lastSyncAt != null &&
      (snapshot.failureCode == 'health_sync_timed_out' ||
          snapshot.failureCode == 'health_cached_snapshot_pending_refresh' ||
          snapshot.failureCode == 'native_health_status_unavailable' ||
          snapshot.failureCode ==
              'daily_activity_refresh_failed_cache_preserved' ||
          snapshot.failureCode ==
              'health_sync_failed_offline_cache_preserved' ||
          snapshot.failureCode == 'health_sync_empty_result_cache_preserved' ||
          snapshot.failureCode ==
              'health_refresh_failed_offline_cache_preserved');
  final usableStatus = switch (snapshot.status) {
    ConnectedHealthStatus.ready ||
    ConnectedHealthStatus.syncing ||
    ConnectedHealthStatus.synchronized => true,
    // Keep the last confirmed watch readings on screen when a foreground
    // retry fails. The status dot still reports the degraded source, while
    // disconnect/revocation snapshots (which have no cache-preserved code)
    // continue to hide stale readings.
    ConnectedHealthStatus.degraded => cachePreservedAfterNativeFailure,
    _ => false,
  };
  final hasCurrentSource =
      snapshot.platformSource?.trim().isNotEmpty == true ||
      snapshot.availableSources.any((source) => source.trim().isNotEmpty);
  final hasActualNativeReading = <ConnectedHealthSignalView>[
    ...snapshot.signals,
    ...snapshot.stepHistory,
  ].any(liveHealthWatchSignalIsActual);
  // `deviceVerified` is a native-import confidence flag, not a physical
  // Apple Watch requirement. A valid iPhone HealthKit aggregate carries its
  // own non-empty source and must remain visible when that flag is delayed.
  return usableStatus &&
      hasCurrentSource &&
      (snapshot.deviceVerified || hasActualNativeReading);
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

class _LiveHealthWatchState extends ConsumerState<LiveHealthWatch>
    with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = ref.read(liveHealthNowProvider)();
    _startClock();
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = ref.read(liveHealthNowProvider)());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (state != AppLifecycleState.resumed || _timer != null) return;
    setState(() => _now = ref.read(liveHealthNowProvider)());
    _startClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  ConnectedHealthSignalView? _signal(String key) {
    if (!liveHealthWatchCanShowMetrics(widget.snapshot)) return null;
    final today = DateTime(_now.year, _now.month, _now.day);
    final todayHistory = widget.snapshot.stepHistory.where((signal) {
      final date = signal.observedAt.toLocal();
      return DateTime(date.year, date.month, date.day) == today;
    });
    // Prefer today's aggregate when it exists, but do not hide a valid
    // reading merely because the native source reported it shortly before
    // the local day boundary. The card already exposes the last-sync time;
    // showing the latest confirmed value is more useful than replacing it
    // with an empty watch face.
    final signals = key == 'steps'
        ? <ConnectedHealthSignalView>[
            ...todayHistory,
            ...widget.snapshot.signals.where((signal) => signal.key == key),
          ]
        : widget.snapshot.signals;
    ConnectedHealthSignalView? latest;
    for (final signal in signals) {
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final referenceSide = widget.compact ? 176.0 : 304.0;
            // The watch can be placed in a short row on narrow devices (for
            // example beside the health summary). Scale against the smallest
            // finite dimension so the metric panel cannot overflow vertically.
            final finiteSides = <double>[
              if (constraints.maxWidth.isFinite) constraints.maxWidth,
              if (constraints.maxHeight.isFinite) constraints.maxHeight,
            ];
            final availableSide = finiteSides.isEmpty
                ? referenceSide
                : finiteSides.reduce((a, b) => a < b ? a : b);
            final layoutScale = (availableSide / referenceSide).clamp(.5, 2.25);
            double d(double value) => value * layoutScale;
            return CustomPaint(
              key: const Key('bil-live-health-watch'),
              painter: _WatchPainter(
                hour: hour,
                minute: minute,
                second: second,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: d(widget.compact ? 28 : 54),
                    right: d(widget.compact ? 28 : 54),
                    top: d(widget.compact ? 25 : 42),
                    child: Text(
                      _dateLine(context),
                      key: const Key('watch-date-line'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF91AEC0),
                        fontSize: d(10),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    left: d(widget.compact ? 38 : 50),
                    right: d(widget.compact ? 38 : 50),
                    // The compact dashboard preview is only about 176 logical
                    // pixels tall. Keep the clock in its own upper zone so the
                    // four-metric grid below can never paint over it.
                    top: d(widget.compact ? 51 : 82),
                    child: Text.rich(
                      key: const Key('watch-digital-time'),
                      TextSpan(
                        children: [
                          TextSpan(text: '$digitalHour:$digitalMinute'),
                          TextSpan(
                            text: '  $digitalSecond',
                            style: TextStyle(
                              color: const Color(0xFF55DFF2),
                              fontSize: d(widget.compact ? 10 : 14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: d(widget.compact ? 28 : 42),
                        height: 1,
                        fontWeight: FontWeight.w400,
                        letterSpacing: d(-1.8),
                      ),
                    ),
                  ),
                  Positioned(
                    left: d(widget.compact ? 26 : 40),
                    right: d(widget.compact ? 26 : 40),
                    bottom: d(widget.compact ? 17 : 44),
                    child: Container(
                      constraints: widget.compact
                          ? BoxConstraints(minHeight: d(78), maxHeight: d(78))
                          : null,
                      padding: EdgeInsets.symmetric(
                        horizontal: d(widget.compact ? 6 : 8),
                        vertical: compactConnectOnly
                            ? 0
                            : widget.compact
                            ? d(4)
                            : d(10),
                      ),
                      decoration: BoxDecoration(
                        color: compactConnectOnly
                            ? Colors.transparent
                            : const Color(0xFF06131F).withValues(alpha: .68),
                        borderRadius: BorderRadius.circular(d(24)),
                        border: compactConnectOnly
                            ? null
                            : Border.all(
                                color: Colors.white.withValues(alpha: .12),
                              ),
                      ),
                      child: showMeasuredMetrics
                          ? LayoutBuilder(
                              builder: (context, metricConstraints) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: metricConstraints.maxWidth,
                                  height: d(widget.compact ? 72 : 100),
                                  child: _WatchMetricsLayout(
                                    children: [
                                      if (steps != null)
                                        Expanded(
                                          child: _WatchMetricButton(
                                            key: const Key(
                                              'watch-metric-steps',
                                            ),
                                            onTap: widget.onStepsTap,
                                            child: _WatchMetric(
                                              icon:
                                                  Icons.directions_walk_rounded,
                                              color: const Color(0xFF55D66B),
                                              value: _value(steps),
                                              compact: widget.compact,
                                              scale: layoutScale,
                                              label: connectedHealthText(
                                                context,
                                                'steps',
                                                'خطوات',
                                              ),
                                              semanticLabel:
                                                  connectedHealthText(
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
                                            key: const Key(
                                              'watch-metric-heart-rate',
                                            ),
                                            onTap: widget.onHeartTap,
                                            child: _WatchMetric(
                                              icon: Icons
                                                  .favorite_outline_rounded,
                                              color: const Color(0xFFFF6472),
                                              value: _value(heart),
                                              compact: widget.compact,
                                              scale: layoutScale,
                                              label: connectedHealthText(
                                                context,
                                                'bpm',
                                                'نبض',
                                              ),
                                              semanticLabel:
                                                  connectedHealthText(
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
                                            key: const Key(
                                              'watch-metric-active-energy',
                                            ),
                                            onTap: widget.onActiveEnergyTap,
                                            child: _WatchMetric(
                                              icon: Icons
                                                  .local_fire_department_outlined,
                                              color: const Color(0xFFFFA24A),
                                              value: _value(activeEnergy),
                                              compact: widget.compact,
                                              scale: layoutScale,
                                              label: connectedHealthText(
                                                context,
                                                'kcal',
                                                'سعرة',
                                              ),
                                              semanticLabel:
                                                  connectedHealthText(
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
                                            key: const Key(
                                              'watch-metric-sleep',
                                            ),
                                            onTap: widget.onSleepTap,
                                            child: _WatchMetric(
                                              icon: Icons.bedtime_outlined,
                                              color: const Color(0xFFA982FF),
                                              value: _value(sleep, decimals: 1),
                                              compact: widget.compact,
                                              scale: layoutScale,
                                              label: connectedHealthText(
                                                context,
                                                'sleep',
                                                'نوم',
                                              ),
                                              semanticLabel:
                                                  connectedHealthText(
                                                    context,
                                                    'Sleep',
                                                    'النوم',
                                                  ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
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
            );
          },
        ),
      ),
    );
  }
}

class _WatchMetricsLayout extends StatelessWidget {
  const _WatchMetricsLayout({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => children.length <= 3
      ? Row(children: children)
      : Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: Row(children: children.take(2).toList())),
            const SizedBox(height: 4),
            Expanded(child: Row(children: children.skip(2).toList())),
          ],
        );
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
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
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
    this.scale = 1,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String semanticLabel;
  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticLabel, $value $label',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: (compact ? 10 : 16) * scale),
            Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontSize: (compact ? 10 : 13) * scale,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFD9EAF4),
                fontSize: compact ? 8 * scale : null,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
