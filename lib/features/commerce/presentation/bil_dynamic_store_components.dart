part of 'bil_dynamic_store_offers.dart';

class _StoreHero extends StatelessWidget {
  const _StoreHero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
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
        const PremiumCrownEmblem(size: 62),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF71510A),
                  fontWeight: FontWeight.w800,
                  letterSpacing: .9,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF17130B),
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF493D25),
                  height: 1.5,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE3E3E8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 18,
          offset: Offset(0, 8),
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
                color: const Color(0xFFF1F3F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF66717D),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF171717),
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
        _PlanBenefitList(benefits: benefits, accent: const Color(0xFF758392)),
      ],
    ),
  );
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
    required this.versusMonthlyLabel,
    required this.trialLabel,
    required this.sevenDayTrialLabel,
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
  final String versusMonthlyLabel;
  final String trialLabel;
  final String sevenDayTrialLabel;
  final bool loading;
  final String selectedOfferIdentity;
  final ValueChanged<BilStoreOfferMetadata> onOfferSelected;

  @override
  Widget build(BuildContext context) {
    final boost = kind == BilStoreProductKind.aiBoostConsumable;
    final accent = boost ? const Color(0xFF59E2EF) : const Color(0xFFFFD66B);
    const offerAccent = Color(0xFFE6AD2F);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: boost ? null : Colors.white,
        gradient: boost
            ? const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFFF0FDFF), Color(0xFFFFFFFF)],
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
        padding: const EdgeInsets.fromLTRB(19, 19, 19, 18),
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
                    if (boost)
                      BilAiBoostCoachArtwork(
                        key: const ValueKey('store-ai-boost-coach-artwork'),
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
                                  color: const Color(0xFF171717),
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            detail,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF66666F),
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
                  color: const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
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
                          color: const Color(0xFF626973),
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
                            tierOffers: offers,
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
                            versusMonthlyLabel: versusMonthlyLabel,
                            trialLabel: offer.trialEligible == true
                                ? switch (offer.trialPeriodIso8601) {
                                    'P1W' || 'P7D' => sevenDayTrialLabel,
                                    _ => trialLabel,
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
            const SizedBox(height: 17),
            _PlanBenefitList(benefits: benefits, accent: accent),
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

class _PlanBenefitList extends StatelessWidget {
  const _PlanBenefitList({required this.benefits, required this.accent});

  final List<String> benefits;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < benefits.length; index++) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .11),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: .28)),
              ),
              child: Icon(Icons.check_rounded, size: 13, color: accent),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                benefits[index],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF3D4148),
                  height: 1.38,
                ),
              ),
            ),
          ],
        ),
        if (index != benefits.length - 1) const SizedBox(height: 9),
      ],
    ],
  );
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x1459B9C5),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0x3359B9C5)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: const Color(0xFF28727A),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _StoreOfferTile extends StatelessWidget {
  const _StoreOfferTile({
    required this.offer,
    required this.tierOffers,
    required this.accent,
    required this.selected,
    required this.termLabel,
    required this.locale,
    required this.billedMonthlyLabel,
    required this.billedAnnuallyLabel,
    required this.twelveMonthlyPaymentsLabel,
    required this.monthlyEquivalentLabel,
    required this.perMonthLabel,
    required this.saveLabel,
    required this.versusMonthlyLabel,
    required this.trialLabel,
    required this.onPressed,
    super.key,
  });

  final BilStoreOfferMetadata offer;
  final List<BilStoreOfferMetadata> tierOffers;
  final Color accent;
  final bool selected;
  final String termLabel;
  final String locale;
  final String billedMonthlyLabel;
  final String billedAnnuallyLabel;
  final String twelveMonthlyPaymentsLabel;
  final String monthlyEquivalentLabel;
  final String perMonthLabel;
  final String saveLabel;
  final String versusMonthlyLabel;
  final String? trialLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final comparison = StorePriceComparison.forAnnualOffer(offer, tierOffers);
    final boostDiscount = offer.verifiedAiBoostDiscountPercent;
    final originalBoostPrice = boostDiscount == null
        ? null
        : offer.localizedOriginalPrice ??
              _formatStoreDerivedPrice(offer.originalPriceMicros!);
    final monthly = offer.billingPeriodIso8601 == 'P1M';
    final annual = offer.billingPeriodIso8601 == 'P1Y';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF8E2) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? accent : const Color(0xFFE1E1E6),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: .12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        termLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF50545B),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? accent : Colors.transparent,
                        border: Border.all(
                          color: selected ? accent : const Color(0xFFADB0B7),
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Color(0xFF06121D),
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (originalBoostPrice != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        originalBoostPrice,
                        key: ValueKey(
                          'ai-boost-original-price-${offer.productId}',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF777B82),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          decorationThickness: 1.5,
                        ),
                      ),
                      Container(
                        key: ValueKey(
                          'ai-boost-discount-badge-${offer.productId}',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1F167985),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x40167985)),
                        ),
                        child: Text(
                          '$saveLabel $boostDiscount%',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFF126C76),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  offer.localizedPrice,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF171717),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
                if (monthly || annual) ...[
                  const SizedBox(height: 4),
                  Text(
                    annual ? billedAnnuallyLabel : billedMonthlyLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF686D75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (comparison != null) ...[
                  const SizedBox(height: 8),
                  if (comparison.hasSavings)
                    Text(
                      '$twelveMonthlyPaymentsLabel: '
                      '${_formatStoreDerivedPrice(comparison.twelveMonthlyPaymentsMicros)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF777B82),
                        decoration: TextDecoration.lineThrough,
                        decorationThickness: 1.4,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '$monthlyEquivalentLabel: '
                    '${_formatStoreDerivedPrice(comparison.monthlyEquivalentMicros)} '
                    '$perMonthLabel',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF4B515A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (comparison.hasSavings) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$saveLabel ${comparison.savingsPercent}% '
                      '$versusMonthlyLabel',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
                if (trialLabel != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    trialLabel!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatStoreDerivedPrice(int micros) {
    final amount = micros / 1000000;
    try {
      return NumberFormat.simpleCurrency(
        locale: locale,
        name: offer.currencyCode,
      ).format(amount);
    } on Object {
      return '${offer.currencyCode} ${amount.toStringAsFixed(2)}';
    }
  }
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFAFFFFFF),
      border: Border(top: BorderSide(color: Color(0xFFE4E4E8))),
      boxShadow: [
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
                                  style: Theme.of(context).textTheme.labelLarge
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
