import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../services/ai_coach_reset_notice_service.dart';

const _resetGiftCopy =
    'A gift from BIL 🎁 Your current-period AI Coach usage was reset, and 2,500 non-expiring AI Boost tokens were added.';

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
    // A reset notice is evidence that any cached access/balance snapshot may
    // predate a server-side mutation. Invalidate access and notify an already
    // mounted settings page before navigating. Neither operation waits on the
    // network or derives a replacement balance locally; both consumers reload
    // from bil_get_ai_usage_status.
    ref.invalidate(aiCoachCreditAccessProvider);
    ref.read(aiCoachUsageRefreshProvider.notifier).requestAuthoritativeReload();
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
    final noticeTitle = adminNotice?.title ?? _resetGiftTitle(context);
    final noticeBody =
        adminNotice?.body ??
        resetNotice?.message ??
        context.strings.text(_resetGiftCopy);
    final rootKey = adminNotice == null
        ? 'ai-coach-reset-root-notice'
        : 'bil-admin-root-notice';
    final dismissKey = adminNotice == null
        ? 'ai-coach-reset-root-notice-dismiss'
        : 'bil-admin-root-notice-dismiss';
    return Stack(
      children: [
        widget.child,
        if (hasVisibleNotice)
          Positioned.fill(
            child: Stack(
              children: [
                const ModalBarrier(
                  key: Key('bil-premium-notice-modal-barrier'),
                  color: Color(0x99030F17),
                  dismissible: false,
                ),
                SafeArea(
                  minimum: const EdgeInsets.all(20),
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Semantics(
                          namesRoute: true,
                          label: noticeTitle,
                          child: Material(
                            key: Key(rootKey),
                            elevation: 28,
                            shadowColor: const Color(0x99000000),
                            color: Colors.transparent,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: BorderSide(
                                color: presentation.border,
                                width: 1.25,
                              ),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    presentation.background,
                                    Color.alphaBlend(
                                      presentation.foreground.withValues(
                                        alpha: 0.055,
                                      ),
                                      presentation.background,
                                    ),
                                  ],
                                ),
                              ),
                              child: Stack(
                                children: [
                                  PositionedDirectional(
                                    top: 8,
                                    end: 8,
                                    child: IconButton.filledTonal(
                                      key: Key(dismissKey),
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
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                          28,
                                          34,
                                          28,
                                          28,
                                        ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 76,
                                          height: 76,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                presentation.foreground,
                                                presentation.foreground
                                                    .withValues(alpha: 0.72),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: presentation.foreground
                                                    .withValues(alpha: 0.24),
                                                blurRadius: 24,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            presentation.icon,
                                            color: Colors.white,
                                            size: 36,
                                          ),
                                        ),
                                        const SizedBox(height: 22),
                                        Text(
                                          noticeTitle,
                                          key: adminNotice == null
                                              ? const Key(
                                                  'ai-coach-reset-notice-title',
                                                )
                                              : const Key(
                                                  'bil-admin-notice-title',
                                                ),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: presentation.foreground,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.35,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          noticeBody,
                                          key: Key(
                                            adminNotice == null
                                                ? 'ai-coach-reset-notice-body'
                                                : 'bil-admin-notice-body',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: presentation.foreground,
                                                height: 1.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            key: Key('$rootKey-acknowledge'),
                                            onPressed: _dismissing
                                                ? null
                                                : _dismiss,
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  presentation.foreground,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(
                                                double.infinity,
                                                54,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(17),
                                              ),
                                            ),
                                            child: Text(
                                              MaterialLocalizations.of(
                                                context,
                                              ).okButtonLabel,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (resetNotice != null ||
                                            (adminNotice != null &&
                                                adminNotice.kind !=
                                                    BilAdminNoticeKind
                                                        .custom)) ...[
                                          const SizedBox(height: 8),
                                          TextButton.icon(
                                            key: const Key(
                                              'ai-coach-reset-root-notice-open',
                                            ),
                                            onPressed: _openAiCoach,
                                            icon: const Icon(
                                              Icons.auto_awesome_rounded,
                                            ),
                                            label: Text(
                                              context.strings.text(
                                                'Open AI Coach',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _resetGiftTitle(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ar' => 'هدية لك من BIL',
      'fr' => 'Un cadeau de BIL',
      'es' => 'Un regalo de BIL',
      'tr' => "BIL'den bir hediye",
      _ => 'A gift from BIL',
    };
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
