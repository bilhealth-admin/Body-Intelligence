import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/daily_reminder.dart';
import '../domain/notification_delivery_preferences.dart';
import 'bil_android_notification_presentation.dart';
import 'bil_notification_navigation.dart';
import 'notification_extended_copy.dart';

part 'bil_daily_notification_grouping.dart';

enum BilNotificationPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
}

class BilNotificationService {
  BilNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const fastingTargetNotificationId = 14016;
  static const fastingOngoingNotificationId = 14015;
  static const fastingHydrationNotificationIdBase = 14100;
  static const fastingHydrationNotificationSlots = 6;
  static const sleepWindDownNotificationId = 14220;
  static const sleepBedtimeNotificationId = 14221;
  static const sleepWakeNotificationId = 14222;
  static const inactivityNotificationId = 14024;
  static const activationTestNotificationId = 14001;
  static bool _androidLaunchDetailsHandled = false;
  bool _initialized = false;

  Future<void> initialize() => _initializeNotificationPlatform();

  Future<bool> areNotificationsEnabled() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<BilNotificationPermissionState> permissionState() async {
    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return BilNotificationPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return BilNotificationPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) {
      return BilNotificationPermissionState.restricted;
    }
    if (status.isDenied) return BilNotificationPermissionState.denied;
    return BilNotificationPermissionState.unknown;
  }

  Future<bool> openSystemSettings() => openAppSettings();

  Future<Set<int>> pendingNotificationIds() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
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

  Future<void> showActivationConfirmation({
    required String languageCode,
  }) async {
    await initialize();
    final copy = _backgroundCopy(
      _activationCopy,
      languageCode,
      BilBackgroundCopyKind.activation,
    );
    await _plugin.show(
      id: activationTestNotificationId,
      title: copy.$1,
      body: copy.$2,
      notificationDetails: NotificationDetails(
        android: BilAndroidNotificationPresentation.rich(
          channelId: 'bil_system_check',
          channelName: 'Notification test',
          channelDescription:
              'Confirms that private BIL reminders can reach this phone.',
          title: copy.$1,
          body: copy.$2,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: BilNotificationPayload.activation,
    );
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
    if (preferences.quietHoursEnabled &&
        preferences.quietStartMinutes == preferences.quietEndMinutes) {
      return;
    }
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
      notificationDetails: NotificationDetails(
        android: BilAndroidNotificationPresentation.rich(
          channelId: 'bil_daily_health',
          channelName: 'Daily reminders',
          channelDescription:
              'Private daily reminders you choose in Body Intelligence Log.',
          title: copy.$1,
          body: copy.$2,
          groupKey: BilAndroidNotificationPresentation.dailyGroupKey,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: BilNotificationPayload.forDaily(reminder.kind),
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
    final copy = _backgroundCopy(
      _fastingTargetCopy,
      languageCode,
      BilBackgroundCopyKind.fastingTarget,
    );
    await _plugin.zonedSchedule(
      id: fastingTargetNotificationId,
      title: copy.$1,
      body: copy.$2,
      scheduledDate: at,
      notificationDetails: NotificationDetails(
        android: BilAndroidNotificationPresentation.rich(
          channelId: 'bil_fasting_target',
          channelName: 'Fasting reminders',
          channelDescription: 'Optional reminders for your selected fast.',
          title: copy.$1,
          body: copy.$2,
          groupKey: 'com.bilhealth.bodyintelligencelog.FASTING',
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: BilNotificationPayload.fasting,
    );
  }

  Future<void> cancelFastingTarget() =>
      _plugin.cancel(id: fastingTargetNotificationId);

  /// Shows one Android-owned countdown. Android updates the chronometer
  /// without waking Dart every second; this is intentionally not a long-lived
  /// foreground service.
  Future<void> showFastingOngoing({
    required DateTime target,
    required String languageCode,
  }) async {
    await initialize();
    await _plugin.cancel(id: fastingOngoingNotificationId);
    if (defaultTargetPlatform != TargetPlatform.android ||
        !target.isAfter(DateTime.now())) {
      return;
    }
    final remainingMillis = target
        .difference(DateTime.now())
        .inMilliseconds
        .clamp(1, 48 * 60 * 60 * 1000);
    final copy = _backgroundCopy(
      _fastingOngoingCopy,
      languageCode,
      BilBackgroundCopyKind.fastingOngoing,
    );
    await _plugin.show(
      id: fastingOngoingNotificationId,
      title: copy.$1,
      body: copy.$2,
      notificationDetails: NotificationDetails(
        android: BilAndroidNotificationPresentation.rich(
          channelId: 'bil_fasting_active',
          channelName: 'Active fasting timer',
          channelDescription:
              'Persistent countdown while an intermittent fast is active.',
          title: copy.$1,
          body: copy.$2,
          importance: Importance.low,
          priority: Priority.low,
          groupKey: 'com.bilhealth.bodyintelligencelog.FASTING',
          ongoing: true,
          autoCancel: false,
          usesChronometer: true,
          chronometerCountDown: true,
          when: target.millisecondsSinceEpoch,
          showWhen: true,
          playSound: false,
          enableVibration: false,
          timeoutAfter: remainingMillis,
          category: AndroidNotificationCategory.progress,
        ),
      ),
      payload: BilNotificationPayload.fasting,
    );
  }

  /// Schedules bounded, best-effort hydration nudges every four hours while
  /// the current fast is active. Stable IDs make restart/timezone rescheduling
  /// idempotent and allow a complete cancel on end.
  Future<void> scheduleFastingHydration({
    required DateTime startedAt,
    required DateTime target,
    required String languageCode,
  }) async {
    await initialize();
    await _cancelFastingHydration();
    final now = tz.TZDateTime.now(tz.local);
    final end = tz.TZDateTime.from(target, tz.local);
    final copy = _backgroundCopy(
      _fastingHydrationCopy,
      languageCode,
      BilBackgroundCopyKind.fastingHydration,
    );
    var slot = 0;
    var at = tz.TZDateTime.from(
      startedAt.add(const Duration(hours: 4)),
      tz.local,
    );
    while (at.isBefore(end) && slot < fastingHydrationNotificationSlots) {
      if (at.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: fastingHydrationNotificationIdBase + slot,
          title: copy.$1,
          body: copy.$2,
          scheduledDate: at,
          notificationDetails: NotificationDetails(
            android: BilAndroidNotificationPresentation.rich(
              channelId: 'bil_fasting_hydration',
              channelName: 'Fasting hydration',
              channelDescription:
                  'Optional four-hour hydration reminders during an active fast.',
              title: copy.$1,
              body: copy.$2,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              groupKey: 'com.bilhealth.bodyintelligencelog.FASTING',
            ),
            iOS: const DarwinNotificationDetails(),
            macOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: BilNotificationPayload.fasting,
        );
      }
      slot += 1;
      at = at.add(const Duration(hours: 4));
    }
  }

  Future<void> cancelFastingSessionNotifications() async {
    await initialize();
    await _plugin.cancel(id: fastingOngoingNotificationId);
    await _plugin.cancel(id: fastingTargetNotificationId);
    await _cancelFastingHydration();
  }

  /// Installs three local-wall-clock daily reminders. Repeating by time lets
  /// Android/iOS recalculate the next occurrence after timezone or DST
  /// changes; no stale UTC offset is persisted.
  Future<void> scheduleSleepSchedule({
    required int bedHour,
    required int bedMinute,
    required int wakeHour,
    required int wakeMinute,
    required int windDownMinutes,
    required String languageCode,
  }) async {
    await initialize();
    await cancelSleepSchedule();
    final bedtime = bedHour * 60 + bedMinute;
    final windDown = (bedtime - windDownMinutes) % (24 * 60);
    await _scheduleSleepDaily(
      id: sleepWindDownNotificationId,
      hour: windDown ~/ 60,
      minute: windDown % 60,
      languageCode: languageCode,
      kind: _SleepNotificationKind.windDown,
    );
    await _scheduleSleepDaily(
      id: sleepBedtimeNotificationId,
      hour: bedHour,
      minute: bedMinute,
      languageCode: languageCode,
      kind: _SleepNotificationKind.bedtime,
    );
    await _scheduleSleepDaily(
      id: sleepWakeNotificationId,
      hour: wakeHour,
      minute: wakeMinute,
      languageCode: languageCode,
      kind: _SleepNotificationKind.wake,
    );
  }

  Future<void> cancelSleepSchedule() async {
    await initialize();
    await _plugin.cancel(id: sleepWindDownNotificationId);
    await _plugin.cancel(id: sleepBedtimeNotificationId);
    await _plugin.cancel(id: sleepWakeNotificationId);
  }

  Future<void> _scheduleSleepDaily({
    required int id,
    required int hour,
    required int minute,
    required String languageCode,
    required _SleepNotificationKind kind,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    final copy = _sleepCopy(languageCode, kind);
    await _plugin.zonedSchedule(
      id: id,
      title: copy.$1,
      body: copy.$2,
      scheduledDate: at,
      notificationDetails: NotificationDetails(
        android: BilAndroidNotificationPresentation.rich(
          channelId: 'bil_sleep_schedule',
          channelName: 'Sleep schedule',
          channelDescription:
              'Optional wind-down, bedtime and wake reminders selected by the user.',
          title: copy.$1,
          body: copy.$2,
          groupKey: 'com.bilhealth.bodyintelligencelog.SLEEP',
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: BilNotificationPayload.sleep,
    );
  }

  Future<void> _cancelFastingHydration() async {
    for (var slot = 0; slot < fastingHydrationNotificationSlots; slot++) {
      await _plugin.cancel(id: fastingHydrationNotificationIdBase + slot);
    }
  }

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
    final copy = _backgroundCopy(
      _returnCopy,
      languageCode,
      BilBackgroundCopyKind.returnAfterDay,
    );
    await _plugin.zonedSchedule(
      id: inactivityNotificationId,
      title: copy.$1,
      body: copy.$2,
      scheduledDate: at,
      notificationDetails: NotificationDetails(
        android: BilAndroidNotificationPresentation.rich(
          channelId: 'bil_private_checkins',
          channelName: 'Private check-ins',
          channelDescription: 'Optional private reminders selected by you.',
          title: copy.$1,
          body: copy.$2,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: BilNotificationPayload.dashboard,
    );
  }

  Future<void> cancelReturnAfter24Hours() async {
    await initialize();
    await _plugin.cancel(id: inactivityNotificationId);
  }

  (String, String) _copy(DailyReminderKind kind, String languageCode) {
    final localized = _notificationCopy[languageCode];
    if (localized != null) return localized[kind]!;
    final extended = bilExtendedNotificationCopy(
      languageCode,
      BilBackgroundCopyKind.dailyReminder,
    );
    return extended ?? _notificationCopy['en']![kind]!;
  }
}

enum _SleepNotificationKind { windDown, bedtime, wake }

(String, String) _sleepCopy(String localeTag, _SleepNotificationKind kind) {
  final language = localeTag
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-')
      .first;
  return _sleepScheduleCopy[language]?[kind] ??
      bilExtendedNotificationCopy(
        localeTag,
        BilBackgroundCopyKind.dailyReminder,
      ) ??
      _sleepScheduleCopy['en']![kind]!;
}

@visibleForTesting
List<(String, String)> bilSleepScheduleCopyForTesting(
  String localeTag,
) => <(String, String)>[
  for (final kind in _SleepNotificationKind.values) _sleepCopy(localeTag, kind),
];

const _sleepScheduleCopy =
    <String, Map<_SleepNotificationKind, (String, String)>>{
      'ar': {
        _SleepNotificationKind.windDown: (
          'حان وقت الاسترخاء',
          'خفّف الإضاءة واستعد لوقت نومك الذي اخترته.',
        ),
        _SleepNotificationKind.bedtime: (
          'حان وقت النوم',
          'ابدأ روتين نومك عندما تكون مستعدًا.',
        ),
        _SleepNotificationKind.wake: (
          'صباح الخير',
          'يمكنك تسجيل نوم الليلة الماضية في BIL.',
        ),
      },
      'en': {
        _SleepNotificationKind.windDown: (
          'Time to wind down',
          'Dim the lights and prepare for your chosen bedtime.',
        ),
        _SleepNotificationKind.bedtime: (
          'Bedtime',
          'Begin your sleep routine when you are ready.',
        ),
        _SleepNotificationKind.wake: (
          'Good morning',
          'You can record last night’s sleep in BIL.',
        ),
      },
      'fr': {
        _SleepNotificationKind.windDown: (
          'Il est temps de ralentir',
          'Baissez la lumière et préparez votre heure de coucher.',
        ),
        _SleepNotificationKind.bedtime: (
          'Heure du coucher',
          'Commencez votre routine de sommeil quand vous êtes prêt.',
        ),
        _SleepNotificationKind.wake: (
          'Bonjour',
          'Vous pouvez noter le sommeil de la nuit dans BIL.',
        ),
      },
      'es': {
        _SleepNotificationKind.windDown: (
          'Hora de relajarse',
          'Baja las luces y prepárate para la hora de dormir elegida.',
        ),
        _SleepNotificationKind.bedtime: (
          'Hora de dormir',
          'Empieza tu rutina de sueño cuando estés listo.',
        ),
        _SleepNotificationKind.wake: (
          'Buenos días',
          'Puedes registrar el sueño de anoche en BIL.',
        ),
      },
      'tr': {
        _SleepNotificationKind.windDown: (
          'Sakinleşme zamanı',
          'Işıkları azaltın ve seçtiğiniz uyku saatine hazırlanın.',
        ),
        _SleepNotificationKind.bedtime: (
          'Uyku zamanı',
          'Hazır olduğunuzda uyku rutininize başlayın.',
        ),
        _SleepNotificationKind.wake: (
          'Günaydın',
          'Dünkü uykunuzu BIL’e kaydedebilirsiniz.',
        ),
      },
    };

(String, String) _backgroundCopy(
  Map<String, (String, String)> base,
  String localeTag,
  BilBackgroundCopyKind kind,
) {
  final language = localeTag
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-')
      .first;
  return base[language] ??
      bilExtendedNotificationCopy(localeTag, kind) ??
      base['en']!;
}

@visibleForTesting
(String, String) bilBackgroundCopyForTesting(
  String localeTag,
  BilBackgroundCopyKind kind,
) {
  final base = switch (kind) {
    BilBackgroundCopyKind.activation => _activationCopy,
    BilBackgroundCopyKind.fastingTarget => _fastingTargetCopy,
    BilBackgroundCopyKind.fastingOngoing => _fastingOngoingCopy,
    BilBackgroundCopyKind.fastingHydration => _fastingHydrationCopy,
    BilBackgroundCopyKind.returnAfterDay => _returnCopy,
    BilBackgroundCopyKind.dailyReminder => const <String, (String, String)>{
      'ar': (
        'تذكير صحي من BIL',
        'افتح BIL لمراجعة سجلك الصحي الخاص أو تحديثه.',
      ),
      'en': (
        'BIL health reminder',
        'Open BIL to review or update your private health log.',
      ),
      'fr': (
        'Rappel santé BIL',
        'Ouvrez BIL pour consulter ou mettre à jour votre journal de santé privé.',
      ),
      'es': (
        'Recordatorio de salud BIL',
        'Abre BIL para revisar o actualizar tu registro de salud privado.',
      ),
      'tr': (
        'BIL sağlık hatırlatıcısı',
        'Özel sağlık kaydınızı incelemek veya güncellemek için BIL’i açın.',
      ),
    },
  };
  return _backgroundCopy(base, localeTag, kind);
}

@visibleForTesting
(String, String) bilDailyReminderCopyForTesting(
  String localeTag,
  DailyReminderKind kind,
) {
  final language = localeTag
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-')
      .first;
  final localized = _notificationCopy[language];
  return localized?[kind] ??
      bilExtendedNotificationCopy(
        localeTag,
        BilBackgroundCopyKind.dailyReminder,
      ) ??
      _notificationCopy['en']![kind]!;
}

const _activationCopy = <String, (String, String)>{
  'ar': (
    'إشعارات BIL تعمل',
    'تم التحقق بنجاح. ستصل تذكيراتك الخاصة على هذا الهاتف.',
  ),
  'en': (
    'BIL notifications are active',
    'Check complete. Your private reminders can reach this phone.',
  ),
  'fr': (
    'Les notifications BIL sont actives',
    'Vérification réussie. Vos rappels privés peuvent arriver sur ce téléphone.',
  ),
  'es': (
    'Las notificaciones de BIL están activas',
    'Comprobación completa. Tus recordatorios privados llegarán a este teléfono.',
  ),
  'tr': (
    'BIL bildirimleri etkin',
    'Kontrol tamamlandı. Özel hatırlatıcılarınız bu telefona ulaşabilir.',
  ),
};

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

const _fastingOngoingCopy = <String, (String, String)>{
  'ar': ('الصيام المتقطع مستمر', 'اضغط لفتح مؤقت الصيام في BIL.'),
  'en': (
    'Intermittent fast in progress',
    'Tap to open your BIL fasting timer.',
  ),
  'fr': ('Jeûne intermittent en cours', 'Touchez pour ouvrir le minuteur BIL.'),
  'es': (
    'Ayuno intermitente en curso',
    'Toca para abrir el temporizador de BIL.',
  ),
  'tr': (
    'Aralıklı oruç sürüyor',
    'BIL oruç zamanlayıcısını açmak için dokunun.',
  ),
};

const _fastingHydrationCopy = <String, (String, String)>{
  'ar': (
    'تذكير لطيف بالماء',
    'اشرب الماء إذا كان مسموحًا ضمن صيامك وخطتك الصحية.',
  ),
  'en': (
    'A gentle water reminder',
    'Drink water if it fits your fast and health plan.',
  ),
  'fr': (
    'Petit rappel pour boire',
    'Buvez de l’eau si votre jeûne et votre santé le permettent.',
  ),
  'es': (
    'Un recordatorio de agua',
    'Bebe agua si encaja con tu ayuno y tu plan de salud.',
  ),
  'tr': (
    'Nazik bir su hatırlatması',
    'Orucunuza ve sağlık planınıza uygunsa su için.',
  ),
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
