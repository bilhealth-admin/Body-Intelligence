import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/food_basis_evidence.dart';
import '../services/meal_image_gateway_contract.dart';
import '../domain/unified_food.dart';

part 'meal_vision_premium_match.dart';
part 'meal_vision_premium_portion.dart';
part 'meal_vision_premium_visuals.dart';
part 'meal_vision_premium_glass.dart';
part 'meal_vision_premium_reference.dart';

/// Only identity and serving suggestions are returned from image analysis.
/// Nutrient values MUST be resolved by the existing trusted-food match flow.
class PremiumVisionSelection {
  const PremiumVisionSelection({
    required this.candidate,
    required this.amount,
    required this.unit,
  });
  final MealImageCandidate candidate;
  final double amount;
  final String unit;
}

/// The exact food and portion confirmed on the final review screen.
class TrustedVisionFoodSelection {
  const TrustedVisionFoodSelection({
    required this.food,
    required this.amount,
    required this.unit,
  });
  final Food food;
  final double amount;
  final String unit;
}

Future<TrustedVisionFoodSelection?> showEditableTrustedVisionFoodMatchDialog(
  BuildContext context, {
  required String recognizedName,
  required List<Food> foods,
  required double reviewedAmount,
  required String reviewedUnit,
  String? imagePath,
  String? evidenceOwnerKey,
}) {
  if (foods.isEmpty) return Future.value(null);
  return showDialog<TrustedVisionFoodSelection>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PremiumTrustedMatchDialog(
      recognizedName: recognizedName,
      foods: foods,
      reviewedAmount: reviewedAmount,
      reviewedUnit: reviewedUnit,
      imagePath: imagePath,
      editable: true,
      evidenceOwnerKey: evidenceOwnerKey,
    ),
  );
}

/// Opt-in replacement for the first review stage. Does not write to the diary.
Future<List<PremiumVisionSelection>?> showPremiumVisionReviewDialog(
  BuildContext context, {
  required MealImageAnalysis analysis,
  String? imagePath,
  String? mealType,
  DateTime? photographedAt,
}) => showDialog<List<PremiumVisionSelection>>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PremiumVisionReviewDialog(
    analysis: analysis,
    imagePath: imagePath,
    mealType: mealType,
    photographedAt: photographedAt,
  ),
);

/// Opt-in replacement for verified catalog record matching. This also performs
/// NO writes; the existing caller remains solely responsible for saving.
Future<Food?> showPremiumTrustedVisionFoodMatchDialog(
  BuildContext context, {
  required String recognizedName,
  required List<Food> foods,
  double? reviewedAmount,
  String? reviewedUnit,
  String? evidenceOwnerKey,
}) {
  if (foods.isEmpty) return Future<Food?>.value(null);
  return showDialog<Food>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PremiumTrustedMatchDialog(
      recognizedName: recognizedName,
      foods: foods,
      reviewedAmount: reviewedAmount,
      reviewedUnit: reviewedUnit,
      evidenceOwnerKey: evidenceOwnerKey,
    ),
  );
}

/// A normal Vision match requires a verified catalog row. Coach can also
/// present an owner-checked immutable modern label snapshot, but never a
/// free-form, unverifiable local or model-generated record.
bool mealVisionFoodCanBeUsed(Food food, {String? evidenceOwnerKey}) {
  if (food.verified) return true;
  if (evidenceOwnerKey == null || evidenceOwnerKey.isEmpty) return false;
  final evidence = FoodBasisEvidence.read(food, ownerKey: evidenceOwnerKey);
  return evidence.isModern && evidence.isValid && evidence.snapshot != null;
}

String _word(BuildContext context, String english, String arabic) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'ar') return arabic;
  return RuntimeCopy.resolve(english, BilLocalePolicy.canonicalTag(locale)) ??
      english;
}

class _PremiumVisionReviewDialog extends StatefulWidget {
  const _PremiumVisionReviewDialog({
    required this.analysis,
    this.imagePath,
    this.mealType,
    this.photographedAt,
  });
  final MealImageAnalysis analysis;
  final String? imagePath, mealType;
  final DateTime? photographedAt;

