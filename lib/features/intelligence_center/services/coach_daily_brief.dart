import '../domain/coach_context_snapshot.dart';
import '../intelligence_locale_copy.dart';

enum CoachDailyBriefKind {
  onboarding,
  nutrition,
  recovery,
  trend,
  experiment,
  steady,
}

class CoachDailyBrief {
  const CoachDailyBrief({
    required this.kind,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.suggestedPrompt,
    required this.evidenceLabel,
    required this.readiness,
  });

  final CoachDailyBriefKind kind;
  final String title;
  final String message;
  final String actionLabel;
  final String suggestedPrompt;
  final String evidenceLabel;
  final double readiness;
}

/// Produces an immediate, deterministic decision from verified BIL data.
///
/// This gives a new user useful guidance on day one without spending a model
/// request. Richer longitudinal conclusions remain deliberately gated on
/// enough observations and are described as patterns, never medical proof.
class CoachDailyBriefEngine {
  const CoachDailyBriefEngine();

  CoachDailyBrief build({
    required CoachContextSnapshot context,
    required DateTime now,
    required String locale,
  }) {
    String t(String en, String arText) =>
        intelligenceTextFor(locale, en, arText);
    String f(String en, String arText, Map<String, Object> values) {
      var value = t(en, arText);
      for (final entry in values.entries) {
        value = value.replaceAll('{${entry.key}}', '${entry.value}');
      }
      return value;
    }

    final readiness = _readiness(context);

    final activeExperiment = context.personalExperiments
        .where((item) => item['status'] == 'active')
        .cast<Map<String, Object?>>()
        .firstOrNull;
    if (activeExperiment != null) {
      final hypothesis = activeExperiment['hypothesis']?.toString().trim();
      final end = DateTime.tryParse(
        activeExperiment['endsAt']?.toString() ?? '',
      );
      final remaining = end == null ? null : end.difference(now).inDays + 1;
      return CoachDailyBrief(
        kind: CoachDailyBriefKind.experiment,
        title: t('Your experiment is active', 'تجربتك الشخصية مستمرة'),
        message: hypothesis?.isNotEmpty == true
            ? '$hypothesis${remaining == null ? '' : ' · ${f('{count} days left', 'بقي {count} يوم', {'count': remaining})}'}'
            : t(
                'Keep one variable consistent today so the result stays useful.',
                'ثبّت المتغير الواحد اليوم حتى تبقى النتيجة مفيدة.',
              ),
        actionLabel: t('Review experiment', 'راجع التجربة'),
        suggestedPrompt: t(
          'Review my active experiment and today’s data',
          'راجع تجربتي الحالية وبيانات اليوم',
        ),
        evidenceLabel: t('Personal experiment', 'تجربة شخصية'),
        readiness: readiness,
      );
    }

    final remaining = context.nutritionRemainingFor(now);
    final targets = context.computedHealth['dailyTargets'];
    if (remaining != null && targets is Map) {
      final proteinTarget = (targets['proteinG'] as num?)?.toDouble() ?? 0;
      final proteinLeft = remaining['proteinG']?.toDouble() ?? 0;
      final caloriesLeft = remaining['caloriesKcal']?.toDouble() ?? 0;
      final consumedProtein = proteinTarget - proteinLeft;
      if (proteinTarget > 0 && proteinLeft > proteinTarget * .25) {
        return CoachDailyBrief(
          kind: CoachDailyBriefKind.nutrition,
          title: t('One useful decision now', 'قرار واحد مفيد الآن'),
          message: f(
            'You have about {protein} g protein and {calories} kcal remaining today. Choose the protein source first.',
            'بقي لك قرابة {protein} غ بروتين و{calories} سعرة اليوم. اختر مصدر البروتين أولًا.',
            {'protein': proteinLeft.round(), 'calories': caloriesLeft.round()},
          ),
          actionLabel: t('Help me choose', 'ساعدني أختار'),
          suggestedPrompt: t(
            'Choose the best protein option for what remains today',
            'اختر لي أفضل مصدر بروتين حسب المتبقي اليوم',
          ),
          evidenceLabel: f(
            '{consumed} of {target} g logged',
            'مسجل {consumed} من {target} غ',
            {
              'consumed': consumedProtein.clamp(0, proteinTarget).round(),
              'target': proteinTarget.round(),
            },
          ),
          readiness: readiness,
        );
      }
    }

    final recentActivity = context.activityHistory.firstOrNull;
    final sleep = (recentActivity?['sleepHours'] as num?)?.toDouble();
    if (sleep != null && sleep > 0 && sleep < 6) {
      return CoachDailyBrief(
        kind: CoachDailyBriefKind.recovery,
        title: t('Protect your energy today', 'احمِ طاقتك اليوم'),
        message: f(
          'Your latest sleep log is {hours} hours. Keep today flexible and decide training intensity after checking how you feel.',
          'آخر نوم مسجل {hours} ساعة. خلّ اليوم مرنًا وحدد شدة التمرين بعد تقييم طاقتك.',
          {'hours': sleep.toStringAsFixed(1)},
        ),
        actionLabel: t('Adjust my day', 'عدّل يومي'),
        suggestedPrompt: t(
          'Adjust today around my latest sleep and activity',
          'عدّل يومي حسب آخر نوم ونشاط مسجل',
        ),
        evidenceLabel: t('Latest check-in', 'آخر تسجيل'),
        readiness: readiness,
      );
    }

    if (context.weights.length >= 3) {
      final latest = context.weights.first.kg;
      final oldest = context.weights.take(7).last.kg;
      final delta = latest - oldest;
      final direction = delta.abs() < .3
          ? t('stable', 'مستقر')
          : delta < 0
          ? t('moving down', 'يتجه للأسفل')
          : t('moving up', 'يتجه للأعلى');
      return CoachDailyBrief(
        kind: CoachDailyBriefKind.trend,
        title: t('BIL is learning your trend', 'BIL يتعلم اتجاهك'),
        message: f(
          'Across your recent comparable entries, weight is {direction}. I can separate the trend from normal daily noise before suggesting a change.',
          'عبر قياساتك الأخيرة المتقاربة، الوزن {direction}. أستطيع فصل الاتجاه عن ضوضاء اليوم قبل اقتراح أي تغيير.',
          {'direction': direction},
        ),
        actionLabel: t('Explain my trend', 'فسّر اتجاهي'),
        suggestedPrompt: t(
          'Explain my recent weight trend without overreacting to one day',
          'فسّر اتجاه وزني الأخير دون المبالغة في يوم واحد',
        ),
        evidenceLabel: f('{count} recent weigh-ins', '{count} قياسات حديثة', {
          'count': context.weights.take(7).length,
        }),
        readiness: readiness,
      );
    }

    if (context.profile.isEmpty) {
      return CoachDailyBrief(
        kind: CoachDailyBriefKind.onboarding,
        title: t('Let’s make the first decision', 'لنأخذ أول قرار معًا'),
        message: t(
          'Tell me your goal or photograph your next meal. I can start helping today and become more personal with each check-in.',
          'قل لي هدفك أو صوّر وجبتك القادمة. أستطيع مساعدتك اليوم وأصبح أدق مع كل تسجيل.',
        ),
        actionLabel: t('Tell BIL my goal', 'أخبر BIL بهدفي'),
        suggestedPrompt: t(
          'Help me choose one realistic goal to start today',
          'ساعدني أختار هدفًا واقعيًا واحدًا أبدأ به اليوم',
        ),
        evidenceLabel: t('Day-one guidance', 'توجيه من اليوم الأول'),
        readiness: readiness,
      );
    }

    return CoachDailyBrief(
      kind: CoachDailyBriefKind.steady,
      title: t('I’m ready for today', 'أنا جاهز ليومك'),
      message: t(
        'Log one meal, weight, sleep, or activity and I’ll turn it into the next useful decision—not another dashboard.',
        'سجّل وجبة أو وزنًا أو نومًا أو نشاطًا وسأحوّله إلى القرار المفيد التالي، لا إلى لوحة أرقام أخرى.',
      ),
      actionLabel: t('Review today', 'راجع يومي'),
      suggestedPrompt: t(
        'Review today and give me one next step',
        'راجع يومي وأعطني خطوة واحدة تالية',
      ),
      evidenceLabel: t('Verified BIL data only', 'بيانات BIL الموثقة فقط'),
      readiness: readiness,
    );
  }

  double _readiness(CoachContextSnapshot context) {
    var signals = 0;
    if (context.profile.isNotEmpty) signals++;
    if (context.weights.isNotEmpty) signals++;
    if (context.nutritionDays.isNotEmpty) signals++;
    if (context.activityHistory.isNotEmpty) signals++;
    if (context.explicitMemories.isNotEmpty ||
        context.decisionMemory.isNotEmpty) {
      signals++;
    }
    return (signals / 5).clamp(0, 1);
  }
}
