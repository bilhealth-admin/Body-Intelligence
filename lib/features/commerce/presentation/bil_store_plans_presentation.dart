part of 'bil_store_plans_page.dart';

extension _BilStorePlansPresentation on _BilStorePlansPageState {
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
