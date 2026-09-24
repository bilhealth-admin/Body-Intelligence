import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../services/community_push_service.dart';

/// Refreshes an enabled owner's provider token after sign-in, token rotation,
/// app restart, or foreground resume. All failures are retryable and must not
/// interrupt local reminders or the local-first application shell.
class CommunityPushRegistrationCoordinator extends StatefulWidget {
  const CommunityPushRegistrationCoordinator({required this.child, super.key});

  final Widget child;

  @override
  State<CommunityPushRegistrationCoordinator> createState() =>
      _CommunityPushRegistrationCoordinatorState();
}

class _CommunityPushRegistrationCoordinatorState
    extends State<CommunityPushRegistrationCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  CommunityPushService? _service;
  bool _refreshing = false;
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    if (!CommunityPushService.isAvailable ||
        !AppEnvironment.supabaseRuntimeReady) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    final client = Supabase.instance.client;
    _service = CommunityPushService(client);
    _authSubscription = client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) unawaited(_refresh());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && client.auth.currentUser != null) unawaited(_refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final service = _service;
    if (service == null) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshQueued = false;
        try {
          await service.refreshRegistrationIfEnabled();
        } on Object {
          // A later auth, startup, or resume event retries safely.
        }
      } while (_refreshQueued);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
