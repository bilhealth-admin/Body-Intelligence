import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_referral.dart';
import 'community_copy.dart';

class CommunityInviteLandingPage extends StatefulWidget {
  const CommunityInviteLandingPage({
    required this.token,
    this.repository,
    this.client,
    super.key,
  });

  final String token;
  final CommunityRepository? repository;
  final SupabaseClient? client;

  @override
  State<CommunityInviteLandingPage> createState() =>
      _CommunityInviteLandingPageState();
}

class _CommunityInviteLandingPageState
    extends State<CommunityInviteLandingPage> {
  CommunityRepository? _repository;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _auth;
  late Future<CommunityInvitePreview> _preview;
  CommunityInviteAcceptance? _acceptance;
  bool _accepting = false;

  bool get _signedIn => _client?.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? _productionClient();
    _repository = widget.repository ?? _productionRepository();
    _preview = _loadPreview();

    final client = _client;
    if (client != null) {
      _auth = client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      }, onError: (Object _) {});
    }
  }

  SupabaseClient? _productionClient() {
    if (!AppEnvironment.supabaseRuntimeReady) return null;
    try {
      final supabase = Supabase.instance;
      return supabase.isInitialized ? supabase.client : null;
    } on Object {
      return null;
    }
  }

  CommunityRepository? _productionRepository() {
    final client = _client ?? _productionClient();
    return client == null ? null : CommunityRepository(client);
  }

  Future<CommunityInvitePreview> _loadPreview() async {
    final repository = _repository;
    if (repository == null ||
        !CommunityInviteCreateResult.tokenPattern.hasMatch(widget.token)) {
      return const CommunityInvitePreview(
        status: CommunityInvitePreviewStatus.invalid,
      );
    }
    return repository.previewCommunityInvite(widget.token);
  }

  void _retry() {
    setState(() => _preview = _loadPreview());
  }

  Future<void> _accept() async {
    final repository = _repository;
    if (repository == null || _accepting) return;
    if (!_signedIn) {
      await context.push('/login');
      if (!mounted || !_signedIn) return;
    }

    setState(() => _accepting = true);
    try {
      final acceptance = await repository.acceptCommunityInvite(widget.token);
      if (!mounted) return;
      setState(() => _acceptance = acceptance);
      if (!acceptance.attributed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_acceptanceMessage(context, acceptance.status)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not accept this invitation safely. Try again.',
                'تعذر قبول هذه الدعوة بأمان. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  void dispose() {
    unawaited(_auth?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(communityText(context, 'BIL invitation', 'دعوة BIL')),
    ),
    body: FutureBuilder<CommunityInvitePreview>(
      future: _preview,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _InviteState(
            icon: Icons.cloud_off_outlined,
            title: communityText(
              context,
              'Invitation unavailable',
              'الدعوة غير متاحة',
            ),
            body: communityText(
              context,
              'BIL could not verify this invitation safely.',
              'تعذر على BIL التحقق من هذه الدعوة بأمان.',
            ),
            action: FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          );
        }

        final preview = snapshot.requireData;
        if (!preview.active) {
          return _InviteState(
            icon: Icons.link_off_rounded,
            title: communityText(
              context,
              'Invitation unavailable',
              'الدعوة غير متاحة',
            ),
            body: preview.status == CommunityInvitePreviewStatus.disabled
                ? communityText(
                    context,
                    'Tracked BIL invitations are not active yet.',
                    'دعوات BIL المتتبعة غير مفعّلة بعد.',
                  )
                : communityText(
                    context,
                    'This invitation is invalid, expired, or already used.',
                    'هذه الدعوة غير صالحة أو منتهية أو تم استخدامها.',
                  ),
          );
        }

        final accepted = _acceptance?.relationshipAccepted == true;
        final inviterName =
            _acceptance?.displayName ?? preview.displayName ?? 'BIL member';
        final inviterId = _acceptance?.inviterId ?? preview.inviterId;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BilAccountAvatar(
                        radius: 44,
                        networkUrl: _acceptance?.avatarUrl ?? preview.avatarUrl,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        communityText(
                          context,
                          '$inviterName invited you to join BIL',
                          '$inviterName دعاك للانضمام إلى BIL',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if ((_acceptance?.handle ?? preview.handle) != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          '@${_acceptance?.handle ?? preview.handle}',
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        accepted
                            ? communityText(
                                context,
                                'Invitation accepted and friendship created. Gold is still gated by new-account and server integrity checks.',
                                'تم قبول الدعوة وإنشاء الصداقة. وتبقى مكافأة Gold مشروطة بكون الحساب جديدًا واجتياز تحقق الخادم.',
                              )
                            : communityText(
                                context,
                                'Accepting records who invited you. It does not grant Gold by itself.',
                                'القبول يسجل من قام بدعوتك، ولا يمنح Gold بمفرده.',
                              ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (!accepted)
                        FilledButton.icon(
                          key: const Key('community-accept-invite'),
                          onPressed: _accepting ? null : _accept,
                          icon: _accepting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _signedIn
                                ? communityText(
                                    context,
                                    'Accept invitation',
                                    'قبول الدعوة',
                                  )
                                : communityText(
                                    context,
                                    'Sign in to accept',
                                    'سجّل الدخول للقبول',
                                  ),
                          ),
                        )
                      else if (inviterId != null)
                        FilledButton.icon(
                          key: const Key('community-open-inviter-profile'),
                          onPressed: () =>
                              context.push('/community/profile/$inviterId'),
                          icon: const Icon(Icons.people_rounded),
                          label: Text(
                            communityText(
                              context,
                              'You’re friends — view profile',
                              'أصبحتما صديقين — عرض الملف',
                            ),
                          ),
                        ),
                      if (!_signedIn && !accepted) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: Text(
                            communityText(
                              context,
                              'Create an account',
                              'إنشاء حساب',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _InviteState extends StatelessWidget {
  const _InviteState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

String _acceptanceMessage(
  BuildContext context,
  CommunityInviteAcceptStatus status,
) => switch (status) {
  CommunityInviteAcceptStatus.disabled => communityText(
    context,
    'Tracked invitations are not active yet.',
    'الدعوات المتتبعة غير مفعّلة بعد.',
  ),
  CommunityInviteAcceptStatus.invalid => communityText(
    context,
    'This invitation is invalid or expired.',
    'هذه الدعوة غير صالحة أو منتهية.',
  ),
  CommunityInviteAcceptStatus.selfInvite => communityText(
    context,
    'You cannot accept your own invitation.',
    'لا يمكنك قبول دعوتك الخاصة.',
  ),
  CommunityInviteAcceptStatus.unavailable => communityText(
    context,
    'This invitation is unavailable.',
    'هذه الدعوة غير متاحة.',
  ),
  CommunityInviteAcceptStatus.alreadyAttributed => communityText(
    context,
    'Another invitation is already linked to this account.',
    'هناك دعوة أخرى مرتبطة بهذا الحساب بالفعل.',
  ),
  CommunityInviteAcceptStatus.consumed => communityText(
    context,
    'This invitation was already used.',
    'تم استخدام هذه الدعوة مسبقًا.',
  ),
  CommunityInviteAcceptStatus.attributed => communityText(
    context,
    'Invitation saved.',
    'تم حفظ الدعوة.',
  ),
};
