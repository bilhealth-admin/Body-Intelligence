import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/community_attention.dart';
import '../services/community_owner_operation.dart';
import 'community_copy.dart';

/// One authenticated subscription owner for More, Community and Messages.
class CommunityAttentionScope extends StatefulWidget {
  const CommunityAttentionScope({
    required this.child,
    this.client,
    this.controller,
    super.key,
  });
  final Widget child;
  final SupabaseClient? client;
  final CommunityAttentionController? controller;

  static CommunityAttentionController? controllerOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AttentionInherited>()
          ?.notifier;

  static Future<void> refresh(BuildContext context) =>
      controllerOf(context)?.refresh() ?? Future.value();

  @override
  State<CommunityAttentionScope> createState() =>
      _CommunityAttentionScopeState();
}

class _CommunityAttentionScopeState extends State<CommunityAttentionScope>
    with WidgetsBindingObserver {
  static const _push = MethodChannel('bil/push');
  SupabaseClient? _client;
  late final CommunityAttentionController _controller =
      widget.controller ?? CommunityAttentionController(_load);
  late final bool _ownsController = widget.controller == null;
  StreamSubscription<AuthState>? _auth;
  RealtimeChannel? _channel;
  Timer? _retry;
  Timer? _debounce;
  String? _subscribedOwner;
  int _bindingGeneration = 0;
  int? _lastBadge;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller.addListener(_updateNativeBadge);
    if (!_ownsController) {
      return;
    }
    _bindClient();
  }

  @override
  void didUpdateWidget(covariant CommunityAttentionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An injected controller is owned and bound by its caller. Replacing a
    // client only rebinds this scope's own authenticated controller.
    if (_ownsController && !identical(oldWidget.client, widget.client)) {
      _retireClient();
      _bindClient();
    }
  }

  void _bindClient() {
    _client = widget.client;
    if (_client == null &&
        AppEnvironment.communityConfigured &&
        AppEnvironment.supabaseRuntimeReady) {
      _client = Supabase.instance.client;
    }
    final client = _client;
    if (client != null) {
      _auth = client.auth.onAuthStateChange.listen((state) {
        if (mounted && identical(client, _client)) {
          _bindOwner(client, state.session?.user.id);
        }
      }, onError: (Object _) {});
      _bindOwner(client, client.auth.currentUser?.id);
      _retry = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_resumed) {
          _refreshCurrent();
        }
      });
    }
  }

  void _retireClient() {
    _bindingGeneration++;
    _retry?.cancel();
    _retry = null;
    _debounce?.cancel();
    _debounce = null;
    unawaited(_auth?.cancel());
    _auth = null;
    final client = _client;
    final channel = _channel;
    _channel = null;
    _client = null;
    _subscribedOwner = null;
    if (client != null && channel != null) {
      unawaited(client.removeChannel(channel));
    }
    _controller.setOwner(null);
  }

  bool _isCurrentBinding(SupabaseClient client, String owner, int generation) =>
      mounted &&
      identical(client, _client) &&
      generation == _bindingGeneration &&
      owner == _subscribedOwner &&
      owner == client.auth.currentUser?.id;

  Future<CommunityAttention> _load() {
    final client = _client;
    final owner = _subscribedOwner;
    final generation = _bindingGeneration;
    if (client == null || owner == null) {
      throw const CommunityOwnerOperationCancelled();
    }
    return CommunityOwnerOperation.run(
      client: client,
      ownerId: owner,
      isCurrentOwner: () => _isCurrentBinding(client, owner, generation),
      action: (operation) async {
        final response = await client.rpc('bil_community_attention_v2');
        operation.check();
        if (response is! Map) {
          throw const FormatException('Invalid Community attention response');
        }
        return CommunityAttention.fromJson(Map<String, dynamic>.from(response));
      },
    );
  }

  void _bindOwner(SupabaseClient client, String? owner) {
    if (owner == _subscribedOwner && owner == _controller.owner) {
      if (owner != null) {
        _refreshCurrent();
      } else {
        _updateNativeBadge();
      }
      return;
    }
    final previous = _channel;
    _channel = null;
    if (previous != null) {
      unawaited(client.removeChannel(previous));
    }
    final generation = ++_bindingGeneration;
    _debounce?.cancel();
    _subscribedOwner = owner;
    // A queued B event must retire A even if the SDK has already restored A.
    // Do not issue B's load using that newer A session; wait for its own event.
    _controller.setOwner(null);
    if (owner == null || owner != client.auth.currentUser?.id) {
      return;
    }
    _controller.setOwner(owner);
    void changed(PostgresChangePayload _) =>
        _scheduleRefresh(client, owner, generation);
    _channel = client
        .channel(
          'community-attention-$owner-${identityHashCode(this)}-$generation',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bil_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: owner,
          ),
          callback: changed,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bil_friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'addressee_id',
            value: owner,
          ),
          callback: changed,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bil_community_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: owner,
          ),
          callback: changed,
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _scheduleRefresh(client, owner, generation);
          }
        });
  }

  void _refreshCurrent() {
    final client = _client;
    final owner = _subscribedOwner;
    if (client != null &&
        owner != null &&
        _isCurrentBinding(client, owner, _bindingGeneration)) {
      unawaited(_controller.refresh());
    }
  }

  void _scheduleRefresh(SupabaseClient client, String owner, int generation) {
    if (!_resumed || !_isCurrentBinding(client, owner, generation)) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (_resumed && _isCurrentBinding(client, owner, generation)) {
        unawaited(_controller.refresh());
      }
    });
  }

  void _updateNativeBadge() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        _controller.stale) {
      return;
    }
    final count = _controller.value.total;
    if (count == _lastBadge) {
      return;
    }
    _lastBadge = count;
    unawaited(_writeBadge(count));
  }

  Future<void> _writeBadge(int count) async {
    final generation = _bindingGeneration;
    try {
      await _push.invokeMethod<void>('setBadgeCount', count);
    } on Object {
      // An old native host or denied permission must not break in-app badges.
      if (mounted && generation == _bindingGeneration && _lastBadge == count) {
        _lastBadge = null;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) {
      _lastBadge = null;
      if (_ownsController) {
        _refreshCurrent();
      } else {
        unawaited(_controller.refresh());
      }
    } else {
      _debounce?.cancel();
    }
  }

  @override
  void dispose() {
    _bindingGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _debounce?.cancel();
    unawaited(_auth?.cancel());
    final channel = _channel;
    if (channel != null) {
      unawaited(_client!.removeChannel(channel));
    }
    _controller.removeListener(_updateNativeBadge);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _AttentionInherited(notifier: _controller, child: widget.child);
}

class _AttentionInherited
    extends InheritedNotifier<CommunityAttentionController> {
  const _AttentionInherited({required super.notifier, required super.child});
}

enum CommunityAttentionKind { messages, requests, all }

/// Compact number with an explicit accessible label; zero is not displayed.
class CommunityUnreadBadge extends StatelessWidget {
  const CommunityUnreadBadge({
    this.kind = CommunityAttentionKind.all,
    this.child,
    super.key,
  });
  final CommunityAttentionKind kind;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final value =
        CommunityAttentionScope.controllerOf(context)?.value ??
        const CommunityAttention();
    final count = switch (kind) {
      CommunityAttentionKind.messages => value.unreadMessages,
      CommunityAttentionKind.requests => value.incomingRequests,
      CommunityAttentionKind.all => value.total,
    };
    if (count == 0) {
      return child ?? const SizedBox.shrink();
    }
    final label = switch (kind) {
      CommunityAttentionKind.messages => communityText(
        context,
        'Unread messages',
        'الرسائل غير المقروءة',
      ),
      CommunityAttentionKind.requests => communityText(
        context,
        'Friend requests',
        'طلبات الصداقة',
      ),
      CommunityAttentionKind.all => communityText(
        context,
        'Community updates',
        'تحديثات المجتمع',
      ),
    };
    return Semantics(
      label: '$label: $count',
      child: Badge(
        alignment: AlignmentDirectional.topEnd,
        backgroundColor: Theme.of(context).colorScheme.error,
        textColor: Theme.of(context).colorScheme.onError,
        label: Text(CommunityAttention.badgeText(count)),
        child: child,
      ),
    );
  }
}
