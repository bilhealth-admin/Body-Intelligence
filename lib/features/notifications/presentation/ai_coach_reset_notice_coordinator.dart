import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../services/ai_coach_reset_notice_service.dart';

const _resetGiftCopy =
    'A gift from BIL 🎁 Your AI Coach usage has been fully reset. You can use your allowance again until the end of your current cycle.';

/// Surfaces a durable reset gift after sign-in and on foreground resume.
///
/// The server RLS policy and the explicit owner filter both restrict reads and
/// acknowledgements to the signed-in account. A notice stays visible until it
/// is handed to the AI Coach settings page or its acknowledgement succeeds.
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
  AiCoachResetNotice? _notice;
  String? _signedInOwnerId;
  int _authGeneration = 0;
  bool _checking = false;
  bool _reloadQueued = false;
  bool _dismissing = false;
  bool _handedToSettings = false;

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
        _notice = null;
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
    if (_notice != null) return;
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
        if (requestedOwnerId == null || _notice != null) break;
        final notice = await ref
            .read(aiCoachResetNoticeGatewayProvider)
            .newestUnseen();
        if (mounted &&
            notice != null &&
            notice.ownerId == requestedOwnerId &&
            _signedInOwnerId == requestedOwnerId &&
            _authGeneration == requestedGeneration) {
          setState(() {
            _notice = notice;
            _handedToSettings = false;
          });
        }
      } while (_reloadQueued && _notice == null);
    } on Object {
      // A later resume/auth event retries without interrupting the app.
    } finally {
      _checking = false;
      if (_reloadQueued &&
          mounted &&
          _notice == null &&
          _signedInOwnerId != null) {
        _reloadQueued = false;
        unawaited(_loadNotice());
      }
    }
  }

  Future<void> _dismiss() async {
    final notice = _notice;
    if (notice == null || _dismissing) return;
    setState(() => _dismissing = true);
    try {
      await ref.read(aiCoachResetNoticeGatewayProvider).dismiss(notice);
      if (mounted &&
          _signedInOwnerId == notice.ownerId &&
          _notice?.ownerId == notice.ownerId &&
          _notice?.resetId == notice.resetId) {
        setState(() {
          _notice = null;
          _handedToSettings = false;
        });
      }
    } on Object {
      // Keep the gift visible until its server acknowledgement succeeds.
    } finally {
      if (mounted) setState(() => _dismissing = false);
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
    final notice = _notice;
    return Stack(
      children: [
        widget.child,
        if (notice != null && !_handedToSettings)
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
                    key: const Key('ai-coach-reset-root-notice'),
                    elevation: 8,
                    color: const Color(0xFFEAF8F0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFB7E3CA)),
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
                          const Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFF17784C),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.strings.text(_resetGiftCopy),
                                  style: const TextStyle(
                                    color: Color(0xFF123D2B),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
                            ),
                          ),
                          IconButton(
                            key: const Key(
                              'ai-coach-reset-root-notice-dismiss',
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
}
