import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commerce/providers/commerce_providers.dart';
import '../providers/ad_providers.dart';
import '../services/admob_ump_consent_gate.dart';

/// Starts Google's Android UMP flow automatically for the current eligible
/// account after Flutter's first frame.
///
/// BIL does not persist a second advertising opt-in or age confirmation. The
/// audience is the current server-verified adult Free account; Premium and
/// Guest never enter UMP for ad delivery. Account identity is part of the
/// refresh signature so a logout or account switch cannot carry eligibility
/// from the previous session.
class BilAndroidUmpBootstrap extends ConsumerStatefulWidget {
  const BilAndroidUmpBootstrap({
    required this.child,
    super.key,
    this.coordinator,
    this.enabled,
    this.audienceEligible,
    this.accountKey,
  });

  final Widget child;
  final UmpConsentCoordinator? coordinator;

  @visibleForTesting
  final bool? enabled;

  @visibleForTesting
  final bool? audienceEligible;

  @visibleForTesting
  final String? accountKey;

  @override
  ConsumerState<BilAndroidUmpBootstrap> createState() =>
      _BilAndroidUmpBootstrapState();
}

class _BilAndroidUmpBootstrapState
    extends ConsumerState<BilAndroidUmpBootstrap> {
  String? _lastSignature;
  int _generation = 0;

  void _scheduleRefresh({
    required bool enabled,
    required bool audienceEligible,
    required String? accountKey,
  }) {
    final signature = '$enabled|$audienceEligible|${accountKey ?? '-'}';
    if (_lastSignature == signature) return;
    _lastSignature = signature;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      unawaited(
        _refreshIfEligible(
          enabled: enabled,
          audienceEligible: audienceEligible,
          accountKey: accountKey,
          generation: generation,
        ),
      );
    });
  }

  Future<void> _refreshIfEligible({
    required bool enabled,
    required bool audienceEligible,
    required String? accountKey,
    required int generation,
  }) async {
    if (!enabled || !audienceEligible || accountKey == null) return;
    try {
      final coordinator = widget.coordinator ?? AdMobUmpConsentGate.instance;
      await coordinator.refresh(force: true);
      if (!mounted || generation != _generation) return;
    } on Object {
      // UMP itself remains fail closed. Startup never turns a platform or
      // network failure into permission to request an ad.
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = widget.coordinator ?? AdMobUmpConsentGate.instance;
    final enabled =
        widget.enabled ??
        (coordinator.isApplicable &&
            ref.watch(contextualAdGatewayProvider).isConfigured);
    final owner = ref.watch(verifiedEntitlementOwnerProvider);
    final accountKey = widget.accountKey ?? owner.asData?.value;
    final bool audienceEligible =
        widget.audienceEligible ??
        ref.watch(registeredAdultFreeAdAudienceProvider);
    _scheduleRefresh(
      enabled: enabled,
      audienceEligible: audienceEligible,
      accountKey: accountKey,
    );
    return widget.child;
  }
}
