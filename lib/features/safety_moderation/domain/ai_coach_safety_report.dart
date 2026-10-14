final class AiCoachSafetyReport {
  const AiCoachSafetyReport({
    required this.id,
    required this.reason,
    required this.locale,
    required this.runtime,
    required this.status,
    required this.reportedAt,
    this.answerText,
    this.userNote,
    this.decision,
    this.reviewedAt,
  });

  final String id;
  final String reason;
  final String locale;
  final String runtime;
  final String status;
  final DateTime reportedAt;
  final String? answerText;
  final String? userNote;
  final String? decision;
  final DateTime? reviewedAt;

  bool get isOpen => status == 'open';

  factory AiCoachSafetyReport.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('invalid_ai_coach_report');
    final data = <String, Object?>{
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    String requiredText(String key) {
      final text = data[key];
      if (text is! String || text.trim().isEmpty) {
        throw FormatException('invalid_ai_coach_report_$key');
      }
      return text;
    }

    final id = requiredText('report_id');
    final reason = requiredText('reason');
    final locale = requiredText('locale');
    final runtime = requiredText('runtime');
    final status = requiredText('status');
    final createdAt = DateTime.tryParse(requiredText('created_at'));
    final reviewedAtValue = data['reviewed_at'];
    final reviewedAt = reviewedAtValue == null
        ? null
        : reviewedAtValue is String
        ? DateTime.tryParse(reviewedAtValue)
        : null;
    final answerText = data['answer_text'];
    final userNote = data['user_note'];
    final decision = data['decision'];
    if (createdAt == null ||
        (reviewedAtValue != null && reviewedAt == null) ||
        (answerText != null && answerText is! String) ||
        (userNote != null && userNote is! String) ||
        (decision != null && decision is! String) ||
        !const {
          'unsafe',
          'offensive',
          'medical_accuracy',
          'other',
          'privacy',
        }.contains(reason) ||
        !const {
          'cloud_personalized',
          'on_device',
          'local_fallback',
        }.contains(runtime) ||
        !const {'open', 'reviewed'}.contains(status) ||
        (status == 'open' &&
            (answerText is! String ||
                decision != null ||
                reviewedAt != null)) ||
        (status == 'reviewed' &&
            (answerText != null ||
                !const {
                  'no_violation',
                  'confirmed_safety_issue',
                }.contains(decision) ||
                reviewedAt == null))) {
      throw const FormatException('invalid_ai_coach_report_payload');
    }
    return AiCoachSafetyReport(
      id: id,
      reason: reason,
      locale: locale,
      runtime: runtime,
      status: status,
      reportedAt: createdAt.toUtc(),
      answerText: answerText as String?,
      userNote: userNote as String?,
      decision: decision as String?,
      reviewedAt: reviewedAt?.toUtc(),
    );
  }
}

final class AiCoachSafetyReportReceipt {
  const AiCoachSafetyReportReceipt({
    required this.reportId,
    required this.status,
    required this.duplicate,
  });

  final String reportId;
  final String status;
  final bool duplicate;

  factory AiCoachSafetyReportReceipt.fromJson(Object? value) {
    if (value is! Map ||
        value['report_id'] is! String ||
        value['status'] is! String ||
        value['duplicate'] is! bool ||
        !const {'open', 'reviewed'}.contains(value['status'])) {
      throw const FormatException('invalid_ai_coach_report_receipt');
    }
    return AiCoachSafetyReportReceipt(
      reportId: value['report_id'] as String,
      status: value['status'] as String,
      duplicate: value['duplicate'] as bool,
    );
  }
}

final class AiCoachSafetyReviewReceipt {
  const AiCoachSafetyReviewReceipt({
    required this.reportId,
    required this.decision,
    required this.status,
    required this.duplicate,
  });

  final String reportId;
  final String decision;
  final String status;
  final bool duplicate;

  factory AiCoachSafetyReviewReceipt.fromJson(Object? value) {
    if (value is! Map ||
        value['report_id'] is! String ||
        value['decision'] is! String ||
        value['status'] != 'reviewed' ||
        value['duplicate'] is! bool ||
        !const {
          'no_violation',
          'confirmed_safety_issue',
        }.contains(value['decision'])) {
      throw const FormatException('invalid_ai_coach_review_receipt');
    }
    return AiCoachSafetyReviewReceipt(
      reportId: value['report_id'] as String,
      decision: value['decision'] as String,
      status: value['status'] as String,
      duplicate: value['duplicate'] as bool,
    );
  }
}
