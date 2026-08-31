part of 'bil_dynamic_store_offers.dart';

class _PlanBenefitList extends StatefulWidget {
  const _PlanBenefitList({
    required this.benefits,
    required this.accent,
    this.collapsedCount,
    this.viewAllLabel,
    this.showFewerLabel,
    this.toggleKey,
    super.key,
  });

  final List<String> benefits;
  final Color accent;
  final int? collapsedCount;
  final String? viewAllLabel;
  final String? showFewerLabel;
  final Key? toggleKey;

  @override
  State<_PlanBenefitList> createState() => _PlanBenefitListState();
}

class _PlanBenefitListState extends State<_PlanBenefitList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final collapsedCount = widget.collapsedCount;
    final canCollapse =
        collapsedCount != null &&
        collapsedCount > 0 &&
        widget.benefits.length > collapsedCount;
    final visibleBenefits = canCollapse && !_expanded
        ? widget.benefits.take(collapsedCount).toList(growable: false)
        : widget.benefits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < visibleBenefits.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: .11),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.accent.withValues(alpha: .28),
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: widget.accent,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  visibleBenefits[index],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark
                        ? scheme.onSurfaceVariant
                        : const Color(0xFF3D4148),
                    height: 1.38,
                  ),
                ),
              ),
            ],
          ),
          if (index != visibleBenefits.length - 1) const SizedBox(height: 9),
        ],
        if (canCollapse) ...[
          const SizedBox(height: 5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: widget.toggleKey,
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: dark
                    ? const Color(0xFFFFD66B)
                    : const Color(0xFF76530A),
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              icon: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 19,
              ),
              label: Text(
                _expanded
                    ? widget.showFewerLabel!
                    : '${widget.viewAllLabel!} (${widget.benefits.length})',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
          color: dark ? const Color(0xFF91E8F0) : const Color(0xFF28727A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StoreOfferTile extends StatelessWidget {
  const _StoreOfferTile({
    required this.offer,
    required this.annualComparison,
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
    required this.trialLabel,
    required this.trialRenewalLabel,
    required this.onPressed,
    super.key,
  });

  final BilStoreOfferMetadata offer;
  final StorePriceComparison? annualComparison;
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
  final String? trialLabel;
  final String? trialRenewalLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final boostDiscount = offer.verifiedAiBoostDiscountPercent;
    final originalBoostPrice = boostDiscount == null
        ? null
        : offer.localizedOriginalPrice ??
              _formatStoreDerivedPrice(offer.originalPriceMicros!);
    final monthly = offer.billingPeriodIso8601 == 'P1M';
    final annual = offer.billingPeriodIso8601 == 'P1Y';
    final hasStoreDerivedAnnualComparison =
        annual &&
        annualComparison != null &&
        (offer.kind == BilStoreProductKind.premiumSubscription ||
            offer.kind == BilStoreProductKind.premiumAiCoachSubscription);
    final storeDerivedAnnualDiscount =
        hasStoreDerivedAnnualComparison && annualComparison!.hasSavings;
    final annualReferencePrice = hasStoreDerivedAnnualComparison
        ? _formatStoreDerivedPrice(
            annualComparison!.twelveMonthlyPaymentsMicros,
          )
        : null;
    final monthlyEquivalentPrice = hasStoreDerivedAnnualComparison
        ? _formatStoreDerivedPrice(annualComparison!.monthlyEquivalentMicros)
        : null;
    return AnimatedContainer(
      key: ValueKey('store-offer-surface-${offer.productId}'),
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? null
            : (dark ? scheme.surfaceContainerHighest : Colors.white),
        gradient: selected
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: dark
                    ? const [Color(0xFF342A12), Color(0xFF242018)]
                    : const [Color(0xFFFFFCF3), Color(0xFFFFF1C6)],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? accent
              : (dark ? scheme.outlineVariant : const Color(0xFFE1E1E6)),
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
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
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
                              color: dark
                                  ? scheme.onSurfaceVariant
                                  : const Color(0xFF50545B),
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
                          color: selected
                              ? accent
                              : (dark
                                    ? scheme.outline
                                    : const Color(0xFFADB0B7)),
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
                const SizedBox(height: 7),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                color: dark
                                    ? const Color(0xFF8DE7EF)
                                    : const Color(0xFF126C76),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ],
                if (annualReferencePrice != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$twelveMonthlyPaymentsLabel:',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        annualReferencePrice,
                        key: ValueKey(
                          'annual-reference-price-${offer.productId}',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          decoration: storeDerivedAnnualDiscount
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationThickness: 1.5,
                        ),
                      ),
                      if (storeDerivedAnnualDiscount)
                        Container(
                          key: ValueKey('annual-savings-${offer.productId}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE49A), Color(0xFFF2BF43)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x66B77B00)),
                          ),
                          child: Text(
                            '$saveLabel ${annualComparison!.savingsPercent}%',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF5B3B00),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .1,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    offer.localizedPrice,
                    key: ValueKey('store-offer-price-${offer.productId}'),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: dark ? scheme.onSurface : const Color(0xFF171717),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                if (monthly || annual) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        annual ? billedAnnuallyLabel : billedMonthlyLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: dark
                              ? scheme.onSurfaceVariant
                              : const Color(0xFF686D75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (monthlyEquivalentPrice != null)
                        Text(
                          '$monthlyEquivalentLabel: '
                          '$monthlyEquivalentPrice $perMonthLabel',
                          key: ValueKey(
                            'annual-monthly-equivalent-${offer.productId}',
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: dark
                                    ? scheme.onSurfaceVariant
                                    : const Color(0xFF686D75),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
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
                if (trialRenewalLabel != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    trialRenewalLabel!,
                    key: ValueKey('store-trial-renewal-${offer.productId}'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: dark
                          ? scheme.onSurfaceVariant
                          : const Color(0xFF5B6068),
                      fontWeight: FontWeight.w600,
                      height: 1.25,
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
