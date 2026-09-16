import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/presentation/premium_label_badge.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/dashboard_preferences_provider.dart';
part 'dashboard_preferences_actions.dart';
part 'dashboard_preferences_catalog.dart';

@visibleForTesting
String dashboardPremiumFeatureDestination(bool paid, String featureRoute) =>
    paid ? featureRoute : '/plans';

class DashboardPreferencesPage extends ConsumerStatefulWidget {
  const DashboardPreferencesPage({super.key});

  @override
  ConsumerState<DashboardPreferencesPage> createState() =>
      _DashboardPreferencesPageState();
}

class _DashboardPreferencesPageState
    extends ConsumerState<DashboardPreferencesPage> {
  bool _saving = false;
  String? _savingSection;
  // A single switch save must not dim every control or flash a page-wide
  // progress bar. Batch changes still use the existing blocking presentation.
  bool get _savingLayout => _saving && _savingSection == null;
  final _presetScrollController = ScrollController();

  @override
  void dispose() {
    _presetScrollController.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback update) => setState(update);

  void _finishEditing() {
    if (_saving) return;
    context.canPop() ? context.pop() : context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final verifiedSubscription = ref.watch(verifiedSubscriptionStateProvider);
    final entitlementResolved = verifiedSubscription.hasValue;
    final paid =
        verifiedSubscription.value?.grants(
          CommerceEntitlement.advancedIntelligence,
        ) ??
        false;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _savingLayout ? null : _finishEditing,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            _sectionCopy(context, 'Customize Today', 'تخصيص شاشة اليوم'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            SizedBox(
              height: 12,
              child: _savingLayout
                  ? const LinearProgressIndicator()
                  : const SizedBox.shrink(),
            ),
            Text(
              _sectionCopy(
                context,
                'Choose what appears on Today. Your data stays saved and every card can be restored at any time.',
                'اختر ما يظهر في شاشة اليوم. تبقى بياناتك محفوظة ويمكن إعادة أي بطاقة في أي وقت.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Text(
              _copy(
                context,
                en: 'Choose the information that matters most to you',
                ar: 'اختر المعلومات الأكثر أهمية لك',
                fr: 'Choisissez les informations les plus importantes pour vous',
                es: 'Elige la información más importante para ti',
                tr: 'Sizin için en önemli bilgileri seçin',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final snapshot = ref.watch(dashboardSelectedPresetProvider);
                if (snapshot.hasError) {
                  return ListTile(
                    leading: const Icon(Icons.error_outline_rounded),
                    title: Text(
                      _sectionCopy(
                        context,
                        'Saved view could not be loaded.',
                        'تعذر تحميل العرض المحفوظ.',
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          ref.invalidate(dashboardSelectedPresetProvider),
                      child: Text(
                        _sectionCopy(context, 'Retry', 'إعادة المحاولة'),
                      ),
                    ),
                  );
                }
                if (snapshot.isLoading && !snapshot.hasValue) {
                  return Semantics(
                    liveRegion: true,
                    label: _sectionCopy(
                      context,
                      'Loading saved view',
                      'جارٍ تحميل العرض المحفوظ',
                    ),
                    child: const LinearProgressIndicator(),
                  );
                }
                final selected = snapshot.value;
                return SizedBox(
                  height: 190 * MediaQuery.textScalerOf(context).scale(1),
                  child: ListView(
                    key: const Key('dashboard-preset-carousel'),
                    controller: _presetScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    children: [
                      for (final preset in _dashboardPresets)
                        SizedBox(
                          width: 310,
                          child: Card(
                            child: ListTile(
                              key: Key('dashboard-preset-${preset.id}'),
                              horizontalTitleGap: 12,
                              leading: BilSemanticIconBadge(
                                kind: _dashboardPresetIconKind(preset.id),
                                size: 32,
                                iconSize: 18,
                              ),
                              title: Text(
                                _copy(
                                  context,
                                  en: preset.titleEn,
                                  ar: preset.titleAr,
                                  fr: preset.titleFr,
                                  es: preset.titleEs,
                                  tr: preset.titleTr,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                _copy(
                                  context,
                                  en: preset.bodyEn,
                                  ar: preset.bodyAr,
                                  fr: preset.bodyFr,
                                  es: preset.bodyEs,
                                  tr: preset.bodyTr,
                                ),
                              ),
                              trailing:
                                  preset.premium &&
                                      verifiedSubscription.hasError
                                  ? IconButton(
                                      tooltip: _sectionCopy(
                                        context,
                                        'Retry subscription check',
                                        'إعادة فحص الاشتراك',
                                      ),
                                      onPressed: () => ref.invalidate(
                                        verifiedSubscriptionStateProvider,
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                    )
                                  : preset.premium && !entitlementResolved
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : preset.premium && !paid
                                  ? const Icon(
                                      Icons.workspace_premium_rounded,
                                      color: Color(0xFFF2B632),
                                    )
                                  : selected == preset.id
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                              onTap:
                                  _savingLayout ||
                                      (preset.premium && !entitlementResolved)
                                  ? null
                                  : preset.premium && !paid
                                  ? () {
                                      if (!_saving) context.push('/plans');
                                    }
                                  : () => _applyPreset(
                                      context,
                                      ref,
                                      preset.id,
                                      preset.sections,
                                    ),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: 310,
                        child: Card(
                          child: ListTile(
                            key: const Key('dashboard-preset-custom'),
                            horizontalTitleGap: 12,
                            leading: const BilSemanticIconBadge(
                              kind: BilSemanticIconKind.preferences,
                              size: 32,
                              iconSize: 18,
                            ),
                            title: Text(
                              _copy(
                                context,
                                en: 'Custom',
                                ar: 'مخصص',
                                fr: 'Personnalisé',
                                es: 'Personalizado',
                                tr: 'Özel',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _copy(
                                context,
                                en: 'Choose each card below.',
                                ar: 'اختر كل بطاقة أدناه.',
                                fr: 'Choisissez chaque carte ci-dessous.',
                                es: 'Elige cada tarjeta a continuación.',
                                tr: 'Aşağıdan her kartı seçin.',
                              ),
                            ),
                            trailing: selected == 'custom'
                                ? Icon(
                                    Icons.check_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : null,
                            onTap: _savingLayout
                                ? null
                                : () => _guardedSave(
                                    () => ref
                                        .read(preferencesRepositoryProvider)
                                        .set('dashboard.preset', 'custom'),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              _copy(
                context,
                en: 'Custom cards',
                ar: 'البطاقات المخصصة',
                fr: 'Cartes personnalisées',
                es: 'Tarjetas personalizadas',
                tr: 'Özel kartlar',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Keep native switch targets and readable labels. Two narrow
                // columns cannot fit both plus a separated decorative badge.
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns = constraints.maxWidth >= 488 * textScale ? 2 : 1;
                final cardWidth =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _dashboardPreferenceItems)
                      SizedBox(
                        width: cardWidth,
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: Consumer(
                            builder: (context, ref, _) {
                              final state = ref.watch(
                                dashboardSectionVisibleProvider(item.$1),
                              );
                              if (state.hasError) {
                                return ListTile(
                                  key: Key(
                                    'dashboard-section-${item.$1}-error',
                                  ),
                                  contentPadding: const EdgeInsets.all(10),
                                  title: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _sectionCopy(
                                            context,
                                            item.$3,
                                            item.$4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: TextButton(
                                    onPressed: () => ref.invalidate(
                                      dashboardSectionVisibleProvider(item.$1),
                                    ),
                                    child: Text(
                                      _sectionCopy(
                                        context,
                                        'Retry',
                                        'إعادة المحاولة',
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (state.isLoading) {
                                return Semantics(
                                  liveRegion: true,
                                  label: _sectionCopy(
                                    context,
                                    'Loading saved setting',
                                    'جارٍ تحميل الإعداد المحفوظ',
                                  ),
                                  child: const Center(
                                    child: SizedBox.square(
                                      dimension: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final visible = state.value!;
                              return SwitchListTile.adaptive(
                                key: Key('dashboard-section-${item.$1}'),
                                contentPadding:
                                    const EdgeInsetsDirectional.fromSTEB(
                                      12,
                                      6,
                                      12,
                                      6,
                                    ),
                                horizontalTitleGap: 12,
                                minLeadingWidth: 0,
                                minTileHeight: 64,
                                secondary: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    BilSemanticIconBadge(
                                      kind: _dashboardSectionIconKind(item.$1),
                                      size: 30,
                                      iconSize: 18,
                                    ),
                                    if (_savingSection == item.$1)
                                      SizedBox.square(
                                        key: Key(
                                          'dashboard-section-${item.$1}-saving',
                                        ),
                                        dimension: 30,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  _sectionCopy(context, item.$3, item.$4),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                value: visible,
                                onChanged: _savingLayout || state.isLoading
                                    ? null
                                    : (value) => _setSectionVisibility(
                                        context,
                                        ref,
                                        item.$1,
                                        value,
                                      ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('dashboard-edit-nutrition-goals'),
                    leading: const BilSemanticIconBadge(
                      kind: BilSemanticIconKind.goals,
                      size: 32,
                      iconSize: 18,
                    ),
                    title: Text(
                      _copy(
                        context,
                        en: 'Nutrition goals',
                        ar: 'أهداف التغذية',
                        fr: 'Objectifs nutritionnels',
                        es: 'Objetivos nutricionales',
                        tr: 'Beslenme hedefleri',
                      ),
                    ),
                    subtitle: Text(
                      _copy(
                        context,
                        en: 'Edit goal',
                        ar: 'تعديل الهدف',
                        fr: 'Modifier l’objectif',
                        es: 'Editar objetivo',
                        tr: 'Hedefi düzenle',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _savingLayout
                        ? null
                        : () {
                            if (!_saving) {
                              context.push('/settings/nutrition-goals');
                            }
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Semantics(
                label: paid
                    ? _sectionCopy(
                        context,
                        'Add nutrient goal cards, Premium active',
                        'إضافة بطاقات أهداف المغذيات، Premium مفعّلة',
                      )
                    : _sectionCopy(
                        context,
                        'Add nutrient goal cards, locked Premium feature',
                        'إضافة بطاقات أهداف المغذيات، ميزة Premium مقفلة',
                      ),
                button: entitlementResolved || verifiedSubscription.hasError,
                child: ListTile(
                  key: const Key('dashboard-add-nutrient-goal-cards'),
                  leading: Consumer(
                    builder: (context, ref, _) {
                      final state = ref.watch(
                        dashboardNutrientGoalCardsProvider,
                      );
                      if (state.isLoading) {
                        return const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (state.hasError) {
                        return const Icon(Icons.error_outline_rounded);
                      }
                      return const BilSemanticIconBadge(
                        kind: BilSemanticIconKind.nutrition,
                        size: 32,
                        iconSize: 18,
                      );
                    },
                  ),
                  title: Consumer(
                    builder: (context, ref, _) {
                      final cards = ref.watch(
                        dashboardNutrientGoalCardsProvider,
                      );
                      final editing = cards.value?.isNotEmpty ?? false;
                      return Text(
                        editing
                            ? _copy(
                                context,
                                en: 'Edit nutrient goal cards',
                                ar: 'تعديل بطاقات أهداف المغذيات',
                                fr: 'Modifier les cartes de nutriments',
                                es: 'Editar tarjetas de nutrientes',
                                tr: 'Besin hedefi kartlarını düzenle',
                              )
                            : _copy(
                                context,
                                en: 'Add nutrient goal cards',
                                ar: 'إضافة بطاقات أهداف المغذيات',
                                fr: 'Ajouter des cartes de nutriments',
                                es: 'Añadir tarjetas de nutrientes',
                                tr: 'Besin hedefi kartları ekle',
                              ),
                      );
                    },
                  ),
                  subtitle: Consumer(
                    builder: (context, ref, _) {
                      final state = ref.watch(
                        dashboardNutrientGoalCardsProvider,
                      );
                      if (state.isLoading) {
                        return Text(
                          _sectionCopy(
                            context,
                            'Loading saved cards',
                            'جارٍ تحميل البطاقات المحفوظة',
                          ),
                        );
                      }
                      if (state.hasError) {
                        return Text(
                          _sectionCopy(
                            context,
                            'Cards could not be loaded. Tap to retry.',
                            'تعذر تحميل البطاقات. اضغط لإعادة المحاولة.',
                          ),
                        );
                      }
                      final count = state.value!.length;
                      return Text(
                        _copy(
                          context,
                          en: '$count ${_sectionCopy(context, 'selected', 'محددة')}',
                          ar: '$count محددة',
                          fr: '$count sélectionnées',
                          es: '$count seleccionadas',
                          tr: '$count seçildi',
                        ),
                      );
                    },
                  ),
                  trailing: verifiedSubscription.hasError
                      ? IconButton(
                          tooltip: _sectionCopy(
                            context,
                            'Retry subscription check',
                            'إعادة فحص الاشتراك',
                          ),
                          onPressed: () =>
                              ref.invalidate(verifiedSubscriptionStateProvider),
                          icon: const Icon(Icons.refresh_rounded),
                        )
                      : !entitlementResolved
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : !paid
                      ? const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFF2B632),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    if (verifiedSubscription.hasError) {
                      ref.invalidate(verifiedSubscriptionStateProvider);
                      return;
                    }
                    if (!entitlementResolved || _saving) return;
                    if (!paid) {
                      _showLockedNutrientPreview(context);
                      return;
                    }
                    final state = ref.read(dashboardNutrientGoalCardsProvider);
                    if (state.isLoading) return;
                    if (state.hasError) {
                      ref.invalidate(dashboardNutrientGoalCardsProvider);
                      return;
                    }
                    _chooseNutrientCards(context, ref, state.value!);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _savingLayout
                  ? null
                  : () => _restoreDefaults(context, ref),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(
                _sectionCopy(
                  context,
                  'Restore default view',
                  'استعادة العرض الافتراضي',
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            key: const Key('dashboard-preferences-done'),
            onPressed: _savingLayout ? null : _finishEditing,
            child: Text(_sectionCopy(context, 'Done editing', 'إنهاء التعديل')),
          ),
        ),
      ),
    );
  }
}
