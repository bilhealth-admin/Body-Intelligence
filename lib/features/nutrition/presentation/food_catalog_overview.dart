part of '../food_page.dart';

/// Keeps the two real entry points above the fold: find an existing food or
/// start one add journey. Capture methods live behind the single Add action so
/// the catalog is not displaced by a row of competing tools.
class _NutritionTaskBar extends StatelessWidget {
  const _NutritionTaskBar({required this.searchField, required this.onAddFood});

  final Widget searchField;
  final VoidCallback onAddFood;

  @override
  Widget build(BuildContext context) {
    final addButton = FilledButton.icon(
      key: const Key('food-primary-add-action'),
      onPressed: onAddFood,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.add_rounded),
      label: Text(
        context.strings.text('Add food'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.45;
        if (largeText || constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [searchField, const SizedBox(height: 8), addButton],
          );
        }
        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 112, maxWidth: 132),
              child: addButton,
            ),
          ],
        );
      },
    );
  }
}

class _FoodAddActionSheet extends StatelessWidget {
  const _FoodAddActionSheet({required this.showPremiumLabel});

  final bool showPremiumLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('Add food'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            PremiumNutritionGlass(
              key: const Key('food-add-barcode-premium-group'),
              compact: true,
              showLabel: showPremiumLabel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FoodAddActionTile(
                    actionKey: const Key('food-add-scan-barcode'),
                    icon: Icons.qr_code_scanner_rounded,
                    label: nutritionText(
                      context,
                      'Scan barcode',
                      'مسح الباركود',
                    ),
                    onTap: () =>
                        Navigator.pop(context, _FoodAddMethod.scanBarcode),
                  ),
                  _FoodAddActionTile(
                    actionKey: const Key('food-add-manual-barcode'),
                    icon: Icons.dialpad_rounded,
                    label: t('Enter barcode manually'),
                    onTap: () =>
                        Navigator.pop(context, _FoodAddMethod.manualBarcode),
                  ),
                ],
              ),
            ),
            _FoodAddActionTile(
              actionKey: const Key('food-add-meal-photo'),
              icon: Icons.center_focus_strong_rounded,
              label: nutritionText(
                context,
                'Analyze meal photo',
                'تحليل صورة الوجبة',
              ),
              onTap: () => Navigator.pop(context, _FoodAddMethod.mealPhoto),
            ),
            _FoodAddActionTile(
              actionKey: const Key('food-add-custom-food'),
              icon: Icons.edit_note_rounded,
              label: customFoodText(context, 'Create custom food'),
              onTap: () => Navigator.pop(context, _FoodAddMethod.customFood),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodAddActionTile extends StatelessWidget {
  const _FoodAddActionTile({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: ListTile(
        key: actionKey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
        ),
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _NutritionHero extends StatelessWidget {
  const _NutritionHero({required this.languageCode});

  final String languageCode;
  String tr(String en, String ar) =>
      nutritionTextForLanguage(languageCode, en, ar);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: tr(
        'Balanced meal in the nutrition studio',
        'وجبة متوازنة ضمن استوديو التغذية',
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusLg),
        child: SizedBox(
          height: 188,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/flagship/bil_meal_discovery_v1.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.08),
                cacheWidth: 720,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x12071120), Color(0xE6071120)],
                    stops: [0.28, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 18,
                end: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'Log smarter. Understand your food.',
                        'سجّل بذكاء. افهم ما تأكل.',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'Verified search, fast scanning, and data you control.',
                        'بحث موثوق ومسح سريع وبيانات تبقى تحت سيطرتك.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD8E5F4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionQuickActions extends StatelessWidget {
  const _NutritionQuickActions({
    required this.languageCode,
    required this.onScan,
    required this.onManualBarcode,
    required this.onCustomFood,
  });

  final String languageCode;
  final VoidCallback onScan;
  final VoidCallback onManualBarcode;
  final VoidCallback onCustomFood;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, VoidCallback)>[
      (
        Icons.qr_code_scanner_rounded,
        nutritionTextForLanguage(languageCode, 'Scan', 'مسح المنتج'),
        onScan,
      ),
      (
        Icons.dialpad_rounded,
        nutritionTextForLanguage(languageCode, 'Barcode', 'الباركود'),
        onManualBarcode,
      ),
      (
        Icons.add_circle_outline_rounded,
        nutritionTextForLanguage(languageCode, 'Custom', 'طعام مخصص'),
        onCustomFood,
      ),
    ];
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PremiumNutritionGlass(
            key: const Key('food-barcode-premium-group'),
            compact: true,
            borderRadius: BilFlagshipTokens.radiusMd,
            child: Row(
              children: [
                for (var index = 0; index < 2; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _NutritionAction(
                      icon: actions[index].$1,
                      label: actions[index].$2,
                      onTap: actions[index].$3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NutritionAction(
            icon: actions[2].$1,
            label: actions[2].$2,
            onTap: actions[2].$3,
          ),
        ),
      ],
    );
  }
}

class _NutritionAction extends StatelessWidget {
  const _NutritionAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: BilFlagshipTokens.cyan500),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuntimeSearchStatus extends StatelessWidget {
  const _RuntimeSearchStatus({required this.state, required this.languageCode});

  final _RuntimeSearchUiState state;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (state) {
      _RuntimeSearchUiState.searching => (
        Icons.sync,
        nutritionTextForLanguage(
          languageCode,
          'Searching the verified catalog and this device…',
          'جارٍ البحث في الكتالوج الموثق وهذا الجهاز…',
        ),
      ),
      _RuntimeSearchUiState.catalogAndLocal => (
        Icons.verified_outlined,
        nutritionTextForLanguage(
          languageCode,
          'Results include the verified catalog and this device.',
          'النتائج من الكتالوج الموثق وهذا الجهاز.',
        ),
      ),
      _RuntimeSearchUiState.localOnly => (
        Icons.phone_android_outlined,
        nutritionTextForLanguage(
          languageCode,
          'Showing results available on this device.',
          'تظهر النتائج المتاحة على هذا الجهاز.',
        ),
      ),
      _RuntimeSearchUiState.localFallback => (
        Icons.cloud_off_outlined,
        nutritionTextForLanguage(
          languageCode,
          'Catalog unavailable — showing device results.',
          'الكتالوج غير متاح الآن — تظهر نتائج الجهاز.',
        ),
      ),
      _RuntimeSearchUiState.idle => (Icons.info_outline, ''),
    };

    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              if (state == _RuntimeSearchUiState.searching)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
