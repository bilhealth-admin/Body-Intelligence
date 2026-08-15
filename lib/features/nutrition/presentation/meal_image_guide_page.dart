import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../providers/meal_vision_usage_provider.dart';
import '../services/meal_vision_usage_contract.dart';

const _mealGuideTranslations = <String, Map<String, String>>{
  'en': {
    'meal_scan': 'Meal Scan',
    'not_now': 'Not now',
    'choose_photo': 'Choose a meal photo',
    'continue': 'Continue',
    'suggestions_disclaimer':
        'Suggestions are not nutrition facts. You stay in control and nothing is logged until you confirm it.',
    'step_progress': 'STEP {current} OF {total}',
    'step_scan_title': 'Scan your entire meal',
    'step_scan_body': 'Keep the full plate in frame and use clear, even light.',
    'step_select_title': 'Select visible foods',
    'step_select_body':
        'Confirm only foods you can see. Remove uncertain suggestions.',
    'step_add_title': 'Add anything we missed',
    'step_add_body':
        'Search the trusted catalog for sauces, drinks, and sides.',
    'step_review_title': 'Review and log your meal',
    'step_review_body':
        'Check portions and nutrition sources before anything is saved.',
    'frame_meal': 'Frame your meal',
    'visible_foods': 'Visible foods',
    'grilled_chicken': 'Grilled chicken',
    'rice': 'Rice',
    'mixed_salad': 'Mixed salad',
    'confirm_visible': 'Confirm only what you see',
    'add_another_food': 'Add another food',
    'search_foods': 'Search foods',
    'tahini_sauce': 'Tahini sauce',
    'sparkling_water': 'Sparkling water',
    'pita_bread': 'Pita bread',
    'review_meal': 'Review meal',
    'chicken': 'Chicken',
    'trusted_source': 'Source: trusted catalog',
    'portion_review': 'Portion needs review',
    'salad': 'Salad',
    'nothing_saved': 'Nothing is saved until you confirm',
    'usage':
        '{remaining} analyses available from weekly allowance and AI Boost',
    'usage_unavailable': 'Analysis allowance is unavailable right now.',
    'usage_signed_out': 'Sign in to check your analysis allowance.',
    'quota_exhausted': 'Weekly allowance and AI Boost balance are exhausted.',
  },
  'ar': {
    'meal_scan': 'مسح الوجبة',
    'not_now': 'ليس الآن',
    'choose_photo': 'اختر صورة للوجبة',
    'continue': 'متابعة',
    'suggestions_disclaimer':
        'الاقتراحات ليست حقائق غذائية. أنت المتحكم، ولن يُسجَّل أي شيء حتى تؤكده.',
    'step_progress': 'الخطوة {current} من {total}',
    'step_scan_title': 'صوّر وجبتك كاملة',
    'step_scan_body':
        'أبقِ الطبق كاملًا داخل الإطار واستخدم إضاءة واضحة ومتوازنة.',
    'step_select_title': 'حدّد الأطعمة الظاهرة',
    'step_select_body':
        'أكّد فقط الأطعمة التي تراها. أزل الاقتراحات غير المؤكدة.',
    'step_add_title': 'أضف ما فاتنا',
    'step_add_body':
        'ابحث في الدليل الموثوق عن الصلصات والمشروبات والأطباق الجانبية.',
    'step_review_title': 'راجع وجبتك وسجّلها',
    'step_review_body':
        'تحقق من الحصص ومصادر المعلومات الغذائية قبل حفظ أي شيء.',
    'frame_meal': 'ضع وجبتك داخل الإطار',
    'visible_foods': 'الأطعمة الظاهرة',
    'grilled_chicken': 'دجاج مشوي',
    'rice': 'أرز',
    'mixed_salad': 'سلطة مشكلة',
    'confirm_visible': 'أكّد فقط ما تراه',
    'add_another_food': 'أضف طعامًا آخر',
    'search_foods': 'ابحث عن الأطعمة',
    'tahini_sauce': 'صلصة طحينة',
    'sparkling_water': 'مياه غازية',
    'pita_bread': 'خبز عربي',
    'review_meal': 'راجع الوجبة',
    'chicken': 'دجاج',
    'trusted_source': 'المصدر: دليل موثوق',
    'portion_review': 'الحصة تحتاج إلى مراجعة',
    'salad': 'سلطة',
    'nothing_saved': 'لن يُحفظ شيء حتى تؤكده',
    'usage': 'يتوفر {remaining} تحليلًا من الحصة الأسبوعية ورصيد AI Boost',
    'usage_unavailable': 'تعذر التحقق من رصيد التحليل الآن.',
    'usage_signed_out': 'سجّل الدخول للتحقق من رصيد التحليل.',
    'quota_exhausted': 'نفدت الحصة الأسبوعية ورصيد AI Boost.',
  },
  'fr': {
    'meal_scan': 'Analyse du repas',
    'not_now': 'Pas maintenant',
    'choose_photo': 'Choisir une photo du repas',
    'continue': 'Continuer',
    'suggestions_disclaimer':
        'Les suggestions ne sont pas des valeurs nutritionnelles. Vous gardez le contrôle et rien n’est enregistré sans votre confirmation.',
    'step_progress': 'ÉTAPE {current} SUR {total}',
    'step_scan_title': 'Photographiez tout votre repas',
    'step_scan_body':
        'Gardez l’assiette entière dans le cadre et utilisez une lumière claire et uniforme.',
    'step_select_title': 'Sélectionnez les aliments visibles',
    'step_select_body':
        'Confirmez uniquement les aliments que vous voyez. Supprimez les suggestions incertaines.',
    'step_add_title': 'Ajoutez ce que nous avons manqué',
    'step_add_body':
        'Recherchez sauces, boissons et accompagnements dans le catalogue vérifié.',
    'step_review_title': 'Vérifiez et enregistrez votre repas',
    'step_review_body':
        'Vérifiez les portions et les sources nutritionnelles avant tout enregistrement.',
    'frame_meal': 'Cadrez votre repas',
    'visible_foods': 'Aliments visibles',
    'grilled_chicken': 'Poulet grillé',
    'rice': 'Riz',
    'mixed_salad': 'Salade composée',
    'confirm_visible': 'Confirmez uniquement ce que vous voyez',
    'add_another_food': 'Ajouter un autre aliment',
    'search_foods': 'Rechercher des aliments',
    'tahini_sauce': 'Sauce tahini',
    'sparkling_water': 'Eau gazeuse',
    'pita_bread': 'Pain pita',
    'review_meal': 'Vérifier le repas',
    'chicken': 'Poulet',
    'trusted_source': 'Source : catalogue vérifié',
    'portion_review': 'Portion à vérifier',
    'salad': 'Salade',
    'nothing_saved': 'Rien n’est enregistré sans votre confirmation',
    'usage':
        '{remaining} analyses disponibles via le quota hebdomadaire et AI Boost',
    'usage_unavailable': 'Le quota d’analyse est indisponible actuellement.',
    'usage_signed_out': 'Connectez-vous pour consulter votre quota d’analyse.',
    'quota_exhausted':
        'Le quota hebdomadaire et le solde AI Boost sont épuisés.',
  },
  'es': {
    'meal_scan': 'Escaneo de comida',
    'not_now': 'Ahora no',
    'choose_photo': 'Elegir una foto de la comida',
    'continue': 'Continuar',
    'suggestions_disclaimer':
        'Las sugerencias no son datos nutricionales. Tú mantienes el control y no se registra nada hasta que lo confirmes.',
    'step_progress': 'PASO {current} DE {total}',
    'step_scan_title': 'Escanea toda tu comida',
    'step_scan_body':
        'Mantén el plato completo dentro del encuadre y usa una luz clara y uniforme.',
    'step_select_title': 'Selecciona los alimentos visibles',
    'step_select_body':
        'Confirma solo los alimentos que ves. Elimina las sugerencias dudosas.',
    'step_add_title': 'Añade lo que falte',
    'step_add_body':
        'Busca salsas, bebidas y acompañamientos en el catálogo verificado.',
    'step_review_title': 'Revisa y registra tu comida',
    'step_review_body':
        'Comprueba las porciones y las fuentes nutricionales antes de guardar nada.',
    'frame_meal': 'Encuadra tu comida',
    'visible_foods': 'Alimentos visibles',
    'grilled_chicken': 'Pollo a la parrilla',
    'rice': 'Arroz',
    'mixed_salad': 'Ensalada mixta',
    'confirm_visible': 'Confirma solo lo que ves',
    'add_another_food': 'Añadir otro alimento',
    'search_foods': 'Buscar alimentos',
    'tahini_sauce': 'Salsa tahini',
    'sparkling_water': 'Agua con gas',
    'pita_bread': 'Pan de pita',
    'review_meal': 'Revisar comida',
    'chicken': 'Pollo',
    'trusted_source': 'Fuente: catálogo verificado',
    'portion_review': 'La porción requiere revisión',
    'salad': 'Ensalada',
    'nothing_saved': 'No se guarda nada hasta que lo confirmes',
    'usage': '{remaining} análisis disponibles del cupo semanal y AI Boost',
    'usage_unavailable': 'El cupo de análisis no está disponible ahora.',
    'usage_signed_out': 'Inicia sesión para consultar tu cupo de análisis.',
    'quota_exhausted': 'Se agotaron el cupo semanal y el saldo de AI Boost.',
  },
  'tr': {
    'meal_scan': 'Öğün Tarama',
    'not_now': 'Şimdi değil',
    'choose_photo': 'Öğün fotoğrafı seç',
    'continue': 'Devam et',
    'suggestions_disclaimer':
        'Öneriler besin değeri değildir. Kontrol sizdedir ve siz onaylayana kadar hiçbir şey kaydedilmez.',
    'step_progress': 'ADIM {current} / {total}',
    'step_scan_title': 'Tüm öğününüzü tarayın',
    'step_scan_body':
        'Tabağın tamamını kadrajda tutun ve net, eşit ışık kullanın.',
    'step_select_title': 'Görünen yiyecekleri seçin',
    'step_select_body':
        'Yalnızca gördüğünüz yiyecekleri onaylayın. Emin olmadığınız önerileri kaldırın.',
    'step_add_title': 'Eksik kalanları ekleyin',
    'step_add_body':
        'Soslar, içecekler ve garnitürler için güvenilir katalogda arama yapın.',
    'step_review_title': 'Öğününüzü gözden geçirip kaydedin',
    'step_review_body':
        'Herhangi bir şey kaydedilmeden önce porsiyonları ve besin kaynaklarını kontrol edin.',
    'frame_meal': 'Öğününüzü kadraja alın',
    'visible_foods': 'Görünen yiyecekler',
    'grilled_chicken': 'Izgara tavuk',
    'rice': 'Pirinç',
    'mixed_salad': 'Karışık salata',
    'confirm_visible': 'Yalnızca gördüklerinizi onaylayın',
    'add_another_food': 'Başka yiyecek ekle',
    'search_foods': 'Yiyecek ara',
    'tahini_sauce': 'Tahin sosu',
    'sparkling_water': 'Maden suyu',
    'pita_bread': 'Pide ekmeği',
    'review_meal': 'Öğünü gözden geçir',
    'chicken': 'Tavuk',
    'trusted_source': 'Kaynak: güvenilir katalog',
    'portion_review': 'Porsiyon gözden geçirilmeli',
    'salad': 'Salata',
    'nothing_saved': 'Siz onaylayana kadar hiçbir şey kaydedilmez',
    'usage':
        'Haftalık haktan ve AI Boost bakiyesinden {remaining} analiz kullanılabilir',
    'usage_unavailable': 'Analiz hakkı şu anda kullanılamıyor.',
    'usage_signed_out': 'Analiz hakkınızı görmek için oturum açın.',
    'quota_exhausted': 'Haftalık hak ve AI Boost bakiyesi tükendi.',
  },
};

