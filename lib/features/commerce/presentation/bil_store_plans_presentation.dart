part of 'bil_store_plans_page.dart';

extension _BilStorePlansPresentation on _BilStorePlansPageState {
  String? _ownedActiveProductHint(
    VerifiedStorePurchaseService? store,
    CommercePlan? currentPlan,
  ) {
    if (store == null ||
        currentPlan == null ||
        currentPlan == CommercePlan.free ||
        store.state != VerifiedStoreState.verified ||
        store.busy ||
        store.userOperationInProgress ||
        store.verifiedInactiveAt != null) {
      return null;
    }
    final productId = store.lastVerifiedProductId;
    final binding = productId == null
        ? null
        : StoreCatalogConfiguration.bindingForProduct(productId);
    final proof = store.entitlement;
    if (binding?.plan != currentPlan ||
        proof?.plan != currentPlan ||
        proof?.grantsPaidAccess != true ||
        !const {
          'app_store',
          'google_play',
        }.contains(store.benefitStoreSource)) {
      return null;
    }
    final visit = store.captureCatalogVisit();
    try {
      final owner = ref.read(verifiedEntitlementOwnerIdProvider);
      return owner != null &&
              owner == visit.ownerId &&
              owner == store.benefitOwnerId &&
              store.isCurrentCatalogVisit(visit)
          ? productId
          : null;
    } on StateError {
      return null;
    }
  }

  (String?, bool) _purchaseFeedbackFor(VerifiedStorePurchaseService store) {
    final code = store.presentationMessageCode;
    // A background StoreKit replay is not a purchase made on this screen.
    // Keep its failure in the service (including the checkout safety block),
    // and explain it only after an explicit Restore/verification action.
    if (code == 'reconciliation_pending' ||
        code == 'reconciliation_verification_failed') {
      return (null, false);
    }
    // A verified receipt can arrive while AppStore.sync is still pending.
    // Preserve the valid benefit, but never call the Restore operation done
    // until its own lifecycle settles.
    if (store.isRecoveringSubscription ||
        (store.isRestoring && store.state != VerifiedStoreState.failed)) {
      return ('restore_checking', false);
    }
    if (!store.lastDeliveryIsUserPurchase &&
        !store.isRestoring &&
        (code == 'subscription_verified' ||
            code == 'ai_boost_verified' ||
            (code == 'store_finish_pending' &&
                store.verifiedInactiveAt == null))) {
      return (null, false);
    }
    final key = switch (code) {
      'purchase_pending' => 'purchase_awaiting_approval',
      'restore_pending' => 'restore_checking',
      'restore_cancelled' => 'restore_cancelled',
      'restore_unconfirmed' => 'restore_unconfirmed',
      'reconciliation_pending' => 'purchase_reconciliation_pending',
      // Cancelling the native sheet is an intentional choice, not an error.
      // Keep the catalog actionable so another term can be selected at once.
      'purchase_cancelled' => null,
      'purchase_not_started' => 'purchase_error',
      'store_catalog_changed' => 'purchase_catalog_changed',
      'store_catalog_refresh_failed' => 'purchase_error',
      'purchase_unavailable' || 'authentication_required' => 'purchase_error',
      'purchase_status_unknown' => 'purchase_confirmation_pending',
      'license_unlicensed' => 'license_unlicensed',
      'play_license_recovered' => 'play_license_recovered',
      'play_readiness_unavailable' => 'play_readiness_unavailable',
      'verification_failed' => 'purchase_verification_unavailable',
      'store_finish_pending' =>
        store.verifiedInactiveAt != null
            ? 'purchase_inactive'
            : 'purchase_verified',
      'restore_verification_failed' => 'restore_verification_failed',
      'purchase_owned_by_another_account' =>
        'purchase_owned_by_another_account',
      'reconciliation_verification_failed' => 'purchase_reconciliation_failed',
      'purchase_failed' || 'store_stream_failed' => 'purchase_error',
      'subscription_verified' || 'ai_boost_verified' => 'purchase_verified',
      _ => switch (store.state) {
        VerifiedStoreState.purchasePending => 'purchase_in_progress',
        VerifiedStoreState.cancelled => null,
        VerifiedStoreState.failed => 'purchase_error',
        _ => null,
      },
    };
    final isError =
        const {
          'purchase_error',
          'purchase_owned_by_another_account',
          'restore_verification_failed',
          'purchase_reconciliation_failed',
        }.contains(key) ||
        code == 'verification_failed';
    return (key, isError);
  }

  String _purchaseFeedbackText(String locale, String key) {
    final text = BilStoreCopy.text(locale, key);
    final code = key == 'restore_failed'
        ? (widget.store ?? _ownedStore)?.restoreSupportCode
        : null;
    return code == null ? text : '$text ($code)';
  }

  void _leavePlans() =>
      context.canPop() ? context.pop() : context.go('/dashboard');

  Widget _accountAccessStatus({
    required String locale,
    required AsyncValue<SubscriptionState> access,
    required CommercePlan? plan,
  }) {
    final copy = AppLocalizations(Localizations.localeOf(context));
    final active = plan != null && plan != CommercePlan.free;
    final checking = access.isLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active) ...[
            Text(
              '${BilStoreCopy.text(locale, 'current_plan')}: '
              '${BilStoreCopy.text(locale, plan == CommercePlan.premiumAiCoach ? 'premium_ai_coach' : 'premium')}',
              key: const Key('store-current-plan-status'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(copy.text('Active')),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('store-current-plan-continue'),
              onPressed: _leavePlans,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(BilStoreCopy.text(locale, 'continue')),
            ),
          ] else if (plan == null) ...[
            Text(
              checking
                  ? BilStoreCopy.text(locale, 'plans')
                  : copy.text('Subscription check unavailable'),
              key: const Key('store-account-access-status'),
            ),
            if (!checking)
              TextButton.icon(
                key: const Key('store-account-access-retry'),
                onPressed: () =>
                    ref.invalidate(verifiedSubscriptionStateProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(copy.text('Try again')),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openLegalLink(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    try {
      final opened =
          await (widget.openLegalUrl?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened || !mounted) return;
    } on Object {
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          BilStoreCopy.text(
            Localizations.localeOf(context).toLanguageTag(),
            'purchase_error',
          ),
        ),
      ),
    );
  }
}
