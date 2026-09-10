import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/invalid_route_page.dart';
import '../services/admin_operation_error.dart';
import '../services/ai_coach_admin_service.dart';

class AiCoachResetAdminPage extends ConsumerStatefulWidget {
  const AiCoachResetAdminPage({super.key, required this.global});
  final bool global;

  @override
  ConsumerState<AiCoachResetAdminPage> createState() =>
      _AiCoachAdminPageState();
}

class _AiCoachAdminPageState extends ConsumerState<AiCoachResetAdminPage> {
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
          'Message delivered with the balance reset',
          ar: 'الرسالة المرسلة مع إعادة ضبط الرصيد',
          fr: 'Message envoyé avec la réinitialisation du solde',
          es: 'Mensaje enviado al restablecer el saldo',
          tr: 'Bakiye sıfırlamasıyla gönderilecek mesaj',
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
          if (widget.global)
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
                          'Reset current-period usage and top up each account’s non-expiring AI Boost balance to 2,500. Full or higher balances receive no extra tokens. Period dates, limits, plans, and subscriptions stay unchanged.',
                          ar: 'صفّر استخدام الفترة الحالية وأكمل رصيد AI Boost غير المنتهي لكل حساب إلى 2,500 فقط. الرصيد المكتمل أو الأعلى لا يحصل على توكين إضافية. تبقى تواريخ الفترات والحدود والخطط والاشتراكات دون تغيير.',
                          fr: 'Réinitialise l’utilisation actuelle et complète le solde AI Boost sans expiration jusqu’à 2 500. Aucun ajout aux soldes pleins ou supérieurs. Dates, limites, forfaits et abonnements inchangés.',
                          es: 'Restablece el uso actual y completa el saldo AI Boost sin caducidad hasta 2.500. Los saldos completos o superiores no reciben más tokens. Fechas, límites, planes y suscripciones no cambian.',
                          tr: 'Mevcut dönem kullanımını sıfırlar ve süresiz AI Boost bakiyesini 2.500’e tamamlar. Dolu veya daha yüksek bakiyelere token eklenmez. Tarihler, limitler, planlar ve abonelikler değişmez.',
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
          if (!widget.global)
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
                          'Reset only the matching account’s current-period usage and top up its non-expiring AI Boost balance to 2,500. Full or higher balances stay unchanged. The server returns only whether a match was found.',
                          ar: 'صفّر استخدام الفترة الحالية للحساب المطابق فقط وأكمل رصيد AI Boost غير المنتهي إلى 2,500. الرصيد المكتمل أو الأعلى يبقى دون تغيير. يعرض الخادم فقط ما إذا وُجد تطابق.',
                          fr: 'Réinitialise l’utilisation actuelle du compte correspondant et complète son solde AI Boost sans expiration jusqu’à 2 500. Les soldes pleins ou supérieurs restent inchangés. Le serveur indique seulement si un compte correspond.',
                          es: 'Restablece el uso actual de la cuenta y completa su saldo AI Boost sin caducidad hasta 2.500. Los saldos completos o superiores no cambian. El servidor solo indica si hubo coincidencia.',
                          tr: 'Eşleşen hesabın mevcut kullanımını sıfırlar ve süresiz AI Boost bakiyesini 2.500’e tamamlar. Dolu veya daha yüksek bakiyeler değişmez. Sunucu yalnızca eşleşme durumunu bildirir.',
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                'If the account exists, reset current usage and fill its AI Boost balance to 2,500 without reducing a higher balance. Send this message:',
                ar: 'إذا وُجد الحساب، يُصفّر استخدامه الحالي ويُكمل رصيد AI Boost إلى 2,500 دون تخفيض رصيد أعلى. تُرسل هذه الرسالة:',
                fr: 'Si le compte existe, réinitialiser son utilisation et compléter son solde AI Boost jusqu’à 2 500 sans réduire un solde supérieur. Envoyer ce message :',
                es: 'Si la cuenta existe, restablecer su uso y completar el saldo AI Boost hasta 2.500 sin reducir un saldo superior. Enviar este mensaje:',
                tr: 'Hesap varsa kullanımı sıfırlayın ve daha yüksek bakiyeyi azaltmadan AI Boost bakiyesini 2.500’e tamamlayın. Şu mesajı gönderin:',
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
      if (!mounted) return;
      _pendingIndividualIdempotencyKey = null;
      _pendingIndividualFingerprint = null;
      if (matched) {
        _emailController.clear();
        _reasonController.clear();
        _individualMessageController.clear();
      }
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
                    'Usage was reset and the AI Boost balance was topped up to 2,500. A higher balance was preserved. The message was sent.',
                    ar: 'تم تصفير الاستخدام وإكمال رصيد AI Boost إلى 2,500 مع الحفاظ على أي رصيد أعلى. أُرسلت الرسالة.',
                    fr: 'Utilisation réinitialisée et solde AI Boost complété jusqu’à 2 500. Tout solde supérieur a été préservé. Message envoyé.',
                    es: 'Uso restablecido y saldo AI Boost completado hasta 2.500. Se conservó cualquier saldo superior. Mensaje enviado.',
                    tr: 'Kullanım sıfırlandı ve AI Boost bakiyesi 2.500’e tamamlandı. Daha yüksek bakiye korundu. Mesaj gönderildi.',
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
                'Reset current usage and fill every AI Boost balance to 2,500 without adding to full balances or reducing higher balances. Send this message:',
                ar: 'صفّر الاستخدام الحالي وأكمل رصيد AI Boost لكل حساب إلى 2,500 دون إضافة للمكتمل أو تخفيض الرصيد الأعلى. أرسل هذه الرسالة:',
                fr: 'Réinitialiser l’utilisation et compléter chaque solde AI Boost jusqu’à 2 500, sans ajout aux soldes pleins ni réduction des soldes supérieurs. Envoyer ce message :',
                es: 'Restablecer el uso y completar cada saldo AI Boost hasta 2.500 sin añadir a saldos completos ni reducir los superiores. Enviar este mensaje:',
                tr: 'Kullanımı sıfırlayın ve dolu bakiyelere eklemeden veya yüksek bakiyeleri azaltmadan tüm AI Boost bakiyelerini 2.500’e tamamlayın. Şu mesajı gönderin:',
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
      if (!mounted) return;
      _pendingIdempotencyKey = null;
      _pendingGlobalFingerprint = null;
      _globalMessageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('admin-ai-coach-reset-success'),
          content: Text(
            _copy(
              '${result.usersNotified} accounts reset and notified. AI Boost balances were topped up to 2,500; higher balances were preserved.',
              ar: 'أُعيد ضبط ${result.usersNotified} حسابًا وأُرسلت الرسالة. أُكملت أرصدة AI Boost إلى 2,500 مع الحفاظ على الأرصدة الأعلى.',
              fr: '${result.usersNotified} comptes réinitialisés et notifiés. Soldes AI Boost complétés jusqu’à 2 500 ; soldes supérieurs préservés.',
              es: '${result.usersNotified} cuentas restablecidas y notificadas. Saldos AI Boost completados hasta 2.500; saldos superiores conservados.',
              tr: '${result.usersNotified} hesap sıfırlandı ve bilgilendirildi. AI Boost bakiyeleri 2.500’e tamamlandı; yüksek bakiyeler korundu.',
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
