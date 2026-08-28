enum MealVisionUsageAvailability { available, signedOut, unavailable }

final class MealVisionUsage {
  const MealVisionUsage({
    required this.limit,
    required this.used,
    required this.reserved,
    required this.remaining,
    this.periodStart,
  });

  factory MealVisionUsage.fromJson(Map<String, Object?> json) {
    int value(String key) {
      final raw = json[key];
      if (raw is! num || !raw.isFinite || raw < 0 || raw != raw.round()) {
        throw const FormatException('invalid_vision_usage');
      }
      return raw.toInt();
    }

    final limit = value('limit');
    final used = value('used');
    final reserved = value('reserved');
    final remaining = value('remaining');
    if (used + reserved + remaining != limit) {
      throw const FormatException('inconsistent_vision_usage');
    }
    return MealVisionUsage(
      limit: limit,
      used: used,
      reserved: reserved,
      remaining: remaining,
      periodStart: DateTime.tryParse(json['period_start']?.toString() ?? ''),
    );
  }

  /// Parses the shared BIL AI Token balance used by text, Vision, and voice.
  /// Weekly tokens are consumed first; paid grants stack and do not reset.
  factory MealVisionUsage.fromAiUsageStatus(Map<String, Object?> json) {
    final rawCredits = json['credits'];
    final Map<String, Object?> credits;
    if (rawCredits is Map) {
      credits = rawCredits.cast<String, Object?>();
    } else {
      // Compatibility with servers from before the unified-token migration.
      final capabilities = json['capabilities'];
      final rawVision = capabilities is Map ? capabilities['vision'] : null;
      if (rawVision is! Map) {
        throw const FormatException('invalid_ai_usage_status');
      }
      credits = rawVision.cast<String, Object?>();
    }
    int integral(String key) {
      final raw = credits[key];
      if (raw is! num || !raw.isFinite || raw < 0 || raw != raw.round()) {
        throw const FormatException('invalid_ai_credit_usage');
      }
      return raw.toInt();
    }

    final weeklyLimit = integral('weekly_limit');
    final weeklyUsed = integral('weekly_used');
    final weeklyReserved = integral('weekly_reserved');
    final weeklyRemaining = integral('weekly_remaining');
    final paidGranted = integral('paid_granted');
    final paidUsed = integral('paid_used');
    final paidReserved = integral('paid_reserved');
    final paidRemaining = integral('paid_remaining');
    if (weeklyUsed + weeklyReserved + weeklyRemaining != weeklyLimit ||
        paidUsed + paidReserved + paidRemaining != paidGranted) {
      throw const FormatException('inconsistent_ai_credit_usage');
    }
    return MealVisionUsage(
      limit: weeklyLimit + paidGranted,
      used: weeklyUsed + paidUsed,
      reserved: weeklyReserved + paidReserved,
      remaining: weeklyRemaining + paidRemaining,
      periodStart: DateTime.tryParse(json['week_start']?.toString() ?? ''),
    );
  }

  final int limit;
  final int used;
  final int reserved;
  final int remaining;
  final DateTime? periodStart;

  bool get exhausted => remaining == 0;
}

final class MealVisionUsageSnapshot {
  const MealVisionUsageSnapshot._({required this.availability, this.usage});

  const MealVisionUsageSnapshot.available(MealVisionUsage usage)
    : this._(availability: MealVisionUsageAvailability.available, usage: usage);
  const MealVisionUsageSnapshot.signedOut()
    : this._(availability: MealVisionUsageAvailability.signedOut);
  const MealVisionUsageSnapshot.unavailable()
    : this._(availability: MealVisionUsageAvailability.unavailable);

  final MealVisionUsageAvailability availability;
  final MealVisionUsage? usage;
  bool get canAnalyze => usage != null && usage!.remaining > 0;
}

final class MealVisionReceiptMetrics {
  const MealVisionReceiptMetrics({
    required this.provider,
    required this.model,
    required this.latencyMs,
    this.inputTokens,
    this.outputTokens,
    this.costUsd,
  });

  final String provider;
  final String model;
  final int latencyMs;
  final int? inputTokens;
  final int? outputTokens;
  final double? costUsd;
}
