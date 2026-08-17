import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../cloud_platform/providers/cloud_sync_providers.dart';
import '../cloud_platform/services/cloud_sync_consent_repository.dart';
import 'reference_settings_copy.dart';

String _privacyText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _privacyCopy[code]?[key] ?? context.strings.text(key);
}

const _privacyCopy = <String, Map<String, String>>{
  'en': {
    'Diary sharing': 'Diary sharing',
    'Profile visibility': 'Profile visibility',
    'Allow people to find me': 'Allow people to find me',
    'Show my activity to friends': 'Show my activity to friends',
    'Private': 'Private',
    'Public': 'Public',
    'Friends only': 'Friends only',
    'Terms of service': 'Terms of service',
    'Privacy policy': 'Privacy policy',
    'Manage personalization preferences': 'Manage personalization preferences',
    'Sharing and email settings': 'Sharing and email settings',
    'Contact support': 'Contact support',
    'Export my data': 'Export my data',
    'Export could not be opened': 'Export could not be opened',
    'Change password': 'Change password',
    'Encrypted cloud sync': 'Encrypted cloud sync',
    'Sync profile, weight and water across your devices. Nutrition stays local until supported.':
        'Sync profile, weight and water across your devices. Nutrition stays local until supported.',
    'Sign in to manage cloud sync.': 'Sign in to manage cloud sync.',
    'Premium is required to turn on cloud sync.':
        'Premium is required to turn on cloud sync.',
    'Cloud sync is temporarily unavailable.':
        'Cloud sync is temporarily unavailable.',
    'Checking cloud sync…': 'Checking cloud sync…',
    'Turn on encrypted cloud sync?': 'Turn on encrypted cloud sync?',
    'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.':
        'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.',
    'Cancel': 'Cancel',
    'Turn on': 'Turn on',
    'Cloud sync preference updated.': 'Cloud sync preference updated.',
    'Could not update cloud sync. Try again.':
        'Could not update cloud sync. Try again.',
    'Sync now': 'Sync now',
    'Run a one-time encrypted sync now.': 'Run a one-time encrypted sync now.',
    'Encrypted cloud sync completed.': 'Encrypted cloud sync completed.',
    'Cloud sync could not run. Check Premium, consent, and internet.':
        'Cloud sync could not run. Check Premium, consent, and internet.',
  },
  'ar': {
    'Diary sharing': 'مشاركة اليوميات',
    'Profile visibility': 'ظهور الملف الشخصي',
    'Allow people to find me': 'السماح للآخرين بالعثور عليّ',
    'Show my activity to friends': 'إظهار نشاطي للأصدقاء',
    'Private': 'خاص',
    'Public': 'عام',
    'Friends only': 'الأصدقاء فقط',
    'Terms of service': 'شروط الاستخدام',
    'Privacy policy': 'سياسة الخصوصية',
    'Manage personalization preferences': 'إدارة تفضيلات التخصيص',
    'Sharing and email settings': 'إعدادات المشاركة والبريد',
    'Contact support': 'التواصل مع الدعم',
    'Export my data': 'تصدير بياناتي',
    'Export could not be opened': 'تعذر فتح التصدير',
    'Change password': 'تغيير كلمة المرور',
    'Encrypted cloud sync': 'المزامنة السحابية المشفّرة',
    'Sync profile, weight and water across your devices. Nutrition stays local until supported.':
        'زامن الملف الشخصي والوزن والماء بين أجهزتك. تبقى بيانات التغذية محلية حتى يتم دعمها.',
    'Sign in to manage cloud sync.': 'سجّل الدخول لإدارة المزامنة السحابية.',
    'Premium is required to turn on cloud sync.':
        'يلزم Premium لتشغيل المزامنة السحابية.',
    'Cloud sync is temporarily unavailable.':
        'المزامنة السحابية غير متاحة مؤقتًا.',
    'Checking cloud sync…': 'جارٍ التحقق من المزامنة السحابية…',
    'Turn on encrypted cloud sync?': 'تشغيل المزامنة السحابية المشفّرة؟',
    'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.':
        'يشفّر BIL الملف الشخصي والوزن والماء قبل التخزين السحابي. يمكنك إيقاف المزامنة في أي وقت.',
    'Cancel': 'إلغاء',
    'Turn on': 'تشغيل',
    'Cloud sync preference updated.': 'تم تحديث تفضيل المزامنة السحابية.',
    'Could not update cloud sync. Try again.':
        'تعذر تحديث المزامنة السحابية. حاول مرة أخرى.',
    'Sync now': 'مزامنة الآن',
    'Run a one-time encrypted sync now.': 'شغّل مزامنة مشفّرة لمرة واحدة الآن.',
    'Encrypted cloud sync completed.': 'اكتملت المزامنة السحابية المشفّرة.',
    'Cloud sync could not run. Check Premium, consent, and internet.':
        'تعذر تشغيل المزامنة. تحقق من Premium والموافقة والإنترنت.',
  },
  'fr': {
    'Diary sharing': 'Partage du journal',
    'Profile visibility': 'Visibilité du profil',
    'Allow people to find me': 'Autoriser les autres à me trouver',
    'Show my activity to friends': 'Afficher mon activité à mes amis',
    'Private': 'Privé',
    'Public': 'Public',
    'Friends only': 'Amis uniquement',
    'Terms of service': 'Conditions d’utilisation',
    'Privacy policy': 'Politique de confidentialité',
    'Manage personalization preferences':
        'Gérer les préférences de personnalisation',
    'Sharing and email settings': 'Paramètres de partage et d’e-mail',
    'Contact support': 'Contacter le support',
    'Export my data': 'Exporter mes données',
    'Export could not be opened': 'Impossible d’ouvrir l’exportation',
    'Change password': 'Modifier le mot de passe',
    'Encrypted cloud sync': 'Synchronisation cloud chiffrée',
    'Sync profile, weight and water across your devices. Nutrition stays local until supported.':
        'Synchronisez profil, poids et eau entre vos appareils. La nutrition reste locale jusqu’à sa prise en charge.',
    'Sign in to manage cloud sync.':
        'Connectez-vous pour gérer la synchronisation cloud.',
    'Premium is required to turn on cloud sync.':
        'Premium est requis pour activer la synchronisation cloud.',
    'Cloud sync is temporarily unavailable.':
        'La synchronisation cloud est temporairement indisponible.',
    'Checking cloud sync…': 'Vérification de la synchronisation cloud…',
    'Turn on encrypted cloud sync?':
        'Activer la synchronisation cloud chiffrée ?',
    'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.':
        'BIL chiffre le profil, le poids et l’eau avant le stockage cloud. Vous pouvez désactiver la synchronisation à tout moment.',
    'Cancel': 'Annuler',
    'Turn on': 'Activer',
    'Cloud sync preference updated.':
        'Préférence de synchronisation cloud mise à jour.',
    'Could not update cloud sync. Try again.':
        'Impossible de mettre à jour la synchronisation cloud. Réessayez.',
    'Sync now': 'Synchroniser maintenant',
    'Run a one-time encrypted sync now.':
        'Exécuter maintenant une synchronisation chiffrée unique.',
    'Encrypted cloud sync completed.':
        'Synchronisation cloud chiffrée terminée.',
    'Cloud sync could not run. Check Premium, consent, and internet.':
        'La synchronisation n’a pas pu démarrer. Vérifiez Premium, le consentement et Internet.',
  },
  'es': {
    'Diary sharing': 'Compartir diario',
    'Profile visibility': 'Visibilidad del perfil',
    'Allow people to find me': 'Permitir que otras personas me encuentren',
    'Show my activity to friends': 'Mostrar mi actividad a mis amigos',
    'Private': 'Privado',
    'Public': 'Público',
    'Friends only': 'Solo amigos',
    'Terms of service': 'Términos del servicio',
    'Privacy policy': 'Política de privacidad',
    'Manage personalization preferences':
        'Gestionar preferencias de personalización',
    'Sharing and email settings': 'Ajustes de uso compartido y correo',
    'Contact support': 'Contactar con soporte',
    'Export my data': 'Exportar mis datos',
    'Export could not be opened': 'No se pudo abrir la exportación',
    'Change password': 'Cambiar contraseña',
    'Encrypted cloud sync': 'Sincronización cifrada en la nube',
    'Sync profile, weight and water across your devices. Nutrition stays local until supported.':
        'Sincroniza perfil, peso y agua entre tus dispositivos. La nutrición permanece local hasta que sea compatible.',
    'Sign in to manage cloud sync.':
        'Inicia sesión para gestionar la sincronización en la nube.',
    'Premium is required to turn on cloud sync.':
        'Se requiere Premium para activar la sincronización en la nube.',
    'Cloud sync is temporarily unavailable.':
        'La sincronización en la nube no está disponible temporalmente.',
    'Checking cloud sync…': 'Comprobando la sincronización en la nube…',
    'Turn on encrypted cloud sync?':
        '¿Activar la sincronización cifrada en la nube?',
    'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.':
        'BIL cifra el perfil, el peso y el agua antes del almacenamiento en la nube. Puedes desactivar la sincronización en cualquier momento.',
    'Cancel': 'Cancelar',
    'Turn on': 'Activar',
    'Cloud sync preference updated.':
        'Preferencia de sincronización en la nube actualizada.',
    'Could not update cloud sync. Try again.':
        'No se pudo actualizar la sincronización en la nube. Inténtalo de nuevo.',
    'Sync now': 'Sincronizar ahora',
    'Run a one-time encrypted sync now.':
        'Ejecuta ahora una sincronización cifrada única.',
    'Encrypted cloud sync completed.': 'Sincronización cifrada completada.',
    'Cloud sync could not run. Check Premium, consent, and internet.':
        'No se pudo sincronizar. Comprueba Premium, el consentimiento e Internet.',
  },
  'tr': {
    'Diary sharing': 'Günlük paylaşımı',
    'Profile visibility': 'Profil görünürlüğü',
    'Allow people to find me': 'İnsanların beni bulmasına izin ver',
    'Show my activity to friends': 'Etkinliğimi arkadaşlarıma göster',
    'Private': 'Özel',
    'Public': 'Herkese açık',
    'Friends only': 'Yalnızca arkadaşlar',
    'Terms of service': 'Hizmet koşulları',
    'Privacy policy': 'Gizlilik politikası',
    'Manage personalization preferences': 'Kişiselleştirme tercihlerini yönet',
    'Sharing and email settings': 'Paylaşım ve e-posta ayarları',
    'Contact support': 'Destekle iletişime geç',
    'Export my data': 'Verilerimi dışa aktar',
    'Export could not be opened': 'Dışa aktarma açılamadı',
    'Change password': 'Parolayı değiştir',
    'Encrypted cloud sync': 'Şifreli bulut eşitleme',
    'Sync profile, weight and water across your devices. Nutrition stays local until supported.':
        'Profil, kilo ve su verilerini cihazlarınız arasında eşitleyin. Beslenme verileri desteklenene kadar yerel kalır.',
    'Sign in to manage cloud sync.':
        'Bulut eşitlemeyi yönetmek için oturum açın.',
    'Premium is required to turn on cloud sync.':
        'Bulut eşitlemeyi açmak için Premium gerekir.',
    'Cloud sync is temporarily unavailable.':
        'Bulut eşitleme geçici olarak kullanılamıyor.',
    'Checking cloud sync…': 'Bulut eşitleme kontrol ediliyor…',
    'Turn on encrypted cloud sync?': 'Şifreli bulut eşitleme açılsın mı?',
    'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.':
        'BIL, bulut depolamadan önce profil, kilo ve su verilerini şifreler. Eşitlemeyi istediğiniz zaman kapatabilirsiniz.',
    'Cancel': 'İptal',
    'Turn on': 'Aç',
    'Cloud sync preference updated.': 'Bulut eşitleme tercihi güncellendi.',
    'Could not update cloud sync. Try again.':
        'Bulut eşitleme güncellenemedi. Tekrar deneyin.',
    'Sync now': 'Şimdi eşitle',
    'Run a one-time encrypted sync now.':
        'Şimdi tek seferlik şifreli eşitleme çalıştırın.',
    'Encrypted cloud sync completed.': 'Şifreli bulut eşitleme tamamlandı.',
    'Cloud sync could not run. Check Premium, consent, and internet.':
        'Bulut eşitleme çalıştırılamadı. Premium, onay ve interneti kontrol edin.',
  },
};

