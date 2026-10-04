part of 'notification_settings_page.dart';

extension _NotificationSettingsCopyHelpers on _NotificationSettingsPageState {
  String _referenceLabel(String english) {
    final values = const {
      'I receive a new message': [
        'عندما أتلقى رسالة جديدة',
        'Je reçois un nouveau message',
        'Recibo un mensaje nuevo',
        'Yeni bir mesaj aldığımda',
      ],
      'I receive a new friend request': [
        'عندما أتلقى طلب صداقة جديدًا',
        'Je reçois une nouvelle demande d’ami',
        'Recibo una solicitud de amistad',
        'Yeni bir arkadaşlık isteği aldığımda',
      ],
      'Someone accepts my friend request': [
        'عندما يقبل شخص طلب صداقتي',
        'Quelqu’un accepte ma demande d’ami',
        'Alguien acepta mi solicitud de amistad',
        'Birisi arkadaşlık isteğimi kabul ettiğinde',
      ],
      'One of my friends logs a workout': [
        'عندما يسجل أحد أصدقائي تمرينًا',
        'Un ami enregistre un entraînement',
        'Un amigo registra un entrenamiento',
        'Bir arkadaşım antrenman kaydettiğinde',
      ],
      'One of my friends hits a login streak': [
        'عندما يحقق أحد أصدقائي سلسلة دخول',
        'Un ami atteint une série de connexions',
        'Un amigo alcanza una racha de inicio',
        'Bir arkadaşım giriş serisine ulaştığında',
      ],
      'I reach my step goal': [
        'عندما أصل إلى هدف الخطوات',
        'J’atteins mon objectif de pas',
        'Alcanzo mi objetivo de pasos',
        'Adım hedefime ulaştığımda',
      ],
    }[english];
    if (values == null || _languageCode == 'en') return english;
    final authored = const {'ar': 0, 'fr': 1, 'es': 2, 'tr': 3}[_languageCode];
    if (authored != null) return values[authored];
    return RuntimeCopy.resolve(english, _languageCode) ?? english;
  }

  String _quietText(String english) {
    const values = <String, Map<String, String>>{
      'Quiet hours for daily reminders': {
        'ar': 'ساعات الهدوء للتذكيرات اليومية',
        'fr': 'Heures de silence pour les rappels quotidiens',
        'es': 'Horas de silencio para los recordatorios diarios',
        'tr': 'Günlük hatırlatıcılar için sessiz saatler',
      },
      'Starts': {
        'ar': 'يبدأ',
        'fr': 'Début',
        'es': 'Inicio',
        'tr': 'Başlangıç',
      },
      'Ends': {'ar': 'ينتهي', 'fr': 'Fin', 'es': 'Fin', 'tr': 'Bitiş'},
      'Push categories control lock-screen delivery. Updates can still appear inside BIL.': {
        'ar':
            'تتحكم الفئات في إشعارات شاشة القفل. وقد تظل التحديثات ظاهرة داخل BIL.',
        'fr':
            'Les catégories contrôlent les notifications sur l’écran verrouillé. Les mises à jour restent visibles dans BIL.',
        'es':
            'Las categorías controlan las notificaciones de la pantalla bloqueada. Las novedades siguen visibles en BIL.',
        'tr':
            'Kategoriler kilit ekranı bildirimlerini denetler. Güncellemeler BIL içinde görünmeye devam edebilir.',
      },
    };
    if (_languageCode == 'en') return english;
    return values[english]?[_languageCode] ??
        RuntimeCopy.resolve(english, _languageCode) ??
        english;
  }

  String _phoneText(
    String english, {
    required String ar,
    required String fr,
    required String es,
    required String tr,
  }) => switch (_languageCode) {
    'ar' => ar,
    'fr' => fr,
    'es' => es,
    'tr' => tr,
    _ =>
      RuntimeCopy.resolve(
            english,
            Localizations.localeOf(context).toLanguageTag(),
          ) ??
          english,
  };

  String _formatMinutes(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  Future<void> _chooseQuietTime({required bool start}) async {
    final current = _deliveryPreferences!;
    final minutes = start ? current.quietStartMinutes : current.quietEndMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (selected == null) return;
    final selectedMinutes = selected.hour * 60 + selected.minute;
    await _saveDelivery(
      start
          ? current.copyWith(quietStartMinutes: selectedMinutes)
          : current.copyWith(quietEndMinutes: selectedMinutes),
    );
  }

  BilSemanticIconKind _semanticKind(DailyReminderKind kind) => switch (kind) {
    DailyReminderKind.weight => BilSemanticIconKind.weight,
    DailyReminderKind.meals => BilSemanticIconKind.meal,
    DailyReminderKind.water => BilSemanticIconKind.water,
    DailyReminderKind.sleep => BilSemanticIconKind.sleep,
    DailyReminderKind.fasting => BilSemanticIconKind.fasting,
    DailyReminderKind.weeklyReview => BilSemanticIconKind.report,
    DailyReminderKind.returnAfter24Hours => BilSemanticIconKind.notifications,
  };
}
