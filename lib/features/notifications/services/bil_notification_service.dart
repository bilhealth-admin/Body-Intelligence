import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/daily_reminder.dart';
import '../domain/notification_delivery_preferences.dart';

class BilNotificationService {
  BilNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const fastingTargetNotificationId = 14016;
  static const inactivityNotificationId = 14024;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on tz.LocationNotFoundException {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final apple = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ??
        await apple?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
  }

  Future<void> schedule(
    DailyReminder reminder, {
    required String languageCode,
    NotificationDeliveryPreferences preferences =
        const NotificationDeliveryPreferences(),
  }) async {
    await initialize();
    await _plugin.cancel(id: reminder.notificationId);
    if (!reminder.enabled) return;
    if (reminder.kind == DailyReminderKind.returnAfter24Hours) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.hour,
      reminder.minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    if (preferences.isQuietAt(at.hour, at.minute)) {
      final endHour = preferences.quietEndMinutes ~/ 60;
      final endMinute = preferences.quietEndMinutes % 60;
      var quietEnd = tz.TZDateTime(
        tz.local,
        at.year,
        at.month,
        at.day,
        endHour,
        endMinute,
      );
      if (!quietEnd.isAfter(at)) {
        quietEnd = quietEnd.add(const Duration(days: 1));
      }
      at = quietEnd;
    }
    final copy = _copy(reminder.kind, languageCode);
    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      title: copy.$1,
      body: copy.$2,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bil_daily_health',
          'BIL daily health',
          channelDescription: 'Private reminders selected by the user.',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: reminder.kind.name,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> scheduleFastingTarget({
    required DateTime target,
    required String languageCode,
  }) async {
    await initialize();
    await _plugin.cancel(id: fastingTargetNotificationId);
    final now = tz.TZDateTime.now(tz.local);
    final at = tz.TZDateTime.from(target, tz.local);
    if (!at.isAfter(now)) return;
    final copy = _fastingTargetCopy[languageCode] ?? _fastingTargetCopy['en']!;
    await _plugin.zonedSchedule(
      id: fastingTargetNotificationId,
      title: copy.$1,
      body: copy.$2,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bil_fasting_target',
          'BIL fasting target',
          channelDescription: 'Optional fasting target reminders.',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'fasting_target',
    );
  }

  Future<void> cancelFastingTarget() =>
      _plugin.cancel(id: fastingTargetNotificationId);

  Future<void> scheduleReturnAfter24Hours({
    required DateTime leftAt,
    required String languageCode,
  }) async {
    await initialize();
    await _plugin.cancel(id: inactivityNotificationId);
    final at = tz.TZDateTime.from(
      leftAt.add(const Duration(hours: 24)),
      tz.local,
    );
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    final copy = _returnCopy[languageCode] ?? _returnCopy['en']!;
    await _plugin.zonedSchedule(
      id: inactivityNotificationId,
      title: copy.$1,
      body: copy.$2,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bil_private_checkins',
          'BIL private check-ins',
          channelDescription: 'Optional private reminders selected by you.',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'return_after_24_hours',
    );
  }

  Future<void> cancelReturnAfter24Hours() async {
    await initialize();
    await _plugin.cancel(id: inactivityNotificationId);
  }

  (String, String) _copy(DailyReminderKind kind, String languageCode) {
    final localized =
        _notificationCopy[languageCode] ?? _notificationCopy['en']!;
    return localized[kind]!;
  }
}

const _fastingTargetCopy = <String, (String, String)>{
  'ar': (
    'اكتملت نافذة الصيام المتقطع',
    'وصلت إلى مدة الصيام المتقطع التي اخترتها.',
  ),
  'en': (
    'Intermittent fasting window complete',
    'You reached your selected intermittent fasting time.',
  ),
  'fr': ('Fenêtre de jeûne terminée', 'Vous avez atteint la durée choisie.'),
  'es': (
    'Ventana de ayuno completada',
    'Alcanzaste el tiempo de ayuno elegido.',
  ),
  'tr': ('Oruç aralığı tamamlandı', 'Seçtiğiniz oruç süresine ulaştınız.'),
};

const _returnCopy = <String, (String, String)>{
  'ar': (
    'نحن هنا عندما تعود',
    'مرّ يوم منذ آخر زيارة. افتح BIL وسجّل ما يهمك فقط.',
  ),
  'en': (
    'Here when you are ready',
    'It has been a day. Open BIL and log only what matters to you.',
  ),
  'fr': (
    'À votre retour',
    'Une journée s’est écoulée. Ouvrez BIL et notez seulement ce qui compte.',
  ),
  'es': (
    'Aquí cuando quieras volver',
    'Ha pasado un día. Abre BIL y registra solo lo que te importe.',
  ),
  'tr': (
    'Hazır olduğunuzda buradayız',
    'Bir gün geçti. BIL’i açın ve yalnızca önemli olanı kaydedin.',
  ),
};

const _notificationCopy = <String, Map<DailyReminderKind, (String, String)>>{
  'ar': {
    DailyReminderKind.weight: (
      'قياس اليوم',
      'سجّل وزنك في ظروف متقاربة لتحسين دقة الاتجاه.',
    ),
    DailyReminderKind.meals: (
      'سجّل وجبتك',
      'دوّن ما تناولته الآن قبل أن تنسى التفاصيل.',
    ),
    DailyReminderKind.water: (
      'تذكير الماء',
      'سجّل مشروبك التالي ضمن هدفك اليومي.',
    ),
    DailyReminderKind.sleep: (
      'تسجيل النوم',
      'سجّل نومك عندما يناسبك لتحافظ على اكتمال يومك.',
    ),
    DailyReminderKind.fasting: (
      'متابعة الصيام المتقطع',
      'افتح مؤقت الصيام المتقطع لمراجعة حالتك أو بدء نافذة جديدة.',
    ),
    DailyReminderKind.weeklyReview: (
      'مراجعتك الأسبوعية جاهزة',
      'راجع القياسات والأدلة قبل تعديل خطتك.',
    ),
    DailyReminderKind.returnAfter24Hours: (
      'نحن هنا عندما تعود',
      'مرّ يوم منذ آخر زيارة. افتح BIL وسجّل ما يهمك فقط.',
    ),
  },
  'en': {
    DailyReminderKind.weight: (
      'Today’s check-in',
      'Log weight under consistent conditions.',
    ),
    DailyReminderKind.meals: (
      'Log your meal',
      'Capture what you ate while it is fresh.',
    ),
    DailyReminderKind.water: (
      'Water reminder',
      'Log your next drink toward today’s target.',
    ),
    DailyReminderKind.sleep: (
      'Sleep check-in',
      'Log sleep when it suits you to keep your day complete.',
    ),
    DailyReminderKind.fasting: (
      'Intermittent fasting check-in',
      'Open the intermittent fasting timer to review or begin a window.',
    ),
    DailyReminderKind.weeklyReview: (
      'Your weekly review is ready',
      'Review evidence before changing your plan.',
    ),
    DailyReminderKind.returnAfter24Hours: (
      'Here when you are ready',
      'It has been a day. Open BIL and log only what matters to you.',
    ),
  },
  'fr': {
    DailyReminderKind.weight: (
      'Mesure du jour',
      'Enregistrez votre poids dans des conditions constantes.',
    ),
    DailyReminderKind.meals: (
      'Enregistrez votre repas',
      'Notez ce que vous avez mangé pendant que vous vous en souvenez.',
    ),
    DailyReminderKind.water: (
      'Rappel d’eau',
      'Enregistrez votre prochaine boisson pour votre objectif du jour.',
    ),
    DailyReminderKind.sleep: (
      'Sommeil',
      'Enregistrez votre sommeil au moment qui vous convient.',
    ),
    DailyReminderKind.fasting: (
      'Suivi du jeûne',
      'Ouvrez le minuteur pour vérifier ou commencer une fenêtre.',
    ),
    DailyReminderKind.weeklyReview: (
      'Votre bilan hebdomadaire est prêt',
      'Examinez les données avant de modifier votre plan.',
    ),
    DailyReminderKind.returnAfter24Hours: (
      'À votre retour',
      'Une journée s’est écoulée. Ouvrez BIL et notez seulement ce qui compte.',
    ),
  },
  'es': {
    DailyReminderKind.weight: (
      'Medición de hoy',
      'Registra tu peso en condiciones constantes.',
    ),
    DailyReminderKind.meals: (
      'Registra tu comida',
      'Anota lo que comiste mientras lo recuerdas.',
    ),
    DailyReminderKind.water: (
      'Recordatorio de agua',
      'Registra tu próxima bebida para el objetivo de hoy.',
    ),
    DailyReminderKind.sleep: (
      'Registro del sueño',
      'Registra el sueño cuando te convenga.',
    ),
    DailyReminderKind.fasting: (
      'Seguimiento del ayuno',
      'Abre el temporizador para revisar o iniciar una ventana.',
    ),
    DailyReminderKind.weeklyReview: (
      'Tu revisión semanal está lista',
      'Revisa los datos antes de cambiar tu plan.',
    ),
    DailyReminderKind.returnAfter24Hours: (
      'Aquí cuando quieras volver',
      'Ha pasado un día. Abre BIL y registra solo lo que te importe.',
    ),
  },
  'tr': {
    DailyReminderKind.weight: (
      'Bugünün ölçümü',
      'Kilonuzu tutarlı koşullarda kaydedin.',
    ),
    DailyReminderKind.meals: (
      'Öğününüzü kaydedin',
      'Ne yediğinizi unutmadan kaydedin.',
    ),
    DailyReminderKind.water: (
      'Su hatırlatıcısı',
      'Bugünkü hedefiniz için sıradaki içeceği kaydedin.',
    ),
    DailyReminderKind.sleep: (
      'Uyku kaydı',
      'Uykunuzu size uygun olduğunda kaydedin.',
    ),
    DailyReminderKind.fasting: (
      'Oruç takibi',
      'Bir aralığı incelemek veya başlatmak için zamanlayıcıyı açın.',
    ),
    DailyReminderKind.weeklyReview: (
      'Haftalık değerlendirmeniz hazır',
      'Planınızı değiştirmeden önce verileri inceleyin.',
    ),
    DailyReminderKind.returnAfter24Hours: (
      'Hazır olduğunuzda buradayız',
      'Bir gün geçti. BIL’i açın ve yalnızca önemli olanı kaydedin.',
    ),
  },
};