  @override
  State<_PremiumVisionReviewDialog> createState() =>
      _PremiumVisionReviewDialogState();
}

class _PremiumVisionReviewDialogState
    extends State<_PremiumVisionReviewDialog> {
  final List<MealImageCandidate> _foods = [];
  final List<TextEditingController> _amounts = [];
  final List<TextEditingController> _units = [];
  final List<int?> _alternatives = [];
  final List<bool?> _amountMeaning = [];
  final Set<int> _selected = <int>{};
  final Set<int> _excluded = <int>{};
  final GlobalKey _ingredientsAnchor = GlobalKey();
  String? _photoStage;
  bool _adding = false;
  final _newFood = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final candidate in widget.analysis.candidates) {
      _append(candidate);
    }
  }

  @override
  void dispose() {
    for (final controller in [..._amounts, ..._units, _newFood]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _append(MealImageCandidate candidate) {
    _foods.add(candidate);
    _amounts.add(
      TextEditingController(text: candidate.amount?.toString() ?? ''),
    );
    _units.add(TextEditingController(text: candidate.unit ?? 'g'));
    _alternatives.add(null);
    _amountMeaning.add(null); // Vision cannot prove "eaten" vs "remaining".
  }

  void _adjust(int index, double delta) {
    final amount = double.tryParse(_digits(_amounts[index].text)) ?? 0;
    final next = amount + delta;
    if (next > 0 && next <= 100000) {
      setState(
        () =>
            _amounts[index].text = next.toStringAsFixed(next % 1 == 0 ? 0 : 1),
      );
    }
  }

  MealImageCandidate _reviewedCandidate(int index) {
    final item = _foods[index];
    final selected = _alternatives[index];
    if (selected == null) return item;
    final option = item.alternatives[selected];
    return MealImageCandidate(
      name: option.name,
      confidence: option.confidence,
      evidence: _word(
        context,
        'Alternative chosen by user',
        'بديل اختاره المستخدم',
      ),
      identificationProvider: item.identificationProvider,
      modelRevision: item.modelRevision,
      nutritionResolution: MealNutritionResolution.requiresVerifiedFoodMatch,
      amount: item.amount,
      unit: item.unit,
      alternatives: item.alternatives,
      uncertainty: item.uncertainty,
      warnings: item.warnings,
      // Never keep the old exact match ID when changing the recognized food.
    );
  }

  Future<void> _addFood() async {
    if (_adding) return;
    setState(() => _adding = true);
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(_word(context, 'Add missing food', 'أضف طعامًا مفقودًا')),
        content: TextField(
          controller: _newFood,
          autofocus: true,
          maxLength: 160,
          decoration: InputDecoration(
            labelText: _word(context, 'Food name', 'اسم الطعام'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(_word(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, _newFood.text.trim()),
            child: Text(_word(context, 'Add', 'إضافة')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (name != null && name.isNotEmpty) {
        _append(
          MealImageCandidate(
            name: name,
            confidence: 0,
            evidence: _word(
              context,
              'Added by you, not recognized by AI',
              'أضفته بنفسك، ولم يتعرف عليه الذكاء الاصطناعي',
            ),
            identificationProvider: 'user',
            modelRevision: 'manual',
            nutritionResolution:
                MealNutritionResolution.requiresVerifiedFoodMatch,
            warnings: [
              _word(
                context,
                'Match with a verified food record',
                'يجب مطابقته بسجل غذائي موثوق',
              ),
            ],
          ),
        );
        _selected.add(_foods.length - 1);
      }
      _newFood.clear();
    });
  }

  static String _digits(String value) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var result = value.trim().replaceAll('٫', '.').replaceAll('،', '.');
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
    }
    return result;
  }

  bool get _canContinue {
    if (_photoStage == null) return false;
    final active = _selected.difference(_excluded);
    if (active.isEmpty) return false;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    for (final index in active) {
      if (_amountMeaning[index] != true) return false;
      final amount = double.tryParse(_digits(_amounts[index].text));
      final unit = mealImageCanonicalUnit(_units[index].text, locale);
      if (amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          amount > 100000 ||
          unit.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _confirm() {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final results = <PremiumVisionSelection>[];
    // Iterate in visual order, not the Set's historical selection order.
    for (var index = 0; index < _foods.length; index++) {
      if (!_selected.contains(index) || _excluded.contains(index)) continue;
      if (_photoStage == null || _amountMeaning[index] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _word(
                context,
                'Confirm the photo stage and amount actually eaten.',
                'حدّد مرحلة الصورة وأكّد الكمية التي تناولتها بالفعل.',
              ),
            ),
          ),
        );
        return;
      }
      final amount = double.tryParse(_digits(_amounts[index].text));
      final unit = mealImageCanonicalUnit(_units[index].text, locale);
      if (amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          amount > 100000 ||
          unit.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _word(
                context,
                'Enter a valid amount and unit for each selected food.',
                'أدخل كمية ووحدة صحيحتين لكل صنف محدد.',
              ),
            ),
          ),
        );
        return;
      }
      results.add(
        PremiumVisionSelection(
          candidate: _reviewedCandidate(index),
          amount: amount,
          unit: unit,
        ),
      );
    }
    if (results.isNotEmpty) Navigator.of(context).pop(results);
  }

  String? get _sourceImagePath => widget.imagePath;
  BuildContext get _visualContext => context;
  void _visualUpdate(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final light = _light(context);
    final count = _selected.difference(_excluded).length;
    final photographedAt = widget.photographedAt;
    final clock = photographedAt == null
        ? '—'
        : '${photographedAt.hour.toString().padLeft(2, '0')}:${photographedAt.minute.toString().padLeft(2, '0')}';
    return _glassShell(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Container(
                  height: 43,
                  width: 43,
                  decoration: _glassDecoration(context, active: true),
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    color: _accent(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIL Vision',
                        style: TextStyle(
                          color: _foreground(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _word(
                          context,
                          'Review the AI meal analysis',
                          'تحليل الوجبة بالذكاء الاصطناعي',
                        ),
                        style: TextStyle(
                          color: _secondary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('premium-vision-close'),
                  tooltip: _word(context, 'Cancel', 'إلغاء'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: _foreground(context)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('premium-vision-review-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _photo(context),
                  const SizedBox(height: 12),
                  Column(
                    key: _ingredientsAnchor,
                    children: [
                      for (var index = 0; index < _foods.length; index++)
                        if (!_excluded.contains(index)) _candidateCard(index),
                    ],
                  ),
                  if (_excluded.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final index in _excluded)
                          ActionChip(
                            label: Text(
                              '${_word(context, 'Restore ', 'استعادة ')}${_foods[index].name}',
                            ),
                            onPressed: () =>
                                setState(() => _excluded.remove(index)),
                          ),
                      ],
                    ),
                  _reviewContext(clock),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: light
                          ? const Color(0xFFFFF4DD)
                          : const Color(0x503C2E10),
                      border: Border.all(
                        color: const Color(0x88EDBD64),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFF3C56E),
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _word(
                              context,
                              'If the photo shows leftovers, enter what you ate, not what remains. Recognition confidence is not calorie accuracy.',
                              'إذا كانت الصورة لبقايا الطعام، أدخل ما أكلته بالفعل. ثقة التعرّف لا تثبت السعرات.',
                            ),
                            style: TextStyle(
                              color: light
                                  ? const Color(0xFF674F26)
                                  : const Color(0xFFFFDE9A),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _unverifiedNutrition(context),
                  TextButton.icon(
                    key: const Key('premium-vision-add-food'),
                    onPressed: _addFood,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      _word(
                        context,
                        'Add missing ingredient',
                        'إضافة مكوّن آخر',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _reviewActionBar(count),
        ],
      ),
    );
  }
}