class SharingPrivacySettingsPage extends ConsumerWidget {
  const SharingPrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ReferenceSettingsCopy.of(context);
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(copy('Sharing & Privacy'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(_privacyText(context, 'Diary sharing')),
            subtitle: Text(_privacyText(context, 'Private')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/diary/sharing'),
          ),
          const _CloudSyncConsentTile(),
          _UnavailableCloudPrivacyTile(
            title: _privacyText(context, 'Profile visibility'),
          ),
          _UnavailableCloudPrivacyTile(
            title: _privacyText(context, 'Allow people to find me'),
          ),
          _UnavailableCloudPrivacyTile(
            title: _privacyText(context, 'Show my activity to friends'),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(_privacyText(context, 'Terms of service')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/legal/terms'),
          ),
          ListTile(
            title: Text(_privacyText(context, 'Privacy policy')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/legal/privacy'),
          ),
          ListTile(
            title: Text(_privacyText(context, 'Trust & support')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/trust-support'),
          ),
          ListTile(
            title: Text(
              _privacyText(context, 'Manage personalization preferences'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/advertising-privacy'),
          ),
          ListTile(
            title: Text(context.strings.text('Email settings')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/email'),
          ),
          ListTile(
            leading: const Icon(Icons.facebook_rounded),
            title: Text(context.strings.text('Facebook settings')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/account-connections/facebook'),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(context.strings.text('Google settings')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/account-connections/google'),
          ),
          ListTile(
            key: const Key('privacy-change-password'),
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(_privacyText(context, 'Change password')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/account-password'),
          ),
          ListTile(
            title: Text(_privacyText(context, 'Contact support')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => launchUrl(
              Uri(scheme: 'mailto', path: 'privacy@bilhealth.com'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            title: Text(_privacyText(context, 'Export my data')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/local-export'),
          ),
        ],
      ),
    );
  }
}

class _CloudSyncConsentTile extends ConsumerStatefulWidget {
  const _CloudSyncConsentTile();

  @override
  ConsumerState<_CloudSyncConsentTile> createState() =>
      _CloudSyncConsentTileState();
}

class _CloudSyncConsentTileState extends ConsumerState<_CloudSyncConsentTile> {
  bool _saving = false;
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudSyncConsentStateProvider);
    return state.when(
      loading: () => SwitchListTile.adaptive(
        value: false,
        onChanged: null,
        title: Text(_privacyText(context, 'Encrypted cloud sync')),
        subtitle: Text(_privacyText(context, 'Checking cloud sync…')),
      ),
      error: (_, _) => SwitchListTile.adaptive(
        value: false,
        onChanged: null,
        title: Text(_privacyText(context, 'Encrypted cloud sync')),
        subtitle: Text(
          _privacyText(context, 'Cloud sync is temporarily unavailable.'),
        ),
      ),
      data: (value) {
        final subtitle = switch (value.availability) {
          CloudSyncConsentAvailability.signedOut => _privacyText(
            context,
            'Sign in to manage cloud sync.',
          ),
          CloudSyncConsentAvailability.premiumRequired => _privacyText(
            context,
            'Premium is required to turn on cloud sync.',
          ),
          CloudSyncConsentAvailability.unavailable => _privacyText(
            context,
            'Cloud sync is temporarily unavailable.',
          ),
          CloudSyncConsentAvailability.available => _privacyText(
            context,
            'Sync profile, weight and water across your devices. Nutrition stays local until supported.',
          ),
        };
        return Column(
          children: [
            SwitchListTile.adaptive(
              key: const Key('encrypted-cloud-sync-consent'),
              value: value.granted,
              onChanged: !_saving && !_syncing && value.canChange
                  ? (next) => _setConsent(next, value)
                  : null,
              title: Text(_privacyText(context, 'Encrypted cloud sync')),
              subtitle: Text(subtitle),
              secondary: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_outlined),
            ),
            if (value.granted &&
                value.availability == CloudSyncConsentAvailability.available)
              ListTile(
                key: const Key('encrypted-cloud-sync-now'),
                leading: _syncing
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                title: Text(_privacyText(context, 'Sync now')),
                subtitle: Text(
                  _privacyText(context, 'Run a one-time encrypted sync now.'),
                ),
                enabled: !_saving && !_syncing,
                onTap: !_saving && !_syncing ? _runManualSync : null,
              ),
          ],
        );
      },
    );
  }

  Future<void> _runManualSync() async {
    if (_saving || _syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await ref.read(cloudManualSyncServiceProvider).runOnce();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(
              context,
              result.completed
                  ? 'Encrypted cloud sync completed.'
                  : 'Cloud sync could not run. Check Premium, consent, and internet.',
            ),
          ),
        ),
      );
      ref.invalidate(cloudRuntimePreparationProvider);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(
              context,
              'Cloud sync could not run. Check Premium, consent, and internet.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _setConsent(bool granted, CloudSyncConsentState current) async {
    if (_saving) return;
    if (granted && !current.canEnable) return;
    if (!granted && !current.canDisable) return;

    if (granted) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                _privacyText(context, 'Turn on encrypted cloud sync?'),
              ),
              content: Text(
                _privacyText(
                  context,
                  'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_privacyText(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_privacyText(context, 'Turn on')),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(cloudSyncConsentRepositoryProvider).setGranted(granted);
      ref.invalidate(cloudSyncConsentStateProvider);
      ref.invalidate(cloudRuntimePreparationProvider);
      await ref.read(cloudSyncConsentStateProvider.future);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(context, 'Cloud sync preference updated.'),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(context, 'Could not update cloud sync. Try again.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _UnavailableCloudPrivacyTile extends StatelessWidget {
  const _UnavailableCloudPrivacyTile({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: false,
    title: Text(title),
    subtitle: Text(
      context.strings.text(
        AppEnvironment.communityConfigured
            ? 'Sign in to manage community privacy.'
            : 'Community privacy controls are unavailable on this build.',
      ),
    ),
    trailing: const Icon(Icons.lock_outline_rounded),
  );
}
