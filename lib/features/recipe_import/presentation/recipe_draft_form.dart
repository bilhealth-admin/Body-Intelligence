import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../nutrition/services/food_presentation_localizer.dart';
import '../domain/trusted_recipe.dart';
import '../services/trusted_recipe_parser.dart';

/// A human-facing editor. Serialization and validation stay internal.
class RecipeDraftForm extends StatefulWidget {
  const RecipeDraftForm({required this.onReview, this.initial, super.key});
  final TrustedRecipeDraft? initial;
  final Future<void> Function(TrustedRecipeDraft) onReview;

  @override
  State<RecipeDraftForm> createState() => _RecipeDraftFormState();
}

class _RecipeDraftFormState extends State<RecipeDraftForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _servings = TextEditingController(
    text: '${widget.initial?.servings ?? 2}',
  );
  late final _prep = TextEditingController(
    text: '${widget.initial?.prepMinutes ?? 0}',
  );
  late final _cook = TextEditingController(
    text: '${widget.initial?.cookMinutes ?? 0}',
  );
  late final _steps = TextEditingController(
    text: widget.initial?.steps.join('\n'),
  );
  late final _ingredients = [
    for (final value
        in widget.initial?.ingredients ?? const <TrustedRecipeIngredient>[])
      _IngredientFields(value),
    if (widget.initial == null) _IngredientFields(null),
  ];
  bool _busy = false;
  bool _invalid = false;

  @override
  void dispose() {
    for (final controller in [_name, _servings, _prep, _cook, _steps]) {
      controller.dispose();
    }
    for (final row in _ingredients) {
      row.dispose();
    }
    super.dispose();
  }

  num? _number(String text) {
    final normalized = text
        .trim()
        .replaceAll(',', '.')
        .replaceAll('٫', '.')
        .replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
          const a = '٠١٢٣٤٥٦٧٨٩';
          const p = '۰۱۲۳۴۵۶۷۸۹';
          final char = match[0]!;
          return '${a.contains(char) ? a.indexOf(char) : p.indexOf(char)}';
        });
    return num.tryParse(normalized);
  }

  Future<void> _review() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _invalid = false;
    });
    try {
      final ingredients = [
        for (final row in _ingredients)
          {
            'name': row.name.text.trim(),
            'quantity': _number(row.quantity.text),
            'unit': row.unit,
            if (row.original?.sourceRecordId != null &&
                row.name.text.trim() == row.original!.name)
              'sourceRecordId': row.original!.sourceRecordId,
          },
      ];
      // Source-backed nutrition is only retained when quantities and servings
      // are unchanged. Editing an ingredient must never retain stale macros.
      final unchanged =
          widget.initial != null &&
          _number(_servings.text) == widget.initial!.servings &&
          ingredients.length == widget.initial!.ingredients.length &&
          Iterable<int>.generate(ingredients.length).every((i) {
            final original = widget.initial!.ingredients[i];
            final edited = ingredients[i];
            return edited['name'] == original.name &&
                edited['quantity'] == original.quantity &&
                edited['unit'] == original.unit &&
                edited['sourceRecordId'] == original.sourceRecordId;
          });
      final draft = TrustedRecipeParser.parse(
        jsonEncode({
          'name': _name.text.trim(),
          'servings': _number(_servings.text),
          'prepMinutes': _number(_prep.text),
          'cookMinutes': _number(_cook.text),
          'ingredients': ingredients,
          'steps': _steps.text
              .split('\n')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList(),
          if (widget.initial?.sourceUrl != null)
            'sourceUrl': widget.initial!.sourceUrl.toString(),
          if (unchanged && widget.initial?.nutrition != null)
            'nutrition': widget.initial!.nutrition!.toJson(),
        }),
      );
      await widget.onReview(draft);
    } on Object {
      if (mounted) setState(() => _invalid = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String text) => context.strings.text(text);
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    Widget field(
      String key,
      String label,
      TextEditingController controller, {
      bool number = false,
      int lines = 1,
    }) => TextField(
      key: Key(key),
      controller: controller,
      enabled: !_busy,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 12,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: t(label),
        border: const OutlineInputBorder(),
      ),
    );
    return ListView(
      key: const Key('recipe-draft-form'),
      padding: const EdgeInsets.all(20),
      children: [
        field('recipe-name', 'Name', _name),
        const SizedBox(height: 12),
        field('recipe-servings', 'Servings', _servings, number: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: field(
                'recipe-prep',
                'Prep time (min)',
                _prep,
                number: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: field(
                'recipe-cook',
                'Cook time (min)',
                _cook,
                number: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(t('Ingredients'), style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < _ingredients.length; i++) ...[
          const SizedBox(height: 12),
          field('recipe-ingredient-name-$i', 'Name', _ingredients[i].name),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: field(
                  'recipe-ingredient-quantity-$i',
                  'Quantity',
                  _ingredients[i].quantity,
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ObjectKey(_ingredients[i]),
                  initialValue: _ingredients[i].unit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final unit in TrustedRecipeParser.allowedUnits)
                      DropdownMenuItem(
                        value: unit,
                        child: Text(
                          FoodPresentationLocalizer.servingUnit(unit, locale),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _ingredients[i].unit = value);
                          }
                        },
                ),
              ),
              IconButton(
                tooltip: t('Remove'),
                onPressed: _busy || _ingredients.length == 1
                    ? null
                    : () {
                        final removed = _ingredients[i];
                        setState(() => _ingredients.removeAt(i));
                        // Removed controllers are no longer referenced after this frame.
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => removed.dispose(),
                        );
                      },
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        ],
        TextButton.icon(
          onPressed: _busy || _ingredients.length >= 100
              ? null
              : () => setState(() => _ingredients.add(_IngredientFields(null))),
          icon: const Icon(Icons.add),
          label: Text(t('Add')),
        ),
        const SizedBox(height: 12),
        field('recipe-method', 'Method', _steps, lines: 4),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              t(
                'Check the required fields, quantities, units, times, and steps.',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('review-imported-recipe'),
          onPressed: _busy ? null : _review,
          child: Text(t('Review recipe')),
        ),
      ],
    );
  }
}

class _IngredientFields {
  _IngredientFields(this.original)
    : name = TextEditingController(text: original?.name),
      quantity = TextEditingController(text: '${original?.quantity ?? 100}'),
      unit = original?.unit ?? 'g';
  final TrustedRecipeIngredient? original;
  final TextEditingController name;
  final TextEditingController quantity;
  String unit;
  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}
