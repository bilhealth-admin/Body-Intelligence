import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/commerce_plan.dart';
import '../domain/market_offer_policy.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import '../domain/store_price_comparison.dart';
import 'ai_boost_coach_artwork.dart';
import 'bil_store_copy.dart';
import 'premium_crown_emblem.dart';

part 'bil_dynamic_store_components.dart';
part 'bil_dynamic_store_plan_components.dart';

bool _isVerifiedAiTrialOffer(BilStoreOfferMetadata offer) =>
    offer.kind == BilStoreProductKind.premiumAiCoachSubscription &&
    StoreCatalogConfiguration.isAiTrialProduct(offer.productId) &&
    offer.trialEligible == true &&
    const {'P1W', 'P7D'}.contains(offer.trialPeriodIso8601) &&
    const {'P1M', 'P1Y'}.contains(offer.billingPeriodIso8601);

/// Store-driven offers. Prices and promotions always come from the device
/// store; this surface never grants entitlement locally.
class BilDynamicStoreOffers extends StatefulWidget {
  const BilDynamicStoreOffers({
    required this.locale,
    required this.offers,
    required this.onPurchaseRequested,
    required this.onRestore,
    required this.onManage,
    this.loading = false,
    this.restoreInProgress = false,
    this.currentPlan = CommercePlan.free,
    this.initialFocus,
    super.key,
  });

  final String locale;
  final List<BilStoreOfferMetadata> offers;
  final ValueChanged<BilStoreOfferMetadata> onPurchaseRequested;
  final VoidCallback? onRestore;
  final VoidCallback? onManage;
  final bool loading;
  final bool restoreInProgress;
  final CommercePlan currentPlan;
  final String? initialFocus;

  @override
  State<BilDynamicStoreOffers> createState() => _BilDynamicStoreOffersState();
}

class _BilDynamicStoreOffersState extends State<BilDynamicStoreOffers> {
  BilStoreOfferMetadata? _selectedOffer;

  String _copy(String key) => BilStoreCopy.text(widget.locale, key);

  @override
  void initState() {
    super.initState();
    _selectedOffer = _preferredOffer(widget.offers);
  }

