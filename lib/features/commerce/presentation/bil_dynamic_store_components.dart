part of 'bil_dynamic_store_offers.dart';

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [Color(0xFFFFE89A), Color(0xFFFFD36A), Color(0xFFFFBE4B)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x28DCA128),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumCrownEmblem(size: 44),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF71510A),
                  fontWeight: FontWeight.w800,
                  letterSpacing: .9,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'BILDisplay',
                  fontFamilyFallback: const ['BILArabic'],
                  color: const Color(0xFF17130B),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.35,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FreeTierCard extends StatelessWidget {
  const _FreeTierCard({
    required this.label,
    required this.benefits,
    required this.currentLabel,
  });

  final String label;
  final List<String> benefits;
  final String? currentLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Container(
      key: const ValueKey('store-free-tier-card'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? scheme.outlineVariant : const Color(0xFFE3E3E8),
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x33000000) : const Color(0x0F000000),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: dark
                      ? scheme.surfaceContainerHighest
                      : const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: dark
                      ? scheme.onSurfaceVariant
                      : const Color(0xFF66717D),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'BILDisplay',
                    fontFamilyFallback: const ['BILArabic'],
                    color: dark ? scheme.onSurface : const Color(0xFF171717),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (currentLabel != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: _CurrentBadge(label: currentLabel!),
                ),
            ],
          ),
          const SizedBox(height: 15),
          _PlanBenefitList(
            benefits: benefits,
            accent: dark ? scheme.onSurfaceVariant : const Color(0xFF758392),
          ),
        ],
      ),
    );
  }
}

class _StoreTierCard extends StatelessWidget {
  const _StoreTierCard({
    required this.kind,
    required this.title,
    required this.detail,
    required this.eyebrow,
    required this.benefits,
    required this.currentLabel,
    required this.offers,
    required this.loadingLabel,
    required this.unavailableLabel,
    required this.monthlyLabel,
    required this.annualLabel,
    required this.locale,
    required this.billedMonthlyLabel,
    required this.billedAnnuallyLabel,
    required this.twelveMonthlyPaymentsLabel,
    required this.monthlyEquivalentLabel,
    required this.perMonthLabel,
    required this.saveLabel,
    required this.trialLabel,
    required this.sevenDayTrialLabel,
    required this.trialRenewsMonthlyLabel,
    required this.trialRenewsAnnuallyLabel,
    required this.viewAllFeaturesLabel,
    required this.showFewerFeaturesLabel,
    required this.loading,
    required this.selectedOfferIdentity,
    required this.onOfferSelected,
  });

