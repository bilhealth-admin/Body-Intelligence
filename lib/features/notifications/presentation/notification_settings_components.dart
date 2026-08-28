part of 'notification_settings_page.dart';

class _ReferencePushToggle extends StatelessWidget {
  const _ReferencePushToggle({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.enabled,
  });
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: value,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(label),
    enabled: enabled,
    onChanged: enabled ? (value) => onChanged(value ?? false) : null,
  );
}

/* LEGACY_COPY_REMOVED
class _NotificationSettingsCopy {
  const _NotificationSettingsCopy({
    required this.title,
    required this.intro,
    required this.permissionError,
    required this.labels,
  });

  factory _NotificationSettingsCopy.forLanguage(String languageCode) =>
      _copies[languageCode] ?? _copies['en']!;

  final String title;
  final String intro;
  final String permissionError;
  final Map<DailyReminderKind, String> labels;

  String label(DailyReminderKind kind) => labels[kind]!;
}

const _copies = <String, _NotificationSettingsCopy>{
  'ar': _NotificationSettingsCopy(
    title: 'التنبيهات اليومية',
    intro:
        'أنت تختار ما يصلك ومتى. نص التنبيه خاص ولا يعرض قياسات صحية على شاشة القفل.',
    permissionError:
        'تعذر تفعيل التنبيه. تحقق من إذن الإشعارات في إعدادات الجهاز.',
    labels: {
      DailyReminderKind.weight: 'قياس الوزن',
      DailyReminderKind.meals: 'تسجيل الوجبات',
      DailyReminderKind.water: 'تسجيل الماء',
      DailyReminderKind.weeklyReview: 'المراجعة الأسبوعية',
    },
  ),
  'en': _NotificationSettingsCopy(
    title: 'Daily reminders',
    intro:
        'You choose what arrives and when. Reminder copy is private and never exposes health measurements on the lock screen.',
    permissionError:
        'The reminder could not be enabled. Check notification permission in device settings.',
    labels: {
      DailyReminderKind.weight: 'Weight check-in',
      DailyReminderKind.meals: 'Meal logging',
      DailyReminderKind.water: 'Water logging',
      DailyReminderKind.weeklyReview: 'Weekly review',
    },
  ),
  'fr': _NotificationSettingsCopy(
    title: 'Rappels quotidiens',
    intro:
        'Vous choisissez les rappels et leur heure. Aucun indicateur de santé ne s’affiche sur l’écran verrouillé.',
    permissionError:
        'Impossible d’activer le rappel. Vérifiez l’autorisation des notifications.',
    labels: {
      DailyReminderKind.weight: 'Mesure du poids',
      DailyReminderKind.meals: 'Journal des repas',
      DailyReminderKind.water: 'Journal de l’eau',
      DailyReminderKind.weeklyReview: 'Bilan hebdomadaire',
    },
  ),
  'es': _NotificationSettingsCopy(
    title: 'Recordatorios diarios',
    intro:
        'Tú eliges qué recibir y cuándo. La pantalla bloqueada no muestra mediciones de salud.',
    permissionError:
        'No se pudo activar el recordatorio. Revisa el permiso de notificaciones.',
    labels: {
      DailyReminderKind.weight: 'Control de peso',
      DailyReminderKind.meals: 'Registro de comidas',
      DailyReminderKind.water: 'Registro de agua',
      DailyReminderKind.weeklyReview: 'Revisión semanal',
    },
  ),
  'tr': _NotificationSettingsCopy(
    title: 'Günlük hatırlatıcılar',
    intro:
        'Neyin ne zaman geleceğini siz seçersiniz. Kilit ekranında sağlık ölçümü gösterilmez.',
    permissionError:
        'Hatırlatıcı etkinleştirilemedi. Bildirim iznini kontrol edin.',
    labels: {
      DailyReminderKind.weight: 'Kilo kontrolü',
      DailyReminderKind.meals: 'Öğün kaydı',
      DailyReminderKind.water: 'Su kaydı',
      DailyReminderKind.weeklyReview: 'Haftalık değerlendirme',
    },
  ),
};
*/
