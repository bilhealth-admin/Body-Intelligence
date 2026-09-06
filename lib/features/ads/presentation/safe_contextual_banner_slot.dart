import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commerce/providers/commerce_providers.dart';
import '../domain/ad_policy.dart';
import '../providers/ad_providers.dart';
import '../services/contextual_ad_gateway.dart';

class SafeContextualBannerSlot extends ConsumerStatefulWidget {
  const SafeContextualBannerSlot({
    required this.placement,
    @visibleForTesting this.now,
    super.key,
  });

  final AdPlacement placement;
  final DateTime Function()? now;

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
  bool _appActive = false;
  ContextualAdPrivacyBoundary? _privacyBoundary;
  bool? _privacyWasAllowed;
  String? _ownerScope;
  Timer? _retryTimer;
  int _retryCount = 0;
  DateTime? _lastAttemptAt;
  static const _retryDelays = [Duration(seconds: 30), Duration(seconds: 60)];
  static const _minimumAttemptInterval = Duration(seconds: 30);

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  String? get _currentOwner {
    final owner = ref.read(verifiedEntitlementOwnerProvider);
    return owner.isLoading || owner.hasError ? null : owner.asData?.value;
  }

  Duration get _cooldownRemaining {
    final previous = _lastAttemptAt;
    if (previous == null) return Duration.zero;
    final elapsed = _now.difference(previous);
    if (elapsed.isNegative) return _minimumAttemptInterval;
    return elapsed >= _minimumAttemptInterval
        ? Duration.zero
        : _minimumAttemptInterval - elapsed;
  }

  void _watchPrivacy(ContextualAdGateway gateway) {
    final boundary = switch (gateway) {
      ContextualAdPrivacyBoundary value => value,
      _ => null,
    };
    if (identical(boundary, _privacyBoundary)) return;
    _privacyBoundary?.removeListener(_privacyChanged);
    _privacyBoundary = boundary;
    _privacyWasAllowed = boundary?.mayDisplayAd;
    boundary?.addListener(_privacyChanged);
  }

