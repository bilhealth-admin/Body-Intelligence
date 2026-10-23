part of 'bil_smart_plan.dart';

/// Bounded reversible history of user-confirmed changes, part of the saved
/// plan rather than a reconstructed chat memory. Reasons are structured, not
/// free text containing medical or other unrelated personal information.
final class BilPlanChange {
  BilPlanChange({
    required this.revision,
    required this.at,
    required this.previousUpdatedAt,
    required this.reason,
    required this.previousStatus,
    required Iterable<BilPlanDay> beforeDays,
  }) : beforeDays = List.unmodifiable(beforeDays) {
    if (revision < 2 ||
        at.isBefore(previousUpdatedAt) ||
        this.beforeDays.length > 14 ||
        this.beforeDays.map((day) => day.date).toSet().length !=
            this.beforeDays.length) {
      throw const FormatException('smart_plan_invalid_change');
    }
  }
  final int revision;
  final DateTime at, previousUpdatedAt;
  final BilPlanChangeReason reason;
  final BilPlanStatus previousStatus;
  final List<BilPlanDay> beforeDays;
  Map<String, Object?> toJson() => {
    'revision': revision,
    'at': at.toUtc().toIso8601String(),
    'previousUpdatedAt': previousUpdatedAt.toUtc().toIso8601String(),
    'reason': reason.name,
    'previousStatus': previousStatus.name,
    'beforeDays': beforeDays.map((day) => day.toJson()).toList(growable: false),
  };
  factory BilPlanChange.fromJson(Map<String, dynamic> data) {
    final rows = data['beforeDays'];
    if (rows is! List ||
        rows.length > 14 ||
        data.keys.any(
          (key) => !const {
            'revision',
            'at',
            'previousUpdatedAt',
            'reason',
            'previousStatus',
            'beforeDays',
          }.contains(key),
        )) {
      throw const FormatException('smart_plan_invalid_change');
    }
    return BilPlanChange(
      revision: _planInt(data['revision']),
      at: DateTime.parse(data['at'] as String),
      previousUpdatedAt: DateTime.parse(data['previousUpdatedAt'] as String),
      reason: _readPlanEnum(BilPlanChangeReason.values, data['reason']),
      previousStatus: _readPlanEnum(
        BilPlanStatus.values,
        data['previousStatus'],
      ),
      beforeDays: rows.map(
        (row) => BilPlanDay.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
    );
  }
}
