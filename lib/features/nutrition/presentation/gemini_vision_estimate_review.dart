import 'dart:io';
import 'package:flutter/material.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../domain/gemini_vision_estimate.dart';
import '../domain/unified_food.dart';
import '../services/meal_image_gateway_contract.dart';
import 'meal_vision_premium_review.dart';
import 'gemini_vision_copy.dart';

Future<List<ReviewedGeminiVisionEstimate>?> showGeminiVisionEstimateReview(
  BuildContext context, {
  required MealImageAnalysis analysis,
  required bool Function() isCurrent,
  required MealVisionReviewLifetime lifetime,
  String? imagePath,
  String? destinationLabel,
  bool savesToDiary = false,
  Future<MealVisionReviewDecision> Function(List<ReviewedGeminiVisionEstimate>)?
  onConfirm,
}) {
  if (analysis.schemaVersion != 2 ||
      analysis.estimates.isEmpty ||
      !isCurrent() ||
      !lifetime.isActive) {
    return Future.value(null);
  }
  if (savesToDiary && onConfirm == null) {
    throw ArgumentError('Saving requires the atomic diary action.');
  }
  return showDialog<List<ReviewedGeminiVisionEstimate>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => guardMealVisionReview(
      lifetime: lifetime,
      child: _EstimateReview(
        analysis: analysis,
        isCurrent: isCurrent,
        lifetime: lifetime,
        imagePath: imagePath,
        destinationLabel: destinationLabel,
        savesToDiary: savesToDiary,
        onConfirm: onConfirm,
      ),
    ),
  );
}

class _EstimateReview extends StatefulWidget {
  const _EstimateReview({
    required this.analysis,
    required this.isCurrent,
    required this.lifetime,
    required this.savesToDiary,
    this.imagePath,
    this.destinationLabel,
    this.onConfirm,
  });
  final MealImageAnalysis analysis;
  final bool Function() isCurrent;
  final MealVisionReviewLifetime lifetime;
  final String? imagePath;
  final String? destinationLabel;
  final bool savesToDiary;
  final Future<MealVisionReviewDecision> Function(
    List<ReviewedGeminiVisionEstimate>,
  )?
  onConfirm;
  @override
  State<_EstimateReview> createState() => _EstimateReviewState();
}

