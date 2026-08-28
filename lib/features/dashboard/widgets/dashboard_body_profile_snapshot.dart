import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../composition/dashboard_composition.dart';
import '../dashboard_five_locale_copy.dart';
import 'dashboard_section_heading.dart';

class DashboardBodyProfileSnapshot extends StatelessWidget {
  const DashboardBodyProfileSnapshot({
    required this.arabic,
    required this.weight,
    required this.height,
    required this.target,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.waterTarget,
    required this.dailyMetabolism,
    required this.neckCircumference,
    required this.waistCircumference,
    required this.bodyMassIndex,
    required this.bodyFatPercentage,
    required this.leanBodyMass,
    required this.onEditProfile,
    required this.onEditPlan,
    super.key,
  });

  final bool arabic;
  final String weight;
  final String height;
  final String target;
  final String calorieTarget;
  final String proteinTarget;
  final String waterTarget;
  final String dailyMetabolism;
  final String neckCircumference;
  final String waistCircumference;
  final String bodyMassIndex;
  final String bodyFatPercentage;
  final String leanBodyMass;
  final VoidCallback onEditProfile;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => dashboardFiveLocaleText(
      en,
      ar,
      locale: _dashboardProfileLocale(context, arabic),
    );
    final scheme = Theme.of(context).colorScheme;
    final values = [
      (tr('Current weight', 'الوزن الحالي'), weight),
      (tr('Height', 'الطول'), height),
      (tr('Target weight', 'الوزن المستهدف'), target),
      (tr('Daily energy plan', 'خطة الطاقة اليومية'), calorieTarget),
      (tr('Protein target', 'هدف البروتين'), proteinTarget),
      (tr('Water target', 'هدف الماء'), waterTarget),
      (tr('Daily metabolism', 'معدل الأيض اليومي'), dailyMetabolism),
      (tr('Neck circumference', 'محيط الرقبة'), neckCircumference),
      (tr('Waist circumference', 'محيط الخصر'), waistCircumference),
      (tr('Body mass index', 'مؤشر كتلة الجسم'), bodyMassIndex),
      (tr('Body fat percentage', 'نسبة دهون الجسم'), bodyFatPercentage),
      (tr('Lean body mass', 'الكتلة الخالية من الدهون'), leanBodyMass),
    ];

    return PremiumSurface(
      key: const Key('dashboard-body-profile'),
      dashboardGlass: true,
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: scheme.primary),
              const SizedBox(width: PremiumDesignTokens.spaceSm),
              Expanded(
                child: DashboardSectionHeading(
                  title: tr('Body Identity', 'هوية الجسم'),
                  subtitle: tr(
                    'Your current local baseline and active plan.',
                    'خط أساسك المحلي الحالي وخطتك النشطة.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          LayoutBuilder(
            builder: (context, constraints) {
              final layout = DashboardComposition.bodyProfile(
                contentWidth: constraints.maxWidth,
              );
              if (layout.bodyProfileCompact) {
                return Column(
                  children: [
                    SizedBox(
                      height: 142,
                      child: SvgPicture.asset(
                        'assets/images/dashboard/bil_body_profile.svg',
                        key: const Key('bil-body-profile-svg'),
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                    SizedBox(
                      height: 220,
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 176,
                              crossAxisSpacing: PremiumDesignTokens.spaceSm,
                              mainAxisSpacing: PremiumDesignTokens.spaceSm,
                            ),
                        itemCount: values.length,
                        itemBuilder: (context, index) => _BodyProfileValue(
                          label: values[index].$1,
                          value: values[index].$2,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final columns = layout.bodyProfileColumns;
              final gap = PremiumDesignTokens.spaceSm;
              final informationWidth =
                  constraints.maxWidth * .76 - PremiumDesignTokens.spaceMd;
              final width = (informationWidth - gap * (columns - 1)) / columns;
              final information = Wrap(
                spacing: gap,
                runSpacing: gap,
                children: values
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _BodyProfileValue(
                          label: item.$1,
                          value: item.$2,
                        ),
                      ),
                    )
                    .toList(),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * .24,
                    height: 220,
                    child: SvgPicture.asset(
                      'assets/images/dashboard/bil_body_profile.svg',
                      key: const Key('bil-body-profile-svg'),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: PremiumDesignTokens.spaceMd),
                  Expanded(child: information),
                ],
              );
            },
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          Wrap(
            spacing: PremiumDesignTokens.spaceSm,
            runSpacing: PremiumDesignTokens.spaceSm,
            children: [
              FilledButton.tonalIcon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined),
                label: Text(tr('Edit profile', 'تعديل الملف')),
              ),
              OutlinedButton.icon(
                onPressed: onEditPlan,
                icon: const Icon(Icons.tune_rounded),
                label: Text(tr('Edit plan', 'تعديل الخطة')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Locale _dashboardProfileLocale(BuildContext context, bool useArabicCopy) {
  if (useArabicCopy) return const Locale('ar');
  return Localizations.localeOf(context);
}

class _BodyProfileValue extends StatelessWidget {
  const _BodyProfileValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .52)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.visible,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
