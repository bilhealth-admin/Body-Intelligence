part of 'notification_settings_page.dart';

extension _NotificationDeliveryControls on _NotificationSettingsPageState {
  bool get _communityDeliveryActive =>
      _pushService != null &&
      !_pushLoadError &&
      !_pushLoading &&
      (_pushPreferences?.enabled ?? false) &&
      (_pushPreferences?.providerReady ?? false) &&
      _phoneNotificationsEnabled == true &&
      !_permissionProbeFailed;

  bool get _communityCategoriesVerified =>
      _pushPreferences?.deliveryCategories?.verified ?? false;

  List<Widget> _dailyDeliveryControls(
    NotificationDeliveryPreferences delivery,
  ) => [
    Card(
      child: SwitchListTile.adaptive(
        key: const Key('all-daily-reminders'),
        value: _allDailyEnabled,
        onChanged: _saving ? null : _setAllDaily,
        secondary: const BilSemanticIconBadge(
          kind: BilSemanticIconKind.notifications,
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
      child: Column(
        children: [
          SwitchListTile(
            value: delivery.quietHoursEnabled,
            title: Text(_quietText('Quiet hours for daily reminders')),
            subtitle: Text(
              '${_formatMinutes(delivery.quietStartMinutes)} – ${_formatMinutes(delivery.quietEndMinutes)}',
            ),
            onChanged: (value) =>
                _saveDelivery(delivery.copyWith(quietHoursEnabled: value)),
          ),
          if (delivery.quietHoursEnabled)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _chooseQuietTime(start: true),
                    child: Text(
                      '${_quietText('Starts')} ${_formatMinutes(delivery.quietStartMinutes)}',
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _chooseQuietTime(start: false),
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
    const SizedBox(height: 16),
  ];

  List<Widget> _communityDeliveryControls(
    NotificationDeliveryPreferences delivery,
  ) => [
    Card(
      key: const Key('community-notification-settings'),
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('community-cloud-push'),
            // The master is the server's saved opt-in, not effective OS
            // delivery. A denied phone permission must not hide an existing
            // opt-in and prevent an explicit cloud opt-out.
            value:
                _pushService != null &&
                !_pushLoadError &&
                (_pushPreferences?.enabled ?? false),
            onChanged:
                _pushService != null &&
                    !_pushSaving &&
                    !_pushLoading &&
                    !_pushLoadError &&
                    (_pushPreferences?.providerReady ?? false)
                ? _setPushEnabled
                : null,
            secondary: const BilSemanticIconBadge(
              kind: BilSemanticIconKind.community,
            ),
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
              _pushService == null || _pushPreferences?.providerReady == false
                  ? _ui(
                      'Remote notification delivery is unavailable on this device.',
                      'إرسال إشعارات المجتمع غير متاح على هذا الجهاز.',
                      'Les notifications distantes ne sont pas disponibles sur cet appareil.',
                      'Las notificaciones remotas no están disponibles en este dispositivo.',
                      'Bu cihazda uzak bildirim teslimi kullanılamıyor.',
                    )
                  : _ui(
                      'Category selections are saved. They are active only when community notifications and phone permission are on.',
                      'تُحفظ اختيارات الفئات، وتعمل فقط عند تشغيل إشعارات المجتمع والسماح بإشعارات الهاتف.',
                      'Les catégories sont conservées et actives seulement avec les notifications de communauté et l’autorisation du téléphone.',
                      'Las categorías se conservan y solo se activan con las notificaciones de comunidad y el permiso del teléfono.',
                      'Kategori seçimleri kaydedilir; yalnızca topluluk bildirimleri ve telefon izni açıkken etkinleşir.',
                    ),
            ),
          ),
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
              subtitle: TextButton(
                onPressed: _pushLoading ? null : _loadPushPreferences,
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
            ),
          const Divider(height: 1),
          if (_communityDeliveryActive &&
              (_pushPreferences?.deliveryCategories?.initialized ?? false) &&
              !(_pushPreferences?.deliveryCategories?.synchronized ?? true))
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.tonal(
                key: const Key('apply-saved-notification-categories'),
                onPressed: _pushSaving || _saving
                    ? null
                    : _applySavedCategories,
                child: Text(
                  _ui(
                    'Apply saved categories',
                    'تطبيق الفئات المحفوظة',
                    'Appliquer les catégories enregistrées',
                    'Aplicar categorías guardadas',
                    'Kayıtlı kategorileri uygula',
                  ),
                ),
              ),
            ),
          _categoryToggle(
            delivery,
            NotificationCategory.newMessage,
            'I receive a new message',
          ),
          const Divider(height: 1),
          _categoryToggle(
            delivery,
            NotificationCategory.friendRequest,
            'I receive a new friend request',
          ),
          const Divider(height: 1),
          _categoryToggle(
            delivery,
            NotificationCategory.friendAccepted,
            'Someone accepts my friend request',
          ),
          const Divider(height: 1),
          _categoryToggle(
            delivery,
            NotificationCategory.friendWorkout,
            'One of my friends logs a workout',
          ),
          const Divider(height: 1),
          _categoryToggle(
            delivery,
            NotificationCategory.friendStreak,
            'One of my friends hits a login streak',
          ),
          const Divider(height: 1),
          _categoryToggle(
            delivery,
            NotificationCategory.stepGoal,
            'I reach my step goal',
          ),
          if (_communityDeliveryActive)
            SwitchListTile(
              key: const Key('sensitive-lock-screen-preview'),
              value: _pushPreferences?.sensitivePreviewAllowed ?? false,
              onChanged: _pushSaving ? null : _setSensitivePreview,
              secondary: const BilSemanticIconBadge(
                kind: BilSemanticIconKind.privacy,
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
              leading: const BilSemanticIconBadge(
                kind: BilSemanticIconKind.time,
              ),
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
  ];
}
