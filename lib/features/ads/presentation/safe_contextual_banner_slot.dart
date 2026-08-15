import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ad_policy.dart';
import '../providers/ad_providers.dart';
import '../services/contextual_ad_gateway.dart';

class SafeContextualBannerSlot extends ConsumerStatefulWidget {
  const SafeContextualBannerSlot({required this.placement, super.key});

  final AdPlacement placement;

  @override
  ConsumerState<SafeContextualBannerSlot> createState() =>
      _SafeContextualBannerSlotState();
}

class _SafeContextualBannerSlotState
    extends ConsumerState<SafeContextualBannerSlot>
    with WidgetsBindingObserver {
  ContextualBannerHandle? _handle;
  bool _loading = false;
  bool _loadScheduled = false;
  bool _attempted = false;
  int _generation = 0;
  ContextualBannerGateway? _activeGateway;
  AdPlacement? _activePlacement;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (!active) _invalidate(immediate: true);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation += 1;
    _handle?.dispose();
    _handle = null;
    super.dispose();
  }

  Future<void> _load(ContextualBannerGateway gateway) async {
    if (_loading || _handle != null) return;
    final generation = _generation;
    final placement = widget.placement;
    _loading = true;
    _attempted = true;
    _activeGateway = gateway;
    _activePlacement = placement;
    ContextualBannerHandle? loaded;
    try {
      loaded = await gateway.loadBanner(placement);
    } catch (_) {
      // Provider/network failures suppress the slot. They must never escape the
      // presentation boundary or leave the slot permanently loading.
    }
    if (!mounted ||
        generation != _generation ||
        !identical(gateway, _activeGateway) ||
        placement != _activePlacement) {
      loaded?.dispose();
      return;
    }
    setState(() {
      _loading = false;
      _handle = loaded;
    });
  }

  void _invalidate({bool immediate = false}) {
    _generation += 1;
    _loading = false;
    _loadScheduled = false;
    _attempted = false;
    _activeGateway = null;
    _activePlacement = null;
    final stale = _handle;
    if (stale == null) return;
    _handle = null;
    if (immediate) {
      stale.dispose();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => stale.dispose());
    }
  }

  void _scheduleLoad(ContextualBannerGateway gateway) {
    if (_loadScheduled || _loading || _attempted || _handle != null) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      _load(gateway);
    });
  }

  @override
  Widget build(BuildContext context) {
    final decision = ref.watch(adDecisionProvider(widget.placement));
    final gateway = ref.watch(contextualAdGatewayProvider);
    if (!_appActive ||
        !decision.mayRequestAd ||
        gateway is! ContextualBannerGateway ||
        !gateway.isConfigured) {
      if (_handle != null || _loading || _loadScheduled) _invalidate();
      return const SizedBox.shrink();
    }
    if ((_activeGateway != null && !identical(_activeGateway, gateway)) ||
        (_activePlacement != null && _activePlacement != widget.placement)) {
      _invalidate();
    }
    if (_handle == null && !_loading && !_attempted) {
      _scheduleLoad(gateway);
      return const SizedBox.shrink();
    }
    final handle = _handle;
    if (handle == null) return const SizedBox.shrink();
    return Semantics(
      label: MaterialLocalizations.of(context).alertDialogLabel,
      container: true,
      child: Center(child: handle.widget),
    );
  }
}
