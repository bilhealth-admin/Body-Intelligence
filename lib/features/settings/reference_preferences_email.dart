part of 'reference_preferences_pages.dart';

class ReferenceEmailSettingsPage extends ConsumerWidget {
  const ReferenceEmailSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PreferenceListPage(
      title: _emailSettingsText(context, 'Email settings'),
      children: const [
        _EmailDeliveryNotice(),
        _StoredSwitch(
          'email.newFeatureAnnouncements',
          'New feature announcements',
          false,
        ),
        _StoredSwitch('email.healthyLivingTips', 'Healthy living tips', false),
        _StoredSwitch('email.healthyRecipes', 'Healthy recipes', false),
        _StoredSwitch(
          'email.workoutRecommendations',
          'Workout recommendations',
          false,
        ),
        _StoredSwitch(
          'email.gearRecommendations',
          'Gear recommendations and offers',
          false,
        ),
        _StoredSwitch('email.weeklyDigest', 'Weekly digest', false),
        _StoredSwitch(
          'email.findMeByEmail',
          'People can find me by email address',
          false,
        ),
        _SectionLabel('Send me an email when'),
        _StoredSwitch('email.whenMessage', 'Someone sends me a message', false),
        _StoredSwitch(
          'email.whenFriendRequest',
          'Someone sends me a friend request',
          false,
        ),
        _StoredSwitch(
          'email.whenGroupInvite',
          'Someone invites me to a group',
          false,
        ),
        _StoredSwitch(
          'email.whenFriendRequestAccepted',
          'Someone accepts my friend request',
          false,
        ),
        _StoredSwitch(
          'email.whenGroupInviteAccepted',
          'Someone accepts my group invitation',
          false,
        ),
        SizedBox(height: 96),
      ],
    );
  }
}

class _EmailDeliveryNotice extends StatelessWidget {
  const _EmailDeliveryNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
    child: Text(
      _emailSettingsText(
        context,
        'Your email choices are saved now. Delivery is sent only after BIL verifies the server mail provider.',
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    ),
  );
}

String _emailSettingsText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _emailSettingsCopy[key]?[code] ?? context.strings.text(key);
}

const _emailSettingsCopy = <String, Map<String, String>>{
  'Email settings': {
    'ar': 'إعدادات البريد الإلكتروني',
    'fr': 'Paramètres e-mail',
    'es': 'Configuración del correo',
    'tr': 'E-posta ayarları',
  },
  'Your email choices are saved now. Delivery is sent only after BIL verifies the server mail provider.': {
    'ar':
        'يتم حفظ اختيارات البريد الآن. لا تُرسل الرسائل إلا بعد تفعيل مزود البريد والتحقق منه على خادم BIL.',
    'fr':
        'Vos choix d’e-mail sont enregistrés. L’envoi commencera après la vérification du fournisseur côté serveur BIL.',
    'es':
        'Tus preferencias de correo se guardan ahora. El envío comenzará después de verificar el proveedor en el servidor de BIL.',
    'tr':
        'E-posta seçimleriniz artık kaydediliyor. Gönderim, BIL sunucusundaki posta sağlayıcısı doğrulandıktan sonra başlar.',
  },
};
