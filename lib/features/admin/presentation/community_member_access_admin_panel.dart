import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../services/community_member_access_admin_service.dart';

class CommunityMemberAccessAdminPanel extends ConsumerStatefulWidget {
  const CommunityMemberAccessAdminPanel({super.key});

  @override
  ConsumerState<CommunityMemberAccessAdminPanel> createState() =>
      _CommunityMemberAccessAdminPanelState();
}

class _CommunityMemberAccessAdminPanelState
    extends ConsumerState<CommunityMemberAccessAdminPanel> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController();
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
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suspended = ref.watch(communitySuspendedMemberListProvider);
    return Card(
      key: const Key('admin-community-member-access-panel'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.policy_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _copy(
                      'Community access and approvals',
                      ar: 'دخول المجتمع والموافقات',
                      fr: 'Accès et validations de la communauté',
                      es: 'Acceso y aprobaciones de la comunidad',
                      tr: 'Topluluk erişimi ve onayları',
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
                'Open the human review queue to approve or reject posts and reports. Suspending an account blocks new Community activity at the server until an administrator restores access.',
                ar: 'افتح قائمة المراجعة البشرية لاعتماد أو رفض المنشورات والبلاغات. تعليق الحساب يمنع أي نشاط جديد في المجتمع من الخادم حتى يعيد الأدمن تفعيله.',
                fr: 'Ouvrez la file de révision humaine pour approuver ou refuser les publications et signalements. La suspension bloque toute nouvelle activité côté serveur jusqu’au rétablissement par un administrateur.',
                es: 'Abre la cola de revisión humana para aprobar o rechazar publicaciones y denuncias. La suspensión bloque nueva actividad en el servidor hasta que un administrador restaure el acceso.',
                tr: 'Gönderi ve bildirimleri onaylamak veya reddetmek için insan inceleme kuyruğunu açın. Askıya alma, yönetici erişimi geri verene kadar yeni topluluk etkinliğini sunucuda engeller.',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('admin-community-open-moderation'),
              onPressed: () => context.push('/community/moderation'),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                _copy(
                  'Open approval queue',
                  ar: 'فتح قائمة الموافقات',
                  fr: 'Ouvrir la file de validation',
                  es: 'Abrir cola de aprobaciones',
                  tr: 'Onay kuyruğunu aç',
                ),
              ),
            ),
            const Divider(height: 32),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('admin-community-suspend-email'),
                    controller: _emailController,
                    enabled: !_mutating,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    maxLength: 254,
                    decoration: InputDecoration(
                      labelText: _copy(
                        'Member account email',
                        ar: 'بريد حساب العضو',
                        fr: 'E-mail du membre',
                        es: 'Correo del miembro',
                        tr: 'Üye hesabı e-postası',
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
                    key: const Key('admin-community-suspend-reason'),
                    controller: _reasonController,
                    enabled: !_mutating,
                    maxLength: 160,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _copy(
                        'Audit reason',
                        ar: 'سبب مسجل للتدقيق',
                        fr: 'Motif d’audit',
                        es: 'Motivo de auditoría',
                        tr: 'Denetim nedeni',
                      ),
                    ),
                    validator: (value) {
                      final reason = value?.trim() ?? '';
                      if (reason.length < 2) {
                        return _copy(
                          'Write at least two characters.',
                          ar: 'اكتب حرفين على الأقل.',
                          fr: 'Écrivez au moins deux caractères.',
                          es: 'Escribe al menos dos caracteres.',
                          tr: 'En az iki karakter yazın.',
                        );
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      key: const Key('admin-community-suspend-member'),
                      onPressed: _mutating ? null : _confirmAndSuspend,
                      icon: const Icon(Icons.person_off_outlined),
                      label: Text(
                        _copy(
                          'Suspend Community access',
                          ar: 'تعليق دخول المجتمع',
                          fr: 'Suspendre l’accès',
                          es: 'Suspender acceso',
                          tr: 'Topluluk erişimini askıya al',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _copy(
                'Suspended members',
                ar: 'الأعضاء المعلقون',
                fr: 'Membres suspendus',
                es: 'Miembros suspendidos',
                tr: 'Askıya alınan üyeler',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            suspended.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('admin-community-suspended-retry'),
                  onPressed: () =>
                      ref.invalidate(communitySuspendedMemberListProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.strings.text('Try again')),
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? Text(
                      _copy(
                        'No account is suspended.',
                        ar: 'لا يوجد حساب معلق.',
                        fr: 'Aucun compte n’est suspendu.',
                        es: 'No hay cuentas suspendidas.',
                        tr: 'Askıya alınmış hesap yok.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final entry in entries)
                          ListTile(
                            key: ValueKey(
                              'admin-community-suspended-${entry.userId}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.block_outlined),
                            ),
                            title: Text(entry.email),
                            subtitle: Text(entry.reason),
                            trailing: IconButton(
                              key: ValueKey(
                                'admin-community-reinstate-${entry.userId}',
                              ),
                              tooltip: _copy(
                                'Restore access',
                                ar: 'إعادة الدخول',
                                fr: 'Rétablir l’accès',
                                es: 'Restaurar acceso',
                                tr: 'Erişimi geri ver',
                              ),
                              onPressed: _mutating
                                  ? null
                                  : () => _confirmAndReinstate(entry),
                              icon: const Icon(Icons.person_add_alt_outlined),
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

  Future<void> _confirmAndSuspend() async {
    if (_formKey.currentState?.validate() != true || _mutating) return;
    final email = _emailController.text.trim().toLowerCase();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('admin-community-suspend-confirmation'),
        title: Text(
          _copy(
            'Suspend Community access?',
            ar: 'تعليق دخول المجتمع؟',
            fr: 'Suspendre l’accès à la communauté ?',
            es: '¿Suspender acceso a la comunidad?',
            tr: 'Topluluk erişimi askıya alınsın mı?',
          ),
        ),
        content: Text(email),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            key: const Key('admin-community-suspend-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _copy(
                'Suspend',
                ar: 'تعليق',
                fr: 'Suspendre',
                es: 'Suspender',
                tr: 'Askıya al',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _mutating = true);
    try {
      final result = await ref
          .read(communityMemberAccessAdminGatewayProvider)
          .suspendMember(email: email, reason: _reasonController.text);
      if (!mounted) return;
      final message = !result.matched
          ? _copy(
              'No account matches that email.',
              ar: 'لا يوجد حساب مطابق لهذا البريد.',
              fr: 'Aucun compte ne correspond à cet e-mail.',
              es: 'Ninguna cuenta coincide con ese correo.',
              tr: 'Bu e-postayla eşleşen hesap yok.',
            )
          : result.changed
          ? _copy(
              'Community access suspended.',
              ar: 'تم تعليق دخول المجتمع.',
              fr: 'Accès à la communauté suspendu.',
              es: 'Acceso a la comunidad suspendido.',
              tr: 'Topluluk erişimi askıya alındı.',
            )
          : _copy(
              'This account is already suspended.',
              ar: 'هذا الحساب معلق بالفعل.',
              fr: 'Ce compte est déjà suspendu.',
              es: 'Esta cuenta ya está suspendida.',
              tr: 'Bu hesap zaten askıya alınmış.',
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (result.matched) {
        _emailController.clear();
        _reasonController.clear();
        ref.invalidate(communitySuspendedMemberListProvider);
      }
    } on Object {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _confirmAndReinstate(CommunitySuspendedMemberEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('admin-community-reinstate-confirmation'),
        title: Text(
          _copy(
            'Restore Community access?',
            ar: 'إعادة دخول المجتمع؟',
            fr: 'Rétablir l’accès à la communauté ?',
            es: '¿Restaurar acceso a la comunidad?',
            tr: 'Topluluk erişimi geri verilsin mi?',
          ),
        ),
        content: Text(entry.email),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            key: const Key('admin-community-reinstate-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _copy(
                'Restore',
                ar: 'إعادة',
                fr: 'Rétablir',
                es: 'Restaurar',
                tr: 'Geri ver',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _mutating) return;

    setState(() => _mutating = true);
    try {
      final reinstated = await ref
          .read(communityMemberAccessAdminGatewayProvider)
          .reinstateMember(entry.userId);
      if (!mounted) return;
      if (!reinstated) {
        _showFailure();
      } else {
        ref.invalidate(communitySuspendedMemberListProvider);
      }
    } on Object {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _showFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.strings.text(
            'The request could not be completed. No partial change was kept. Try again.',
          ),
        ),
      ),
    );
  }
}