class _EstimateReviewState extends State<_EstimateReview> {
  final _amounts = <TextEditingController>[];
  final _units = <TextEditingController>[];
  final _nodes = <String, FocusNode>{};
  final _selected = <int>{};
  final _editControllers = <ExpansibleController>[];
  bool _busy = false, _closing = false, _missingOpen = false;
  String? _error;
  bool get _current =>
      mounted && !_closing && widget.lifetime.isActive && widget.isCurrent();
  FocusNode _node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'gemini-$id'));
  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.analysis.estimates.length; i++) {
      final estimate = widget.analysis.estimates[i];
      _selected.add(i);
      _amounts.add(
        TextEditingController(text: estimate.picturedAmount?.toString() ?? ''),
      );
      _units.add(TextEditingController(text: estimate.picturedUnit ?? ''));
      _editControllers.add(ExpansibleController());
    }
  }

  @override
  void dispose() {
    for (final controller in [..._amounts, ..._units]) {
      controller.dispose();
    }
    for (final node in _nodes.values) {
      node.dispose();
    }
    for (final controller in _editControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _amount(int i) {
    var raw = _amounts[i].text.trim().replaceAll('٫', '.');
    const digits = ['٠١٢٣٤٥٦٧٨٩', '۰۱۲۳۴۵۶۷۸۹'];
    for (final alphabet in digits) {
      for (var n = 0; n < 10; n++) {
        raw = raw.replaceAll(alphabet[n], '$n');
      }
    }
    return double.tryParse(raw);
  }

  MealImageReviewedQuantity? _quantity(int i) {
    final basis = widget.analysis.estimates[i].basis;
    final amount = _amount(i);
    if (basis == null || amount == null) return null;
    return mealImageReviewedQuantity(
      amount: amount,
      unit: _units[i].text,
      servingSize: basis.quantity,
      servingUnit: basis.unit,
    );
  }

  void _close([List<ReviewedGeminiVisionEstimate>? result]) {
    final route = ModalRoute.of<List<ReviewedGeminiVisionEstimate>>(context);
    if (route == null || !route.isActive) return;
    _closing = true;
    if (route.isCurrent) {
      Navigator.pop(context, result);
    } else {
      route.navigator?.removeRoute(route, result);
    }
  }

  Future<void> _confirm() async {
    if (!_current || _busy || _missingOpen) return;
    final missing = <({String id, String label})>[];
    if (_selected.isEmpty) {
      missing.add((
        id: 'selection-0',
        label: geminiEstimateFieldCopy(context, 0),
      ));
    }
    for (var i = 0; i < widget.analysis.estimates.length; i++) {
      if (!_selected.contains(i)) continue;
      final e = widget.analysis.estimates[i];
      if (e.basis == null ||
          e.nutrients.toJson().values.every((v) => v == null)) {
        missing.add((
          id: 'source-$i',
          label: '${e.name}: ${geminiVisionText(context, 'Unknown')}',
        ));
      }
      final amount = _amount(i);
      if (amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          amount > 100000) {
        missing.add((
          id: 'amount-$i',
          label: '${e.name}: ${geminiEstimateFieldCopy(context, 1)}',
        ));
      }
      if (_quantity(i) == null &&
          e.basis != null &&
          amount != null &&
          amount > 0 &&
          amount.isFinite) {
        missing.add((
          id: 'unit-$i',
          label: '${e.name}: ${geminiEstimateFieldCopy(context, 2)}',
        ));
      }
    }
    if (missing.isNotEmpty) {
      await _showMissing(missing);
      return;
    }
    final selected = [
      for (var i = 0; i < widget.analysis.estimates.length; i++)
        if (_selected.contains(i))
          ReviewedGeminiVisionEstimate(
            estimate: widget.analysis.estimates[i],
            amount: _amount(i)!,
            unit: _units[i].text.trim(),
          ),
    ];
    if (widget.onConfirm == null) {
      _close(List.unmodifiable(selected));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.onConfirm!(List.unmodifiable(selected));
      if (!_current) return;
      switch (outcome.kind) {
        case MealVisionReviewDecisionKind.accepted:
          _close(List.unmodifiable(selected));
        case MealVisionReviewDecisionKind.retired:
          _close();
        case MealVisionReviewDecisionKind.retry:
          setState(() => _error = outcome.message);
        case MealVisionReviewDecisionKind.cancelled:
          break;
      }
    } on Object {
      if (_current) {
        setState(
          () => _error = geminiVisionText(context, 'Could not save changes.'),
        );
      }
    } finally {
      if (mounted && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _showMissing(List<({String id, String label})> missing) async {
    final title = geminiVisionText(context, 'Complete required details');
    final cancel = geminiVisionText(context, 'Cancel');
    _missingOpen = true;
    try {
      final selected = await showDialog<String>(
        context: context,
        builder: (dialog) => guardMealVisionReview(
          lifetime: widget.lifetime,
          child: BilPearlMaterialAlertDialog(
            key: const Key('gemini-required-details'),
            scrollable: true,
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in missing)
                  ListTile(
                    key: Key('gemini-missing-${field.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    leading: const Icon(Icons.radio_button_unchecked),
                    onTap: () {
                      if (_current && dialog.mounted) {
                        Navigator.pop(dialog, field.id);
                      }
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(cancel),
              ),
            ],
          ),
        ),
      );
      if (!_current || selected == null) return;
      if (selected.startsWith('amount-') || selected.startsWith('unit-')) {
        final index = int.tryParse(selected.split('-').last);
        if (index != null && index >= 0 && index < _editControllers.length) {
          _editControllers[index].expand();
          await WidgetsBinding.instance.endOfFrame;
          if (!_current) return;
        }
      }
      final node = _nodes[selected];
      final target = node?.context;
      if (node == null || target == null || !target.mounted) return;
      await Scrollable.ensureVisible(
        target,
        alignment: .3,
        duration: Duration.zero,
      );
      if (_current && node.context?.mounted == true) node.requestFocus();
    } finally {
      _missingOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Dialog.fullscreen(
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('gemini-review-scroll'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BIL Vision',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('gemini-review-close'),
                    onPressed: _busy ? null : () => _close(),
                    tooltip: geminiVisionText(context, 'Cancel'),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (widget.imagePath case final path?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(path),
                      height: 170,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              BilPearlMaterialCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    geminiEstimateCopy(context, 0),
                    key: const Key('gemini-estimate-notice'),
                  ),
                ),
              ),
              if (widget.destinationLabel != null)
                Text(widget.destinationLabel!),
              for (var i = 0; i < widget.analysis.estimates.length; i++)
                _card(i),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('gemini-estimate-confirm'),
                onPressed: _busy || !_current ? null : _confirm,
                icon: _busy
                    ? const BilFeatureWelcomeStatus()
                    : const Icon(Icons.check),
                label: Text(
                  widget.savesToDiary
                      ? geminiVisionText(context, 'Save')
                      : geminiEstimateCopy(context, 1),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _card(int i) {
    final e = widget.analysis.estimates[i];
    final factor = _quantity(i)?.servingFactor;
    return BilPearlMaterialCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Checkbox(
                  key: Key('gemini-selection-$i'),
                  focusNode: _node('selection-$i'),
                  value: _selected.contains(i),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            _selected.add(i);
                          } else {
                            _selected.remove(i);
                          }
                        }),
                ),
              ],
            ),
            Focus(
              focusNode: _node('source-$i'),
              child: Text(
                'Google Gemini · ${geminiVisionText(context, 'Estimated')}',
                key: Key('gemini-source-$i'),
              ),
            ),
            if (e.uncertainty != null) Text(e.uncertainty!),
            if (e.picturedAmount != null)
              Text(
                '${geminiVisionText(context, 'Portion')}: ${e.picturedAmount} ${e.picturedUnit ?? ''}',
              ),
            _facts(
              i,
              const [
                FoodNutrient.calories,
                FoodNutrient.protein,
                FoodNutrient.carbohydrates,
                FoodNutrient.fat,
                FoodNutrient.fiber,
                FoodNutrient.sugar,
              ],
              factor,
              includeNet: true,
            ),
            ExpansionTile(
              key: Key('gemini-more-nutrients-$i'),
              tilePadding: EdgeInsets.zero,
              title: Text(geminiVisionText(context, 'Nutrition details')),
              children: [
                _facts(
                  i,
                  FoodNutrient.values
                      .where((n) => n.index > FoodNutrient.sugar.index)
                      .toList(),
                  factor,
                ),
              ],
            ),
            ExpansionTile(
              key: Key('gemini-edit-portion-$i'),
              controller: _editControllers[i],
              maintainState: true,
              tilePadding: EdgeInsets.zero,
              title: Text(geminiVisionText(context, 'Adjust')),
              children: [
                TextField(
                  key: Key('gemini-amount-$i'),
                  focusNode: _node('amount-$i'),
                  controller: _amounts[i],
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: geminiVisionText(context, 'Amount'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  key: Key('gemini-unit-$i'),
                  focusNode: _node('unit-$i'),
                  controller: _units[i],
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: geminiVisionText(context, 'Unit'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _facts(
    int i,
    List<FoodNutrient> nutrients,
    double? factor, {
    bool includeNet = false,
  }) {
    final e = widget.analysis.estimates[i];
    final facts = [
      for (final n in nutrients)
        (
          n.name,
          _labels[n]!,
          e.nutrients[n],
          GeminiEstimateNutrients.units[n]!,
        ),
      if (includeNet)
        ('netCarbohydrates', 'Net carbs', e.nutrients.netCarbohydrates, 'g'),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns =
            (box.maxWidth /
                    (110 * MediaQuery.textScalerOf(context).scale(12) / 12))
                .floor()
                .clamp(1, 3);
        final width = (box.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final fact in facts)
              SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(geminiVisionText(context, fact.$2)),
                      Text(
                        fact.$3 == null || factor == null
                            ? '—'
                            : '${(fact.$3! * factor).toStringAsFixed(1)} ${fact.$4}',
                        key: Key('gemini-value-$i-${fact.$1}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

const _labels = <FoodNutrient, String>{
  FoodNutrient.calories: 'Calories',
  FoodNutrient.protein: 'Protein',
  FoodNutrient.carbohydrates: 'Carbs',
  FoodNutrient.fat: 'Fat',
  FoodNutrient.fiber: 'Fiber',
  FoodNutrient.sugar: 'Sugar',
  FoodNutrient.sodium: 'Sodium',
  FoodNutrient.potassium: 'Potassium',
  FoodNutrient.calcium: 'Calcium',
  FoodNutrient.magnesium: 'Magnesium',
  FoodNutrient.phosphorus: 'Phosphorus',
  FoodNutrient.iron: 'Iron',
  FoodNutrient.vitaminC: 'Vitamin C',
  FoodNutrient.saturatedFat: 'Saturated fat',
  FoodNutrient.polyunsaturatedFat: 'Polyunsaturated fat',
  FoodNutrient.monounsaturatedFat: 'Monounsaturated fat',
  FoodNutrient.transFat: 'Trans fat',
  FoodNutrient.cholesterol: 'Cholesterol',
  FoodNutrient.vitaminA: 'Vitamin A',
};
