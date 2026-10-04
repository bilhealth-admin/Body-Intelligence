import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../domain/community_push_preferences.dart';
import '../domain/daily_reminder.dart';
import '../domain/notification_delivery_preferences.dart';
import '../services/bil_notification_service.dart';
import '../services/community_push_service.dart';
import '../services/daily_reminder_store.dart';
import 'notification_settings_copy.dart';

part 'notification_settings_components.dart';
part 'notification_settings_actions.dart';
part 'notification_settings_copy_helpers.dart';
part 'notification_settings_delivery_controls.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.reminderStore,
    this.deliveryStore,
    this.notificationService,
    this.communityPushService,
  });

  final DailyReminderStore? reminderStore;
  final NotificationDeliveryPreferencesStore? deliveryStore;
  final BilNotificationService? notificationService;
  final CommunityPushService? communityPushService;

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
  bool _pushLoading = false;
  NotificationCategory? _savingCategory;

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
    if (widget.communityPushService != null) {
      _pushService = widget.communityPushService;
      _loadPushPreferences();
    } else if (CommunityPushService.isAvailable &&
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _permissionStatusText,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_requiresSystemSettings ||
                              _phoneNotificationsEnabled != true)
                            FilledButton.tonal(
                              key: const Key('notification-phone-check'),
                              onPressed: _saving
                                  ? null
                                  : _requiresSystemSettings
                                  ? _openSystemNotificationSettings
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
                  ..._communityDeliveryControls(delivery),
                  const SizedBox(height: 18),
                  ..._dailyDeliveryControls(delivery),
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
                          secondary: BilSemanticIconBadge(
                            kind: _semanticKind(reminder.kind),
                          ),
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
}
