import '../domain/daily_reminder.dart';
import '../../../app/localization/runtime_copy.dart';

class NotificationSettingsCopy {
  const NotificationSettingsCopy({
    required this.title,
    required this.intro,
    required this.permissionError,
    required this.labels,
  });

  factory NotificationSettingsCopy.forLanguage(String languageCode) {
    final authored = copies[languageCode];
    if (authored != null) return authored;
    final english = copies['en']!;
    String resolve(String value) =>
        RuntimeCopy.resolve(value, languageCode) ?? value;
    return NotificationSettingsCopy(
      title: resolve(english.title),
      intro: resolve(english.intro),
      permissionError: resolve(english.permissionError),
      labels: {
        for (final entry in english.labels.entries)
          entry.key: resolve(entry.value),
      },
    );
  }

  final String title;
  final String intro;
  final String permissionError;
  final Map<DailyReminderKind, String> labels;

  String label(DailyReminderKind kind) => labels[kind]!;
}

const copies = <String, NotificationSettingsCopy>{
  'ar': NotificationSettingsCopy(
    title: 'التنبيهات اليومية',
    intro: 'أنت تختار ما يصلك ومتى. لا نعرض قياساتك الصحية على شاشة القفل.',
    permissionError:
        'تعذّر تفعيل التنبيه. تحقق من إذن الإشعارات في إعدادات الجهاز.',
    labels: {
      DailyReminderKind.weight: 'قياس الوزن',
      DailyReminderKind.meals: 'تسجيل الوجبات',
      DailyReminderKind.water: 'تسجيل الماء',
      DailyReminderKind.sleep: 'تسجيل النوم',
      DailyReminderKind.fasting: 'متابعة الصيام المتقطع',
      DailyReminderKind.weeklyReview: 'المراجعة الأسبوعية',
      DailyReminderKind.returnAfter24Hours: 'تذكير العودة بعد 24 ساعة',
    },
  ),
  'en': NotificationSettingsCopy(
    title: 'Daily reminders',
    intro:
        'You choose what arrives and when. Health measurements never appear on the lock screen.',
    permissionError:
        'The reminder could not be enabled. Check notification permission in device settings.',
    labels: {
      DailyReminderKind.weight: 'Weight check-in',
      DailyReminderKind.meals: 'Meal logging',
      DailyReminderKind.water: 'Water logging',
      DailyReminderKind.sleep: 'Sleep check-in',
      DailyReminderKind.fasting: 'Intermittent fasting check-in',
      DailyReminderKind.weeklyReview: 'Weekly review',
      DailyReminderKind.returnAfter24Hours: 'Return after 24 hours',
    },
  ),
  'fr': NotificationSettingsCopy(
    title: 'Rappels quotidiens',
    intro:
        'Vous choisissez les rappels et leur heure. Aucune mesure de santé ne s’affiche sur l’écran verrouillé.',
    permissionError:
        'Impossible d’activer le rappel. Vérifiez l’autorisation des notifications.',
    labels: {
      DailyReminderKind.weight: 'Mesure du poids',
      DailyReminderKind.meals: 'Journal des repas',
      DailyReminderKind.water: 'Journal de l’eau',
      DailyReminderKind.sleep: 'Journal du sommeil',
      DailyReminderKind.fasting: 'Suivi du jeûne intermittent',
      DailyReminderKind.weeklyReview: 'Bilan hebdomadaire',
      DailyReminderKind.returnAfter24Hours: 'Retour après 24 heures',
    },
  ),
  'es': NotificationSettingsCopy(
    title: 'Recordatorios diarios',
    intro:
        'Tú eliges qué recibir y cuándo. La pantalla bloqueada no muestra mediciones de salud.',
    permissionError:
        'No se pudo activar el recordatorio. Revisa el permiso de notificaciones.',
    labels: {
      DailyReminderKind.weight: 'Control de peso',
      DailyReminderKind.meals: 'Registro de comidas',
      DailyReminderKind.water: 'Registro de agua',
      DailyReminderKind.sleep: 'Registro del sueño',
      DailyReminderKind.fasting: 'Seguimiento del ayuno intermitente',
      DailyReminderKind.weeklyReview: 'Revisión semanal',
      DailyReminderKind.returnAfter24Hours: 'Volver después de 24 horas',
    },
  ),
  'tr': NotificationSettingsCopy(
    title: 'Günlük hatırlatıcılar',
    intro:
        'Neyin ne zaman geleceğini siz seçersiniz. Kilit ekranında sağlık ölçümü gösterilmez.',
    permissionError:
        'Hatırlatıcı etkinleştirilemedi. Bildirim iznini kontrol edin.',
    labels: {
      DailyReminderKind.weight: 'Kilo kontrolü',
      DailyReminderKind.meals: 'Öğün kaydı',
      DailyReminderKind.water: 'Su kaydı',
      DailyReminderKind.sleep: 'Uyku kaydı',
      DailyReminderKind.fasting: 'Aralıklı oruç takibi',
      DailyReminderKind.weeklyReview: 'Haftalık değerlendirme',
      DailyReminderKind.returnAfter24Hours: '24 saat sonra geri dön',
    },
  ),
};
