part of '../food_page.dart';

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
        for (var index = 0; index < actions.length; index++) ...[
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