  @override
  void didUpdateWidget(covariant BilDynamicStoreOffers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFocus != widget.initialFocus) {
      _selectedOffer = _preferredOffer(widget.offers);
      return;
    }
    final available = MarketOfferPolicy.visibleOffers(widget.offers);
    final selectionStillAvailable = available.any(
      (offer) => _offerIdentity(offer) == _offerIdentity(_selectedOffer),
    );
    if (!selectionStillAvailable) _selectedOffer = _preferredOffer(available);
  }

  BilStoreOfferMetadata? _preferredOffer(List<BilStoreOfferMetadata> source) {
    final visible = MarketOfferPolicy.visibleOffers(source);
    if (widget.initialFocus == 'boost') {
      for (final offer in visible) {
        if (offer.kind == BilStoreProductKind.aiBoostConsumable) return offer;
      }
      // A Boost deep link must never fall through to a subscription purchase.
      return null;
    }
    if (widget.initialFocus == 'ai-coach') {
      for (final offer in visible) {
        if (offer.kind == BilStoreProductKind.premiumAiCoachSubscription) {
          return offer;
        }
      }
      // The AI Coach subscription CTA is exact. If that product is unavailable
      // in the current storefront, do not silently select ordinary Premium.
      return null;
    }
    final subscriptions = visible
        .where((offer) => offer.kind != BilStoreProductKind.aiBoostConsumable)
        .toList(growable: false);
    for (final offer in subscriptions) {
      if (offer.billingPeriodIso8601 == 'P1Y') return offer;
    }
    if (subscriptions.isNotEmpty) return subscriptions.first;
    return visible.isEmpty ? null : visible.first;
  }

  String _offerIdentity(BilStoreOfferMetadata? offer) =>
      '${offer?.productId ?? ''}|${offer?.offerId ?? ''}|${offer?.basePlanId ?? ''}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final grouped = <BilStoreProductKind, List<BilStoreOfferMetadata>>{};
    final visibleOffers = MarketOfferPolicy.visibleOffers(widget.offers);
    for (final offer in visibleOffers) {
      grouped.putIfAbsent(offer.kind, () => []).add(offer);
    }
    final target = MarketOfferPolicy.targetPlanForKinds(
      visibleOffers.map((offer) => offer.kind),
    );
    // Unknown or unconfigured storefronts fail closed to the token model.
    // Premium AI Coach appears only when the store explicitly returns it for
    // an eligible profitable market.
    final kinds = target == null
        ? const <BilStoreProductKind>[
            BilStoreProductKind.premiumSubscription,
            BilStoreProductKind.aiBoostConsumable,
          ]
        : <BilStoreProductKind>[
            if (target == CommercePlan.premium)
              BilStoreProductKind.premiumSubscription
            else
              BilStoreProductKind.premiumAiCoachSubscription,
            BilStoreProductKind.aiBoostConsumable,
          ];

    final selectedOffer = _selectedOffer;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            key: const ValueKey('store-offers-background'),
            decoration: BoxDecoration(
              color: dark ? scheme.surface : Colors.white,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                selectedOffer == null ? 36 : 126,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StoreHero(
                        // Keep one visible Premium label per route. The tier
                        // title below owns that label in Premium storefronts;
                        // AI storefronts name the coach and use one inherited
                        // benefit line to explain the Premium relationship.
                        eyebrow: _copy('plans'),
                        title: _copy('premium_store_title'),
                      ),
                      const SizedBox(height: 16),
                      for (final kind in kinds) ...[
                        _StoreTierCard(
                          kind: kind,
                          title: _copy(switch (kind) {
                            BilStoreProductKind.premiumSubscription =>
                              'premium',
                            BilStoreProductKind.premiumAiCoachSubscription =>
                              'premium_ai_coach',
                            BilStoreProductKind.aiBoostConsumable => 'ai_boost',
                          }),
                          detail: _copy(switch (kind) {
                            BilStoreProductKind.premiumSubscription =>
                              'premium_detail',
                            BilStoreProductKind.premiumAiCoachSubscription =>
                              'premium_ai_detail',
                            BilStoreProductKind.aiBoostConsumable =>
                              'boost_detail',
                          }),
                          eyebrow: kind == BilStoreProductKind.aiBoostConsumable
                              ? _copy('boost_eyebrow')
                              : null,
                          benefits: _benefitKeys(
                            kind,
                            grouped[kind] ?? const [],
                          ).map(_copy).toList(growable: false),
                          currentLabel: _isCurrent(kind)
                              ? _copy('current_plan')
                              : null,
                          offers: grouped[kind] ?? const [],
                          loadingLabel: _copy('store_loading'),
                          unavailableLabel: _copy('store_unavailable'),
                          monthlyLabel: _copy('monthly'),
                          annualLabel: _copy('annual'),
                          locale: widget.locale,
                          billedMonthlyLabel: _copy('billed_monthly'),
                          billedAnnuallyLabel: _copy('billed_annually'),
                          twelveMonthlyPaymentsLabel: _copy(
                            'twelve_monthly_payments',
                          ),
                          monthlyEquivalentLabel: _copy('monthly_equivalent'),
                          perMonthLabel: _copy('per_month'),
                          saveLabel: _copy('save'),
                          trialLabel: _copy('trial'),
                          sevenDayTrialLabel: _copy('trial_7_days'),
                          trialRenewsMonthlyLabel: _copy(
                            'trial_renews_monthly',
                          ),
                          trialRenewsAnnuallyLabel: _copy(
                            'trial_renews_annually',
                          ),
                          viewAllFeaturesLabel: _copy('view_all_features'),
                          showFewerFeaturesLabel: _copy('show_fewer_features'),
                          loading: widget.loading,
                          selectedOfferIdentity: _offerIdentity(selectedOffer),
                          onOfferSelected: (offer) =>
                              setState(() => _selectedOffer = offer),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _FreeTierCard(
                        label: _copy('free'),
                        benefits: [
                          for (var index = 1; index <= 5; index++)
                            _copy('free_benefit_$index'),
                        ],
                        currentLabel: widget.currentPlan == CommercePlan.free
                            ? _copy('current_plan')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: widget.restoreInProgress
                            ? null
                            : widget.onRestore,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: dark
                              ? scheme.onSurface
                              : const Color(0xFF343434),
                          side: BorderSide(
                            color: dark
                                ? scheme.outlineVariant
                                : const Color(0xFFE0E0E5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: widget.restoreInProgress
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Icon(Icons.restore_rounded, size: 19),
                        label: Text(
                          _copy(
                            widget.restoreInProgress
                                ? 'restore_checking'
                                : 'restore',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onManage,
                        style: TextButton.styleFrom(
                          foregroundColor: dark
                              ? scheme.onSurfaceVariant
                              : const Color(0xFF66666F),
                        ),
                        child: Text(_copy('manage')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (selectedOffer != null)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: _StickyPurchaseBar(
              label: _copy('continue'),
              price: selectedOffer.localizedPrice,
              loading: widget.loading,
              onPressed: () => widget.onPurchaseRequested(selectedOffer),
            ),
          ),
      ],
    );
  }

  bool _isCurrent(BilStoreProductKind kind) => switch (kind) {
    BilStoreProductKind.premiumSubscription =>
      widget.currentPlan == CommercePlan.premium,
    BilStoreProductKind.premiumAiCoachSubscription =>
      widget.currentPlan == CommercePlan.premiumAiCoach,
    BilStoreProductKind.aiBoostConsumable => false,
  };

  static const _premiumPaidBenefitKeys = <String>[
    'premium_benefit_2',
    'premium_benefit_barcode',
    'premium_benefit_dashboard',
    'premium_benefit_recipes',
    'premium_benefit_workouts',
    'premium_benefit_strength_plans',
    'premium_benefit_3',
    'premium_benefit_meal_plan',
    'premium_benefit_programs',
    'premium_benefit_reports',
    'premium_benefit_fasting',
    'premium_benefit_sleep',
    'premium_benefit_body',
    'premium_benefit_4',
    'premium_benefit_fitness_devices',
    'premium_benefit_community',
    'premium_benefit_messages',
    'premium_benefit_5',
  ];

  static const _premiumCoreBenefitKeys = <String>[
    'premium_benefit_1',
    ..._premiumPaidBenefitKeys,
  ];

  List<String> _benefitKeys(
    BilStoreProductKind kind,
    List<BilStoreOfferMetadata> offers,
  ) => switch (kind) {
    BilStoreProductKind.premiumSubscription => [..._premiumCoreBenefitKeys],
    // The two paid tiers are sold in different storefront markets, so the AI
    // route must stand on its own: one inheritance line names the complete
    // Premium relationship, then the concrete paid and AI benefits prove it.
    BilStoreProductKind.premiumAiCoachSubscription => [
      'ai_benefit_1',
      'ai_benefit_2',
      'ai_benefit_3',
      'ai_benefit_4',
      ..._premiumPaidBenefitKeys,
      if (_hasVerifiedTrial(offers)) 'ai_benefit_trial',
    ],
    BilStoreProductKind.aiBoostConsumable => const [
      'boost_benefit_1',
      'boost_benefit_2',
      'boost_benefit_3',
      'boost_benefit_4',
      'boost_benefit_5',
    ],
  };

  /// A trial is user-visible only when the selected storefront reports both
  /// eligibility and a concrete introductory period. BIL never authors a
  /// trial promise independently of Play Billing / StoreKit metadata.
  static bool _hasVerifiedTrial(List<BilStoreOfferMetadata> offers) =>
      offers.any(_isVerifiedAiTrialOffer);
}