  final BilStoreProductKind kind;
  final String title;
  final String detail;
  final String? eyebrow;
  final List<String> benefits;
  final String? currentLabel;
  final List<BilStoreOfferMetadata> offers;
  final String loadingLabel;
  final String unavailableLabel;
  final String monthlyLabel;
  final String annualLabel;
  final String locale;
  final String billedMonthlyLabel;
  final String billedAnnuallyLabel;
  final String twelveMonthlyPaymentsLabel;
  final String monthlyEquivalentLabel;
  final String perMonthLabel;
  final String saveLabel;
  final String trialLabel;
  final String sevenDayTrialLabel;
  final String trialRenewsMonthlyLabel;
  final String trialRenewsAnnuallyLabel;
  final String viewAllFeaturesLabel;
  final String showFewerFeaturesLabel;
  final bool loading;
  final String selectedOfferIdentity;
  final ValueChanged<BilStoreOfferMetadata> onOfferSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final boost = kind == BilStoreProductKind.aiBoostConsumable;
    final coachArtwork =
        boost || kind == BilStoreProductKind.premiumAiCoachSubscription;
    final accent = boost ? const Color(0xFF59E2EF) : const Color(0xFFFFD66B);
    const offerAccent = Color(0xFFE6AD2F);
    return Container(
      key: ValueKey('store-tier-${kind.name}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: boost
            ? null
            : (dark ? scheme.surfaceContainerLow : Colors.white),
        gradient: boost
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: dark
                    ? const [Color(0xFF10292E), Color(0xFF171B1D)]
                    : const [Color(0xFFF0FDFF), Color(0xFFFFFFFF)],
              )
            : null,
        border: Border.all(color: accent.withValues(alpha: .48), width: 1.15),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .09),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final artworkSize = (constraints.maxWidth * .17)
                    .clamp(54.0, 82.0)
                    .toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (coachArtwork)
                      BilAiBoostCoachArtwork(
                        key: ValueKey(
                          boost
                              ? 'store-ai-boost-coach-artwork'
                              : 'store-premium-ai-coach-artwork',
                        ),
                        size: artworkSize,
                        semanticLabel: title,
                      )
                    else
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: accent.withValues(alpha: .22),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: PremiumCrownEmblem(size: 32),
                        ),
                      ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null) ...[
                            Text(
                              eyebrow!,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFF167985),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .7,
                                  ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontFamily: 'BILDisplay',
                                  fontFamilyFallback: const ['BILArabic'],
                                  color: dark
                                      ? scheme.onSurface
                                      : const Color(0xFF171717),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2,
                                  height: 1.12,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: dark
                                      ? scheme.onSurfaceVariant
                                      : const Color(0xFF66666F),
                                  height: 1.3,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (currentLabel != null)
                      _CurrentBadge(label: currentLabel!),
                  ],
                );
              },
            ),
            const SizedBox(height: 15),
            if (offers.isEmpty)
              Container(
                key: ValueKey('store-placeholder-$title'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? scheme.surfaceContainerHighest
                      : const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dark
                        ? scheme.outlineVariant
                        : const Color(0xFFE5E5EA),
                  ),
                ),
                child: Row(
                  children: [
                    if (loading)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(end: 10),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Color(0xFFFFD66B),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsetsDirectional.only(end: 9),
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 18,
                          color: Color(0xFF727984),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        loading ? loadingLabel : unavailableLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: dark
                              ? scheme.onSurfaceVariant
                              : const Color(0xFF626973),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 10.0;
                  final tileWidth = offers.length > 1
                      ? (constraints.maxWidth - gap) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 10,
                    children: [
                      for (final offer in offers)
                        SizedBox(
                          width: tileWidth,
                          child: _StoreOfferTile(
                            key: ValueKey('store-offer-${offer.productId}'),
                            offer: offer,
                            annualComparison:
                                StorePriceComparison.forAnnualOffer(
                                  offer,
                                  offers,
                                ),
                            accent: offerAccent,
                            selected:
                                _offerIdentity(offer) == selectedOfferIdentity,
                            termLabel: _termLabel(offer),
                            locale: locale,
                            billedMonthlyLabel: billedMonthlyLabel,
                            billedAnnuallyLabel: billedAnnuallyLabel,
                            twelveMonthlyPaymentsLabel:
                                twelveMonthlyPaymentsLabel,
                            monthlyEquivalentLabel: monthlyEquivalentLabel,
                            perMonthLabel: perMonthLabel,
                            saveLabel: saveLabel,
                            trialLabel: _isVerifiedAiTrialOffer(offer)
                                ? switch (offer.trialPeriodIso8601) {
                                    'P1W' || 'P7D' => sevenDayTrialLabel,
                                    _ => trialLabel,
                                  }
                                : null,
                            trialRenewalLabel: _isVerifiedAiTrialOffer(offer)
                                ? switch (offer.billingPeriodIso8601) {
                                    'P1M' => trialRenewsMonthlyLabel.replaceAll(
                                      '{price}',
                                      offer.localizedPrice,
                                    ),
                                    'P1Y' =>
                                      trialRenewsAnnuallyLabel.replaceAll(
                                        '{price}',
                                        offer.localizedPrice,
                                      ),
                                    _ => null,
                                  }
                                : null,
                            onPressed: loading
                                ? null
                                : () => onOfferSelected(offer),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 15),
            _PlanBenefitList(
              key: ValueKey('store-benefits-${kind.name}'),
              benefits: benefits,
              accent: accent,
              collapsedCount: boost ? null : 5,
              viewAllLabel: viewAllFeaturesLabel,
              showFewerLabel: showFewerFeaturesLabel,
              toggleKey: ValueKey('store-benefits-toggle-${kind.name}'),
            ),
          ],
        ),
      ),
    );
  }

  String _offerIdentity(BilStoreOfferMetadata offer) =>
      '${offer.productId}|${offer.offerId ?? ''}|${offer.basePlanId ?? ''}';

  String _termLabel(BilStoreOfferMetadata offer) =>
      switch (offer.billingPeriodIso8601) {
        'P1M' => monthlyLabel,
        'P1Y' => annualLabel,
        _ => offer.localizedTitle,
      };
}

class _StickyPurchaseBar extends StatelessWidget {
  const _StickyPurchaseBar({
    required this.label,
    required this.price,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final String price;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      key: const ValueKey('store-sticky-purchase-bar'),
      decoration: BoxDecoration(
        color: dark
            ? scheme.surface.withValues(alpha: .98)
            : const Color(0xFAFFFFFF),
        border: Border(
          top: BorderSide(
            color: dark ? scheme.outlineVariant : const Color(0xFFE4E4E8),
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFE99C),
                    Color(0xFFF4C34F),
                    Color(0xFFD99B27),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44E4AE38),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('store-purchase-cta'),
                  onTap: loading ? null : onPressed,
                  borderRadius: BorderRadius.circular(19),
                  child: SizedBox(
                    height: 56,
                    child: Center(
                      child: loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF06121D),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '$label · $price',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: const Color(0xFF06121D),
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF06121D),
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
