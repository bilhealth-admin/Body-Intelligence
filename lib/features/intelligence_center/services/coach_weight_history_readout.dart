import '../domain/coach_context_snapshot.dart';

/// Owner-scoped, read-only weight facts for the Coach conversation.
///
/// Computations use actual saved weigh-ins, never a target or inferred body fat.
/// A missing date is unknown, not a zero measurement. The caller must already
/// have a verified owner/context permission and a successful repository read.
class CoachWeightHistoryReadout {
  const CoachWeightHistoryReadout({
    required this.message,
    required this.recordCount,
    required this.comparableCount,
    this.changeKg,
  });

  final String message;
  final int recordCount;
  final int comparableCount;
  final double? changeKg;

  static CoachWeightHistoryReadout build({
    required CoachContextSnapshot snapshot,
    required String question,
    required String languageTag,
    required DateTime now,
  }) {
    if (snapshot.weightReadStatus != CoachWeightReadStatus.verified) {
      throw StateError('weight_history_not_verified');
    }

    final arabic = languageTag.toLowerCase().startsWith('ar');
    final normalized = question.toLowerCase().replaceAll(
      RegExp('[أإآٱ]'),
      'ا',
    );
    final periodDays = RegExp(
      r'\b(?:year|12 months|365 days)\b|سنه|سنة|عام',
    ).hasMatch(normalized)
        ? 365
        : RegExp(
            r'\b(?:month|30 days|four weeks)\b|شهر|ثلاثين يوم|30 يوم',
          ).hasMatch(normalized)
        ? 30
        : RegExp(r'\b(?:week|7 days)\b|اسبوع|اسبوعين|7 ايام')
              .hasMatch(normalized)
        ? 7
        : null;

    // Do not trust storage ordering, and never count nonsensical values.
    final entries = snapshot.weights
        .where((point) =>
            point.kg.isFinite &&
            point.kg > 0 &&
            point.at.isBefore(now.add(const Duration(days: 1))))
        .toList(growable: true)
      ..sort((a, b) => a.at.compareTo(b.at));

    if (entries.isEmpty) {
      return CoachWeightHistoryReadout(
        message: arabic
            ? 'نجحت قراءة سجل الوزن، لكن لم أجد فيه قياسات وزن مؤكدة. '
              'قد يكون وزن الملف الشخصي محفوظًا في مصدر مختلف، ولا أستطيع اختراع تاريخ قياسات.'
            : 'The weight-history read succeeded, but no verified weigh-ins were found there. '
              'Profile weight may be stored separately; I cannot invent a measurement history.',
        recordCount: 0,
        comparableCount: 0,
      );
    }

    final cutoff = periodDays == null
        ? null
        : DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: periodDays));
    final selected = cutoff == null
        ? entries
        : entries
            .where((point) => !point.at.toLocal().isBefore(cutoff))
            .toList(growable: false);
    final scope = periodDays == null
        ? (arabic ? 'جميع الفترات المسجلة' : 'the full recorded period')
        : (arabic ? 'آخر $periodDays يومًا' : 'the last $periodDays days');
    if (selected.isEmpty) {
      return CoachWeightHistoryReadout(
        message: arabic
            ? 'لا توجد قياسات وزن مؤكدة ضمن $scope. '
              'السجل العام يحتوي ${entries.length} قياسًا، لذا لا يمكن حساب تغيّر هذه الفترة.'
            : 'There are no verified weigh-ins within $scope. '
              'The full history contains ${entries.length} entries, so no change can be calculated for this period.',
        recordCount: entries.length,
        comparableCount: 0,
      );
    }

    String date(DateTime value) {
      final local = value.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
    }

    final first = selected.first;
    final latest = selected.last;
    if (selected.length == 1) {
      return CoachWeightHistoryReadout(
        message: arabic
            ? 'لدي قياس واحد فقط ضمن $scope: ${latest.kg.toStringAsFixed(1)} كغ '
              'بتاريخ ${date(latest.at)}. أحتاج قياسين على الأقل لحساب تغيّر الفترة.'
            : 'Only one weigh-in is available in $scope: ${latest.kg.toStringAsFixed(1)} kg '
              'on ${date(latest.at)}. At least two weigh-ins are needed to calculate change.',
        recordCount: entries.length,
        comparableCount: 1,
      );
    }

    final change = latest.kg - first.kg;
    final days = DateTime(
      latest.at.toLocal().year,
      latest.at.toLocal().month,
      latest.at.toLocal().day,
    ).difference(
      DateTime(
        first.at.toLocal().year,
        first.at.toLocal().month,
        first.at.toLocal().day,
      ),
    ).inDays;
    final signedChange = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}';
    return CoachWeightHistoryReadout(
      message: arabic
          ? 'راجعت ${selected.length} قياسات مؤكدة ضمن $scope '
            '(من ${date(first.at)} إلى ${date(latest.at)}؛ $days يومًا). '
            'الوزن تغيّر من ${first.kg.toStringAsFixed(1)} إلى '
            '${latest.kg.toStringAsFixed(1)} كغ؛ الفارق $signedChange كغ. '
            'هذه مقارنة لوزن الميزان فقط؛ لا تثبت تغيّر الدهون، '
            'ولا يمكن ملء الأيام غير المسجلة ببيانات مفترضة.'
          : 'I reviewed ${selected.length} verified weigh-ins in $scope '
            '(from ${date(first.at)} to ${date(latest.at)}; $days days). '
            'Measured weight changed from ${first.kg.toStringAsFixed(1)} to '
            '${latest.kg.toStringAsFixed(1)} kg, a change of $signedChange kg. '
            'This is a scale-weight trend, not proof of body-fat change; '
            'missing dates are not assumed to contain measurements.',
      recordCount: entries.length,
      comparableCount: selected.length,
      changeKg: change,
    );
  }
}