  void _privacyChanged() {
    if (!mounted) return;
    final allowed = _privacyBoundary?.mayDisplayAd ?? false;
    final wasAllowed = _privacyWasAllowed;
    _privacyWasAllowed = allowed;
    // Initial UMP refresh starts closed. Only a true-to-false transition is a
    // withdrawal of an existing grant; do not cancel that initial refresh.
    if (!allowed && (wasAllowed == true || _handle != null)) {
      _invalidate(immediate: true);
      // Wait for an explicit new grant rather than repeatedly retrying denial.
      _attempted = true;
      setState(() {});
    } else if (allowed &&
        wasAllowed == false &&
        !_loading &&
        _handle == null &&
        _attempted) {
      _retryTimer?.cancel();
      _retryTimer = null;
      setState(() {
        _attempted = false;
        _retryCount = 0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Observers receive future transitions, not the state before mounting.
    // A newly inserted slot must never assume it is already in the foreground.
    _appActive =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
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
    _privacyBoundary?.removeListener(_privacyChanged);
    _generation += 1;
    _retryTimer?.cancel();
    _handle?.dispose();
    _handle = null;
    super.dispose();
  }

  Future<void> _load(ContextualBannerGateway gateway) async {
    if (_loading || _handle != null) return;
    final owner = _currentOwner;
    final currentDecision = ref.read(adDecisionProvider(widget.placement));
    final currentGateway = ref.read(contextualAdGatewayProvider);
    if (owner == null ||
        !_appActive ||
        !currentDecision.mayRequestAd ||
        currentGateway is! ContextualBannerGateway ||
        !identical(currentGateway, gateway) ||
        !gateway.isConfigured) {
      return;
    }
    final cooldown = _cooldownRemaining;
    if (cooldown > Duration.zero) {
      _armRetry(gateway, cooldown);
      return;
    }
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
    // A native callback can resolve just before consent/entitlement changes,
    // while the Future continuation has not yet installed its handle. The
    // notification then sees no displayed ad, so validate again at hand-off.
    if (_currentOwner != owner ||
        !_appActive ||
        !ref.read(adDecisionProvider(placement)).mayRequestAd ||
        !identical(ref.read(contextualAdGatewayProvider), gateway) ||
        !gateway.isConfigured ||
        _privacyBoundary?.mayDisplayAd == false) {
      loaded?.dispose();
      loaded = null;
    }
    setState(() {
      _loading = false;
      _handle = loaded;
    });
    if (loaded != null) {
      _retryCount = 0;
      _lastAttemptAt = null;
    } else if (_retryCount < _retryDelays.length &&
        _currentOwner == owner &&
        _appActive &&
        ref.read(adDecisionProvider(placement)).mayRequestAd &&
        identical(ref.read(contextualAdGatewayProvider), gateway) &&
        gateway.isConfigured &&
        _privacyBoundary?.mayDisplayAd == true) {
      // A live transport is not proof of working Internet. Retry a failed
      // load at most twice; never timer-refresh a banner already on screen.
      _lastAttemptAt = _now;
      _armRetry(gateway, _retryDelays[_retryCount++]);
    }
  }

  void _armRetry(ContextualBannerGateway gateway, Duration delay) {
    if (_retryTimer != null || _loading || _handle != null) return;
    final generation = _generation;
    final owner = _currentOwner;
    final placement = widget.placement;
    _activeGateway = gateway;
    _activePlacement = placement;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!mounted ||
          generation != _generation ||
          owner == null ||
          _currentOwner != owner ||
          widget.placement != placement ||
          !_appActive ||
          _handle != null ||
          _loading ||
          !ref.read(adDecisionProvider(placement)).mayRequestAd ||
          !identical(ref.read(contextualAdGatewayProvider), gateway) ||
          !gateway.isConfigured) {
        return;
      }
      // Initial consent may still be unknown, but a retry after a failed ad
      // request must not reopen a withdrawn/denied grant.
      if (_attempted && _privacyBoundary?.mayDisplayAd == false) return;
      _load(gateway);
    });
  }

  void _invalidate({bool immediate = false}) {
    _generation += 1;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
    // Preserve the request cooldown across transport flaps and plan changes.
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
    if (_loadScheduled ||
        _loading ||
        _attempted ||
        _retryTimer != null ||
        _handle != null) {
      return;
    }
    final scheduledGeneration = _generation;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted || scheduledGeneration != _generation || !_appActive) {
        return;
      }
      final currentDecision = ref.read(adDecisionProvider(widget.placement));
      final currentGateway = ref.read(contextualAdGatewayProvider);
      if (!currentDecision.mayRequestAd ||
          currentGateway is! ContextualBannerGateway ||
          !identical(currentGateway, gateway) ||
          !gateway.isConfigured) {
        return;
      }
      _load(gateway);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ownerState = ref.watch(verifiedEntitlementOwnerProvider);
    final owner = ownerState.isLoading || ownerState.hasError
        ? null
        : ownerState.asData?.value;
    // A Free-to-Free account switch can keep the policy reason identical.
    // Watch the opaque local owner independently; never send it to AdMob.
    if (owner != null && owner != _ownerScope) {
      _invalidate(immediate: true);
      _ownerScope = owner;
      _lastAttemptAt = null;
    }
    final decision = ref.watch(adDecisionProvider(widget.placement));
    final gateway = ref.watch(contextualAdGatewayProvider);
    _watchPrivacy(gateway);
    if (owner == null ||
        !_appActive ||
        !decision.mayRequestAd ||
        gateway is! ContextualBannerGateway ||
        !gateway.isConfigured) {
      if (_handle != null ||
          _loading ||
          _loadScheduled ||
          _attempted ||
          _retryTimer != null) {
        _invalidate(immediate: true);
      }
      return const SizedBox.shrink();
    }
    if ((_activeGateway != null && !identical(_activeGateway, gateway)) ||
        (_activePlacement != null && _activePlacement != widget.placement)) {
      _invalidate(immediate: true);
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: handle.widget),
      ),
    );
  }
}
