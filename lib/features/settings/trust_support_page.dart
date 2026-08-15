import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/runtime_copy.dart';

const _trustPolicyRevision = 'BIL-TRUST-2026-08-R1';

const _trustSecondary = <String, Map<String, String>>{
  'Trust & support': {
    'fr': 'Confiance et assistance',
    'es': 'Confianza y ayuda',
    'tr': 'Güven ve destek',
  },
  'Privacy by design': {
    'fr': 'Confidentialité dès la conception',
    'es': 'Privacidad desde el diseño',
    'tr': 'Tasarım gereği gizlilik',
  },
  'Your profile, meals, water, weight and preferences remain in the local database unless you explicitly enable and authorize a connected service.': {
    'fr':
        'Votre profil, vos repas, votre eau, votre poids et vos préférences restent dans la base locale sauf si vous autorisez explicitement un service connecté.',
    'es':
        'Tu perfil, comidas, agua, peso y preferencias permanecen en la base local salvo que autorices expresamente un servicio conectado.',
    'tr':
        'Profiliniz, öğünleriniz, su, kilo ve tercihleriniz bağlı bir hizmeti açıkça yetkilendirmediğiniz sürece yerel veritabanında kalır.',
  },
  'Health responsibility': {
    'fr': 'Responsabilité en matière de santé',
    'es': 'Responsabilidad sanitaria',
    'tr': 'Sağlık sorumluluğu',
  },
  'BIL supports tracking and cautious personal hypotheses. It does not diagnose, prescribe treatment, or replace a qualified health professional. Seek urgent care for emergency symptoms.': {
    'fr':
        'BIL facilite le suivi et les hypothèses personnelles prudentes. Il ne diagnostique pas, ne prescrit pas et ne remplace pas un professionnel qualifié. Consultez en urgence en cas de symptômes graves.',
    'es':
        'BIL facilita el seguimiento y las hipótesis personales prudentes. No diagnostica, prescribe ni sustituye a un profesional cualificado. Busca atención urgente ante síntomas graves.',
    'tr':
        'BIL takip ve temkinli kişisel varsayımları destekler. Tanı koymaz, tedavi yazmaz veya uzman yerine geçmez. Acil belirtilerde acil yardım alın.',
  },
  'How BIL intelligence answers': {
    'fr': 'Comment répond l’intelligence BIL',
    'es': 'Cómo responde la inteligencia de BIL',
    'tr': 'BIL zekâsı nasıl yanıt verir',
  },
  'BIL is designed to distinguish recorded facts from interpretation, show confidence and missing data, and ask for consent before changing a plan.': {
    'fr':
        'BIL est conçu pour distinguer les faits enregistrés de l’interprétation, afficher le niveau de confiance et les données manquantes, et demander votre accord avant de modifier un programme.',
    'es':
        'BIL está diseñado para distinguir los hechos registrados de la interpretación, mostrar la confianza y los datos faltantes, y pedir permiso antes de cambiar un plan.',
    'tr':
        'BIL, kayıtlı gerçekleri yorumdan ayırmak, güveni ve eksik verileri göstermek ve plan değişikliğinden önce onay istemek üzere tasarlanmıştır.',
  },
  'Connected health sources': {
    'fr': 'Sources de santé connectées',
    'es': 'Fuentes de salud conectadas',
    'tr': 'Bağlı sağlık kaynakları',
  },
  'Review permissions, connection state and imported readings.': {
    'fr':
        'Vérifiez les autorisations, l’état de connexion et les mesures importées.',
    'es':
        'Revisa los permisos, el estado de conexión y las lecturas importadas.',
    'tr': 'İzinleri, bağlantı durumunu ve içe aktarılan ölçümleri inceleyin.',
  },
  'Export local data': {
    'fr': 'Exporter les données locales',
    'es': 'Exportar datos locales',
    'tr': 'Yerel verileri dışa aktar',
  },
  'Create a local export for a date range.': {
    'fr': 'Créez un export local pour une période choisie.',
    'es': 'Crea una exportación local para un intervalo de fechas.',
    'tr': 'Seçtiğiniz tarih aralığı için yerel bir dışa aktarım oluşturun.',
  },
  'Request cloud-account deletion': {
    'fr': 'Demander la suppression du compte cloud',
    'es': 'Solicitar la eliminación de la cuenta en la nube',
    'tr': 'Bulut hesabının silinmesini iste',
  },
  'Open the verified deletion-request workflow. Local records remain separate.': {
    'fr':
        'Ouvrez la procédure vérifiée de demande de suppression. Les données locales restent séparées.',
    'es':
        'Abre el proceso verificado de solicitud de eliminación. Los datos locales permanecen separados.',
    'tr': 'Doğrulanmış silme talebi akışını açın. Yerel kayıtlar ayrı kalır.',
  },
  'Privacy Policy': {
    'fr': 'Politique de confidentialité',
    'es': 'Política de privacidad',
    'tr': 'Gizlilik Politikası',
  },
  'Terms of Service': {
    'fr': 'Conditions d’utilisation',
    'es': 'Términos del servicio',
    'tr': 'Hizmet Koşulları',
  },
  'Trust statement revision BIL-TRUST-2026-08-R1': {
    'fr': 'Révision de la déclaration de confiance BIL-TRUST-2026-08-R1',
    'es': 'Revisión de la declaración de confianza BIL-TRUST-2026-08-R1',
    'tr': 'Güven bildirimi revizyonu BIL-TRUST-2026-08-R1',
  },
  'Your data. Your decision.': {
    'fr': 'Vos données. Votre décision.',
    'es': 'Tus datos. Tu decisión.',
    'tr': 'Verileriniz. Kararınız.',
  },
  'Clear boundaries for privacy, intelligence and health.': {
    'fr':
        'Des limites claires pour la confidentialité, l’intelligence et la santé.',
    'es': 'Límites claros para la privacidad, la inteligencia y la salud.',
    'tr': 'Gizlilik, zekâ ve sağlık için net sınırlar.',
  },
  'Copied': {'fr': 'Copié', 'es': 'Copiado', 'tr': 'Kopyalandı'},
};

