import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
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
