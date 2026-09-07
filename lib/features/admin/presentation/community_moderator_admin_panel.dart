import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../services/admin_operation_error.dart';
import '../services/community_moderator_admin_service.dart';

class CommunityModeratorAdminPanel extends ConsumerStatefulWidget {
  const CommunityModeratorAdminPanel({super.key});

  @override
  ConsumerState<CommunityModeratorAdminPanel> createState() =>
      _CommunityModeratorAdminPanelState();
}

class _CommunityModeratorAdminPanelState
    extends ConsumerState<CommunityModeratorAdminPanel> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _mutating = false;

  String _copy(
    String en, {
    required String ar,
    required String fr,
    required String es,
    required String tr,
  }) => switch (Localizations.localeOf(context).languageCode) {
    'ar' => ar,
    'fr' => fr,
    'es' => es,
    'tr' => tr,
    _ => context.strings.text(en),
  };

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moderators = ref.watch(communityModeratorAdminListProvider);
    return Card(
      key: const Key('admin-community-moderators-panel'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _copy(
                      'Community moderators',
                      ar: 'مشرفو المجتمع',
                      fr: 'Modérateurs de la communauté',
                      es: 'Moderadores de la comunidad',
                      tr: 'Topluluk moderatörleri',
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
                'Only an administrator can add or remove moderators. Protected administrators cannot be removed from the review roster.',
                ar: 'الأدمن وحده يستطيع إضافة المشرفين أو إزالتهم. لا يمكن إزالة الأدمن المحمي من قائمة المراجعة.',
                fr: 'Seul un administrateur peut ajouter ou retirer des modérateurs. Les administrateurs protégés restent dans l’équipe de révision.',
                es: 'Solo un administrador puede añadir o quitar moderadores. Los administradores protegidos permanecen en el equipo de revisión.',
                tr: 'Moderatörleri yalnızca yönetici ekleyebilir veya kaldırabilir. Korumalı yöneticiler inceleme ekibinden çıkarılamaz.',
              ),
            ),
            const SizedBox(height: 14),
            Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('admin-community-moderator-email'),
                      controller: _emailController,
                      enabled: !_mutating,
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
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      key: const Key('admin-community-moderator-add'),
                      onPressed: _mutating ? null : _add,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        _copy(
                          'Add',
                          ar: 'إضافة',
                          fr: 'Ajouter',
                          es: 'Añadir',
                          tr: 'Ekle',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            moderators.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('admin-community-moderator-retry'),
                  onPressed: () =>
                      ref.invalidate(communityModeratorAdminListProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.strings.text('Try again')),
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? Text(
                      _copy(
                        'No moderators are configured.',
                        ar: 'لا يوجد مشرفون مضافون.',
                        fr: 'Aucun modérateur configuré.',
                        es: 'No hay moderadores configurados.',
                        tr: 'Yapılandırılmış moderatör yok.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final entry in entries)
                          ListTile(
                            key: ValueKey(
                              'admin-community-moderator-${entry.userId}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.shield_outlined),
                            ),
                            title: Text(entry.email),
                            subtitle: entry.protectedAdministrator
                                ? Text(
                                    _copy(
                                      'Protected administrator',
                                      ar: 'أدمن محمي',
                                      fr: 'Administrateur protégé',
                                      es: 'Administrador protegido',
                                      tr: 'Korumalı yönetici',
                                    ),
                                  )
                                : null,
                            trailing: IconButton(
                              key: ValueKey(
                                'admin-community-moderator-remove-${entry.userId}',
                              ),
                              tooltip: context.strings.text('Delete'),
                              onPressed:
                                  _mutating || entry.protectedAdministrator
                                  ? null
                                  : () => _remove(entry),
                              icon: const Icon(Icons.person_remove_outlined),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    if (_formKey.currentState?.validate() != true || _mutating) return;
    setState(() => _mutating = true);
    try {
      final result = await ref
          .read(communityModeratorAdminGatewayProvider)
          .addModerator(_emailController.text);
      if (!mounted) return;
      final message = !result.matched
          ? _copy(
              'No account matches that email.',
              ar: 'لا يوجد حساب مطابق لهذا البريد.',
              fr: 'Aucun compte ne correspond à cet e-mail.',
              es: 'Ninguna cuenta coincide con ese correo.',
              tr: 'Bu e-postayla eşleşen hesap yok.',
            )
          : result.added
          ? _copy(
              'Moderator added.',
              ar: 'تمت إضافة المشرف.',
              fr: 'Modérateur ajouté.',
              es: 'Moderador añadido.',
              tr: 'Moderatör eklendi.',
            )
          : _copy(
              'This account is already a moderator.',
              ar: 'هذا الحساب مشرف بالفعل.',
              fr: 'Ce compte est déjà modérateur.',
              es: 'Esta cuenta ya es moderadora.',
              tr: 'Bu hesap zaten moderatör.',
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (result.matched) {
        _emailController.clear();
        ref.invalidate(communityModeratorAdminListProvider);
      }
    } on Object catch (error) {
      if (mounted) _showFailure(error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _remove(CommunityModeratorAdminEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('admin-community-moderator-remove-confirmation'),
        title: Text(
          _copy(
            'Remove moderator?',
            ar: 'إزالة المشرف؟',
            fr: 'Retirer le modérateur ?',
            es: '¿Quitar moderador?',
            tr: 'Moderatör kaldırılsın mı?',
          ),
        ),
        content: Text(entry.email),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            key: const Key('admin-community-moderator-remove-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _mutating) return;
    setState(() => _mutating = true);
    try {
      final removed = await ref
          .read(communityModeratorAdminGatewayProvider)
          .removeModerator(entry.userId);
      if (!mounted) return;
      if (!removed) {
        _showFailure(StateError('community_moderator_remove_rejected'));
      } else {
        ref.invalidate(communityModeratorAdminListProvider);
      }
    } on Object catch (error) {
      if (mounted) _showFailure(error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _showFailure(Object error) {
    final kind = classifyAdminOperationFailure(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _copy(
            _moderatorFailureEnglish(kind),
            ar: _moderatorFailureArabic(kind),
            fr: _moderatorFailureEnglish(kind),
            es: _moderatorFailureEnglish(kind),
            tr: _moderatorFailureEnglish(kind),
          ),
        ),
      ),
    );
  }

  String _moderatorFailureEnglish(
    AdminOperationFailureKind kind,
  ) => switch (kind) {
    AdminOperationFailureKind.timedOut =>
      'The admin operation timed out. Check that the Edge Function is deployed, then try again.',
    AdminOperationFailureKind.serviceUnavailable =>
      'The admin service is not available. Deploy the current Edge Function and migrations, then try again.',
    AdminOperationFailureKind.authorization =>
      'This account is not authorized for the admin operation, or the deployed service is using an older admin roster.',
    AdminOperationFailureKind.integrity =>
      'Mobile integrity verification blocked the operation. Use a signed build or keep the server canary in off mode during QA.',
    _ =>
      'The request could not be completed. No partial change was kept. Try again.',
  };

  String _moderatorFailureArabic(
    AdminOperationFailureKind kind,
  ) => switch (kind) {
    AdminOperationFailureKind.timedOut =>
      'انتهت مهلة عملية الإدارة. تأكد من نشر Edge Function ثم حاول مجددًا.',
    AdminOperationFailureKind.serviceUnavailable =>
      'خدمة الإدارة غير متاحة. انشر Edge Function والترحيلات الحالية ثم حاول مجددًا.',
    AdminOperationFailureKind.authorization =>
      'هذا الحساب غير مخول بعملية الإدارة، أو أن الخدمة المنشورة تستخدم قائمة أدمن قديمة.',
    AdminOperationFailureKind.integrity =>
      'تحقق سلامة التطبيق منع العملية. استخدم نسخة موقعة أو أبقِ وضع الاختبار في الخادم على off أثناء QA.',
    _ => 'تعذر إكمال الطلب، ولم يُحفظ أي تغيير جزئي. حاول مجددًا.',
  };
}
