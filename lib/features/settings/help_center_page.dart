import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/runtime_copy.dart';
import '../../app/theme/bil_semantic_icons.dart';

String _localized(BuildContext context, Map<String, String> values) {
  final locale = Localizations.localeOf(context);
  final authored = values[locale.languageCode];
  if (authored != null) return authored;
  final english = values['en']!;
  return RuntimeCopy.resolve(english, locale.toLanguageTag()) ??
      (throw StateError(
        'Missing help copy for ${locale.toLanguageTag()}: $english',
      ));
}

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  Future<void> _email(BuildContext context, String subject) async {
    try {
      final opened = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: 'support@bilhealth.com',
          queryParameters: {'subject': subject},
        ),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _localized(context, const {
            'en': 'Email support@bilhealth.com from your mail app.',
            'ar': 'أرسل رسالة إلى support@bilhealth.com من تطبيق البريد.',
            'fr': 'Écrivez à support@bilhealth.com depuis votre messagerie.',
            'es': 'Escribe a support@bilhealth.com desde tu correo.',
            'tr':
                'E-posta uygulamanızdan support@bilhealth.com adresine yazın.',
          }),
        ),
      ),
    );
  }

  void _show(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              _localized(context, const {
                'en': 'Close',
                'ar': 'إغلاق',
                'fr': 'Fermer',
                'es': 'Cerrar',
                'tr': 'Kapat',
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String ar, String fr, String es, String tr) =>
        _localized(context, {'en': en, 'ar': ar, 'fr': fr, 'es': es, 'tr': tr});
    final rows =
        <
          ({
            String id,
            String title,
            BilSemanticIconKind kind,
            IconData? iconOverride,
            IconData? appleIconOverride,
            VoidCallback action,
          })
        >[
          (
            id: 'about',
            title: t(
              'About BIL',
              'حول BIL',
              'À propos de BIL',
              'Acerca de BIL',
              'BIL Hakkında',
            ),
            kind: BilSemanticIconKind.support,
            iconOverride: Icons.info_outline_rounded,
            appleIconOverride: CupertinoIcons.info_circle,
            action: () => _show(
              context,
              'Body Intelligence Log™',
              t(
                'Private body intelligence for nutrition, movement, recovery and progress. BIL keeps evidence and user control visible.',
                'ذكاء صحي شخصي وخاص للتغذية والحركة والتعافي والتقدم، مع إبقاء الأدلة وتحكم المستخدم واضحين.',
                'Une intelligence corporelle privée pour la nutrition, le mouvement, la récupération et le progrès.',
                'Inteligencia corporal privada para nutrición, movimiento, recuperación y progreso.',
                'Beslenme, hareket, toparlanma ve ilerleme için özel beden zekâsı.',
              ),
            ),
          ),
          (
            id: 'faq',
            title: t(
              'Frequently Asked Questions',
              'الأسئلة الشائعة',
              'Questions fréquentes',
              'Preguntas frecuentes',
              'Sık Sorulan Sorular',
            ),
            kind: BilSemanticIconKind.support,
            iconOverride: Icons.quiz_outlined,
            appleIconOverride: CupertinoIcons.question_circle,
            action: () => context.push('/help/faq'),
          ),
          (
            id: 'contact-support',
            title: t(
              'Contact Support',
              'تواصل مع الدعم',
              'Contacter le support',
              'Contactar con soporte',
              'Destekle İletişim',
            ),
            kind: BilSemanticIconKind.support,
            iconOverride: null,
            appleIconOverride: null,
            action: () => _email(context, 'BIL support request'),
          ),
          (
            id: 'terms',
            title: t(
              'Terms of Service',
              'شروط الاستخدام',
              'Conditions d’utilisation',
              'Términos del servicio',
              'Hizmet Koşulları',
            ),
            kind: BilSemanticIconKind.legal,
            iconOverride: null,
            appleIconOverride: null,
            action: () => context.push('/legal/terms'),
          ),
          (
            id: 'troubleshooting',
            title: t(
              'Troubleshooting',
              'حل المشكلات',
              'Dépannage',
              'Solución de problemas',
              'Sorun Giderme',
            ),
            kind: BilSemanticIconKind.preferences,
            iconOverride: Icons.build_outlined,
            appleIconOverride: CupertinoIcons.wrench,
            action: () => _show(
              context,
              t(
                'Troubleshooting',
                'حل المشكلات',
                'Dépannage',
                'Solución de problemas',
                'Sorun Giderme',
              ),
              t(
                'Check connectivity and permissions, restart BIL, then try again. Your saved local data is not removed.',
                'تحقق من الاتصال والصلاحيات، ثم أعد تشغيل BIL وحاول مجددًا. لن تُحذف بياناتك المحلية المحفوظة.',
                'Vérifiez la connexion et les autorisations, redémarrez BIL puis réessayez. Vos données locales sont conservées.',
                'Comprueba la conexión y los permisos, reinicia BIL y vuelve a intentarlo. Tus datos locales se conservan.',
                'Bağlantı ve izinleri kontrol edin, BIL’i yeniden başlatıp tekrar deneyin. Yerel verileriniz korunur.',
              ),
            ),
          ),
          (
            id: 'delete-account',
            title: t(
              'Delete Account',
              'حذف الحساب',
              'Supprimer le compte',
              'Eliminar cuenta',
              'Hesabı Sil',
            ),
            kind: BilSemanticIconKind.accountDeletion,
            iconOverride: null,
            appleIconOverride: null,
            action: () => context.push('/help/delete-account'),
          ),
          (
            id: 'service-status',
            title: t(
              'Service Status',
              'حالة الخدمة',
              'État du service',
              'Estado del servicio',
              'Hizmet Durumu',
            ),
            kind: BilSemanticIconKind.health,
            iconOverride: Icons.monitor_heart_outlined,
            appleIconOverride: CupertinoIcons.waveform_path_ecg,
            action: () => _show(
              context,
              t(
                'Service Status',
                'حالة الخدمة',
                'État du service',
                'Estado del servicio',
                'Hizmet Durumu',
              ),
              t(
                'Core local logging is available. Connected integrations show their current state and permissions on Apps & Devices.',
                'التسجيل المحلي الأساسي متاح. تعرض التكاملات المتصلة حالتها وصلاحياتها الحالية في التطبيقات والأجهزة.',
                'Le suivi local est disponible. Les intégrations affichent leur état et leurs autorisations dans Applications et appareils.',
                'El registro local está disponible. Las integraciones muestran su estado y permisos en Aplicaciones y dispositivos.',
                'Yerel kayıt kullanılabilir. Bağlı entegrasyonlar durumlarını ve izinlerini Uygulamalar ve Cihazlar bölümünde gösterir.',
              ),
            ),
          ),
        ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(t('Help', 'المساعدة', 'Aide', 'Ayuda', 'Yardım')),
      ),
      body: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final row = rows[index];
          return ListTile(
            minTileHeight: 72,
            leading: BilSemanticIconBadge(
              key: Key('help-center-icon-${row.id}'),
              kind: row.kind,
              size: 42,
              iconOverride: row.iconOverride,
              appleIconOverride: row.appleIconOverride,
              shape: BoxShape.rectangle,
            ),
            title: Text(row.title),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: row.action,
          );
        },
      ),
    );
  }
}

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    String t(String en, String ar, String fr, String es, String tr) =>
        _localized(context, {'en': en, 'ar': ar, 'fr': fr, 'es': es, 'tr': tr});
    final questions = [
      (
        t(
          'How does BIL calculate my targets?',
          'كيف يحسب BIL أهدافي؟',
          'Comment BIL calcule-t-il mes objectifs ?',
          '¿Cómo calcula BIL mis objetivos?',
          'BIL hedeflerimi nasıl hesaplar?',
        ),
        t(
          'BIL uses the profile and goals you saved and shows missing evidence instead of inventing values.',
          'يستخدم BIL ملفك وأهدافك المحفوظة، ويعرض البيانات الناقصة بدل اختراع قيم.',
          'BIL utilise votre profil et vos objectifs et signale les données manquantes.',
          'BIL usa tu perfil y objetivos y muestra los datos faltantes.',
          'BIL profilinizi ve hedeflerinizi kullanır, eksik verileri gösterir.',
        ),
      ),
      (
        t(
          'Can I use BIL offline?',
          'هل يمكن استخدام BIL دون اتصال؟',
          'Puis-je utiliser BIL hors ligne ?',
          '¿Puedo usar BIL sin conexión?',
          'BIL çevrimdışı kullanılabilir mi?',
        ),
        t(
          'Core logging and saved content work offline. Connected services clearly show when a connection is required.',
          'يعمل التسجيل الأساسي والمحتوى المحفوظ دون اتصال، وتوضح الخدمات المتصلة متى تحتاج إلى الإنترنت.',
          'Le suivi principal fonctionne hors ligne; les services connectés indiquent leurs besoins.',
          'El registro básico funciona sin conexión; los servicios conectados indican sus requisitos.',
          'Temel kayıt çevrimdışı çalışır; bağlı hizmetler gereksinimlerini gösterir.',
        ),
      ),
      (
        t(
          'Is BIL medical advice?',
          'هل يقدم BIL نصيحة طبية؟',
          'BIL fournit-il un avis médical ?',
          '¿BIL ofrece asesoramiento médico?',
          'BIL tıbbi tavsiye verir mi?',
        ),
        t(
          'No. BIL supports wellness tracking and does not diagnose, prescribe, or replace a qualified clinician.',
          'لا. يدعم BIL متابعة العافية ولا يشخّص أو يصف علاجًا أو يستبدل الطبيب المختص.',
          'Non. BIL ne diagnostique pas et ne remplace pas un professionnel qualifié.',
          'No. BIL no diagnostica ni sustituye a un profesional cualificado.',
          'Hayır. BIL tanı koymaz ve uzman yerine geçmez.',
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            'Frequently Asked Questions',
            'الأسئلة الشائعة',
            'Questions fréquentes',
            'Preguntas frecuentes',
            'Sık Sorulan Sorular',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final question in questions)
            Card(
              child: ExpansionTile(
                title: Text(question.$1),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Text(question.$2)],
              ),
            ),
        ],
      ),
    );
  }
}
