import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/runtime_copy.dart';
import '../domain/community_push_preferences.dart';
import '../domain/daily_reminder.dart';
import '../domain/notification_delivery_preferences.dart';
import '../services/bil_notification_service.dart';
import '../services/community_push_service.dart';
import '../services/daily_reminder_store.dart';
import 'notification_settings_copy.dart';

part 'notification_settings_components.dart';
part 'notification_settings_actions.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.reminderStore,
    this.deliveryStore,
    this.notificationService,
  });

  final DailyReminderStore? reminderStore;
  final NotificationDeliveryPreferencesStore? deliveryStore;
  final BilNotificationService? notificationService;

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  late final DailyReminderStore _store;
  late final NotificationDeliveryPreferencesStore _deliveryStore;
  late final BilNotificationService _service;
  List<DailyReminder>? _reminders;
  NotificationDeliveryPreferences? _deliveryPreferences;
  CommunityPushService? _pushService;
  CommunityPushPreferences? _pushPreferences;
  bool? _phoneNotificationsEnabled;
  BilNotificationPermissionState _permissionState =
      BilNotificationPermissionState.unknown;
  Set<int> _pendingNotificationIds = const {};
  bool _permissionProbeFailed = false;
  bool _saving = false;
  bool _pushSaving = false;
  bool _pushLoadError = false;

  void _updateState(VoidCallback update) => setState(update);
  Object? _loadError;

  String get _languageCode => Localizations.localeOf(context).languageCode;

  NotificationSettingsCopy get _copy =>
      NotificationSettingsCopy.forLanguage(_languageCode);

  bool get _allDailyEnabled =>
      _reminders
          ?.where(
            (reminder) => reminder.kind != DailyReminderKind.returnAfter24Hours,
          )
          .every((reminder) => reminder.enabled) ??
      false;

  bool get _requiresSystemSettings =>
      _permissionProbeFailed ||
      _permissionState == BilNotificationPermissionState.permanentlyDenied ||
      _permissionState == BilNotificationPermissionState.restricted;

  String get _permissionStatusText {
    if (_permissionProbeFailed) {
      return _phoneText(
        'Permission status is unavailable. Check phone settings.',
        ar: 'تعذّر التحقق من الإذن. راجعه في إعدادات الهاتف.',
        fr: 'État de l’autorisation indisponible. Vérifiez les réglages.',
        es: 'No se pudo comprobar el permiso. Revisa los ajustes.',
        tr: 'İzin durumu alınamadı. Telefon ayarlarını kontrol edin.',
      );
    }
    if (_phoneNotificationsEnabled == true) {
      return _phoneText(
        'This phone is ready for BIL reminders.',
        ar: 'هذا الهاتف جاهز لاستقبال تذكيرات BIL.',
        fr: 'Ce téléphone est prêt pour les rappels BIL.',
        es: 'Este teléfono está listo para los recordatorios de BIL.',
        tr: 'Bu telefon BIL hatırlatıcıları için hazır.',
      );
    }
    if (_requiresSystemSettings) {
      return _phoneText(
        'Notifications are blocked in phone settings.',
        ar: 'الإشعارات محظورة في إعدادات الهاتف.',
        fr: 'Les notifications sont bloquées dans les réglages.',
        es: 'Las notificaciones están bloqueadas en los ajustes.',
        tr: 'Bildirimler telefon ayarlarında engellenmiş.',
      );
    }
    return _phoneText(
      'Allow notifications to receive the reminders you enable.',
      ar: 'اسمح بالإشعارات لتصلك التذكيرات التي تفعّلها.',
      fr: 'Autorisez les notifications pour recevoir vos rappels.',
      es: 'Permite las notificaciones para recibir tus recordatorios.',
      tr: 'Etkinleştirdiğiniz hatırlatıcıları almak için izin verin.',
    );
  }

  String _scheduleStatus(DailyReminder reminder) {
    if (!reminder.enabled) {
      return _phoneText(
        'Off',
        ar: 'متوقف',
        fr: 'Désactivé',
        es: 'Desactivado',
        tr: 'Kapalı',
      );
    }
    if (_pendingNotificationIds.contains(reminder.notificationId)) {
      return _phoneText(
        'Scheduled on this phone',
        ar: 'مجدول على هذا الهاتف',
        fr: 'Programmé sur ce téléphone',
        es: 'Programado en este teléfono',
        tr: 'Bu telefonda planlandı',
      );
    }
    return _phoneText(
      'Not scheduled on this phone',
      ar: 'غير مجدول على هذا الهاتف',
      fr: 'Non programmé sur ce téléphone',
      es: 'No programado en este teléfono',
      tr: 'Bu telefonda planlanmadı',
    );
  }

  String _ui(String en, String ar, String fr, String es, String tr) =>
      switch (_languageCode) {
        'ar' => ar,
        'fr' => fr,
        'es' => es,
        'tr' => tr,
        _ => RuntimeCopy.resolve(en, _languageCode) ?? en,
      };

  @override
  void initState() {
    super.initState();
    _store = widget.reminderStore ?? DailyReminderStore();
    _deliveryStore =
        widget.deliveryStore ?? NotificationDeliveryPreferencesStore();
    _service =
        widget.notificationService ??
        BilNotificationService(FlutterLocalNotificationsPlugin());
    _load();
    if (CommunityPushService.isAvailable &&
        AppEnvironment.supabaseRuntimeReady &&
        Supabase.instance.client.auth.currentUser != null) {
      _pushService = CommunityPushService(Supabase.instance.client);
      _loadPushPreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminders = _reminders;
    final delivery = _deliveryPreferences;
    final busy = _saving || _pushSaving;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: busy
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go('/settings'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(_copy.title),
          actions: [
            IconButton(
              key: const Key('add-reminder'),
              tooltip: _ui(
                'Add reminder',
                'إضافة تذكير',
                'Ajouter un rappel',
                'Añadir recordatorio',
                'Hatırlatıcı ekle',
              ),
              onPressed: reminders == null || busy ? null : _addReminder,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_off_outlined, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        _ui(
                          'Saved setting could not be loaded. Tap to retry.',
                          'تعذر تحميل إعدادات التنبيهات المحفوظة.',
                          'Impossible de charger les réglages enregistrés.',
                          'No se pudieron cargar los ajustes guardados.',
                          'Kayıtlı bildirim ayarları yüklenemedi.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          _ui(
                            'Retry',
                            'إعادة المحاولة',
                            'Réessayer',
                            'Reintentar',
                            'Yeniden dene',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : reminders == null || delivery == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _copy.intro,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Card.filled(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _phoneNotificationsEnabled == true
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _copy.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _permissionStatusText,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            key: const Key('notification-phone-check'),
                            onPressed: _saving
                                ? null
                                : _requiresSystemSettings
                                ? _openSystemNotificationSettings
                                : _phoneNotificationsEnabled == true
                                ? _sendNotificationCheck
                                : () => _setAllDaily(true),
                            child: Text(
                              _requiresSystemSettings
                                  ? _phoneText(
                                      'Open settings',
                                      ar: 'فتح الإعدادات',
                                      fr: 'Ouvrir les réglages',
                                      es: 'Abrir ajustes',
                                      tr: 'Ayarları aç',
                                    )
                                  : _phoneNotificationsEnabled == true
                                  ? (RuntimeCopy.resolve(
                                          'Try now',
                                          Localizations.localeOf(
                                            context,
                                          ).toLanguageTag(),
                                        ) ??
                                        'Try now')
                                  : _phoneText(
                                      'Turn on',
                                      ar: 'تشغيل',
                                      fr: 'Activer',
                                      es: 'Activar',
                                      tr: 'Aç',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile.adaptive(
                      key: const Key('all-daily-reminders'),
                      value: _allDailyEnabled,
                      onChanged: _saving ? null : _setAllDaily,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: Text(
                        _ui(
                          'Enable all daily reminders',
                          'تشغيل كل التذكيرات اليومية',
                          'Activer tous les rappels quotidiens',
                          'Activar todos los recordatorios diarios',
                          'Tüm günlük hatırlatıcıları etkinleştir',
                        ),
                      ),
                      subtitle: Text(
                        _ui(
                          'You can still adjust every reminder below.',
                          'يمكنك تخصيص كل تذكير أدناه.',
                          'Vous pouvez toujours régler chaque rappel ci-dessous.',
                          'Puedes ajustar cada recordatorio abajo.',
                          'Aşağıda her hatırlatıcıyı ayrı ayrı ayarlayabilirsiniz.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _ReferencePushToggle(
                          enabled: !_saving,
                          value: delivery.allows(
                            NotificationCategory.newMessage,
                          ),
                          label: _referenceLabel('I receive a new message'),
                          onChanged: (value) => _toggleCategory(
                            NotificationCategory.newMessage,
                            value,
                          ),
                        ),
                        const Divider(height: 1),
                        _ReferencePushToggle(
                          enabled: !_saving,
                          value: delivery.allows(
                            NotificationCategory.friendRequest,
                          ),
                          label: _referenceLabel(
                            'I receive a new friend request',
                          ),
                          onChanged: (value) => _toggleCategory(
                            NotificationCategory.friendRequest,
                            value,
                          ),
                        ),
                        const Divider(height: 1),
                        _ReferencePushToggle(
                          enabled: !_saving,
                          value: delivery.allows(
                            NotificationCategory.friendWorkout,
                          ),
                          label: _referenceLabel(
                            'One of my friends logs a workout',
                          ),
                          onChanged: (value) => _toggleCategory(
                            NotificationCategory.friendWorkout,
                            value,
                          ),
                        ),
                        const Divider(height: 1),
                        _ReferencePushToggle(
                          enabled: !_saving,
                          value: delivery.allows(
                            NotificationCategory.friendStreak,
                          ),
                          label: _referenceLabel(
                            'One of my friends hits a login streak',
                          ),
                          onChanged: (value) => _toggleCategory(
                            NotificationCategory.friendStreak,
                            value,
                          ),
                        ),
                        const Divider(height: 1),
                        _ReferencePushToggle(
                          enabled: !_saving,
                          value: delivery.allows(NotificationCategory.stepGoal),
                          label: _referenceLabel('I reach my step goal'),
                          onChanged: (value) => _toggleCategory(
                            NotificationCategory.stepGoal,
                            value,
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: delivery.quietHoursEnabled,
                          title: Text(_quietText('Do not notify me between')),
                          subtitle: Text(
                            '${_formatMinutes(delivery.quietStartMinutes)} – ${_formatMinutes(delivery.quietEndMinutes)}',
                          ),
                          onChanged: (value) => _saveDelivery(
                            delivery.copyWith(quietHoursEnabled: value),
                          ),
                        ),
                        if (delivery.quietHoursEnabled)
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      _chooseQuietTime(start: true),
                                  child: Text(
                                    '${_quietText('Starts')} ${_formatMinutes(delivery.quietStartMinutes)}',
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      _chooseQuietTime(start: false),
                                  child: Text(
                                    '${_quietText('Ends')} ${_formatMinutes(delivery.quietEndMinutes)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _quietText(
                        'Push categories control lock-screen delivery. Updates can still appear inside BIL.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_pushService != null) ...[
                    Card(
                      child: Column(
                        children: [
                          if (_pushLoadError)
                            ListTile(
                              leading: const Icon(Icons.cloud_off_outlined),
                              title: Text(
                                _ui(
                                  'Cloud notification settings could not be loaded.',
                                  'تعذر تحميل إعدادات الإشعارات السحابية.',
                                  'Impossible de charger les réglages de notification cloud.',
                                  'No se pudieron cargar los ajustes de notificación en la nube.',
                                  'Bulut bildirim ayarları yüklenemedi.',
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: _loadPushPreferences,
                                child: Text(
                                  _ui(
                                    'Retry',
                                    'إعادة المحاولة',
                                    'Réessayer',
                                    'Reintentar',
                                    'Tekrar dene',
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            SwitchListTile(
                              key: const Key('community-cloud-push'),
                              value: _pushPreferences?.enabled ?? false,
                              onChanged: _pushSaving ? null : _setPushEnabled,
                              secondary: const Icon(Icons.forum_outlined),
                              title: Text(
                                _ui(
                                  'Private community notifications',
                                  'إشعارات المجتمع الخاصة',
                                  'Notifications privées de la communauté',
                                  'Notificaciones privadas de la comunidad',
                                  'Özel topluluk bildirimleri',
                                ),
                              ),
                              subtitle: Text(
                                _ui(
                                  'Friend requests and messages in your time zone.',
                                  'طلبات الأصدقاء والرسائل حسب منطقتك الزمنية.',
                                  'Demandes d’amis et messages selon votre fuseau horaire.',
                                  'Solicitudes y mensajes según tu zona horaria.',
                                  'Saat diliminize göre arkadaşlık istekleri ve mesajlar.',
                                ),
                              ),
                            ),
                            if (_pushPreferences?.enabled ?? false)
                              SwitchListTile(
                                key: const Key('sensitive-lock-screen-preview'),
                                value:
                                    _pushPreferences?.sensitivePreviewAllowed ??
                                    false,
                                onChanged: _pushSaving
                                    ? null
                                    : _setSensitivePreview,
                                secondary: const Icon(
                                  Icons.visibility_outlined,
                                ),
                                title: Text(
                                  _ui(
                                    'Allow sensitive previews',
                                    'السماح بمعاينة حساسة',
                                    'Autoriser les aperçus sensibles',
                                    'Permitir vistas previas sensibles',
                                    'Hassas önizlemelere izin ver',
                                  ),
                                ),
                                subtitle: Text(
                                  _ui(
                                    'Off by default. Health measurements are never shown without explicit consent.',
                                    'متوقف افتراضيًا. لا تظهر القياسات الصحية دون موافقة صريحة.',
                                    'Désactivé par défaut. Les mesures de santé exigent un consentement explicite.',
                                    'Desactivado por defecto. Las mediciones requieren consentimiento explícito.',
                                    'Varsayılan olarak kapalıdır. Sağlık ölçümleri açık onay olmadan gösterilmez.',
                                  ),
                                ),
                              ),
                            if (_pushPreferences != null)
                              ListTile(
                                leading: const Icon(Icons.public_outlined),
                                title: Text(_pushPreferences!.timeZone),
                                subtitle: Text(
                                  _ui(
                                    'Delivery time zone',
                                    'المنطقة الزمنية للإرسال',
                                    'Fuseau horaire de livraison',
                                    'Zona horaria de entrega',
                                    'Teslimat saat dilimi',
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...reminders.expand(
                    (reminder) => [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                        child: Text(
                          _copy.label(reminder.kind),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Card(
                        child: SwitchListTile(
                          key: Key('daily-reminder-${reminder.kind.name}'),
                          value: reminder.enabled,
                          onChanged: _saving
                              ? null
                              : (enabled) => _update(
                                  DailyReminder(
                                    kind: reminder.kind,
                                    hour: reminder.hour,
                                    minute: reminder.minute,
                                    enabled: enabled,
                                  ),
                                ),
                          secondary: Icon(_icon(reminder.kind)),
                          title: Text(_copy.label(reminder.kind)),
                          subtitle:
                              reminder.kind ==
                                  DailyReminderKind.returnAfter24Hours
                              ? Text(
                                  _ui(
                                    'Only after the app has been away for a full day.',
                                    'فقط بعد الابتعاد عن التطبيق ليوم كامل.',
                                    'Seulement après une journée complète sans ouvrir l’application.',
                                    'Solo después de un día completo sin abrir la aplicación.',
                                    'Yalnızca uygulama tam bir gün açılmadığında.',
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _chooseTime(reminder),
                                      icon: const Icon(
                                        Icons.schedule_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        TimeOfDay(
                                          hour: reminder.hour,
                                          minute: reminder.minute,
                                        ).format(context),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        start: 12,
                                        bottom: 8,
                                      ),
                                      child: Text(
                                        _scheduleStatus(reminder),
                                        key: Key(
                                          'daily-reminder-status-${reminder.kind.name}',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

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
      'Do not notify me between': {
        'ar': 'عدم إرسال إشعارات بين',
        'fr': 'Ne pas me notifier entre',
        'es': 'No notificarme entre',
        'tr': 'Şu saatler arasında bildirim gönderme',
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

  IconData _icon(DailyReminderKind kind) => switch (kind) {
    DailyReminderKind.weight => Icons.monitor_weight_outlined,
    DailyReminderKind.meals => Icons.restaurant_outlined,
    DailyReminderKind.water => Icons.water_drop_outlined,
    DailyReminderKind.sleep => Icons.bedtime_outlined,
    DailyReminderKind.fasting => Icons.timelapse_rounded,
    DailyReminderKind.weeklyReview => Icons.insights_outlined,
    DailyReminderKind.returnAfter24Hours => Icons.waving_hand_outlined,
  };
}
