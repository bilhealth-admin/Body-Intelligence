import 'bil_locale_policy.dart';

/// Presentation-only metric copy for My Plan (BIL-13/BIL-27).
/// Counts come from the existing plan data; these strings do not change it.
abstract final class SmartPlanVisualRuntimeCopy {
  static const onlyConfirmed =
      'Only confirmed sessions count as completed.';
  static const scheduled = 'Scheduled';
  static const daysInPlan = 'Days in plan';
  static const scheduledWorkouts = 'Scheduled workouts';

  static const sources = <String>{
    onlyConfirmed,
    scheduled,
    daysInPlan,
    scheduledWorkouts,
  };

  static const values = <String, Map<String, String>>{
    onlyConfirmed: {
      'en': onlyConfirmed,
      'ar': 'تُحتسب الجلسات المؤكدة فقط بوصفها مكتملة.',
      'fr': 'Seules les séances confirmées comptent comme terminées.',
      'es': 'Solo las sesiones confirmadas cuentan como completadas.',
      'tr': 'Yalnızca onaylanan seanslar tamamlanmış sayılır.',
      'de': 'Nur bestätigte Einheiten zählen als abgeschlossen.',
      'it': 'Solo le sessioni confermate contano come completate.',
      'pt-BR': 'Somente sessões confirmadas contam como concluídas.',
      'pt-PT': 'Apenas as sessões confirmadas contam como concluídas.',
      'ur': 'صرف تصدیق شدہ سیشن مکمل شمار ہوتے ہیں۔',
      'fa': 'فقط جلسه‌های تأییدشده تکمیل‌شده محسوب می‌شوند.',
      'hi': 'केवल पुष्टि किए गए सत्र पूरे माने जाते हैं।',
      'id': 'Hanya sesi yang dikonfirmasi dihitung selesai.',
      'ms': 'Hanya sesi yang disahkan dikira selesai.',
      'ja': '完了として数えるのは確認済みのセッションのみです。',
      'ko': '확인된 세션만 완료로 계산됩니다.',
      'zh-Hans': '只有已确认的训练才计为完成。',
      'zh-Hant': '只有已確認的訓練才計為完成。',
      'ru': 'Завершёнными считаются только подтверждённые занятия.',
      'bn': 'শুধু নিশ্চিত করা সেশন সম্পন্ন হিসেবে গণনা করা হয়।',
      'vi': 'Chỉ các buổi đã xác nhận mới được tính là hoàn thành.',
      'th': 'นับเฉพาะเซสชันที่ยืนยันแล้วว่าเสร็จสิ้น',
      'pl': 'Tylko potwierdzone sesje liczą się jako ukończone.',
      'nl': 'Alleen bevestigde sessies tellen als voltooid.',
      'uk': 'Завершеними вважаються лише підтверджені заняття.',
    },
    scheduled: {
      'en': scheduled,
      'ar': 'المجدولة',
      'fr': 'Planifiées',
      'es': 'Programadas',
      'tr': 'Planlanan',
      'de': 'Geplant',
      'it': 'Programmate',
      'pt-BR': 'Programadas',
      'pt-PT': 'Agendadas',
      'ur': 'طے شدہ',
      'fa': 'برنامه‌ریزی‌شده',
      'hi': 'निर्धारित',
      'id': 'Terjadwal',
      'ms': 'Dijadualkan',
      'ja': '予定済み',
      'ko': '예정됨',
      'zh-Hans': '已安排',
      'zh-Hant': '已排定',
      'ru': 'Запланировано',
      'bn': 'নির্ধারিত',
      'vi': 'Đã lên lịch',
      'th': 'ตามกำหนด',
      'pl': 'Zaplanowane',
      'nl': 'Gepland',
      'uk': 'Заплановано',
    },
    daysInPlan: {
      'en': daysInPlan,
      'ar': 'أيام الخطة',
      'fr': 'Jours du programme',
      'es': 'Días del plan',
      'tr': 'Plandaki günler',
      'de': 'Tage im Plan',
      'it': 'Giorni del piano',
      'pt-BR': 'Dias no plano',
      'pt-PT': 'Dias no plano',
      'ur': 'منصوبے میں دن',
      'fa': 'روزهای برنامه',
      'hi': 'योजना में दिन',
      'id': 'Hari dalam rencana',
      'ms': 'Hari dalam pelan',
      'ja': 'プランの日数',
      'ko': '계획 일수',
      'zh-Hans': '计划天数',
      'zh-Hant': '計畫天數',
      'ru': 'Дней в плане',
      'bn': 'পরিকল্পনায় দিনের সংখ্যা',
      'vi': 'Số ngày trong kế hoạch',
      'th': 'จำนวนวันในแผน',
      'pl': 'Dni w planie',
      'nl': 'Dagen in het plan',
      'uk': 'Днів у плані',
    },
    scheduledWorkouts: {
      'en': scheduledWorkouts,
      'ar': 'التمارين المجدولة',
      'fr': 'Entraînements planifiés',
      'es': 'Entrenamientos programados',
      'tr': 'Planlanan antrenmanlar',
      'de': 'Geplante Trainingseinheiten',
      'it': 'Allenamenti programmati',
      'pt-BR': 'Treinos agendados',
      'pt-PT': 'Treinos agendados',
      'ur': 'طے شدہ ورزشیں',
      'fa': 'تمرین‌های برنامه‌ریزی‌شده',
      'hi': 'निर्धारित वर्कआउट',
      'id': 'Latihan terjadwal',
      'ms': 'Senaman berjadual',
      'ja': '予定されているワークアウト',
      'ko': '예정된 운동',
      'zh-Hans': '已安排的训练',
      'zh-Hant': '已排定的訓練',
      'ru': 'Запланированные тренировки',
      'bn': 'নির্ধারিত ওয়ার্কআউট',
      'vi': 'Buổi tập đã lên lịch',
      'th': 'การออกกำลังกายตามกำหนด',
      'pl': 'Zaplanowane treningi',
      'nl': 'Geplande trainingen',
      'uk': 'Заплановані тренування',
    },
  };

  static String? resolve(String english, String localeTag) {
    final translations = values[english];
    if (translations == null) return null;
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final tag in BilLocalePolicy.productionTags) {
      if (tag.toLowerCase() == normalized) return translations[tag];
    }
    return translations[normalized.split('-').first] ?? translations['en'];
  }

  static bool get balanced => values.keys.toSet().containsAll(sources) &&
      sources.every(
        (source) => BilLocalePolicy.productionTags.every((tag) {
          final translated = values[source]?[tag];
          return translated != null &&
              translated.trim().isNotEmpty &&
              (tag == 'en' || translated != source);
        }),
      );
}
