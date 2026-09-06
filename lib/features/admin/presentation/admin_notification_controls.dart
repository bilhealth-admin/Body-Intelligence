import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/runtime_copy_admin_notifications.dart';
import '../services/ai_coach_admin_service.dart';
import 'admin_notification_presets.dart';

/// Admin-only notification controls.
///
/// The parent page is already hidden behind the server-backed admin access
/// check. Sending is independently authorized by the Edge Function, so this
/// widget is never treated as an authorization boundary.
class AdminNotificationControls extends ConsumerStatefulWidget {
  const AdminNotificationControls({super.key});

  @override
  ConsumerState<AdminNotificationControls> createState() =>
      _AdminNotificationControlsState();
}

class _AdminNotificationControlsState
    extends ConsumerState<AdminNotificationControls> {
  bool _sending = false;
  String? _pendingFingerprint;
  String? _pendingIdempotencyKey;

  String _copy(
    String en, {
    required String ar,
    required String fr,
    required String es,
    required String tr,
  }) {
    return AdminNotificationRuntimeCopy.resolve(
      en,
      Localizations.localeOf(context).toLanguageTag(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final presets = AdminNotificationPresetCatalog.ready(locale);
    final customPreset = AdminNotificationPresetCatalog.blankCustom(locale);
    return Card(
      key: const Key('admin-notification-controls'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _copy(
                      'Send a BIL notification',
                      ar: 'إرسال إشعار من BIL',
                      fr: 'Envoyer une notification BIL',
                      es: 'Enviar una notificación de BIL',
                      tr: 'BIL bildirimi gönder',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _copy(
                'Choose a polished preset or write your own message, then send it to everyone or one exact account.',
                ar: 'اختر رسالة جاهزة بصياغة راقية أو اكتب رسالتك، ثم أرسلها للجميع أو إلى حساب محدد.',
                fr: 'Choisissez un message soigné ou rédigez le vôtre, puis envoyez-le à tous ou à un compte précis.',
                es: 'Elige un mensaje cuidado o escribe el tuyo y envíalo a todos o a una cuenta concreta.',
                tr: 'Özenli bir hazır mesaj seçin veya kendi mesajınızı yazın; ardından herkese ya da belirli bir hesaba gönderin.',
              ),
            ),
            const SizedBox(height: 16),
            for (final preset in presets) ...[
              _NotificationActionButton(
                key: Key('admin-notification-${preset.id}'),
                icon: preset.icon,
                color: preset.color,
                title: preset.title,
                subtitle: preset.body,
                enabled: !_sending,
                onPressed: () => _compose(preset),
              ),
              const SizedBox(height: 10),
            ],
            _NotificationActionButton(
              key: const Key('admin-notification-custom'),
              icon: customPreset.icon,
              color: colors.primary,
              title: customPreset.title,
              subtitle: customPreset.body,
              enabled: !_sending,
              onPressed: () => _compose(customPreset),
            ),
            if (_sending) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(
                key: Key('admin-notification-sending'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _compose(AdminNotificationPreset preset) async {
    if (_sending) return;
    final request = await showModalBottomSheet<_AdminNotificationRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AdminNotificationComposer(preset: preset),
    );
    if (request == null || !mounted) return;
    final confirmed = await _confirm(request);
    if (confirmed != true || !mounted || _sending) return;
    await _send(request);
  }

  Future<bool?> _confirm(_AdminNotificationRequest request) {
    final target = request.audience == AiCoachAdminNotificationAudience.all
        ? _copy(
            'Everyone',
            ar: 'جميع المستخدمين',
            fr: 'Tout le monde',
            es: 'Todos',
            tr: 'Herkes',
          )
        : request.email!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('admin-notification-confirmation'),
        icon: const Icon(Icons.mark_email_read_rounded),
        title: Text(
          _copy(
            'Confirm notification',
            ar: 'تأكيد الإشعار',
            fr: 'Confirmer la notification',
            es: 'Confirmar la notificación',
            tr: 'Bildirimi onayla',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _copy(
                'The notification will be delivered to:',
                ar: 'سيُرسل الإشعار إلى:',
                fr: 'La notification sera envoyée à :',
                es: 'La notificación se enviará a:',
                tr: 'Bildirim şu hedefe gönderilecek:',
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              target,
              key: const Key('admin-notification-confirm-target'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (request.previewMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                request.previewMessage,
                key: const Key('admin-notification-confirm-message'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton.icon(
            key: const Key('admin-notification-confirm-send'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.send_rounded),
            label: Text(
              _copy(
                'Send now',
                ar: 'إرسال الآن',
                fr: 'Envoyer maintenant',
                es: 'Enviar ahora',
                tr: 'Şimdi gönder',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(_AdminNotificationRequest request) async {
    final fingerprint = <String>[
      request.kind.wireValue,
      request.audience.wireValue,
      request.email ?? '',
      request.message ?? '',
    ].join('\n');
    if (_pendingFingerprint != fingerprint) {
      _pendingFingerprint = fingerprint;
      _pendingIdempotencyKey = 'notification:${const Uuid().v4()}';
    }
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(aiCoachAdminGatewayProvider)
          .sendNotification(
            kind: request.kind,
            audience: request.audience,
            email: request.email,
            message: request.message,
            idempotencyKey: _pendingIdempotencyKey!,
          );
      _pendingFingerprint = null;
      _pendingIdempotencyKey = null;
      if (!mounted) return;
      final noMatch =
          request.audience == AiCoachAdminNotificationAudience.email &&
          !result.matched;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: Key(
            noMatch
                ? 'admin-notification-no-match'
                : 'admin-notification-success',
          ),
          content: Text(
            noMatch
                ? _copy(
                    'No matching BIL account was found. Nothing was sent.',
                    ar: 'لم يوجد حساب BIL مطابق؛ لم يُرسل شيء.',
                    fr: 'Aucun compte BIL correspondant. Aucun envoi effectué.',
                    es: 'No se encontró una cuenta BIL coincidente. No se envió nada.',
                    tr: 'Eşleşen bir BIL hesabı bulunamadı. Hiçbir şey gönderilmedi.',
                  )
                : _copy(
                    'Notification queued safely for {count} recipient(s).',
                    ar: 'تم تجهيز الإشعار بأمان لـ{count} مستلم.',
                    fr: 'Notification mise en file en toute sécurité pour {count} destinataire(s).',
                    es: 'Notificación preparada de forma segura para {count} destinatario(s).',
                    tr: 'Bildirim {count} alıcı için güvenle sıraya alındı.',
                  ).replaceAll(
                    '{count}',
                    context.strings.number(result.recipientsEnqueued),
                  ),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('admin-notification-error'),
          content: Text(
            _copy(
              'The notification was not sent. Review the details and try again.',
              ar: 'لم يُرسل الإشعار. راجع التفاصيل وحاول مجددًا.',
              fr: 'La notification n’a pas été envoyée. Vérifiez les détails et réessayez.',
              es: 'La notificación no se envió. Revisa los datos e inténtalo de nuevo.',
              tr: 'Bildirim gönderilmedi. Bilgileri kontrol edip yeniden deneyin.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
    required super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          alignment: AlignmentDirectional.centerStart,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _AdminNotificationComposer extends StatefulWidget {
  const _AdminNotificationComposer({required this.preset});

  final AdminNotificationPreset preset;

  @override
  State<_AdminNotificationComposer> createState() =>
      _AdminNotificationComposerState();
}

class _AdminNotificationComposerState
    extends State<_AdminNotificationComposer> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final TextEditingController _messageController;
  AiCoachAdminNotificationAudience _audience =
      AiCoachAdminNotificationAudience.all;

  bool get _customReady =>
      widget.preset.kind != AiCoachAdminNotificationKind.custom ||
      _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: widget.preset.serverLocalized || widget.preset.id == 'custom'
          ? ''
          : widget.preset.body,
    );
  }

  String _copy(
    String en, {
    required String ar,
    required String fr,
    required String es,
    required String tr,
  }) {
    return AdminNotificationRuntimeCopy.resolve(
      en,
      Localizations.localeOf(context).toLanguageTag(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.preset.kind == AiCoachAdminNotificationKind.custom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(_description),
              if (widget.preset.serverLocalized) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  key: const Key('admin-notification-server-preview'),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(widget.preset.body),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ...[
                TextFormField(
                  key: const Key('admin-notification-custom-message'),
                  controller: _messageController,
                  autofocus: widget.preset.id == 'custom',
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 180,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(
                      RegExp(r'[\x00-\x1F\x7F]'),
                    ),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _copy(
                      'Notification text',
                      ar: 'نص الإشعار',
                      fr: 'Texte de la notification',
                      es: 'Texto de la notificación',
                      tr: 'Bildirim metni',
                    ),
                    hintText: _copy(
                      'Write the message exactly as users should receive it.',
                      ar: 'اكتب الرسالة كما تريد أن تصل للمستخدم تمامًا.',
                      fr: 'Rédigez le message exactement comme les utilisateurs doivent le recevoir.',
                      es: 'Escribe el mensaje exactamente como deben recibirlo los usuarios.',
                      tr: 'Mesajı kullanıcılara ulaşmasını istediğiniz biçimde yazın.',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (custom && text.isEmpty) {
                      return _copy(
                        'Write a message before continuing.',
                        ar: 'اكتب الرسالة قبل المتابعة.',
                        fr: 'Rédigez un message avant de continuer.',
                        es: 'Escribe un mensaje antes de continuar.',
                        tr: 'Devam etmeden önce bir mesaj yazın.',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              Text(
                _copy(
                  'Recipients',
                  ar: 'المستلمون',
                  fr: 'Destinataires',
                  es: 'Destinatarios',
                  tr: 'Alıcılar',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<AiCoachAdminNotificationAudience>(
                key: const Key('admin-notification-audience'),
                segments: [
                  ButtonSegment(
                    value: AiCoachAdminNotificationAudience.all,
                    icon: const Icon(Icons.groups_rounded),
                    label: Text(
                      _copy(
                        'Everyone',
                        ar: 'الجميع',
                        fr: 'Tous',
                        es: 'Todos',
                        tr: 'Herkes',
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: AiCoachAdminNotificationAudience.email,
                    icon: const Icon(Icons.person_rounded),
                    label: Text(
                      _copy(
                        'Specific email',
                        ar: 'بريد محدد',
                        fr: 'E-mail précis',
                        es: 'Correo concreto',
                        tr: 'Belirli e-posta',
                      ),
                    ),
                  ),
                ],
                selected: {_audience},
                onSelectionChanged: (selection) {
                  setState(() => _audience = selection.single);
                },
              ),
              if (_audience == AiCoachAdminNotificationAudience.email) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('admin-notification-email'),
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
                    border: const OutlineInputBorder(),
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
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('admin-notification-review'),
                onPressed: _customReady ? _review : null,
                icon: const Icon(Icons.fact_check_rounded),
                label: Text(
                  _copy(
                    'Review before sending',
                    ar: 'مراجعة قبل الإرسال',
                    fr: 'Vérifier avant l’envoi',
                    es: 'Revisar antes de enviar',
                    tr: 'Göndermeden önce incele',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title => widget.preset.title;

  String get _description {
    if (widget.preset.kind == AiCoachAdminNotificationKind.custom &&
        widget.preset.id != 'custom') {
      return _copy(
        'Review before sending',
        ar: 'مراجعة قبل الإرسال',
        fr: 'Vérifier avant l’envoi',
        es: 'Revisar antes de enviar',
        tr: 'Göndermeden önce incele',
      );
    }
    return switch (widget.preset.kind) {
      AiCoachAdminNotificationKind.compensation => _copy(
        'BIL will use its reviewed compensation copy. Choose who receives it.',
        ar: 'ستستخدم BIL صياغة التعويض المعتمدة. اختر من سيستلمها.',
        fr: 'BIL utilisera son texte de compensation validé. Choisissez les destinataires.',
        es: 'BIL usará su texto de compensación revisado. Elige quién lo recibirá.',
        tr: 'BIL onaylı telafi metnini kullanacak. Kimin alacağını seçin.',
      ),
      AiCoachAdminNotificationKind.gift => _copy(
        'BIL will use its reviewed gift copy. Choose who receives it.',
        ar: 'ستستخدم BIL صياغة الهدية المعتمدة. اختر من سيستلمها.',
        fr: 'BIL utilisera son texte cadeau validé. Choisissez les destinataires.',
        es: 'BIL usará su texto de regalo revisado. Elige quién lo recibirá.',
        tr: 'BIL onaylı hediye metnini kullanacak. Kimin alacağını seçin.',
      ),
      AiCoachAdminNotificationKind.custom => _copy(
        'Write the text first, then choose everyone or one exact email.',
        ar: 'اكتب النص أولًا، ثم اختر الجميع أو بريدًا محددًا.',
        fr: 'Rédigez d’abord le texte, puis choisissez tous les comptes ou un e-mail précis.',
        es: 'Escribe primero el texto y luego elige todos o un correo concreto.',
        tr: 'Önce metni yazın, ardından herkesi veya belirli bir e-postayı seçin.',
      ),
    };
  }

  void _review() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      _AdminNotificationRequest(
        kind: widget.preset.kind,
        audience: _audience,
        email: _audience == AiCoachAdminNotificationAudience.email
            ? _emailController.text.trim().toLowerCase()
            : null,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        previewMessage: _messageController.text.trim().isEmpty
            ? widget.preset.body
            : _messageController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

class _AdminNotificationRequest {
  const _AdminNotificationRequest({
    required this.kind,
    required this.audience,
    required this.email,
    required this.message,
    required this.previewMessage,
  });

  final AiCoachAdminNotificationKind kind;
  final AiCoachAdminNotificationAudience audience;
  final String? email;
  final String? message;
  final String previewMessage;
}