String _trustText(BuildContext context, String en, String ar) {
  final locale = Localizations.localeOf(context);
  final language = locale.languageCode;
  return switch (language) {
    'ar' => ar,
    'fr' || 'es' || 'tr' => _trustSecondary[en]![language]!,
    'en' => en,
    _ =>
      RuntimeCopy.resolve(en, locale.toLanguageTag()) ??
          (throw StateError(
            'Missing trust copy for ${locale.toLanguageTag()}: $en',
          )),
  };
}

class TrustSupportPage extends StatelessWidget {
  const TrustSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    String tr(String en, String arabic) => _trustText(context, en, arabic);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Trust & support', 'الثقة والمساعدة'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
        children: [
          const _TrustHero(),
          const SizedBox(height: 18),
          _TrustSection(
            icon: Icons.privacy_tip_outlined,
            title: tr('Privacy by design', 'خصوصية من التصميم'),
            body: tr(
              'Your profile, meals, water, weight and preferences remain in the local database unless you explicitly enable and authorize a connected service.',
              'يبقى ملفك ووجباتك وماؤك ووزنك وتفضيلاتك في قاعدة البيانات المحلية ما لم تفعّل خدمة متصلة وتمنحها الإذن صراحةً.',
            ),
          ),
          _TrustSection(
            icon: Icons.health_and_safety_outlined,
            title: tr('Health responsibility', 'المسؤولية الصحية'),
            body: tr(
              'BIL supports tracking and cautious personal hypotheses. It does not diagnose, prescribe treatment, or replace a qualified health professional. Seek urgent care for emergency symptoms.',
              'يدعم BIL التتبع والفرضيات الشخصية الحذرة. لا يشخّص ولا يصف علاجًا ولا يستبدل المختص الصحي المؤهل. اطلب رعاية عاجلة عند ظهور أعراض طارئة.',
            ),
          ),
          _TrustSection(
            icon: Icons.psychology_alt_outlined,
            title: tr('How BIL intelligence answers', 'كيف يجيب ذكاء BIL'),
            body: tr(
              'BIL is designed to distinguish recorded facts from interpretation, show confidence and missing data, and ask for consent before changing a plan.',
              'صُمم BIL للتمييز بين الحقائق المسجلة والتفسير، وعرض الثقة والبيانات الناقصة، وطلب الموافقة قبل تغيير الخطة.',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            minLeadingWidth: 32,
            horizontalTitleGap: 20,
            leading: const Icon(Icons.devices_other_outlined),
            title: Text(tr('Connected health sources', 'مصادر الصحة المتصلة')),
            subtitle: Text(
              tr(
                'Review permissions, connection state and imported readings.',
                'راجع الأذونات وحالة الاتصال والقراءات المستوردة.',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/connected-health'),
          ),
          ListTile(
            minLeadingWidth: 32,
            horizontalTitleGap: 20,
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(tr('Export local data', 'تصدير البيانات المحلية')),
            subtitle: Text(
              tr(
                'Create a local export for a date range.',
                'أنشئ تصديرًا محليًا لنطاق زمني تختاره.',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/local-export'),
          ),
          ListTile(
            minLeadingWidth: 32,
            horizontalTitleGap: 20,
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(
              tr('Request cloud-account deletion', 'طلب حذف الحساب السحابي'),
            ),
            subtitle: Text(
              tr(
                'Open the verified deletion-request workflow. Local records remain separate.',
                'افتح مسار طلب الحذف الموثق. تبقى السجلات المحلية منفصلة.',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/help/delete-account'),
          ),
          ListTile(
            minLeadingWidth: 32,
            horizontalTitleGap: 20,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(tr('Privacy Policy', 'سياسة الخصوصية')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/legal/privacy'),
          ),
          ListTile(
            minLeadingWidth: 32,
            horizontalTitleGap: 20,
            leading: const Icon(Icons.gavel_outlined),
            title: Text(tr('Terms of Service', 'شروط الخدمة')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/legal/terms'),
          ),
          const SizedBox(height: 20),
          Text(
            tr(
              'Trust statement revision $_trustPolicyRevision',
              'مراجعة بيان الثقة $_trustPolicyRevision',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              const _TrustEmailButton(address: 'privacy@bilhealth.com'),
              const _TrustEmailButton(address: 'support@bilhealth.com'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustEmailButton extends StatelessWidget {
  const _TrustEmailButton({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => _openTrustEmail(context, address),
    child: Text(address),
  );
}

Future<void> _openTrustEmail(BuildContext context, String address) async {
  try {
    final opened = await launchUrl(
      Uri(scheme: 'mailto', path: address),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
  } on Object {
    if (!context.mounted) return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _trustText(
          context,
          'No mail app is available. Copy the address instead.',
          'لا يتوفر تطبيق بريد. انسخ العنوان بدلًا من ذلك.',
        ),
      ),
      action: SnackBarAction(
        label: _trustText(context, 'Copy', 'نسخ'),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: address));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_trustText(context, 'Copied', 'تم النسخ'))),
          );
        },
      ),
    ),
  );
}

class _TrustHero extends StatelessWidget {
  const _TrustHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF071727), Color(0xFF123C55)],
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF58D9EA),
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            _trustText(context, 'Your data. Your decision.', 'بياناتك. قرارك.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _trustText(
              context,
              'Clear boundaries for privacy, intelligence and health.',
              'حدود واضحة للخصوصية والذكاء والصحة.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC5D8E3)),
          ),
        ],
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
