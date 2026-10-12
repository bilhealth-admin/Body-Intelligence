import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/environment/app_environment.dart';
import '../providers/app_purchase_providers.dart';
import '../providers/commerce_providers.dart';
import '../domain/store_benefit_delivery.dart';
import '../services/store_confirmation_journal.dart';
import '../services/store_purchase_trace.dart';
import '../services/verified_store_purchase_service.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../../shared/widgets/bil_experience_presentation.dart';
import 'app_purchase_presentation_routes.dart';
import 'store_benefit_confirmation.dart';

/// Lifetime for native receipt observers. Opening a success surface never
/// creates another listener, starts a checkout or changes a balance.
class AppPurchaseCoordinator extends ConsumerStatefulWidget {
  const AppPurchaseCoordinator({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AppPurchaseCoordinator> createState() =>
      _AppPurchaseCoordinatorState();
}

class _AppPurchaseCoordinatorState extends ConsumerState<AppPurchaseCoordinator>
    with WidgetsBindingObserver {
  Object? _initializedService;
  final _pending = <_PendingConfirmation>[];
  final _observed = <String>{};
  VoidCallback? _detachServices;
  DialogRoute<void>? _activeRoute;
  bool _presenting = false;
  bool _foreground = true;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    BilExperiencePresentation.occupied.addListener(_schedulePresentation);
    bilStorePresentationRouteObserver.changed.addListener(
      _schedulePresentation,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BilExperiencePresentation.occupied.removeListener(_schedulePresentation);
    bilStorePresentationRouteObserver.changed.removeListener(
      _schedulePresentation,
    );
    _detachServices?.call();
    final route = _activeRoute;
    if (route?.navigator != null) route!.navigator!.removeRoute(route);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _initializedService != null) {
      unawaited(_initialize());
      _schedulePresentation();
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    await Future.wait([
      ref.read(appSubscriptionPurchaseProvider).initialize(),
      ref.read(appBoostPurchaseProvider).initialize(),
    ]);
    if (!mounted) return;
    final subscription = ref.read(appSubscriptionPurchaseProvider);
    if (subscription.hasPendingVerifiedFinish) {
      unawaited(subscription.continueVerification());
    }
    final boost = ref.read(appBoostPurchaseProvider);
    if (boost.canRetry) unawaited(boost.retryPendingTransaction());
  }

  void _attachServices() {
    _detachServices?.call();
    final subscription = ref.read(appSubscriptionPurchaseProvider);
    final boost = ref.read(appBoostPurchaseProvider);
    void observeSubscription() {
      _schedulePresentation();
      final event = subscription.lastDelivery;
      if (event != null) {
        _observe(
          event,
          subscription.lastDeliveryIsUserPurchase,
          () =>
              mounted &&
              identical(
                ref.read(appSubscriptionPurchaseProvider),
                subscription,
              ) &&
              subscription.deliveryIsActive(event.eventKey) &&
              subscription.entitlement?.grantsPaidAccess == true,
          subscriptionLifecycle: () => subscription.entitlement?.lifecycle,
        );
      }
    }

    void observeBoost() {
      _schedulePresentation();
      final event = boost.lastDelivery;
      if (event != null) {
        _observe(
          event,
          boost.lastDeliveryIsUserPurchase,
          () =>
              mounted &&
              identical(ref.read(appBoostPurchaseProvider), boost) &&
              boost.deliveryIsActive(event.eventKey),
        );
      }
    }

    subscription.addListener(observeSubscription);
    boost.addListener(observeBoost);
    _detachServices = () {
      subscription.removeListener(observeSubscription);
      boost.removeListener(observeBoost);
    };
    observeSubscription();
    observeBoost();
  }

  Future<void> _observe(
    StoreBenefitDelivery event,
    bool userInitiated,
    bool Function() current, {
    String? Function()? subscriptionLifecycle,
  }) async {
    if (!current() || !event.active || !_observed.add(event.eventKey)) return;
    if (_observed.length > 512) _observed.remove(_observed.first);
    final preferences = ref.read(preferencesRepositoryProvider);
    bool ownerCurrent() =>
        current() &&
        ref.read(verifiedEntitlementOwnerIdProvider) == event.ownerId &&
        identical(ref.read(preferencesRepositoryProvider), preferences);
    final journal = StoreConfirmationJournal(preferences, ownerCurrent);
    try {
      if (await journal.enqueue(event, userInitiated: userInitiated) &&
          ownerCurrent()) {
        _pending.add(
          _PendingConfirmation(
            event,
            journal,
            ownerCurrent,
            subscriptionLifecycle,
          ),
        );
        _schedulePresentation();
      }
    } on Object {
      // Presentation storage is independent of the already committed benefit.
      _observed.remove(event.eventKey);
    }
  }

  void _schedulePresentation() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_presentNext());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _presentNext() async {
    final active = _activeRoute;
    if (active != null && _pending.isNotEmpty && !_pending.first.current()) {
      active.navigator?.removeRoute(active);
      return;
    }
    if (_presenting ||
        !_foreground ||
        bilStorePresentationRouteObserver.blocked ||
        _pending.isEmpty) {
      return;
    }
    final navigator = bilAppNavigatorKey.currentState;
    final context = bilAppNavigatorKey.currentContext;
    if (navigator == null || context == null || !context.mounted) return;
    final item = _pending.first;
    if (!item.current()) {
      _pending.removeAt(0);
      _schedulePresentation();
      return;
    }
    final release = BilExperiencePresentation.tryClaim();
    if (release == null) return;
    _presenting = true;
    try {
      if (!await item.journal.reserve(item.event) ||
          !item.current() ||
          !context.mounted ||
          !_foreground) {
        return;
      }
      late DialogRoute<void> route;
      route = DialogRoute<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(16),
          child: StoreBenefitConfirmation(
            delivery: item.event,
            subscriptionLifecycle: item.subscriptionLifecycle?.call(),
            onPainted: () async {
              try {
                if (item.current()) {
                  StorePurchaseTraceRegistry.forDelivery(
                    item.event.eventKey,
                  )?.mark(StorePurchaseStage.confirmationPainted);
                  await item.journal.painted(item.event);
                }
              } on Object {
                /* avoid historical replay after reservation */
              }
            },
            onContinue: () {
              if (route.navigator != null) route.navigator!.removeRoute(route);
            },
          ),
        ),
      );
      _activeRoute = route;
      await navigator.push<void>(route);
    } on Object {
      // Decorations never fail a financial transaction or reset a draft.
    } finally {
      _activeRoute = null;
      if (_pending.isNotEmpty && identical(_pending.first, item)) {
        _pending.removeAt(0);
      }
      _presenting = false;
      release();
      _schedulePresentation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppEnvironment.supabaseRuntimeReady &&
        AppEnvironment.commerceConfigured &&
        ref.watch(verifiedEntitlementOwnerIdProvider) != null) {
      final service = ref.watch(appSubscriptionPurchaseProvider);
      ref.watch(appBoostPurchaseProvider);
      if (!identical(service, _initializedService)) {
        _initializedService = service;
        _attachServices();
        _schedulePresentation();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_initialize());
        });
      }
    } else {
      _initializedService = null;
      _detachServices?.call();
      _detachServices = null;
      _schedulePresentation();
    }
    return widget.child;
  }
}

final class _PendingConfirmation {
  const _PendingConfirmation(
    this.event,
    this.journal,
    this.current,
    this.subscriptionLifecycle,
  );
  final StoreBenefitDelivery event;
  final StoreConfirmationJournal journal;
  final bool Function() current;
  final String? Function()? subscriptionLifecycle;
}