String _mealGuideText(
  BuildContext context,
  String key, {
  Map<String, String> values = const {},
}) {
  assert(_mealGuideTranslationsAreComplete);
  final locale = Localizations.localeOf(context);
  final languageCode = locale.languageCode;
  final english = _mealGuideTranslations['en']![key]!;
  var text =
      _mealGuideTranslations[languageCode]?[key] ??
      RuntimeCopy.resolve(english, BilLocalePolicy.canonicalTag(locale)) ??
      english;
  for (final entry in values.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}

bool get _mealGuideTranslationsAreComplete {
  final englishKeys = _mealGuideTranslations['en']!.keys.toSet();
  return _mealGuideTranslations.length == 5 &&
      _mealGuideTranslations.values.every(
        (catalog) =>
            catalog.keys.toSet().containsAll(englishKeys) &&
            englishKeys.containsAll(catalog.keys) &&
            catalog.values.every((value) => value.trim().isNotEmpty),
      );
}

String _mealGuideNumber(BuildContext context, int value) {
  final text = '$value';
  if (Localizations.localeOf(context).languageCode != 'ar') return text;
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  return text.split('').map((digit) => arabicDigits[int.parse(digit)]).join();
}

/// The production education boundary shown before a meal image leaves the
/// device. It explains the four-step review flow without implying that image
/// analysis is configured or that nutrition values can be inferred directly.
class MealImageGuidePage extends ConsumerStatefulWidget {
  const MealImageGuidePage({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  ConsumerState<MealImageGuidePage> createState() => _MealImageGuidePageState();
}

class _MealImageGuidePageState extends ConsumerState<MealImageGuidePage> {
  late final PageController _controller;
  late int _page;

  static const _steps = <_MealImageGuideStep>[
    _MealImageGuideStep(
      icon: Icons.center_focus_strong_rounded,
      title: 'step_scan_title',
      body: 'step_scan_body',
      preview: _MealImagePreview.plate,
    ),
    _MealImageGuideStep(
      icon: Icons.checklist_rtl_rounded,
      title: 'step_select_title',
      body: 'step_select_body',
      preview: _MealImagePreview.selection,
    ),
    _MealImageGuideStep(
      icon: Icons.edit_note_rounded,
      title: 'step_add_title',
      body: 'step_add_body',
      preview: _MealImagePreview.search,
    ),
    _MealImageGuideStep(
      icon: Icons.fact_check_outlined,
      title: 'step_review_title',
      body: 'step_review_body',
      preview: _MealImagePreview.review,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _steps.length - 1);
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usage = ref.watch(mealVisionUsageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_mealGuideText(context, 'meal_scan')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_mealGuideText(context, 'not_now')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) =>
                    _GuideStepView(step: _steps[index], stepNumber: index + 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _page ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _VisionUsageCard(snapshot: usage),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('meal-image-guide-next'),
                      onPressed: usage.asData?.value.canAnalyze == true
                          ? () {
                              if (_page == _steps.length - 1) {
                                Navigator.of(context).pop(true);
                              } else {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            }
                          : null,
                      child: Text(
                        _page == _steps.length - 1
                            ? _mealGuideText(context, 'choose_photo')
                            : _mealGuideText(context, 'continue'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _mealGuideText(context, 'suggestions_disclaimer'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisionUsageCard extends StatelessWidget {
  const _VisionUsageCard({required this.snapshot});

  final AsyncValue<MealVisionUsageSnapshot> snapshot;

  @override
  Widget build(BuildContext context) {
    final resolved = snapshot.asData?.value;
    final usage = resolved?.usage;
    final exhausted = usage?.exhausted ?? false;
    final text = usage != null
        ? _mealGuideText(
            context,
            exhausted ? 'quota_exhausted' : 'usage',
            values: {
              'used': _mealGuideNumber(context, usage.used),
              'limit': _mealGuideNumber(context, usage.limit),
              'remaining': _mealGuideNumber(context, usage.remaining),
            },
          )
        : _mealGuideText(
            context,
            resolved?.availability == MealVisionUsageAvailability.signedOut
                ? 'usage_signed_out'
                : 'usage_unavailable',
          );
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('meal-vision-usage'),
      label: text,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: exhausted
              ? colors.errorContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              exhausted ? Icons.lock_clock_outlined : Icons.auto_awesome,
              size: 18,
              color: exhausted ? colors.onErrorContainer : colors.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStepView extends StatelessWidget {
  const _GuideStepView({required this.step, required this.stepNumber});

  final _MealImageGuideStep step;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      child: Column(
        children: [
          Text(
            _mealGuideText(
              context,
              'step_progress',
              values: {
                'current': _mealGuideNumber(context, stepNumber),
                'total': _mealGuideNumber(context, 4),
              },
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          _MealImagePhonePreview(type: step.preview),
          const SizedBox(height: 26),
          Icon(step.icon, color: colors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            _mealGuideText(context, step.title),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            _mealGuideText(context, step.body),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MealImagePreview { plate, selection, search, review }

class _MealImagePhonePreview extends StatelessWidget {
  const _MealImagePhonePreview({required this.type});

  final _MealImagePreview type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      // The review and selection previews contain several full-size labels.
      // Give them enough vertical room instead of shrinking accessible text.
      height: 360,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.onSurface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ColoredBox(
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: switch (type) {
              _MealImagePreview.plate => _plate(context, colors),
              _MealImagePreview.selection => _selection(context, colors),
              _MealImagePreview.search => _search(context, colors),
              _MealImagePreview.review => _review(context, colors),
            },
          ),
        ),
      ),
    );
  }

  Widget _plate(BuildContext context, ColorScheme colors) => Column(
    children: [
      Text(
        _mealGuideText(context, 'frame_meal'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
          border: Border.all(color: colors.primary, width: 3),
        ),
        child: const Icon(Icons.dinner_dining_rounded, size: 72),
      ),
      const Spacer(),
      const Icon(Icons.camera_alt_rounded, size: 36),
    ],
  );

  Widget _selection(BuildContext context, ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _mealGuideText(context, 'visible_foods'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      for (final item in const ['grilled_chicken', 'rice', 'mixed_salad'])
        Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: CheckboxListTile(
            dense: true,
            value: true,
            onChanged: null,
            title: Text(
              _mealGuideText(context, item),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      const Spacer(),
      Text(
        _mealGuideText(context, 'confirm_visible'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _search(BuildContext context, ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _mealGuideText(context, 'add_another_food'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 44,
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: _mealGuideText(context, 'search_foods'),
          ),
        ),
      ),
      const SizedBox(height: 8),
      for (final item in const [
        'tahini_sauce',
        'sparkling_water',
        'pita_bread',
      ])
        SizedBox(
          height: 46,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.add_circle_outline,
              color: colors.primary,
              size: 20,
            ),
            title: Text(
              _mealGuideText(context, item),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      const Spacer(),
    ],
  );

  Widget _review(BuildContext context, ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _mealGuideText(context, 'review_meal'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      for (final item in const [
        ('chicken', 'trusted_source'),
        ('rice', 'portion_review'),
        ('salad', 'trusted_source'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mealGuideText(context, item.$1),
                      style: const TextStyle(fontSize: 15, height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _mealGuideText(context, item.$2),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _mealGuideText(context, 'nothing_saved'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _MealImageGuideStep {
  const _MealImageGuideStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.preview,
  });
  final IconData icon;
  final String title;
  final String body;
  final _MealImagePreview preview;
}
