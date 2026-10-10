import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/database/app_database.dart';
import '../services/meal_image_gateway_contract.dart';
import '../domain/unified_food.dart';

part 'meal_vision_premium_match.dart';
part 'meal_vision_premium_visuals.dart';

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
    ),
  );
}

String _word(BuildContext context, String english, String arabic) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'ar') return arabic;
  return RuntimeCopy.resolve(english, BilLocalePolicy.canonicalTag(locale)) ??
      english;
}

const _bgTop = Color(0xFF071D26);
const _bgBottom = Color(0xFF041017);
const _mint = Color(0xFF56F3B3);
const _muted = Color(0xFFADC4C8);
const _outline = Color(0x334BD9BA);

bool _light(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;
Color _foreground(BuildContext context) =>
    _light(context) ? const Color(0xFF102B32) : Colors.white;
Color _secondary(BuildContext context) =>
    _light(context) ? const Color(0xFF46636B) : _muted;
Color _accent(BuildContext context) =>
    _light(context) ? const Color(0xFF087A5D) : _mint;

BoxDecoration _glassDecoration(BuildContext context, {bool active = false}) {
  final light = _light(context);
  return BoxDecoration(
    color: light
        ? (active ? const Color(0xFFE0F8EC) : const Color(0xEBFFFFFF))
        : (active ? const Color(0x2841CF9B) : const Color(0x18FFFFFF)),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: light
          ? (active ? const Color(0xFF43AA81) : const Color(0x22546A70))
          : (active ? const Color(0xAA56F3B3) : _outline),
    ),
  );
}

Widget _glassShell(BuildContext context, Widget child) {
  final size = MediaQuery.sizeOf(context);
  final light = _light(context);
  return RepaintBoundary(
    key: const Key('premium-vision-render-surface'),
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: size.height - 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: light
                      ? const [
                          Color(0xF7F4FCF8),
                          Color(0xF2E1F0EE),
                          Color(0xFAFFFFFF),
                        ]
                      : const [_bgTop, Color(0xFF092D33), _bgBottom],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: light ? const Color(0x553F7D72) : _outline,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 25),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: light
                      ? Theme.of(context).colorScheme.copyWith(
                          primary: const Color(0xFF087A5D),
                          onPrimary: Colors.white,
                        )
                      : Theme.of(context).colorScheme.copyWith(primary: _mint),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
    return _glassShell(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: _accent(context),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'BIL Vision',
                        style: TextStyle(
                          color: _foreground(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _word(context, 'Cancel', 'إلغاء'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _foreground(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _word(
                    context,
                    'Review your meal analysis',
                    'تحليل وجبتك — راجع النتائج',
                  ),
                  style: TextStyle(color: _secondary(context), fontSize: 14),
                ),
                const SizedBox(height: 7),
                Text(
                  _word(
                    context,
                    'If the photo shows leftovers, enter what you actually ate, not what remains.',
                    'إذا كانت الصورة لبقايا الطعام، أدخل ما أكلته بالفعل وليس الكمية المتبقية.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFFFDA8B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _glassDecoration(context),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: _accent(context),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _word(
                            context,
                            'AI suggestions are not nutrition facts. Only a trusted food record supplies nutrients after your confirmation.',
                            'الاقتراحات ليست قيمًا غذائية مؤكدة. تُحسب المغذيات من سجل موثوق بعد مراجعتك ومطابقتك.',
                          ),
                          style: TextStyle(
                            color: _secondary(context),
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _photo(context),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _glassDecoration(context),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              color: _accent(context),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _word(context, 'Meal type: ', 'نوع الوجبة: ') +
                                    _mealLabel(context, widget.mealType),
                                style: TextStyle(color: _foreground(context)),
                              ),
                            ),
                            Text(
                              widget.photographedAt == null
                                  ? '—'
                                  : '${widget.photographedAt!.hour.toString().padLeft(2, '0')}: '
                                        '${widget.photographedAt!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(color: _secondary(context)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _stageChooser(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _foods.length; index++)
                    if (!_excluded.contains(index)) _candidateCard(index),
                  if (_excluded.isNotEmpty)
                    Wrap(
                      children: [
                        for (final index in _excluded)
                          ActionChip(
                            label: Text(
                              _word(context, 'Restore ', 'استعادة ') +
                                  _foods[index].name,
                            ),
                            onPressed: () =>
                                setState(() => _excluded.remove(index)),
                          ),
                      ],
                    ),
                  TextButton.icon(
                    key: const Key('premium-vision-add-food'),
                    onPressed: _addFood,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      _word(context, 'Add missing food', 'إضافة عنصر مفقود'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _light(context)
                  ? const Color(0xFFF1FAF7)
                  : const Color(0xA3051720),
              border: const Border(top: BorderSide(color: _outline)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      color: _accent(context),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _word(
                          context,
                          'Selected foods: ${_selected.difference(_excluded).length}',
                          'الأطعمة المحددة: ${_selected.difference(_excluded).length}',
                        ),
                        style: TextStyle(
                          color: _foreground(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _word(context, 'Nothing logged yet', 'لم يُسجّل شيء بعد'),
                      style: TextStyle(
                        color: _secondary(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (!_canContinue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _word(
                        context,
                        'To continue: select an item, confirm the photo stage and amount eaten, and enter a valid positive quantity and unit.',
                        'للمتابعة: حدّد الطعام ومرحلة الصورة والكمية المأكولة، وأدخل مقدارًا موجبًا ووحدة صحيحة.',
                      ),
                      style: TextStyle(
                        color: _secondary(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    key: const Key('premium-vision-continue'),
                    onPressed: _canContinue ? _confirm : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      _word(
                        context,
                        'Match selected foods',
                        'مطابقة الأطعمة المحددة',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
