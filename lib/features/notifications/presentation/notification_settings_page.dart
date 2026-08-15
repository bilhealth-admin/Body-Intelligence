import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/runtime_copy.dart';
import '../domain/community_push_preferences.dart';
import '../domain/daily_reminder.dart';
import '../domain/notification_delivery_preferences.dart';
import '../services/bil_notification_service.dart';
import '../services/community_push_service.dart';
import '../services/daily_reminder_store.dart';
import 'notification_settings_copy.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  final _store = DailyReminderStore();
  final _deliveryStore = NotificationDeliveryPreferencesStore();
  final _service = BilNotificationService(FlutterLocalNotificationsPlugin());
  List<DailyReminder>? _reminders;
  NotificationDeliveryPreferences? _deliveryPreferences;
  CommunityPushService? _pushService;
  CommunityPushPreferences? _pushPreferences;
  bool _saving = false;
  bool _pushSaving = false;
  bool _pushLoadError = false;
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
    _load();
    if (CommunityPushService.isAvailable &&
        Supabase.instance.isInitialized &&
        Supabase.instance.client.auth.currentUser != null) {
      _pushService = CommunityPushService(Supabase.instance.client);
      _loadPushPreferences();
    }
  }

  Future<void> _loadPushPreferences() async {
    if (mounted) setState(() => _pushLoadError = false);
    try {
      final preferences = await _pushService!.loadPreferences();
      if (mounted) setState(() => _pushPreferences = preferences);
    } on Object {
      if (mounted) setState(() => _pushLoadError = true);
    }
  }

  Future<void> _setPushEnabled(bool enabled) async {
    if (_pushService == null || _pushSaving) return;
    setState(() => _pushSaving = true);
    try {
      await _pushService!.setEnabled(enabled);
      await _loadPushPreferences();
    } on Object {
      if (mounted) _showPushError();
    } finally {
      if (mounted) setState(() => _pushSaving = false);
    }
  }

  Future<void> _setSensitivePreview(bool allowed) async {
    if (_pushService == null || _pushSaving) return;
    setState(() => _pushSaving = true);
    try {
      await _pushService!.setSensitivePreviewAllowed(allowed);
      await _loadPushPreferences();
    } on Object {
      if (mounted) _showPushError();
    } finally {
      if (mounted) setState(() => _pushSaving = false);
    }
  }

  void _showPushError() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _ui(
          'Community notifications could not be updated safely. Try again.',
          'تعذر تحديث إشعارات المجتمع بأمان. حاول مجددًا.',
          'Impossible de mettre à jour les notifications de la communauté.',
          'No se pudieron actualizar las notificaciones de la comunidad.',
          'Topluluk bildirimleri güvenle güncellenemedi.',
        ),
      ),
    ),
  );

  Future<void> _load() async {
    if (mounted) setState(() => _loadError = null);
    try {
      final values = await Future.wait([_store.load(), _deliveryStore.load()]);
      if (mounted) {
        setState(() {
          _reminders = values[0] as List<DailyReminder>;
          _deliveryPreferences = values[1] as NotificationDeliveryPreferences;
          _loadError = null;
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _saveDelivery(NotificationDeliveryPreferences value) async {
    if (_saving) return;
    final previous = _deliveryPreferences!;
    final reminders = _reminders!;
    setState(() {
      _deliveryPreferences = value;
      _saving = true;
    });
    try {
      await _deliveryStore.save(value);
      await _reconcile(reminders, value);
    } on Object {
      if (mounted) setState(() => _deliveryPreferences = previous);
      try {
        await _deliveryStore.save(previous);
        await _reconcile(reminders, previous);
      } on Object {
        // Best-effort reconciliation; the visible state remains the last
        // durable preference snapshot and the next edit retries scheduling.
      }
      if (mounted) _showLocalError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reconcile(
    List<DailyReminder> reminders,
    NotificationDeliveryPreferences delivery,
  ) async {
    for (final reminder in reminders) {
      await _service.schedule(
        reminder,
        languageCode: _languageCode,
        preferences: delivery,
      );
    }
  }

  void _showLocalError() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_copy.permissionError)));

  Future<void> _toggleCategory(NotificationCategory category, bool enabled) {
    final current = _deliveryPreferences!;
    final categories = {...current.enabledCategories};
    enabled ? categories.add(category) : categories.remove(category);
    return _saveDelivery(current.copyWith(enabledCategories: categories));
  }

  Future<void> _update(DailyReminder updated) async {
    final current = _reminders;
    if (current == null || _saving) return;
    final next = [
      for (final reminder in current)
        if (reminder.kind == updated.kind) updated else reminder,
    ];
    setState(() {
      _reminders = next;
      _saving = true;
    });
    try {
      if (updated.enabled) {
        final allowed = await _service.requestPermission();
        if (!allowed) {
          throw StateError('notification permission denied');
        }
      }
      await _service.schedule(
        updated,
        languageCode: _languageCode,
        preferences:
            _deliveryPreferences ?? const NotificationDeliveryPreferences(),
      );
      await _store.save(next);
    } on Object {
      if (!mounted) return;
      setState(() => _reminders = current);
      try {
        await _store.save(current);
        await _reconcile(
          current,
          _deliveryPreferences ?? const NotificationDeliveryPreferences(),
        );
      } on Object {
        // Best-effort reconciliation after restoring the durable list.
      }
      _showLocalError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAllDaily(bool enabled) async {
    final current = _reminders;
    if (current == null || _saving) return;
    final previous = current;
    final next = [
      for (final reminder in current)
        if (reminder.kind == DailyReminderKind.returnAfter24Hours)
          reminder
        else
          DailyReminder(
            kind: reminder.kind,
            hour: reminder.hour,
            minute: reminder.minute,
            enabled: enabled,
          ),
    ];
    setState(() {
      _reminders = next;
      _saving = true;
    });
    try {
      if (enabled && !await _service.requestPermission()) {
        throw StateError('notification permission denied');
      }
      await _reconcile(
        next,
        _deliveryPreferences ?? const NotificationDeliveryPreferences(),
      );
      await _store.save(next);
    } on Object {
      if (!mounted) return;
      setState(() => _reminders = previous);
      try {
        await _store.save(previous);
        await _reconcile(
          previous,
          _deliveryPreferences ?? const NotificationDeliveryPreferences(),
        );
      } on Object {
        // Best-effort reconciliation after restoring the durable list.
      }
      _showLocalError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseTime(DailyReminder reminder) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (selected == null) return;
    await _update(
      DailyReminder(
        kind: reminder.kind,
        hour: selected.hour,
        minute: selected.minute,
        enabled: reminder.enabled,
      ),
    );
  }

  Future<void> _addReminder() async {
    final reminders = _reminders;
    if (reminders == null) return;
    final kind = await showModalBottomSheet<DailyReminderKind>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reminder in reminders)
              ListTile(
                leading: Icon(_icon(reminder.kind)),
                title: Text(_copy.label(reminder.kind)),
                trailing: reminder.enabled
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, reminder.kind),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final reminder = reminders.firstWhere((item) => item.kind == kind);
    await _update(
      DailyReminder(
        kind: reminder.kind,
        hour: reminder.hour,
        minute: reminder.minute,
        enabled: true,
      ),
    );
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
                              : TextButton.icon(
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
