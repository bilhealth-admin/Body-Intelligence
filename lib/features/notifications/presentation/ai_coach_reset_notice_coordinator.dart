import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../services/ai_coach_reset_notice_service.dart';

const _resetGiftCopy =
    'A gift from BIL 🎁 Your AI Coach usage has been fully reset. You can use your allowance again until the end of your current cycle.';

/// Surfaces durable owner-scoped notices after sign-in and on foreground
/// resume. General admin notices take precedence over reset gifts; dismissing
/// one immediately checks for the next queued notice.
///
/// Server RLS and the explicit owner filters restrict reads and acknowledgments
/// to the signed-in account. This coordinator treats the UI as presentation,
/// never as an authorization boundary.
class AiCoachResetNoticeCoordinator extends ConsumerStatefulWidget {
  const AiCoachResetNoticeCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AiCoachResetNoticeCoordinator> createState() =>
      _AiCoachResetNoticeCoordinatorState();
}

class _AiCoachResetNoticeCoordinatorState
    extends ConsumerState<AiCoachResetNoticeCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<String?>? _authSubscription;
  AiCoachResetNotice? _resetNotice;
  BilAdminNotice? _adminNotice;
  String? _signedInOwnerId;
  int _authGeneration = 0;
  bool _checking = false;
  bool _reloadQueued = false;
  bool _dismissing = false;
  bool _handedToSettings = false;

  bool get _hasNotice => _adminNotice != null || _resetNotice != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final gateway = ref.read(aiCoachResetNoticeGatewayProvider);
    _authSubscription = gateway.watchSignedInUserId().listen((ownerId) {
      if (!mounted) return;
      _authGeneration += 1;
      setState(() {
        _signedInOwnerId = ownerId;
        _resetNotice = null;
        _adminNotice = null;
        _handedToSettings = false;
      });
      if (ownerId != null) unawaited(_loadNotice());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadNotice());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadNotice());
  }

  Future<void> _loadNotice() async {
    if (_hasNotice) return;
    if (_checking) {
      _reloadQueued = true;
      return;
    }
    _checking = true;
    try {
      do {
        _reloadQueued = false;
        final requestedGeneration = _authGeneration;
        final requestedOwnerId = _signedInOwnerId;
        if (requestedOwnerId == null || _hasNotice) break;

        BilAdminNotice? adminNotice;
        try {
          adminNotice = await ref
              .read(bilAdminNoticeGatewayProvider)
              .newestUnseen();
        } on Object {
          // Reset gifts remain deliverable when this source is unavailable.
        }
        if (mounted &&
            adminNotice != null &&
            adminNotice.ownerId == requestedOwnerId &&
            _signedInOwnerId == requestedOwnerId &&
            _authGeneration == requestedGeneration) {
          setState(() {
            _adminNotice = adminNotice;
            _handedToSettings = false;
          });
          break;
        }

        final resetNotice = await ref
            .read(aiCoachResetNoticeGatewayProvider)
            .newestUnseen();
        if (mounted &&
            resetNotice != null &&
            resetNotice.ownerId == requestedOwnerId &&
            _signedInOwnerId == requestedOwnerId &&
            _authGeneration == requestedGeneration) {
          setState(() {
            _resetNotice = resetNotice;
            _handedToSettings = false;
          });
        }
      } while (_reloadQueued && !_hasNotice);
    } on Object {
      // A later resume/auth event retries without interrupting the app.
    } finally {
      _checking = false;
      if (_reloadQueued && mounted && !_hasNotice && _signedInOwnerId != null) {
        _reloadQueued = false;
        unawaited(_loadNotice());
      }
    }
  }

  Future<void> _dismiss() async {
    final adminNotice = _adminNotice;
    final resetNotice = _resetNotice;
    if ((adminNotice == null && resetNotice == null) || _dismissing) return;
    setState(() => _dismissing = true);
    try {
      if (adminNotice != null) {
        await ref.read(bilAdminNoticeGatewayProvider).dismiss(adminNotice);
        if (mounted &&
            _signedInOwnerId == adminNotice.ownerId &&
            _adminNotice?.notificationId == adminNotice.notificationId) {
          setState(() {
            _adminNotice = null;
            _handedToSettings = false;
          });
        }
      } else if (resetNotice != null) {
        await ref.read(aiCoachResetNoticeGatewayProvider).dismiss(resetNotice);
        if (mounted &&
            _signedInOwnerId == resetNotice.ownerId &&
            _resetNotice?.resetId == resetNotice.resetId) {
          setState(() {
            _resetNotice = null;
            _handedToSettings = false;
          });
        }
      }
    } on Object {
      // Keep the notice visible until its server acknowledgment succeeds.
    } finally {
      if (mounted) setState(() => _dismissing = false);
      if (mounted && !_hasNotice && _signedInOwnerId != null) {
        unawaited(_loadNotice());
      }
    }
  }

  void _openAiCoach() {
    setState(() => _handedToSettings = true);
    AppRouter.router.go('/settings/ai-coach');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resetNotice = _resetNotice;
    final adminNotice = _adminNotice;
    final hasVisibleNotice =
        (adminNotice != null || resetNotice != null) && !_handedToSettings;
    final presentation = _presentationFor(context, adminNotice?.kind);
    return Stack(
      children: [
        widget.child,
        if (hasVisibleNotice)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Material(
                    key: Key(
                      adminNotice == null
                          ? 'ai-coach-reset-root-notice'
                          : 'bil-admin-root-notice',
                    ),
                    elevation: 8,
                    color: presentation.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: presentation.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        12,
                        6,
                        12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            presentation.icon,
                            color: presentation.foreground,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (adminNotice != null) ...[
                                  Text(
                                    adminNotice.title,
                                    key: const Key('bil-admin-notice-title'),
                                    style: TextStyle(
                                      color: presentation.foreground,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Text(
                                  adminNotice?.body ??
                                      context.strings.text(_resetGiftCopy),
                                  key: Key(
                                    adminNotice == null
                                        ? 'ai-coach-reset-notice-body'
                                        : 'bil-admin-notice-body',
                                  ),
                                  style: TextStyle(
                                    color: presentation.foreground,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (resetNotice != null) ...[
                                  const SizedBox(height: 5),
                                  TextButton(
                                    key: const Key(
                                      'ai-coach-reset-root-notice-open',
                                    ),
                                    onPressed: _openAiCoach,
                                    child: Text(
                                      context.strings.text('Open AI Coach'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            key: Key(
                              adminNotice == null
                                  ? 'ai-coach-reset-root-notice-dismiss'
                                  : 'bil-admin-root-notice-dismiss',
                            ),
                            onPressed: _dismissing ? null : _dismiss,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            icon: _dismissing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  _NoticePresentation _presentationFor(
    BuildContext context,
    BilAdminNoticeKind? kind,
  ) {
    return switch (kind) {
      BilAdminNoticeKind.compensation => const _NoticePresentation(
        background: Color(0xFFFFF8E1),
        border: Color(0xFFE7C86A),
        foreground: Color(0xFF4E3A00),
        icon: Icons.favorite_rounded,
      ),
      BilAdminNoticeKind.gift => const _NoticePresentation(
        background: Color(0xFFEAF8F0),
        border: Color(0xFFB7E3CA),
        foreground: Color(0xFF123D2B),
        icon: Icons.card_giftcard_rounded,
      ),
      BilAdminNoticeKind.custom => _NoticePresentation(
        background: Theme.of(context).colorScheme.primaryContainer,
        border: Theme.of(context).colorScheme.outlineVariant,
        foreground: Theme.of(context).colorScheme.onPrimaryContainer,
        icon: Icons.notifications_active_rounded,
      ),
      null => const _NoticePresentation(
        background: Color(0xFFEAF8F0),
        border: Color(0xFFB7E3CA),
        foreground: Color(0xFF123D2B),
        icon: Icons.card_giftcard_rounded,
      ),
    };
  }
}

class _NoticePresentation {
  const _NoticePresentation({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}
