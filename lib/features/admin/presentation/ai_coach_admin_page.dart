import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/invalid_route_page.dart';
import '../services/admin_operation_error.dart';
import '../services/ai_coach_admin_service.dart';
import 'admin_notification_controls.dart';
import 'community_member_access_admin_panel.dart';
import 'community_moderator_admin_panel.dart';

class AiCoachAdminPage extends ConsumerStatefulWidget {
  const AiCoachAdminPage({super.key});

  @override
  ConsumerState<AiCoachAdminPage> createState() => _AiCoachAdminPageState();
}

class _AiCoachAdminPageState extends ConsumerState<AiCoachAdminPage> {
  final _globalFormKey = GlobalKey<FormState>();
  final _individualFormKey = GlobalKey<FormState>();
  final _globalMessageController = TextEditingController();
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController();
  final _individualMessageController = TextEditingController();
  bool _resetting = false;
  bool _individualResetting = false;
  String? _pendingIdempotencyKey;
  String? _pendingGlobalFingerprint;
  String? _pendingIndividualIdempotencyKey;
  String? _pendingIndividualFingerprint;

  String _copy(
    String en, {
    required String ar,
    required String fr,
    required String es,
    required String tr,
  }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ar' => ar,
      'fr' => fr,
      'es' => es,
      'tr' => tr,
      _ => context.strings.text(en),
    };
  }

  Widget _resetMessageField({
    required Key key,
    required TextEditingController controller,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: !_resetting && !_individualResetting,
      maxLength: 180,
      maxLines: 3,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'[\u0000-\u001F\u007F]')),
      ],
      decoration: InputDecoration(
        labelText: _copy(
          'Message delivered with the 2,500-token gift',
          ar: 'الرسالة المرسلة مع هدية 2,500 توكين',
          fr: 'Message envoyé avec le cadeau de 2 500 jetons',
          es: 'Mensaje enviado con el regalo de 2.500 tokens',
          tr: '2.500 token hediyesiyle gönderilecek mesaj',
        ),
        hintText: _copy(
          'Write the exact message members will see',
          ar: 'اكتب النص الذي سيراه المستخدمون بالضبط',
          fr: 'Rédigez le message exact que verront les membres',
          es: 'Escribe el mensaje exacto que verán los miembros',
          tr: 'Üyelerin göreceği tam mesajı yazın',
        ),
      ),
      validator: (value) {
        final message = value?.trim() ?? '';
        if (message.isEmpty) {
          return _copy(
            'Write a message before resetting.',
            ar: 'اكتب رسالة قبل إعادة الضبط.',
            fr: 'Rédigez un message avant la réinitialisation.',
            es: 'Escribe un mensaje antes de restablecer.',
            tr: 'Sıfırlamadan önce bir mesaj yazın.',
          );
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(aiCoachAdminAccessProvider);
    return access.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const InvalidRoutePage(),
      data: (allowed) => allowed
          ? _adminPanel(context)
          : const InvalidRoutePage(key: Key('admin-ai-coach-access-denied')),
    );
  }

  Widget _adminPanel(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _copy(
            'BIL Administration',
            ar: 'إدارة BIL',
            fr: 'Administration BIL',
            es: 'Administración de BIL',
            tr: 'BIL Yönetimi',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _globalFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AI Coach',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _copy(
                        'Reset every user’s consumed current-period allowance and grant each account 2,500 non-expiring AI Boost tokens. Period dates, limits, plans, and subscriptions stay unchanged.',
                        ar: 'صفّر الاستخدام المستهلك في الفترة الحالية لكل المستخدمين وامنح كل حساب 2,500 توكين AI Boost غير منتهية. تبقى تواريخ الفترات والحدود والخطط والاشتراكات دون تغيير.',
                        fr: 'Réinitialise l’utilisation consommée de la période actuelle et accorde à chaque compte 2 500 jetons AI Boost sans expiration. Les dates, limites, forfaits et abonnements restent inchangés.',
                        es: 'Restablece el uso consumido del periodo actual y concede a cada cuenta 2.500 tokens AI Boost sin caducidad. Las fechas, límites, planes y suscripciones no cambian.',
                        tr: 'Herkesin mevcut dönem kullanımını sıfırlar ve her hesaba süresiz 2.500 AI Boost tokeni verir. Dönem tarihleri, limitler, planlar ve abonelikler değişmez.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _resetMessageField(
                      key: const Key('admin-ai-coach-global-message'),
                      controller: _globalMessageController,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const Key('admin-ai-coach-global-reset'),
                      onPressed: _resetting ? null : _confirmAndReset,
                      icon: _resetting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restart_alt_rounded),
                      label: Text(
                        _copy(
                          'Global AI Coach Reset',
                          ar: 'إعادة ضبط AI Coach للجميع',
                          fr: 'Réinitialisation globale d’AI Coach',
                          es: 'Restablecimiento global de AI Coach',
                          tr: 'Genel AI Coach sıfırlaması',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _individualFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_search_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _copy(
                              'Individual AI Coach Reset',
                              ar: 'إعادة ضبط AI Coach لحساب واحد',
                              fr: 'Réinitialisation individuelle d’AI Coach',
                              es: 'Restablecimiento individual de AI Coach',
                              tr: 'Bireysel AI Coach sıfırlaması',
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _copy(
                        'Reset only the matching account’s consumed current-period allowance and grant it 2,500 non-expiring AI Boost tokens. The server returns only whether a match was found.',
                        ar: 'صفّر الاستخدام المستهلك في الفترة الحالية للحساب المطابق فقط وامنحه 2,500 توكين AI Boost غير منتهية. يعرض الخادم فقط ما إذا وُجد تطابق.',
                        fr: 'Réinitialise uniquement l’utilisation de la période actuelle du compte correspondant et lui accorde 2 500 jetons AI Boost sans expiration. Le serveur indique seulement si une correspondance existe.',
                        es: 'Restablece solo el uso del periodo actual de la cuenta coincidente y le concede 2.500 tokens AI Boost sin caducidad. El servidor solo informa si hubo coincidencia.',
                        tr: 'Yalnızca eşleşen hesabın mevcut dönem kullanımını sıfırlar ve 2.500 süresiz AI Boost tokeni verir. Sunucu yalnızca eşleşme durumunu bildirir.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('admin-ai-coach-individual-email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      maxLength: 254,
                      decoration: InputDecoration(
                        labelText: _copy(
                          'Account email',
                          ar: 'بريد الحساب',
                          fr: 'E-mail du compte',
                          es: 'Correo de la cuenta',
                          tr: 'Hesap e-postası',
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(email)) {
                          return context.strings.text(
                            'Enter a valid email address.',
                          );
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      key: const Key('admin-ai-coach-individual-reason'),
                      controller: _reasonController,
                      maxLength: 120,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _copy(
                          'Reason (optional)',
                          ar: 'السبب (اختياري)',
                          fr: 'Motif (facultatif)',
                          es: 'Motivo (opcional)',
                          tr: 'Neden (isteğe bağlı)',
                        ),
                        hintText: _copy(
                          'Compensation or reward',
                          ar: 'تعويض أو مكافأة',
                          fr: 'Compensation ou récompense',
                          es: 'Compensación o recompensa',
                          tr: 'Telafi veya ödül',
                        ),
                      ),
                      validator: (value) {
                        final reason = value?.trim() ?? '';
                        if (reason.length == 1) {
                          return context.strings.text(
                            'Use at least two characters or leave it blank.',
                          );
                        }
                        return null;
                      },
                    ),
                    _resetMessageField(
                      key: const Key('admin-ai-coach-individual-message'),
                      controller: _individualMessageController,
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      key: const Key('admin-ai-coach-individual-reset'),
                      onPressed: _individualResetting
                          ? null
                          : _confirmAndResetIndividual,
                      icon: _individualResetting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_outline_rounded),
                      label: Text(
                        _copy(
                          'Reset this account',
                          ar: 'إعادة ضبط هذا الحساب',
                          fr: 'Réinitialiser ce compte',
                          es: 'Restablecer esta cuenta',
                          tr: 'Bu hesabı sıfırla',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const CommunityModeratorAdminPanel(),
          const SizedBox(height: 16),
          const CommunityMemberAccessAdminPanel(),
          const SizedBox(height: 16),
          const AdminNotificationControls(),
        ],
      ),
    );
  }

  Future<void> _confirmAndResetIndividual() async {
    if (_individualFormKey.currentState?.validate() != true) return;
    final email = _emailController.text.trim().toLowerCase();
    final reason = _reasonController.text.trim();
    final message = _individualMessageController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('admin-ai-coach-individual-reset-confirmation'),
        title: Text(
          _copy(
            'Confirm individual reset',
            ar: 'تأكيد إعادة الضبط الفردية',
            fr: 'Confirmer la réinitialisation individuelle',
            es: 'Confirmar el restablecimiento individual',
            tr: 'Bireysel sıfırlamayı onayla',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _copy(
                'If a matching account is found, its current usage resets and it receives 2,500 non-expiring AI Boost tokens with this message:',
                ar: 'إذا وُجد حساب مطابق، فسيُصفّر استخدامه الحالي وسيحصل على 2,500 توكين AI Boost غير منتهية مع هذه الرسالة:',
                fr: 'Si un compte correspond, son utilisation actuelle est réinitialisée et il reçoit 2 500 jetons AI Boost sans expiration avec ce message :',
                es: 'Si se encuentra una cuenta, se restablece su uso actual y recibe 2.500 tokens AI Boost sin caducidad con este mensaje:',
                tr: 'Eşleşen hesap bulunursa mevcut kullanımı sıfırlanır ve bu mesajla süresiz 2.500 AI Boost tokeni alır:',
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              email,
              key: const Key('admin-ai-coach-individual-confirm-email'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(message, key: const Key('admin-ai-coach-confirm-message')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('admin-ai-coach-individual-reset-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              _copy(
                'Reset this account',
                ar: 'إعادة ضبط هذا الحساب',
                fr: 'Réinitialiser ce compte',
                es: 'Restablecer esta cuenta',
                tr: 'Bu hesabı sıfırla',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _individualResetting) return;

    final fingerprint = '$email\n$reason\n$message';
    if (_pendingIndividualFingerprint != fingerprint) {
      _pendingIndividualFingerprint = fingerprint;
      _pendingIndividualIdempotencyKey = 'individual:${const Uuid().v4()}';
    }
    setState(() => _individualResetting = true);
    try {
      final matched = await ref
          .read(aiCoachAdminGatewayProvider)
          .individualReset(
            email: email,
            reason: reason,
            message: message,
            idempotencyKey: _pendingIndividualIdempotencyKey!,
          );
      _pendingIndividualIdempotencyKey = null;
      _pendingIndividualFingerprint = null;
      if (matched) {
        _emailController.clear();
        _reasonController.clear();
        _individualMessageController.clear();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: Key(
            matched
                ? 'admin-ai-coach-individual-reset-success'
                : 'admin-ai-coach-individual-reset-no-match',
          ),
          content: Text(
            matched
                ? _copy(
                    'The account’s current AI Coach usage was reset safely, 2,500 non-expiring AI Boost tokens were granted, and the message was sent.',
                    ar: 'تمت إعادة ضبط استخدام AI Coach الحالي للحساب بأمان، ومُنح 2,500 توكين AI Boost غير منتهية، وأُرسلت الرسالة.',
                    fr: 'L’utilisation actuelle d’AI Coach du compte a été réinitialisée en toute sécurité, 2 500 jetons AI Boost sans expiration ont été accordés et le message a été envoyé.',
                    es: 'El uso actual de AI Coach de la cuenta se restableció de forma segura, se concedieron 2.500 tokens AI Boost sin vencimiento y se envió el mensaje.',
                    tr: 'Hesabın mevcut AI Coach kullanımı güvenle sıfırlandı, süresiz 2.500 AI Boost jetonu verildi ve mesaj gönderildi.',
                  )
                : _copy(
                    'No matching BIL account was found. Nothing was changed.',
                    ar: 'لم يوجد حساب BIL مطابق؛ لم يُغيّر شيء.',
                    fr: 'Aucun compte BIL correspondant n’a été trouvé. Rien n’a été modifié.',
                    es: 'No se encontró una cuenta BIL coincidente. No se cambió nada.',
                    tr: 'Eşleşen bir BIL hesabı bulunamadı. Hiçbir şey değiştirilmedi.',
                  ),
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _adminFailureCopy(
              classifyAdminOperationFailure(error),
              individual: true,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _individualResetting = false);
    }
  }

  Future<void> _confirmAndReset() async {
    if (_globalFormKey.currentState?.validate() != true) return;
    final message = _globalMessageController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('admin-ai-coach-reset-confirmation'),
        title: Text(
          _copy(
            'Confirm global reset',
            ar: 'تأكيد إعادة الضبط العامة',
            fr: 'Confirmer la réinitialisation globale',
            es: 'Confirmar el restablecimiento global',
            tr: 'Genel sıfırlamayı onayla',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _copy(
                'This resets current consumed usage, grants every account 2,500 non-expiring AI Boost tokens, and sends this message:',
                ar: 'سيُصفّر هذا الاستخدام الحالي ويمنح كل حساب 2,500 توكين AI Boost غير منتهية ويرسل هذه الرسالة:',
                fr: 'Cette action réinitialise l’utilisation actuelle, accorde à chaque compte 2 500 jetons AI Boost sans expiration et envoie ce message :',
                es: 'Esta acción restablece el uso actual, concede a cada cuenta 2.500 tokens AI Boost sin caducidad y envía este mensaje:',
                tr: 'Bu işlem mevcut kullanımı sıfırlar, her hesaba süresiz 2.500 AI Boost tokeni verir ve şu mesajı gönderir:',
              ),
            ),
            const SizedBox(height: 10),
            Text(message, key: const Key('admin-ai-coach-confirm-message')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              _copy(
                'Cancel',
                ar: 'إلغاء',
                fr: 'Annuler',
                es: 'Cancelar',
                tr: 'İptal',
              ),
            ),
          ),
          FilledButton(
            key: const Key('admin-ai-coach-reset-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              _copy(
                'Reset for everyone',
                ar: 'إعادة الضبط للجميع',
                fr: 'Réinitialiser pour tous',
                es: 'Restablecer para todos',
                tr: 'Herkes için sıfırla',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _resetting) return;

    if (_pendingGlobalFingerprint != message) {
      _pendingGlobalFingerprint = message;
      _pendingIdempotencyKey = 'admin:${const Uuid().v4()}';
    }
    setState(() => _resetting = true);
    try {
      final result = await ref
          .read(aiCoachAdminGatewayProvider)
          .globalReset(
            message: message,
            idempotencyKey: _pendingIdempotencyKey!,
          );
      _pendingIdempotencyKey = null;
      _pendingGlobalFingerprint = null;
      _globalMessageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('admin-ai-coach-reset-success'),
          content: Text(
            _copy(
              'AI Coach was reset safely. ${result.usersNotified} users received 2,500 tokens and the message.',
              ar: 'تمت إعادة ضبط AI Coach بأمان، وتلقى ${result.usersNotified} مستخدمًا 2,500 توكين والرسالة.',
              fr: 'AI Coach a été réinitialisé en toute sécurité. ${result.usersNotified} utilisateurs ont reçu 2 500 jetons et le message.',
              es: 'AI Coach se restableció de forma segura. ${result.usersNotified} usuarios recibieron 2.500 tokens y el mensaje.',
              tr: 'AI Coach güvenle sıfırlandı. ${result.usersNotified} kullanıcı 2.500 tokeni ve mesajı aldı.',
            ),
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _adminFailureCopy(
              classifyAdminOperationFailure(error),
              individual: false,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  String _adminFailureCopy(
    AdminOperationFailureKind kind, {
    required bool individual,
  }) => switch (kind) {
    AdminOperationFailureKind.timedOut => _copy(
      'The admin operation timed out. Check that the Edge Function is deployed, then try again.',
      ar: 'انتهت مهلة عملية الإدارة. تأكد من نشر Edge Function ثم حاول مجددًا.',
      fr: 'L’opération d’administration a expiré. Vérifiez le déploiement de l’Edge Function, puis réessayez.',
      es: 'La operación de administración agotó el tiempo. Comprueba que Edge Function esté desplegada y vuelve a intentarlo.',
      tr: 'Yönetici işlemi zaman aşımına uğradı. Edge Function dağıtımını kontrol edip yeniden deneyin.',
    ),
    AdminOperationFailureKind.serviceUnavailable => _copy(
      'The admin service is not available. Deploy the current Edge Function and migrations, then try again.',
      ar: 'خدمة الإدارة غير متاحة. انشر Edge Function والترحيلات الحالية ثم حاول مجددًا.',
      fr: 'Le service d’administration est indisponible. Déployez l’Edge Function et les migrations actuelles, puis réessayez.',
      es: 'El servicio de administración no está disponible. Despliega Edge Function y las migraciones actuales y vuelve a intentarlo.',
      tr: 'Yönetici hizmeti kullanılamıyor. Güncel Edge Function ve migration’ları dağıtıp yeniden deneyin.',
    ),
    AdminOperationFailureKind.authorization => _copy(
      'This account is not authorized for the admin operation, or the deployed service is using an older admin roster.',
      ar: 'هذا الحساب غير مخول بعملية الإدارة، أو أن الخدمة المنشورة تستخدم قائمة أدمن قديمة.',
      fr: 'Ce compte n’est pas autorisé ou le service déployé utilise une ancienne liste d’administrateurs.',
      es: 'Esta cuenta no está autorizada o el servicio desplegado usa una lista de administradores antigua.',
      tr: 'Bu hesap yetkili değil veya dağıtılan hizmet eski yönetici listesini kullanıyor.',
    ),
    AdminOperationFailureKind.integrity => _copy(
      'Mobile integrity verification blocked the operation. Use a signed build or keep the server canary in off mode during QA.',
      ar: 'تحقق سلامة التطبيق منع العملية. استخدم نسخة موقعة أو أبقِ وضع الاختبار في الخادم على off أثناء QA.',
      fr: 'La vérification d’intégrité mobile a bloqué l’opération. Utilisez une version signée ou gardez le canary serveur sur off pendant la QA.',
      es: 'La verificación de integridad móvil bloqueó la operación. Usa una compilación firmada o mantén el canary del servidor en off durante QA.',
      tr: 'Mobil bütünlük doğrulaması işlemi engelledi. İmzalı derleme kullanın veya QA sırasında sunucu canary’sini off tutun.',
    ),
    AdminOperationFailureKind.rejected ||
    AdminOperationFailureKind.unknown => _copy(
      individual
          ? 'The individual reset was not completed. No partial change was kept. Try again.'
          : 'The reset was not completed. No partial change was kept. Try again.',
      ar: individual
          ? 'لم تكتمل إعادة الضبط الفردية، ولم يُحفظ أي تغيير جزئي. حاول مجددًا.'
          : 'لم تكتمل إعادة الضبط، ولم يُحفظ أي تغيير جزئي. حاول مجددًا.',
      fr: 'L’opération n’a pas abouti. Aucun changement partiel n’a été conservé. Réessayez.',
      es: 'La operación no se completó. No se conservó ningún cambio parcial. Inténtalo de nuevo.',
      tr: 'İşlem tamamlanmadı. Kısmi bir değişiklik kaydedilmedi. Yeniden deneyin.',
    ),
  };

  @override
  void dispose() {
    _globalMessageController.dispose();
    _emailController.dispose();
    _reasonController.dispose();
    _individualMessageController.dispose();
    super.dispose();
  }
}
