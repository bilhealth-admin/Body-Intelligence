import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/runtime_copy.dart';
import '../domain/commerce_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/subscription_term.dart';
import '../services/verified_store_purchase_service.dart';

class GlassStoreOffer extends StatelessWidget {
  const GlassStoreOffer({
    super.key,
    required this.annual,
    required this.selectedPlan,
    required this.language,
    required this.store,
    required this.onTermChanged,
    required this.onPlanChanged,
  });

  final bool annual;
  final CommercePlan selectedPlan;
  final String language;
  final VerifiedStorePurchaseService? store;
  final ValueChanged<bool> onTermChanged;
  final ValueChanged<CommercePlan> onPlanChanged;

  String t(String key) {
    final english = _copy['en']?[key] ?? key;
    return _copy[language]?[key] ??
        RuntimeCopy.resolve(english, language) ??
        english;
  }

  @override
  Widget build(BuildContext context) {
    final term = annual ? SubscriptionTerm.oneYear : SubscriptionTerm.oneMonth;
    final product = selectedPlan == CommercePlan.free
        ? null
        : store?.productFor(selectedPlan, term: term);
    final premiumPlusReady =
        StoreCatalogConfiguration.premiumPlusMealPlannerReady;
    final purchasable =
        product != null &&
        store?.state == VerifiedStoreState.ready &&
        (selectedPlan != CommercePlan.plus || premiumPlusReady);
    final hasVerifiedPro = store?.entitlement?.grantsPaidAccess == true;
    final features = switch (selectedPlan) {
      CommercePlan.free => const [
        'freeTracking',
        'freeNutrition',
        'freeAnalytics',
        'freeExport',
      ],
      CommercePlan.pro => const ['coach', 'sync', 'freeIncluded'],
      CommercePlan.plus =>
        premiumPlusReady
            ? const ['mealPlanner', 'premiumIncluded']
            : const ['premiumPlusRequired'],
      _ => const <String>[],
    };
    final annualSaving = _annualSavingPercent(store, selectedPlan);
    return Scaffold(
      backgroundColor: const Color(0xFF01070C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/commerce/bil_paywall_splash_identity_v3.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x18FFFFFF),
                  Color(0x08FFFFFF),
                  Color(0x30F7FBFE),
                ],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: store ?? const _IdleListenable(),
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LongWordmark(),
                        const SizedBox(height: 10),
                        Text(
                          t('headline'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Color(0xFF101923),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t('subtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF536579),
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          key: const Key('paywall-pro-only-plan'),
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A4511), Color(0xFFB47A22)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFFD978),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55D59B2A),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFFFFE6A3),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF5B3A0D),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                t(
                                  selectedPlan == CommercePlan.free
                                      ? 'freePlan'
                                      : selectedPlan == CommercePlan.pro
                                      ? 'premiumPlan'
                                      : 'premiumPlusPlan',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ChoiceBar<CommercePlan>(
                          values: const [
                            CommercePlan.free,
                            CommercePlan.pro,
                            CommercePlan.plus,
                          ],
                          selected: selectedPlan,
                          label: (value) => t(switch (value) {
                            CommercePlan.free => 'free',
                            CommercePlan.pro => 'premium',
                            _ => 'premiumPlus',
                          }),
                          onChanged: onPlanChanged,
                        ),
                        const SizedBox(height: 10),
                        if (selectedPlan != CommercePlan.free)
                          _ChoiceBar<bool>(
                            values: const [false, true],
                            selected: annual,
                            label: (value) => t(value ? 'annual' : 'monthly'),
                            onChanged: onTermChanged,
                            badge: annual && annualSaving != null
                                ? t(
                                    'saveDynamic',
                                  ).replaceAll('{percent}', '$annualSaving')
                                : null,
                          ),
                        if (selectedPlan != CommercePlan.free &&
                            annual &&
                            annualSaving != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            t(
                              'annualSavingDetail',
                            ).replaceAll('{percent}', '$annualSaving'),
                            key: const Key('paywall-annual-saving-detail'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF704A0B),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          key: const Key('paywall-live-price'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          decoration: _glassDecoration(radius: 18),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5B3A0D),
                                      Color(0xFFB77A1F),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFFFDF8D),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.sell_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  selectedPlan == CommercePlan.free
                                      ? t('freePrice')
                                      : product?.price ?? t('storePrice'),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: const Color(0xFF101923),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        for (
                          var index = 0;
                          index < features.length;
                          index++
                        ) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 27,
                                  height: 27,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF4A310E),
                                    border: Border.all(
                                      color: const Color(0xFFD7A83E),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFFFFE6A3),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Text(
                                    t(features[index]),
                                    style: const TextStyle(
                                      color: Color(0xFF101923),
                                      fontSize: 15,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index != features.length - 1)
                            const Divider(
                              height: 1,
                              indent: 40,
                              color: Color(0x33708392),
                            ),
                        ],
                        if (selectedPlan == CommercePlan.plus) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const Key('paywall-premium-plus-preview'),
                            onPressed: () => context.push('/meal-planner'),
                            icon: const Icon(Icons.preview_outlined),
                            label: Text(t('previewMealPlanner')),
                          ),
                        ],
                        const SizedBox(height: 10),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE39A), Color(0xFFD49A2A)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFFFEDB7)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x88C68A1F),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: FilledButton(
                            key: const Key('paywall-purchase'),
                            onPressed: () {
                              if (selectedPlan == CommercePlan.free) {
                                context.canPop()
                                    ? context.pop()
                                    : context.go('/today');
                                return;
                              }
                              if (selectedPlan == CommercePlan.plus &&
                                  !premiumPlusReady) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(t('premiumPlusRequired')),
                                    ),
                                  );
                                return;
                              }
                              if (hasVerifiedPro) {
                                store?.manageSubscription(
                                  productId: product?.id,
                                );
                                return;
                              }
                              if (purchasable) {
                                store!.purchasePlan(selectedPlan, term: term);
                                return;
                              }
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text(t('storeMessage'))),
                                );
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(62),
                              backgroundColor: Colors.transparent,
                              foregroundColor: const Color(0xFF2B1A03),
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              t(
                                selectedPlan == CommercePlan.free
                                    ? 'continueFree'
                                    : selectedPlan == CommercePlan.plus &&
                                          !premiumPlusReady
                                    ? 'notAvailable'
                                    : hasVerifiedPro
                                    ? 'manage'
                                    : annual
                                    ? 'startAnnual'
                                    : 'startMonthly',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: store == null || store!.busy
                              ? null
                              : store!.restore,
                          child: Text(
                            t('restore'),
                            style: const TextStyle(
                              color: Color(0xFF8A5A00),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('paywall-manage'),
                          onPressed: store == null || store!.busy
                              ? null
                              : () => store!.manageSubscription(
                                  productId: product?.id,
                                ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            t('manage'),
                            style: const TextStyle(
                              color: Color(0xFF704A0B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          t('renewal'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF46586B),
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed:
                                  StoreCatalogConfiguration.legalLinksConfigured
                                  ? () => launchUrl(
                                      Uri.parse(
                                        StoreCatalogConfiguration.termsUrl,
                                      ),
                                    )
                                  : () => context.push('/legal/terms'),
                              child: Text(
                                t('terms'),
                                style: const TextStyle(
                                  color: Color(0xFF34475A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Text(
                              '│',
                              style: TextStyle(color: Color(0xFF8A96A4)),
                            ),
                            TextButton(
                              onPressed:
                                  StoreCatalogConfiguration.legalLinksConfigured
                                  ? () => launchUrl(
                                      Uri.parse(
                                        StoreCatalogConfiguration.privacyUrl,
                                      ),
                                    )
                                  : () => context.push('/legal/privacy'),
                              child: Text(
                                t('privacy'),
                                style: const TextStyle(
                                  color: Color(0xFF34475A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, top: 10),
                child: Material(
                  color: const Color(0xEFFFFFFF),
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0xFF8C6B2A)),
                  ),
                  elevation: 3,
                  child: IconButton(
                    key: const Key('paywall-close'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/settings'),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF101923),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _glassDecoration({required double radius}) => BoxDecoration(
  color: const Color(0xD9FFFFFF),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xFF8C6B2A)),
  boxShadow: const [
    BoxShadow(color: Color(0x1F617487), blurRadius: 22, offset: Offset(0, 10)),
  ],
);

class _LongWordmark extends StatelessWidget {
  const _LongWordmark();
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'BODY INTELLIGENCE LOG'),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Padding(
              padding: EdgeInsets.only(left: 3),
              child: Text(
                '™',
                style: TextStyle(
                  color: Color(0xFF101923),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      key: const Key('paywall-long-wordmark'),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Color(0xFF101923),
        fontWeight: FontWeight.w500,
        letterSpacing: 1.45,
      ),
    ),
  );
}

class _ChoiceBar<T> extends StatelessWidget {
  const _ChoiceBar({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.showCheck = false,
    this.badge,
  });
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;
  final bool showCheck;
  final String? badge;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: _glassDecoration(radius: 18),
    child: Row(
      children: [
        for (final value in values)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 58,
                decoration: BoxDecoration(
                  gradient: value == selected
                      ? const LinearGradient(
                          colors: [Color(0xCC5A3A0E), Color(0xCC9A671B)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(15),
                  border: value == selected
                      ? Border.all(color: const Color(0xFFFFD978), width: 1.5)
                      : null,
                  boxShadow: value == selected
                      ? const [
                          BoxShadow(color: Color(0x88D59B2A), blurRadius: 15),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label(value),
                      style: TextStyle(
                        color: value == selected
                            ? Colors.white
                            : const Color(0xFF334456),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (value == selected && showCheck) ...[
                      const SizedBox(width: 9),
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFFFE6A3),
                        child: Icon(
                          Icons.check_rounded,
                          color: Color(0xFF5B3A0D),
                          size: 20,
                        ),
                      ),
                    ],
                    if (value == selected && badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE99F), Color(0xFFE4A834)],
                          ),
                          border: Border.all(color: const Color(0xFFFFF0BD)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Color(0xFF3C2503),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

final class _IdleListenable implements Listenable {
  const _IdleListenable();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

int? _annualSavingPercent(
  VerifiedStorePurchaseService? store,
  CommercePlan plan,
) {
  if (store == null || plan == CommercePlan.free) return null;
  final monthly = store.productFor(plan, term: SubscriptionTerm.oneMonth);
  final annual = store.productFor(plan, term: SubscriptionTerm.oneYear);
  if (monthly == null || annual == null || monthly.rawPrice <= 0) return null;
  final percent = ((1 - (annual.rawPrice / (monthly.rawPrice * 12))) * 100)
      .round();
  return percent > 0 && percent < 100 ? percent : null;
}

const _copy = <String, Map<String, String>>{
  'en': {
    'free': 'Free',
    'premium': 'Premium',
    'premiumPlus': 'Premium+',
    'freePlan': 'BIL Free',
    'premiumPlan': 'BIL Premium',
    'premiumPlusPlan': 'BIL Premium+',
    'freePrice': 'Free',
    'continueFree': 'Continue with Free',
    'notAvailable': 'Coming later',
    'saveDynamic': 'SAVE {percent}%',
    'premiumPlusRequired':
        'Premium+ is unavailable until Meal Planner is fully implemented.',
    'mealPlanner': 'Personalized Meal Planner',
    'previewMealPlanner': 'Preview Meal Planner',
    'premiumIncluded': 'Everything included in BIL Premium',
    'freeTracking': 'Food, water and weight tracking',
    'freeNutrition': 'Core nutrition insights',
    'freeAnalytics': 'Local progress analytics',
    'freeExport': 'Export your own data',
    'proFull': 'BIL Pro',
    'headline': 'Know your body. Progress intelligently.',
    'subtitle':
        'Personal health intelligence that understands your data and turns it into clear next steps.',
    'monthly': 'Monthly',
    'annual': 'Annual',
    'annualSavingDetail':
        'The annual store price saves {percent}% compared with 12 monthly payments.',
    'storePrice': 'Price from the store',
    'startAnnual': 'Choose annual Pro',
    'startMonthly': 'Choose monthly Pro',
    'restore': 'Restore purchases',
    'manage': 'Manage subscription',
    'coach': 'Advanced personalized AI Coach',
    'sync': 'Secure sync across your devices',
    'freeIncluded': 'Everything included in BIL Free',
    'renewal':
        'Payment is charged by the store. Subscription renews automatically unless cancelled in the store before renewal. The final price and terms are shown before purchase.',
    'terms': 'Terms',
    'privacy': 'Privacy',
    'storeMessage': 'The store is not ready. No charge was made.',
  },
  'ar': {
    'free': 'مجاني',
    'premium': 'Premium',
    'premiumPlus': 'Premium+',
    'freePlan': 'BIL المجاني',
    'premiumPlan': 'BIL Premium',
    'premiumPlusPlan': 'BIL Premium+',
    'freePrice': 'مجاني',
    'continueFree': 'المتابعة بالخطة المجانية',
    'notAvailable': 'يتوفر لاحقًا',
    'saveDynamic': 'وفّر {percent}%',
    'premiumPlusRequired': 'Premium+ غير متاحة حتى يكتمل مخطط الوجبات بالكامل.',
    'mealPlanner': 'مخطط وجبات شخصي',
    'previewMealPlanner': 'معاينة مخطط الوجبات',
    'premiumIncluded': 'كل مزايا BIL Premium',
    'freeTracking': 'تتبع الطعام والماء والوزن',
    'freeNutrition': 'رؤى التغذية الأساسية',
    'freeAnalytics': 'تحليلات تقدم محلية',
    'freeExport': 'تصدير بياناتك',
    'proFull': 'BIL Pro — الخطة الاحترافية',
    'headline': 'اعرف جسمك. تقدّم بذكاء.',
    'subtitle': 'ذكاء صحي شخصي يفهم بياناتك ويحوّلها إلى خطوات تالية واضحة.',
    'monthly': 'شهري',
    'annual': 'سنوي',
    'annualSavingDetail':
        'يوفر سعر المتجر السنوي {percent}% مقارنةً بـ 12 دفعة شهرية.',
    'storePrice': 'السعر من المتجر',
    'startAnnual': 'اختر Pro السنوي',
    'startMonthly': 'اختر Pro الشهري',
    'restore': 'استعادة المشتريات',
    'manage': 'إدارة الاشتراك',
    'coach': 'مدرب ذكاء شخصي متقدم',
    'sync': 'مزامنة آمنة عبر أجهزتك',
    'freeIncluded': 'كل ما تتضمنه خطة BIL المجانية',
    'renewal':
        'يحصّل المتجر قيمة الاشتراك، ويتجدد تلقائيًا ما لم يُلغَ من المتجر قبل موعد التجديد. يظهر السعر النهائي والشروط قبل الشراء.',
    'terms': 'الشروط',
    'privacy': 'الخصوصية',
    'storeMessage': 'المتجر غير جاهز. لم يتم تحصيل أي مبلغ.',
  },
  'fr': {
    'free': 'Gratuit',
    'premium': 'Premium',
    'premiumPlus': 'Premium+',
    'freePlan': 'BIL Gratuit',
    'premiumPlan': 'BIL Premium',
    'premiumPlusPlan': 'BIL Premium+',
    'freePrice': 'Gratuit',
    'continueFree': 'Continuer gratuitement',
    'notAvailable': 'Bientôt disponible',
    'saveDynamic': 'ÉCONOMISEZ {percent} %',
    'premiumPlusRequired':
        'Premium+ reste indisponible jusqu’à l’intégration complète du planificateur de repas.',
    'mealPlanner': 'Planificateur de repas personnalisé',
    'previewMealPlanner': 'Aperçu du planificateur de repas',
    'premiumIncluded': 'Tout BIL Premium',
    'freeTracking': 'Suivi des aliments, de l’eau et du poids',
    'freeNutrition': 'Analyses nutritionnelles essentielles',
    'freeAnalytics': 'Analyse locale des progrès',
    'freeExport': 'Export de vos données',
    'proFull': 'BIL Pro — Offre professionnelle',
    'headline': 'Comprenez votre corps. Progressez intelligemment.',
    'subtitle':
        'Une intelligence santé personnelle qui transforme vos données en prochaines étapes claires.',
    'monthly': 'Mensuel',
    'annual': 'Annuel',
    'annualSavingDetail':
        'Le prix annuel de la boutique économise {percent} % par rapport à 12 paiements mensuels.',
    'storePrice': 'Prix de la boutique',
    'startAnnual': 'Choisir Pro annuel',
    'startMonthly': 'Choisir Pro mensuel',
    'restore': 'Restaurer les achats',
    'manage': 'Gérer l’abonnement',
    'coach': 'Coach IA personnel avancé',
    'sync': 'Synchronisation sécurisée entre vos appareils',
    'freeIncluded': 'Tout ce qui est inclus dans BIL Gratuit',
    'renewal':
        'Le paiement est prélevé par la boutique. Renouvellement automatique sauf annulation dans la boutique avant l’échéance. Le prix final et les conditions sont affichés avant l’achat.',
    'terms': 'Conditions',
    'privacy': 'Confidentialité',
    'storeMessage': 'La boutique n’est pas prête. Aucun débit.',
  },
  'es': {
    'free': 'Gratis',
    'premium': 'Premium',
    'premiumPlus': 'Premium+',
    'freePlan': 'BIL Gratis',
    'premiumPlan': 'BIL Premium',
    'premiumPlusPlan': 'BIL Premium+',
    'freePrice': 'Gratis',
    'continueFree': 'Continuar gratis',
    'notAvailable': 'Próximamente',
    'saveDynamic': 'AHORRA {percent} %',
    'premiumPlusRequired':
        'Premium+ no estará disponible hasta completar el planificador de comidas.',
    'mealPlanner': 'Planificador de comidas personalizado',
    'previewMealPlanner': 'Vista previa del planificador de comidas',
    'premiumIncluded': 'Todo BIL Premium',
    'freeTracking': 'Registro de alimentos, agua y peso',
    'freeNutrition': 'Información nutricional esencial',
    'freeAnalytics': 'Análisis local del progreso',
    'freeExport': 'Exportación de tus datos',
    'proFull': 'BIL Pro — Plan profesional',
    'headline': 'Conoce tu cuerpo. Progresa con inteligencia.',
    'subtitle':
        'Inteligencia de salud personal que convierte tus datos en próximos pasos claros.',
    'monthly': 'Mensual',
    'annual': 'Anual',
    'annualSavingDetail':
        'El precio anual de la tienda ahorra un {percent} % frente a 12 pagos mensuales.',
    'storePrice': 'Precio de la tienda',
    'startAnnual': 'Elegir Pro anual',
    'startMonthly': 'Elegir Pro mensual',
    'restore': 'Restaurar compras',
    'manage': 'Gestionar suscripción',
    'coach': 'Entrenador de IA personal avanzado',
    'sync': 'Sincronización segura entre dispositivos',
    'freeIncluded': 'Todo lo incluido en BIL Gratis',
    'renewal':
        'La tienda cobra el pago. La suscripción se renueva automáticamente salvo cancelación en la tienda antes de la renovación. El precio final y las condiciones aparecen antes de comprar.',
    'terms': 'Términos',
    'privacy': 'Privacidad',
    'storeMessage': 'La tienda no está lista. No se realizó ningún cargo.',
  },
  'tr': {
    'free': 'Ücretsiz',
    'premium': 'Premium',
    'premiumPlus': 'Premium+',
    'freePlan': 'BIL Ücretsiz',
    'premiumPlan': 'BIL Premium',
    'premiumPlusPlan': 'BIL Premium+',
    'freePrice': 'Ücretsiz',
    'continueFree': 'Ücretsiz devam et',
    'notAvailable': 'Daha sonra',
    'saveDynamic': '%{percent} TASARRUF',
    'premiumPlusRequired':
        'Premium+, Yemek Planlayıcı tamamen uygulanana kadar kullanılamaz.',
    'mealPlanner': 'Kişisel Yemek Planlayıcı',
    'previewMealPlanner': 'Yemek Planlayıcı önizlemesi',
    'premiumIncluded': 'Tüm BIL Premium özellikleri',
    'freeTracking': 'Yemek, su ve kilo takibi',
    'freeNutrition': 'Temel beslenme içgörüleri',
    'freeAnalytics': 'Yerel ilerleme analizi',
    'freeExport': 'Verilerini dışa aktar',
    'proFull': 'BIL Pro — Profesyonel plan',
    'headline': 'Bedenini tanı. Akıllıca ilerle.',
    'subtitle':
        'Verilerini anlayıp net sonraki adımlara dönüştüren kişisel sağlık zekâsı.',
    'monthly': 'Aylık',
    'annual': 'Yıllık',
    'annualSavingDetail':
        'Yıllık mağaza fiyatı, 12 aylık ödemeye kıyasla %{percent} tasarruf sağlar.',
    'storePrice': 'Mağaza fiyatı',
    'startAnnual': 'Yıllık Pro’yu seç',
    'startMonthly': 'Aylık Pro’yu seç',
    'restore': 'Satın alımları geri yükle',
    'manage': 'Aboneliği yönet',
    'coach': 'Gelişmiş kişisel yapay zekâ koçu',
    'sync': 'Cihazlarında güvenli eşitleme',
    'freeIncluded': 'BIL Ücretsiz’deki her şey',
    'renewal':
        'Ödeme mağaza tarafından alınır. Abonelik, yenilemeden önce mağazada iptal edilmediği sürece otomatik yenilenir. Son fiyat ve koşullar satın almadan önce gösterilir.',
    'terms': 'Koşullar',
    'privacy': 'Gizlilik',
    'storeMessage': 'Mağaza hazır değil. Ücret alınmadı.',
  },
};
