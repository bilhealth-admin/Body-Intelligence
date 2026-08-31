import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/invalid_route_page.dart';
import '../services/ai_coach_admin_service.dart';
import 'admin_notification_controls.dart';

class AiCoachAdminPage extends ConsumerStatefulWidget {
  const AiCoachAdminPage({super.key});

  @override
  ConsumerState<AiCoachAdminPage> createState() => _AiCoachAdminPageState();
}

class _AiCoachAdminPageState extends ConsumerState<AiCoachAdminPage> {
  final _individualFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _resetting = false;
  bool _individualResetting = false;
  String? _pendingIdempotencyKey;
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
                      'Reset every user’s consumed AI Coach allowance in the current weekly and monthly periods. Period dates, limits, plans, subscriptions, and AI Boost balances stay unchanged.',
                      ar: 'صفّر استخدام AI Coach المستهلك لكل المستخدمين داخل الفترتين الأسبوعية والشهرية الحاليتين. تبقى تواريخ الفترات والحدود والخطط والاشتراكات وأرصدة AI Boost دون تغيير.',
                      fr: 'Réinitialise l’utilisation consommée d’AI Coach dans les périodes hebdomadaire et mensuelle actuelles, sans modifier dates, limites, forfaits, abonnements ni soldes AI Boost.',
                      es: 'Restablece el uso consumido de AI Coach en los periodos semanal y mensual actuales sin cambiar fechas, límites, planes, suscripciones ni saldos de AI Boost.',
                      tr: 'Her kullanıcının tüketilmiş AI Coach kullanımını mevcut haftalık ve aylık dönemlerde sıfırlar; tarihler, limitler, planlar, abonelikler ve AI Boost bakiyeleri değişmez.',
                    ),
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
                        'Reset only the matching account’s consumed weekly and monthly allowances. The server searches securely, never exposes a UUID or account data, and reports only whether a match was found.',
                        ar: 'صفّر الاستخدام المستهلك الأسبوعي والشهري للحساب المطابق فقط. يبحث الخادم بأمان، ولا يعرض UUID أو بيانات الحساب، ويخبرك فقط إن وُجد تطابق.',
                        fr: 'Réinitialise uniquement les quotas hebdomadaire et mensuel consommés du compte correspondant. Le serveur recherche en sécurité, sans exposer d’UUID ni de données, et indique seulement si une correspondance existe.',
                        es: 'Restablece solo las cuotas semanal y mensual consumidas de la cuenta coincidente. El servidor busca de forma segura, no expone UUID ni datos y solo informa si hubo coincidencia.',
                        tr: 'Yalnızca eşleşen hesabın tüketilmiş haftalık ve aylık kotalarını sıfırlar. Sunucu güvenle arar, UUID veya hesap verisi göstermez ve yalnızca eşleşme olup olmadığını bildirir.',
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
          const AdminNotificationControls(),
        ],
      ),
    );
  }

  Future<void> _confirmAndResetIndividual() async {
    if (_individualFormKey.currentState?.validate() != true) return;
    final email = _emailController.text.trim().toLowerCase();
    final reason = _reasonController.text.trim();
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
                'If a matching account is found, its consumed weekly and monthly AI Coach allowances will reset inside the same current periods and it will receive one gift notice. Only match status is returned.',
                ar: 'إذا وُجد حساب مطابق، فسيُصفّر استخدام AI Coach الأسبوعي والشهري داخل الفترات الحالية نفسها، وسيصله إشعار هدية واحد. لن يظهر سوى حالة التطابق.',
                fr: 'Si un compte correspond, ses quotas AI Coach hebdomadaire et mensuel consommés seront remis à zéro dans les mêmes périodes et il recevra un avis cadeau. Seul le statut de correspondance est renvoyé.',
                es: 'Si se encuentra una cuenta coincidente, sus cuotas semanal y mensual consumidas se restablecerán en los mismos periodos y recibirá un aviso de regalo. Solo se devuelve el estado de coincidencia.',
                tr: 'Eşleşen bir hesap bulunursa tüketilmiş haftalık ve aylık AI Coach kotaları aynı dönemlerde sıfırlanır ve tek hediye bildirimi gönderilir. Yalnızca eşleşme durumu döner.',
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              email,
              key: const Key('admin-ai-coach-individual-confirm-email'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
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

    final fingerprint = '$email\n$reason';
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
            idempotencyKey: _pendingIndividualIdempotencyKey!,
          );
      _pendingIndividualIdempotencyKey = null;
      _pendingIndividualFingerprint = null;
      if (matched) {
        _emailController.clear();
        _reasonController.clear();
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
                ? context.strings.text(
                    'The account’s current AI Coach usage was reset safely and one gift notice was sent.',
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
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'The request could not be completed. No partial change was kept. Try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _individualResetting = false);
    }
  }

  Future<void> _confirmAndReset() async {
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
        content: Text(
          _copy(
            'This immediately restores the consumed weekly and monthly AI Coach allowances for every user inside the same periods and sends one gift notice to each account.',
            ar: 'سيُعاد فورًا الاستخدام المستهلك الأسبوعي والشهري لـAI Coach لكل مستخدم داخل الفترات نفسها، وسيُرسل إشعار هدية واحد إلى كل حساب.',
            fr: 'Cette action restaure immédiatement les quotas AI Coach hebdomadaire et mensuel consommés dans les mêmes périodes et envoie un avis cadeau à chaque compte.',
            es: 'Esta acción restaura de inmediato las cuotas semanal y mensual consumidas en los mismos periodos y envía un aviso de regalo a cada cuenta.',
            tr: 'Bu işlem tüketilmiş haftalık ve aylık AI Coach kotalarını aynı dönemlerde hemen yeniler ve her hesaba bir hediye bildirimi gönderir.',
          ),
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

    setState(() => _resetting = true);
    _pendingIdempotencyKey ??= 'admin:${const Uuid().v4()}';
    try {
      final result = await ref
          .read(aiCoachAdminGatewayProvider)
          .globalReset(_pendingIdempotencyKey!);
      _pendingIdempotencyKey = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('admin-ai-coach-reset-success'),
          content: Text(
            _copy(
              'AI Coach was reset safely. ${result.usersNotified} users were notified.',
              ar: 'تمت إعادة ضبط AI Coach بأمان، وإشعار ${result.usersNotified} مستخدمًا.',
              fr: 'AI Coach a été réinitialisé en toute sécurité. ${result.usersNotified} utilisateurs ont été notifiés.',
              es: 'AI Coach se restableció de forma segura. Se notificó a ${result.usersNotified} usuarios.',
              tr: 'AI Coach güvenle sıfırlandı. ${result.usersNotified} kullanıcı bilgilendirildi.',
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              'The reset was not completed. No partial change was kept. Try again.',
              ar: 'لم تكتمل إعادة الضبط، ولم يُحفظ أي تغيير جزئي. حاول مجددًا.',
              fr: 'La réinitialisation n’a pas abouti. Aucun changement partiel n’a été conservé. Réessayez.',
              es: 'El restablecimiento no se completó. No se conservó ningún cambio parcial. Inténtalo de nuevo.',
              tr: 'Sıfırlama tamamlanmadı. Kısmi bir değişiklik kaydedilmedi. Yeniden deneyin.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}
